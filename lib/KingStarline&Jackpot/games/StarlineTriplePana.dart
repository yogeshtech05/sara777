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

class StarlineTPMotorsScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType; // e.g. "triplePana"
  final int gameId; // STARLINE session/slot id
  final String gameName; // human label like "12:30 PM"
  final bool selectionStatus; // true=open, false=closed

  const StarlineTPMotorsScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
    required this.selectionStatus,
  });

  @override
  State<StarlineTPMotorsScreen> createState() => _StarlineTPMotorsScreenState();
}

class _StarlineTPMotorsScreenState extends State<StarlineTPMotorsScreen> {
  // UI/session label only (Starline API ignores this)
  String selectedGameBetType = "OPEN";

  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  final List<String> triplePanaOptions = const [
    "111",
    "222",
    "333",
    "444",
    "555",
    "666",
    "777",
    "888",
    "999",
    "000",
  ];
  List<String> filteredDigitOptions = [];
  bool _isDigitSuggestionsVisible = false;

  final List<Map<String, String>> addedEntries =
      []; // {digit, amount, type, gameType}
  late final GetStorage storage;
  late final StarlineBidService _bidService;

  String accessToken = '';
  String registerId = '';
  bool accountStatus = false;
  int walletBalance = 0;
  int minBid = 10;
  static const int _maxBid = 1000;

  // device headers (from storage with fallbacks)
  String get _deviceId =>
      storage.read('deviceId')?.toString() ?? 'flutter_device';
  String get _deviceName =>
      storage.read('deviceName')?.toString() ?? 'Flutter_App';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  bool _isApiCalling = false;

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  bool get _biddingClosed => !widget.selectionStatus;

  @override
  void initState() {
    super.initState();
    storage = GetStorage();
    _bidService = StarlineBidService(storage);
    _loadInitialData();
    _syncWallet();
    digitController.addListener(_onDigitChanged);
  }

  void _syncWallet() {
    final raw = userController.walletBalance.value;
    final n = num.tryParse(raw);
    walletBalance = n?.toInt() ?? 0;
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;
    minBid = int.tryParse(storage.read('minBid')?.toString() ?? '10') ?? 10;

    // live wallet sync
    storage.listenKey('walletBalance', (val) {
      final parsed = int.tryParse(val?.toString() ?? '0') ?? 0;
      if (mounted) setState(() => walletBalance = parsed);
    });

    log(
      'TPMotors init: token=${accessToken.isNotEmpty}, reg=${registerId.isNotEmpty}, acc=$accountStatus, minBid=$minBid',
    );
  }

