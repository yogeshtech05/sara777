// lib/screens/odd_even_board_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:marquee/marquee.dart';

import '../../BidService.dart';
import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../components/GameTypeSelectorField.dart';

enum GameType { odd, even }

enum LataDayType { open, close }

class OddEvenBoardScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameType; // e.g. "oddEven"
  final String gameName;
  final bool
  selectionStatus; // true => OPEN + CLOSE visible, false => only CLOSE

  const OddEvenBoardScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameType,
    this.gameName = "",
    required this.selectionStatus,
  }) : super(key: key);

  @override
  State<OddEvenBoardScreen> createState() => _OddEvenBoardScreenState();
}

class _OddEvenBoardScreenState extends State<OddEvenBoardScreen> {
  // Inputs
  GameType? _selectedGameType = GameType.odd;
  LataDayType? _selectedLataDayType;
  final TextEditingController _pointsController = TextEditingController();

  /// each entry: { digit, points, type: OPEN/CLOSE, group: ODD/EVEN }
  final List<Map<String, String>> _entries = [];

  // Auth / state
  final GetStorage storage = GetStorage();
  late String _accessToken;
  late String _registerId;
  late bool _accountStatus;
  late int _walletBalance;

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  // Services
  late final BidService _bidService;

  // Message bar
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _msgTimer;

  bool _isApiCalling = false;

  static const List<String> _oddDigits = ['1', '3', '5', '7', '9'];
  static const List<String> _evenDigits = ['0', '2', '4', '6', '8'];

