import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:new_sara/KingStarline&Jackpot/StarlineBidService.dart';

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';

/// Simple model for Starline sessions (id + human label)
class StarlineSession {
  final int id;
  final String timeLabel; // e.g., "09:30 PM"
  StarlineSession({required this.id, required this.timeLabel});
}

class StarlineSingleDigitBetScreen extends StatefulWidget {
  final String title; // e.g., "Starline Single Digit"
  final String gameCategoryType; // e.g., "singleDigits"
  final int gameId; // TYPE id (sent as STRING)
  final String gameName; // e.g., "Starline ..." / "Jackpot ..."
  final bool selectionStatus; // true => bidding open (UI)

  /// Optional Starline time-slot info (UI only; not sent to API)
  final int? starlineSessionId;
  final String? starlineSessionTimeLabel;
  final List<StarlineSession>? sessions;
  final bool autoPickSession;

  const StarlineSingleDigitBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
    required this.selectionStatus,
    this.starlineSessionId,
    this.starlineSessionTimeLabel,
    this.sessions,
    this.autoPickSession = true,
  });

  @override
  State<StarlineSingleDigitBetScreen> createState() =>
      _StarlineSingleDigitBetScreenState();
}

class _StarlineSingleDigitBetScreenState
    extends State<StarlineSingleDigitBetScreen> {
  /// Amount limits (minBid can be overridden from storage)
  static const int _defaultMinBet = 10;
  static const int _maxBet = 1000;

  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  final List<String> _digitOptions = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
  ];
  List<String> _filteredDigitOptions = [];
  bool _isDigitSuggestionsVisible = false;

  /// Local entries: {digit, points}
  final List<Map<String, String>> _addedEntries = [];

  late final GetStorage _storage = GetStorage();
  late final StarlineBidService _bidService;

  late String _registerId;
  bool _accountStatus = false;
  late int _walletBalance;
  bool _isApiCalling = false;

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  // Worker to react to controller updates
  Worker? _walletWorker;

  // UI-only (if provided); not required for API
  String? _resolvedSessionTime;

  @override
  void initState() {
    super.initState();
    _bidService = StarlineBidService(_storage);

    // ---- Wallet source of truth: UserController ----
    // Initial value: try controller first, then storage (digits only)
    double walletBalance = double.parse(userController.walletBalance.value);
    int walletBalanceInt = walletBalance.toInt();
    _walletBalance = walletBalanceInt;

    _loadInitialData();
    digitController.addListener(_onDigitChanged);
    _resolveSessionLabelForUi();
  }

  void _resolveSessionLabelForUi() {
    // show a time label if we can; purely cosmetic
    _resolvedSessionTime = widget.starlineSessionTimeLabel;
    if (_resolvedSessionTime == null &&
        (widget.sessions?.isNotEmpty ?? false) &&
        widget.autoPickSession) {
      final now = DateTime.now();
      final fmt = DateFormat('hh:mm a');
      for (final s in widget.sessions!) {
        try {
          final t = fmt.parse(s.timeLabel);
          final candidate = DateTime(
            now.year,
            now.month,
            now.day,
            t.hour,
            t.minute,
          );
          if (!candidate.isBefore(now)) {
            _resolvedSessionTime = s.timeLabel;
            break;
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _loadInitialData() async {
    _registerId = _storage.read('registerId') ?? '';
    _accountStatus = userController.accountStatus.value;
  }

  @override
  void dispose() {
    digitController.removeListener(_onDigitChanged);
    digitController.dispose();
    pointsController.dispose();
    _messageDismissTimer?.cancel();
    _walletWorker?.dispose();
    super.dispose();
  }

  // -------- helpers --------
  Market _detectMarket() {
    final s = ('${widget.title} ${widget.gameName}').toLowerCase();
    return s.contains('jackpot') ? Market.jackpot : Market.starline;
  }

  bool get _biddingClosed => !widget.selectionStatus;

  void _onDigitChanged() {
    final text = digitController.text;
    if (text.isEmpty) {
      setState(() {
        _filteredDigitOptions = [];
        _isDigitSuggestionsVisible = false;
      });
      return;
    }
    setState(() {
      _filteredDigitOptions = _digitOptions
          .where((o) => o.startsWith(text))
          .toList();
      _isDigitSuggestionsVisible = _filteredDigitOptions.isNotEmpty;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    _messageDismissTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
    _messageDismissTimer = Timer(const Duration(seconds: 3), _clearMessage);
  }

  void _clearMessage() {
    if (!mounted) return;
    setState(() => _messageToShow = null);
    _messageDismissTimer?.cancel();
  }

  int _getTotalPoints() {
    return _addedEntries.fold<int>(
      0,
      (sum, e) => sum + (int.tryParse(e['points'] ?? '0') ?? 0),
    );
  }

  // -------- add/remove --------
  void _addEntry() {
    _clearMessage();
    if (_isApiCalling) return;

    if (_biddingClosed) {
      _showMessage('Bidding is closed for this slot.', isError: true);
      return;
    }

    final digit = digitController.text.trim();
    final pointsStr = pointsController.text.trim();

    if (digit.isEmpty || digit.length != 1 || !_digitOptions.contains(digit)) {
      _showMessage('Please enter a valid single digit (0-9).', isError: true);
      return;
    }
    if (pointsStr.isEmpty) {
      _showMessage('Please enter an amount.', isError: true);
      return;
    }

    final fromStorage =
        int.tryParse(_storage.read('minBid')?.toString() ?? '') ??
        _defaultMinBet;
    final minBid = fromStorage > 0 ? fromStorage : _defaultMinBet;

    final points = int.tryParse(pointsStr);
    if (points == null) {
      _showMessage('Amount must be a number.', isError: true);
      return;
    }
    if (points < minBid || points > _maxBet) {
      _showMessage(
        'Amount must be between $minBid and $_maxBet.',
        isError: true,
      );
      return;
    }

    // Calculate total after replacing/adding this entry
    int currentTotal = _getTotalPoints();
    final idx = _addedEntries.indexWhere((e) => e['digit'] == digit);
    if (idx != -1) {
      currentTotal -= (int.tryParse(_addedEntries[idx]['points'] ?? '0') ?? 0);
    }
    final totalWithNew = currentTotal + points;
    if (totalWithNew > _walletBalance) {
      _showMessage(
        'Insufficient wallet balance to place these bids.',
        isError: true,
      );
      return;
    }

    setState(() {
      if (idx != -1) {
        _addedEntries[idx]['points'] = points.toString();
        _showMessage('Updated digit $digit amount to $points.');
      } else {
        _addedEntries.add({'digit': digit, 'points': points.toString()});
        _showMessage('Added bid: Digit $digit, Amount $points.');
      }
      digitController.clear();
      pointsController.clear();
      _isDigitSuggestionsVisible = false;
    });
  }

  void _removeEntry(int index) {
    _clearMessage();
    if (_isApiCalling) return;
    setState(() {
      final removed = _addedEntries[index];
      _addedEntries.removeAt(index);
      _showMessage('Removed bid: Digit ${removed['digit']}.');
    });
  }

  // -------- confirm & submit --------
  void _showConfirmationDialog() {
    FocusScope.of(context).unfocus();
    _clearMessage();
    if (_isApiCalling) return;

    if (_addedEntries.isEmpty) {
      _showMessage(
        'Please add at least one bid before submitting.',
        isError: true,
      );
      return;
    }
    if (_biddingClosed) {
      _showMessage('Bidding is closed for this slot.', isError: true);
      return;
    }

    final totalPointsForConfirmation = _getTotalPoints();
    if (totalPointsForConfirmation > _walletBalance) {
      _showMessage('Insufficient wallet balance to submit.', isError: true);
      return;
    }

    final bidsForConfirmation = _addedEntries
        .map((e) => {'digit': e['digit']!, 'points': e['points']!})
        .toList();

    final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BidConfirmationDialog(
        gameTitle: widget.title,
        gameDate: formattedDate,
        bids: bidsForConfirmation,
        totalBids: bidsForConfirmation.length,
        totalBidsAmount: totalPointsForConfirmation,
        walletBalanceBeforeDeduction: _walletBalance,
        walletBalanceAfterDeduction:
            (_walletBalance - totalPointsForConfirmation).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameCategoryType,
        onConfirm: () async {
          await _placeFinalBids();
        },
      ),
    );
  }

  Future<void> _placeFinalBids() async {
    if (!mounted) return;

    setState(() => _isApiCalling = true);
    _clearMessage();
    FocusScope.of(context).unfocus();

    if (_addedEntries.isEmpty) {
      _showMessage('No bids to submit.', isError: true);
      if (mounted) setState(() => _isApiCalling = false);
      return;
    }

    final accessToken = _storage.read('accessToken') as String?;
    final deviceId = _storage.read('deviceId') as String?;
    final deviceName = _storage.read('deviceName') as String?;
    print("TOKEN: $accessToken");
    print("DEVICE ID: $deviceId");
    print("DEVICE NAME: $deviceName");
    if (accessToken == null || deviceId == null || deviceName == null) {
      _showMessage('Authentication error. Please log in again.', isError: true);
      if (mounted) setState(() => _isApiCalling = false);
      return;
    }

    // Build (digit -> amount) map
    final bidAmounts = <String, String>{};
    var totalBidAmount = 0;
    for (final bid in _addedEntries) {
      final d = bid['digit'];
      final p = int.tryParse(bid['points'] ?? '0') ?? 0;
      if (d != null && p > 0) {
        bidAmounts[d] = p.toString();
        totalBidAmount += p;
      }
    }

    try {
      final market = _detectMarket();

      final resp = await _bidService.placeFinalBids(
        market: market,
        accessToken: accessToken,
        registerId: _registerId,
        deviceId: deviceId,
        deviceName: deviceName,
        accountStatus: _accountStatus,
        bidAmounts: bidAmounts,
        gameId: widget.gameId, // TYPE id (as STRING in API)
        gameType: widget.gameCategoryType, // e.g. "singleDigits"
        totalBidAmount: totalBidAmount,
      );

      if (!mounted) return;

      if (resp['status'] == true) {
        // Prefer server wallet if available
        final dynamic serverBal =
            resp['updatedWalletBalance'] ??
            resp['data']?['updatedWalletBalance'] ??
            resp['data']?['wallet_balance'];

        final int newBalance =
            int.tryParse(serverBal?.toString() ?? '') ??
            (_walletBalance - totalBidAmount);

        setState(() {
          _walletBalance = newBalance;
          _addedEntries.clear();
          digitController.clear();
          pointsController.clear();
          _isDigitSuggestionsVisible = false;
        });

        // Persist + broadcast
        await _bidService.updateWalletBalance(newBalance);
        userController.walletBalance.value = newBalance.toString();

        _showMessage('All bids submitted successfully!');
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );
      } else {
        final err = (resp['msg'] as String?) ?? 'Unknown error occurred.';
        _showMessage(err, isError: true);
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(errorMessage: err),
        );
      }
    } catch (e) {
      log('Bid submission error: $e');
      final msg = 'An unexpected error occurred: $e';
      _showMessage(msg, isError: true);
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => BidFailureDialog(errorMessage: msg),
      );
    } finally {
      if (mounted) setState(() => _isApiCalling = false);
    }
  }

  // -------- UI --------
  @override
  Widget build(BuildContext context) {
    final isStarline = widget.gameName.toLowerCase().contains('starline');
    return WillPopScope(
      onWillPop: () async => !_isApiCalling,
      child: Scaffold(
        backgroundColor: Colors.grey.shade200,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.grey.shade300,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: _isApiCalling ? Colors.grey : Colors.black,
            ),
            onPressed: _isApiCalling ? null : () => Navigator.pop(context),
          ),
          title: Text(
            widget.title,
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          actions: [
            if (isStarline && _resolvedSessionTime != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Text(
                    _resolvedSessionTime!,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            Image.asset(
              'assets/images/ic_wallet.png',
              width: 22,
              height: 22,
              color: Colors.black,
            ),
            const SizedBox(width: 6),
            Center(
              child: Text(
                '$_walletBalance',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      children: [
                        _inputRow(
                          'Enter Single Digit:',
                          _buildDigitInputField(),
                        ),
                        const SizedBox(height: 12),
                        _inputRow(
                          'Enter Points:',
                          _buildAmountField(pointsController, 'Enter Amount'),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isApiCalling
                                  ? Colors.grey
                                  : Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: _isApiCalling ? null : _addEntry,
                            child: _isApiCalling
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'ADD BID',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_biddingClosed)
                          Text(
                            'Bidding is closed for this slot.',
                            style: GoogleFonts.poppins(color: Colors.orange),
                          ),
                      ],
                    ),
                  ),
                  const Divider(thickness: 1),
                  if (_addedEntries.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Digit',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Amount',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  if (_addedEntries.isNotEmpty) const Divider(thickness: 1),
                  Expanded(
                    child: _addedEntries.isEmpty
                        ? const Center(child: Text('No data added yet'))
                        : ListView.builder(
                            itemCount: _addedEntries.length,
                            itemBuilder: (_, index) {
                              final entry = _addedEntries[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry['digit']!,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        entry['points']!,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    const SizedBox(width: 48),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.orange,
                                      ),
                                      onPressed: _isApiCalling
                                          ? null
                                          : () => _removeEntry(index),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  if (_addedEntries.isNotEmpty) _buildBottomBar(),
                ],
              ),
              if (_messageToShow != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedMessageBar(
                    key: _messageBarKey,
                    message: _messageToShow!,
                    isError: _isErrorForMessage,
                    onDismissed: _clearMessage,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(flex: 3, child: field),
        ],
      ),
    );
  }

  Widget _buildDigitInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 38, child: TextFormField(
            controller: digitController,
            cursorColor: Colors.orange,
            keyboardType: const TextInputType.numberWithOptions(
              signed: false,
              decimal: false,
            ),
            style: GoogleFonts.poppins(fontSize: 14),
            inputFormatters: [
              LengthLimitingTextInputFormatter(1),
              FilteringTextInputFormatter.digitsOnly,
            ],
            onTap: _clearMessage,
            enabled: !_isApiCalling,
            decoration: InputDecoration(
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Color(0xFFF9B233),
                  size: 16,
                ),
              ),
            ),

              hintText: 'Enter Digit',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 0,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (_isDigitSuggestionsVisible)
          Container(
            width: 150,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _filteredDigitOptions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  title: Text(_filteredDigitOptions[index]),
                  onTap: () {
                    setState(() {
                      digitController.text = _filteredDigitOptions[index];
                      _isDigitSuggestionsVisible = false;
                      FocusScope.of(context).unfocus();
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAmountField(TextEditingController controller, String hint) {
    return SizedBox(
      width: 150,
      height: 38, child: TextFormField(
        controller: controller,
        cursorColor: Colors.orange,
        keyboardType: const TextInputType.numberWithOptions(
          signed: false,
          decimal: false,
        ),
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onTap: _clearMessage,
        enabled: !_isApiCalling,
        decoration: InputDecoration(
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Color(0xFFF9B233),
                  size: 16,
                ),
              ),
            ),

          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
          enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
          focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final totalBids = _addedEntries.length;
    final totalPoints = _getTotalPoints();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stat('Bids', '$totalBids'),
          _stat('Points', '$totalPoints'),
          ElevatedButton(
            onPressed: (_isApiCalling || _addedEntries.isEmpty)
                ? null
                : _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: (_isApiCalling || _addedEntries.isEmpty)
                  ? Colors.grey
                  : Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: _isApiCalling
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'SUBMIT',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