  @override
  void dispose() {
    digitController.removeListener(_onDigitChanged);
    digitController.dispose();
    pointsController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  // ---------- messages ----------
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

  // ---------- suggestions ----------
  void _onDigitChanged() {
    final q = digitController.text.trim();
    if (q.isEmpty) {
      setState(() {
        filteredDigitOptions = [];
        _isDigitSuggestionsVisible = false;
      });
      return;
    }
    setState(() {
      filteredDigitOptions = triplePanaOptions
          .where((d) => d.startsWith(q))
          .toList();
      _isDigitSuggestionsVisible = filteredDigitOptions.isNotEmpty;
    });
  }

  // ---------- add/remove ----------
  void _addEntry() {
    _clearMessage();
    if (_isApiCalling) return;

    if (_biddingClosed) {
      _showMessage('Bidding is closed for this slot.', isError: true);
      return;
    }

    final digit = digitController.text.trim();
    final pointsStr = pointsController.text.trim();

    if (digit.length != 3 || int.tryParse(digit) == null) {
      _showMessage('Enter a valid 3-digit number.', isError: true);
      return;
    }
    if (!triplePanaOptions.contains(digit)) {
      _showMessage('Invalid Triple Panna number.', isError: true);
      return;
    }
    if (pointsStr.isEmpty) {
      _showMessage('Please enter an amount.', isError: true);
      return;
    }

    final pts = int.tryParse(pointsStr);
    if (pts == null || pts < minBid || pts > _maxBid) {
      _showMessage(
        'Points must be between $minBid and $_maxBid.',
        isError: true,
      );
      return;
    }

    // wallet guard (with replacement logic)
    _syncWallet();
    int currentTotal = _getTotalPoints();
    final idx = addedEntries.indexWhere(
      (e) => e['digit'] == digit && e['type'] == selectedGameBetType,
    );
    if (idx != -1) {
      currentTotal -= int.tryParse(addedEntries[idx]['amount'] ?? '0') ?? 0;
    }
    if (currentTotal + pts > walletBalance) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    setState(() {
      if (idx != -1) {
        addedEntries[idx]['amount'] = pts.toString(); // replace (not sum)
        _showMessage('Updated bid for $digit.');
      } else {
        addedEntries.add({
          "digit": digit,
          "amount": pts.toString(),
          "type": selectedGameBetType, // "OPEN"
          "gameType": widget.gameCategoryType, // e.g. "triplePana"
        });
        _showMessage("Added bid: $digit - $pts points");
      }
      digitController.clear();
      pointsController.clear();
      _isDigitSuggestionsVisible = false;
      FocusScope.of(context).unfocus();
    });
  }

  void _removeEntry(int index) {
    _clearMessage();
    if (_isApiCalling || index < 0 || index >= addedEntries.length) return;

    setState(() {
      final removed = addedEntries[index];
      addedEntries.removeAt(index);
      _showMessage("Removed bid: ${removed['digit']}");
    });
  }

  int _getTotalPoints() {
    return addedEntries.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
    );
  }