  @override
  void initState() {
    super.initState();
    _bidService = BidService(storage);

    _accessToken = storage.read('accessToken') ?? '';
    _registerId = storage.read('registerId') ?? '';
    _accountStatus = userController.accountStatus.value;

    final num? bal = num.tryParse(userController.walletBalance.value);
    _walletBalance = bal?.toInt() ?? 0;

    _selectedLataDayType = widget.selectionStatus
        ? LataDayType.open
        : LataDayType.close;
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  // -------- messages --------
  void _showMessage(String message, {bool isError = false}) {
    _msgTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
    _msgTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _messageToShow = null);
    });
  }

  void _clearMessage() {
    if (!mounted) return;
    setState(() => _messageToShow = null);
  }

  // -------- helpers --------
  int _getTotalPoints() =>
      _entries.fold(0, (s, e) => s + (int.tryParse(e['points'] ?? '0') ?? 0));

  int _totalFor(String session) => _entries
      .where((e) => e['type'] == session)
      .fold(0, (s, e) => s + (int.tryParse(e['points'] ?? '0') ?? 0));

  Map<String, String> _mapFor(String session) => {
    for (final e in _entries.where((e) => e['type'] == session))
      e['digit']!: e['points']!,
  };

  // -------- add / remove --------
  void _addEntry() {
    _clearMessage();
    if (_isApiCalling) return;

    final ptsTxt = _pointsController.text.trim();
    final pts = int.tryParse(ptsTxt);
    if (pts == null || pts < 10 || pts > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }
    if (_selectedGameType == null) {
      _showMessage('Please select Odd or Even.', isError: true);
      return;
    }

    final session = _selectedLataDayType == LataDayType.close
        ? 'CLOSE'
        : 'OPEN';
    final group = _selectedGameType == GameType.odd ? 'ODD' : 'EVEN';
    final digits = _selectedGameType == GameType.odd ? _oddDigits : _evenDigits;

    // wallet guard for this add (5 digits)
    final futureTotal = _getTotalPoints() + (pts * digits.length);
    if (futureTotal > _walletBalance) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    setState(() {
      // merge by (digit + session)
      for (final d in digits) {
        final i = _entries.indexWhere(
          (e) => e['digit'] == d && e['type'] == session,
        );
        if (i != -1) {
          final curr = int.tryParse(_entries[i]['points'] ?? '0') ?? 0;
          _entries[i]['points'] = (curr + pts).toString();
        } else {
          _entries.add({
            'digit': d,
            'points': pts.toString(),
            'type': session,
            'group': group,
          });
        }
      }
      _pointsController.clear();
    });

    _showMessage('Added $group ($session): ${digits.join(", ")}');
  }

  void _deleteEntry(int index) {
    _clearMessage();
    setState(() {
      final removed = _entries.removeAt(index);
      _showMessage('Removed ${removed['digit']} (${removed['type']}).');
    });
  }

  // -------- confirm & submit (now for BOTH sessions) --------
  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    if (_entries.isEmpty) {
      _showMessage('Please add at least one bid.', isError: true);
      return;
    }

    final totalAll = _getTotalPoints();
    if (_walletBalance < totalAll) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    // show BOTH sessions in the dialog
    final bidsForDialog = _entries
        .map(
          (e) => {
            "digit": e['digit']!,
            "points": e['points']!,
            "type": e['type']!, // OPEN/CLOSE
            "pana":
                e['digit']!, // non-empty to satisfy any validation in dialog
          },
        )
        .toList();

    final whenStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.title,
        gameDate: whenStr,
        bids: bidsForDialog,
        totalBids: bidsForDialog.length,
        totalBidsAmount: totalAll,
        walletBalanceBeforeDeduction: _walletBalance,
        walletBalanceAfterDeduction: (_walletBalance - totalAll).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () async {
          if (!mounted) return;
          setState(() => _isApiCalling = true);
          final ok = await _submitBothSessions();
          if (mounted) setState(() => _isApiCalling = false);
          if (ok) {
            setState(() => _entries.clear());
          }
        },
      ),
    );
  }

  /// Submits OPEN and CLOSE in separate calls if present.
  Future<bool> _submitBothSessions() async {
    if (_accessToken.isEmpty || _registerId.isEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Authentication error. Please log in again.',
        ),
      );
      return false;
    }

    final hasOpen = _entries.any((e) => e['type'] == 'OPEN');
    final hasClose = _entries.any((e) => e['type'] == 'CLOSE');

    bool openOk = true;
    bool closeOk = true;
    int walletAfter = _walletBalance;

    // helper to submit one session
    Future<Map<String, dynamic>> _submitSession(
      String session,
      Map<String, String> bidMap,
      int sessionTotal,
    ) {
      return _bidService.placeFinalBids(
        gameName: widget.gameName,
        accessToken: _accessToken,
        registerId: _registerId,
        deviceId: storage.read('deviceId')?.toString() ?? 'odd_even_device',
        deviceName: storage.read('deviceName')?.toString() ?? 'OddEvenBoardApp',
        accountStatus: _accountStatus,
        bidAmounts: bidMap,
        selectedGameType: session, // "OPEN" or "CLOSE"
        gameId: widget.gameId,
        gameType: widget.gameType, // "oddEven"
        totalBidAmount: sessionTotal,
      );
    }

    // OPEN first (order doesn't really matter)
    if (hasOpen) {
      final openMap = _mapFor('OPEN');
      final openTotal = _totalFor('OPEN');
      final r = await _submitSession('OPEN', openMap, openTotal);
      if (r['status'] == true) {
        final dynamic updated = r['updatedWalletBalance'];
        walletAfter =
            int.tryParse(updated?.toString() ?? '') ??
            (walletAfter - openTotal);
        // remove OPEN rows from list (they are done)
        setState(() => _entries.removeWhere((e) => e['type'] == 'OPEN'));
      } else {
        openOk = false;
      }
    }

    // CLOSE next
    if (hasClose) {
      final closeMap = _mapFor('CLOSE');
      final closeTotal = _totalFor('CLOSE');
      final r = await _submitSession('CLOSE', closeMap, closeTotal);
      if (r['status'] == true) {
        final dynamic updated = r['updatedWalletBalance'];
        walletAfter =
            int.tryParse(updated?.toString() ?? '') ??
            (walletAfter - closeTotal);
        // remove CLOSE rows from list (they are done)
        setState(() => _entries.removeWhere((e) => e['type'] == 'CLOSE'));
      } else {
        closeOk = false;
      }
    }

    // Update wallet if anything succeeded
    if (openOk || closeOk) {
      await _bidService.updateWalletBalance(walletAfter);
      userController.walletBalance.value = walletAfter.toString();
      setState(() => _walletBalance = walletAfter);
    }

    if (openOk && closeOk) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidSuccessDialog(),
      );
      _clearMessage();
      return true;
    }

    // partial / full fail
    final msg = (!openOk && !closeOk)
        ? 'Place bid failed for all sessions. Please try again later.'
        : 'Some bids were placed, but others failed. Please review.';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidFailureDialog(errorMessage: msg),
    );
    return false;
  }

  // -------- UI --------
  @override
  Widget build(BuildContext context) {
    final types = widget.selectionStatus
        ? const [LataDayType.open, LataDayType.close]
        : const [LataDayType.close];

    if (!types.contains(_selectedLataDayType)) {
      _selectedLataDayType = types.first;
    }

    final totalBids = _entries.length;
    final totalPoints = _getTotalPoints();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title.toUpperCase(),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        actions: [
          Image.asset(
            "assets/images/ic_wallet.png",
            width: 22,
            height: 22,
            color: Colors.black,
          ),
          const SizedBox(width: 5),
          Center(
            child: Obx(
              () => Text(
                userController.walletBalance.value,
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      _row(
                        'Select Game Type',
                        GameTypeSelectorField(
                          selectedOption: _selectedLataDayType == LataDayType.open ? 'OPEN' : 'CLOSE',
                          options: types.map((t) => t == LataDayType.open ? 'OPEN' : 'CLOSE').toList(),
                          enabled: !_isApiCalling,
                          displayTextBuilder: (val) => "${widget.title} $val".toUpperCase(),
                          onSelected: (val) {
                            setState(() {
                              _selectedLataDayType = val == 'OPEN' ? LataDayType.open : LataDayType.close;
                              _clearMessage();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _row(
                        'Select Option',
                        _gameTypeRadioGroup(),
                      ),
                      const SizedBox(height: 12),
                      _row(
                        'Enter Points :',
                        SizedBox(
                          height: 38,
                          child: TextFormField(
                            controller: _pointsController,
                            cursorColor: Colors.orange,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _tfDecoration('Enter Points'),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            flex: 2,
                            child: SizedBox(),
                          ),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 38,
                              child: ElevatedButton(
                                onPressed: _isApiCalling ? null : _addEntry,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isApiCalling
                                      ? Colors.grey
                                      : const Color(0xFFF9B233),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'ADD',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(thickness: 1, height: 1),
                if (_entries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 28,
                      right: 28,
                      top: 8,
                      bottom: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Digit',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Points',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Type',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 38),
                      ],
                    ),
                  ),
                if (_entries.isNotEmpty) const Divider(thickness: 1, height: 1),
                Expanded(
                  child: _entries.isEmpty
                      ? Center(
                          child: Text(
                            'No Bids Added',
                            style: GoogleFonts.poppins(
                              color: Colors.black38,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final e = _entries[index];
                            return _buildEntryItem(
                              e['digit']!,
                              e['points']!,
                              e['type']!,
                              index,
                            );
                          },
                        ),
                ),
                if (_entries.isNotEmpty) _buildBottomBar(totalBids, totalPoints),
              ],
            ),
            if (_messageToShow != null)
              AnimatedMessageBar(
                key: _messageBarKey,
                message: _messageToShow!,
                isError: _isErrorForMessage,
                onDismissed: _clearMessage,
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, Widget field) {
    String cleanedLabel = label;
    if (label.contains('Select Game Type')) {
      cleanedLabel = 'Select Game Type';
    } else if (label.contains('Select Option')) {
      cleanedLabel = 'Select Option';
    } else if (label.contains('Enter Points')) {
      cleanedLabel = 'Enter Points :';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              cleanedLabel,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF333333),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: field,
          ),
        ],
      ),
    );
  }

  Widget _gameTypeRadioGroup() {
    return Row(
      children: [
        Expanded(child: _gameTypeRadio(GameType.odd, 'Odd')),
        Expanded(child: _gameTypeRadio(GameType.even, 'Even')),
      ],
    );
  }

  Widget _gameTypeRadio(GameType type, String label) {
    return InkWell(
      onTap: () => setState(() => _selectedGameType = type),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<GameType>(
            value: type,
            groupValue: _selectedGameType,
            onChanged: (v) => setState(() => _selectedGameType = v),
            activeColor: const Color(0xFFF9B233),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _tfDecoration(String hint) => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.only(
          left: 16,
          right: 4,
        ),
        filled: true,
        fillColor: Colors.white,
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
      );

  InputDecoration _ddDecoration() => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.only(left: 14, right: 6),
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
      );

  Widget _buildEntryItem(String digit, String points, String type, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              digit,
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              points,
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              type.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: type.toLowerCase() == 'open'
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _deleteEntry(index),
            child: const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: Icon(
                Icons.delete,
                color: Color(0xFFC62828),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(int totalBids, int totalPoints) {
    final canSubmit = !_isApiCalling && _entries.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFF9B233),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bids',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalBids',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Points',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalPoints',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 38,
              child: ElevatedButton(
                onPressed: canSubmit ? _showConfirmationDialog : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit ? const Color(0xFFF9B233) : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: _isApiCalling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'SUBMIT',
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
