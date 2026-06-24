import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:new_sara/KingStarline&Jackpot/StarlineBidService.dart';

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';

enum GameType { odd, even }

class StarlineOddEvenBoardScreen extends StatefulWidget {
  final String title;
  final int gameId; // TYPE id (sent as STRING in API)
  final String gameType; // e.g. "oddEven"
  final String gameName; // label
  final bool selectionStatus; // UI only

  const StarlineOddEvenBoardScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameType,
    this.gameName = "",
    required this.selectionStatus,
  }) : super(key: key);

  @override
  _StarlineOddEvenBoardScreenState createState() =>
      _StarlineOddEvenBoardScreenState();
}

class _StarlineOddEvenBoardScreenState
    extends State<StarlineOddEvenBoardScreen> {
  GameType? _selectedGameType = GameType.odd; // default Odd
  final TextEditingController _pointsController = TextEditingController();

  /// Parent entries: each is one Odd/Even line with points
  /// { "points": "xx", "bidType": "Odd"|"Even" }
  final List<Map<String, String>> _entries = [];

  // services / auth
  final GetStorage storage = GetStorage();
  late final StarlineBidService _bidService;
  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  String _accessToken = '';
  String _registerId = '';
  bool _accountStatus = false;
  int _walletBalance = 0;
  bool _isApiCalling = false;

  // messages
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _msgTimer;

  // UI session label only (API me sessionType nahi bhejte)
  String get _lockedSession => widget.selectionStatus ? 'OPEN' : 'CLOSE';

  @override
  void initState() {
    super.initState();
    _bidService = StarlineBidService(storage);

    _accessToken = storage.read('accessToken') ?? '';
    _registerId = storage.read('registerId') ?? '';
    _accountStatus = userController.accountStatus.value;

    final num? bal = num.tryParse(userController.walletBalance.value);
    _walletBalance = bal?.toInt() ?? 0;

    // live wallet sync
    storage.listenKey('walletBalance', (value) {
      final int newBal = int.tryParse(value?.toString() ?? '0') ?? 0;
      if (mounted) setState(() => _walletBalance = newBal);
    });
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  // ---------- messaging ----------
  void _showMessage(String message, {bool isError = false}) {
    _msgTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
    _msgTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _messageToShow = null);
    });
  }

  void _clearMessage() {
    if (!mounted) return;
    if (_messageToShow != null) setState(() => _messageToShow = null);
  }

  // ---------- helpers ----------
  Market _detectMarket() {
    final s = ('${widget.title} ${widget.gameName}').toLowerCase();
    return s.contains('jackpot') ? Market.jackpot : Market.starline;
  }

  List<String> _digitsForType(String bidType) =>
      bidType == 'Odd' ? ['1', '3', '5', '7', '9'] : ['0', '2', '4', '6', '8'];

  /// Each map: {digit, points, bidType, parentIndex}
  List<Map<String, dynamic>> _expandedRowsForUi() {
    final out = <Map<String, dynamic>>[];
    for (int i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      final pts = e['points'] ?? '0';
      final type = e['bidType'] ?? 'Odd';
      for (final d in _digitsForType(type)) {
        out.add({'digit': d, 'points': pts, 'bidType': type, 'parentIndex': i});
      }
    }
    return out;
  }

  /// Build bulk bid map for API: {digit: points} and true total
  (Map<String, String>, int) _buildBidMapAndTrueTotal() {
    final Map<String, String> out = {};
    int trueTotal = 0;
    for (final e in _entries) {
      final pts = int.tryParse(e['points'] ?? '0') ?? 0;
      if (pts <= 0) continue;
      for (final d in _digitsForType(e['bidType'] ?? 'Odd')) {
        out[d] = pts.toString();
        trueTotal += pts;
      }
    }
    return (out, trueTotal);
  }

  int _getUiTotalPoints() {
    final (_, total) = _buildBidMapAndTrueTotal();
    return total;
  }

  // ---------- add/remove ----------
  void _addEntry() {
    if (_isApiCalling) return;
    _clearMessage();

    final points = _pointsController.text.trim();
    final int? parsed = int.tryParse(points);
    if (parsed == null || parsed < 10 || parsed > 1000) {
      _showMessage('Points 10–1000 ke beech do.', isError: true);
      return;
    }

    final bidType = _selectedGameType == GameType.odd ? 'Odd' : 'Even';

    setState(() {
      // keep single row per type (replace if exists)
      _entries.removeWhere((e) => e['bidType'] == bidType);
      _entries.add({'points': points, 'bidType': bidType});
      _pointsController.clear();
    });

    _showMessage('$bidType bid added!');
  }

  void _deleteParentByIndex(int parentIndex) {
    if (_isApiCalling) return;
    _clearMessage();
    if (parentIndex < 0 || parentIndex >= _entries.length) return;
    setState(() => _entries.removeAt(parentIndex));
    _showMessage('Entry deleted.');
  }

  // ---------- confirm & submit ----------
  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    if (_entries.isEmpty) {
      _showMessage('Pehle koi entry add karo.', isError: true);
      return;
    }

    final (bidMap, trueTotal) = _buildBidMapAndTrueTotal();
    if (_walletBalance < trueTotal) {
      _showMessage('Wallet balance kam hai.', isError: true);
      return;
    }

    final rows = _expandedRowsForUi()
        .map(
          (r) => {
            'digit': r['digit'] as String,
            'pana': '',
            'points': r['points'] as String,
            'type': _lockedSession, // UI label only
            'bidType': r['bidType'] as String,
          },
        )
        .toList();

    final when = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.title,
        gameDate: when,
        bids: rows,
        totalBids: rows.length,
        totalBidsAmount: trueTotal,
        walletBalanceBeforeDeduction: _walletBalance,
        walletBalanceAfterDeduction: (_walletBalance - trueTotal).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () async {
          if (!mounted) return;
          setState(() => _isApiCalling = true);
          final ok = await _placeFinalBids(bidMap, trueTotal);
          if (!mounted) return;
          setState(() => _isApiCalling = false);
          if (ok) setState(() => _entries.clear());
        },
      ),
    );
  }

  Future<bool> _placeFinalBids(
    Map<String, String> bidMap,
    int trueTotal,
  ) async {
    if (_accessToken.isEmpty || _registerId.isEmpty) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Authentication error. Please log in again.',
        ),
      );
      return false;
    }

    // device info from storage (fallbacks)
    final deviceId = storage.read('deviceId')?.toString() ?? 'odd_even_device';
    final deviceName =
        storage.read('deviceName')?.toString() ?? 'OddEvenBoardApp';

    try {
      final market = _detectMarket();

      // Single unified payload; only endpoint differs by market.
      final resp = await _bidService.placeFinalBids(
        market: market,
        accessToken: _accessToken,
        registerId: _registerId,
        deviceId: deviceId,
        deviceName: deviceName,
        accountStatus: _accountStatus,
        bidAmounts: bidMap, // per-digit
        gameId: widget.gameId, // TYPE id (sent as STRING)
        gameType: widget.gameType, // e.g. "oddEven"
        totalBidAmount: trueTotal,
      );

      if (resp['status'] == true) {
        // Prefer server wallet
        final dynamic updatedBalanceRaw =
            resp['updatedWalletBalance'] ??
            resp['data']?['updatedWalletBalance'] ??
            resp['data']?['wallet_balance'];
        final int newBal =
            int.tryParse(updatedBalanceRaw?.toString() ?? '') ??
            (_walletBalance - trueTotal);

        await _bidService.updateWalletBalance(newBal);
        userController.walletBalance.value = newBal.toString();

        if (mounted) {
          setState(() => _walletBalance = newBal);
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const BidSuccessDialog(),
          );
        }
        return true;
      } else {
        final msg = (resp['msg'] ?? 'Unknown error occurred.').toString();
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => BidFailureDialog(errorMessage: msg),
          );
        }
        return false;
      }
    } catch (e) {
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
    final expanded = _expandedRowsForUi();

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Image.asset(
                  "assets/images/ic_wallet.png",
                  width: 22,
                  height: 22,
                  color: Colors.black,
                ),
                const SizedBox(width: 4),
                Obx(
                  () => Text(
                    userController.walletBalance.value,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<GameType>(
                              title: const Text('Odd'),
                              value: GameType.odd,
                              groupValue: _selectedGameType,
                              onChanged: (v) =>
                                  setState(() => _selectedGameType = v),
                              activeColor: Colors.orange,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<GameType>(
                              title: const Text('Even'),
                              value: GameType.even,
                              groupValue: _selectedGameType,
                              onChanged: (v) =>
                                  setState(() => _selectedGameType = v),
                              activeColor: Colors.orange,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Enter Points :',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _pointsField(_pointsController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 150,
                            child: ElevatedButton(
                              onPressed: _isApiCalling ? null : _addEntry,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isApiCalling
                                    ? Colors.grey
                                    : Colors.orange,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 3,
                              ),
                              child: const Text(
                                'ADD',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey[400]),

                // Header for expanded rows
                if (expanded.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: const [
                        Expanded(
                          child: Text(
                            'Digit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Points',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Type',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Session',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        SizedBox(width: 48),
                      ],
                    ),
                  ),
                if (expanded.isNotEmpty)
                  Divider(height: 1, color: Colors.grey[400]),

                // Expanded rows list (each digit)
                Expanded(
                  child: expanded.isEmpty
                      ? Center(
                          child: Text(
                            'No entries yet. Add some data!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: expanded.length,
                          itemBuilder: (_, i) {
                            final r = expanded[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r['digit'] as String,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        r['points'] as String,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        r['bidType'] as String,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _lockedSession,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.orange,
                                      ),
                                      tooltip:
                                          'Remove this ${r['bidType']} set',
                                      onPressed: _isApiCalling
                                          ? null
                                          : () => _deleteParentByIndex(
                                              r['parentIndex'] as int,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                if (expanded.isNotEmpty) _bottomBar(),
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

  Widget _pointsField(TextEditingController c) {
    return SizedBox(
      height: 38,
      child: TextField(
        cursorColor: Colors.orange,
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onTap: _clearMessage,
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
          hintText: 'Enter Points',
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

  Widget _bottomBar() {
    final totalBids = _expandedRowsForUi().length; // per-digit rows
    final uiTotal = _getUiTotalPoints();
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
          const Text(
            'Bids',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Count',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Text(
                '$totalBids',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Points',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Text(
                '$uiTotal',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _isApiCalling ? null : _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isApiCalling ? Colors.grey : Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: const Text(
              'SUBMIT',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