  // ---------- confirm & submit ----------
  void _showConfirmationDialog() {
    _clearMessage();

    final int totalPoints = _getTotalPoints();
    if (_biddingClosed) {
      _showMessage("Bidding is closed for this slot.", isError: true);
      return;
    }
    if (totalPoints == 0) {
      _showMessage("No bids added to submit.", isError: true);
      return;
    }
    if (walletBalance < totalPoints) {
      _showMessage("Insufficient wallet balance.", isError: true);
      return;
    }

    final formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BidConfirmationDialog(
        gameTitle: widget.title,
        gameDate: formattedDate,
        bids: addedEntries.map((bid) {
          return {
            "digit": bid['digit']!,
            "points": bid['amount']!,
            "type": "${bid['gameType']} (${bid['type']})",
            "pana": bid['digit']!,
            "jodi": "",
          };
        }).toList(),
        totalBids: addedEntries.length,
        totalBidsAmount: totalPoints,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameCategoryType,
        onConfirm: () async {
          setState(() => _isApiCalling = true);
          final ok = await _placeFinalBids();
          if (mounted) setState(() => _isApiCalling = false);
          if (ok && mounted) setState(() => addedEntries.clear());
        },
      ),
    );
  }

  Future<bool> _placeFinalBids() async {
    // Build per-digit payload
    final Map<String, String> bidPayload = {};
    int total = 0;
    for (final e in addedEntries) {
      final d = e['digit'] ?? '';
      final a = int.tryParse(e['amount'] ?? '0') ?? 0;
      if (d.isNotEmpty && a > 0) {
        bidPayload[d] = a.toString();
        total += a;
      }
    }

    if (bidPayload.isEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const BidFailureDialog(errorMessage: 'No valid bids to submit.'),
      );
      return false;
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Authentication error. Please log in again.',
        ),
      );
      return false;
    }

    try {
      // This screen is always Starline
      // ✅ NEW (exactly matches your StarlineBidService signature)
      final result = await _bidService.placeFinalBids(
        market: Market.starline,
        accessToken: accessToken,
        registerId: registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: accountStatus,
        bidAmounts: bidPayload, // Map<String,String> -> {digit: amount}
        gameType: widget.gameCategoryType, // e.g. "triplePana" (server key)
        gameId: widget.gameId, // int (service will send as string)
        totalBidAmount: total, // int
      );

      if (!mounted) return false;

      if (result['status'] == true) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );

        // Wallet sync (prefer server field if present)
        final data = result['data'] as Map<String, dynamic>?;
        final dynamic serverBal =
            data?['updatedWalletBalance'] ?? data?['wallet_balance'];
        final int newBal =
            int.tryParse(serverBal?.toString() ?? '') ??
            (walletBalance - total);

        await _bidService.updateWalletBalance(newBal);
        userController.walletBalance.value = newBal.toString();
        if (mounted) setState(() => walletBalance = newBal);

        return true;
      } else {
        final msg = (result['msg'] ?? 'Something went wrong').toString();
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(errorMessage: msg),
        );
        return false;
      }
    } catch (e) {
      log('TPMotors placeFinalBids error: $e', name: 'StarlineTPMotorsScreen');
      if (!mounted) return false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'An unexpected error occurred during bid submission.',
        ),
      );
      return false;
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey.shade300,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
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
          if (widget.gameName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  widget.gameName, // session label (e.g., 12:30 PM)
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Image.asset(
            "assets/images/ic_wallet.png",
            width: 22,
            height: 22,
            color: Colors.black,
          ),
          const SizedBox(width: 6),
          Center(
            child: Obx(
              () => Text(
                userController.walletBalance.value,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
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
                if (_biddingClosed)
                  Container(
                    width: double.infinity,
                    color: Colors.amber.shade200,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      'Bidding is closed for this slot.',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _inputRow(
                        "Enter 3-Digit Triple Panna:",
                        _buildDigitInputField(),
                      ),
                      if (_isDigitSuggestionsVisible &&
                          filteredDigitOptions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredDigitOptions.length,
                            itemBuilder: (context, index) {
                              final suggestion = filteredDigitOptions[index];
                              return ListTile(
                                title: Text(suggestion),
                                onTap: () {
                                  setState(() {
                                    digitController.text = suggestion;
                                    _isDigitSuggestionsVisible = false;
                                    digitController.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(
                                            offset: digitController.text.length,
                                          ),
                                        );
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      _inputRow(
                        "Enter Points:",
                        _buildTextField(
                          pointsController,
                          "Enter Amount",
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isApiCalling || _biddingClosed
                                ? Colors.grey
                                : Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: (_isApiCalling || _biddingClosed)
                              ? null
                              : _addEntry,
                          child: _isApiCalling
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                              : const Text(
                                  "ADD BID",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
                const Divider(thickness: 1),
                if (addedEntries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Digit",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "Amount",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "Game Type",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                if (addedEntries.isNotEmpty) const Divider(thickness: 1),
                Expanded(
                  child: addedEntries.isEmpty
                      ? Center(
                          child: Text(
                            "No bids added yet",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: addedEntries.length,
                          itemBuilder: (_, index) {
                            final entry = addedEntries[index];
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
                                      entry['amount']!,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${entry['gameType']} (${entry['type']})',
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
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
                if (addedEntries.isNotEmpty) _buildBottomBar(),
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
    return SizedBox(
      width: double.infinity,
      height: 38, child: TextFormField(
        controller: digitController,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: [
          LengthLimitingTextInputFormatter(3),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: () {
          _clearMessage();
          if (digitController.text.isNotEmpty) _onDigitChanged();
        },
        onChanged: (_) => _onDigitChanged(),
        enabled: !_isApiCalling && !_biddingClosed,
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

          hintText: "Enter 3-Digit Triple Panna",
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

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      width: 150,
      height: 38, child: TextFormField(
        controller: controller,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: inputFormatters,
        onTap: _clearMessage,
        enabled: !_isApiCalling && !_biddingClosed,
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
    final totalBids = addedEntries.length;
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
          _footStat('Bids', '$totalBids'),
          _footStat('Points', '$totalPoints'),
          ElevatedButton(
            onPressed: (_isApiCalling || totalPoints == 0 || _biddingClosed)
                ? null
                : _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  (_isApiCalling || totalPoints == 0 || _biddingClosed)
                  ? Colors.grey
                  : Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: _isApiCalling
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
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

  Widget _footStat(String label, String value) {
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
