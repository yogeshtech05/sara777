import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:new_sara/KingStarline&Jackpot/StarlineBidService.dart';

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../ulits/Constents.dart';

class StarlineSpDpTpScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId; // TYPE id to send in place-bid
  final String gameType; // e.g. "SPDPTP"

  const StarlineSpDpTpScreen({
    Key? key,
    required this.screenTitle,
    required this.gameId,
    required this.gameType,
  }) : super(key: key);

  @override
  State<StarlineSpDpTpScreen> createState() => _StarlineSpDpTpScreenState();
}

class _StarlineSpDpTpScreenState extends State<StarlineSpDpTpScreen> {
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _pannaController = TextEditingController();

  bool _isSPSelected = false;
  bool _isDPSelected = false;
  bool _isTPSelected = false;

  // UI-only label; Starline API ignores sessionType
  final String _selectedGameTypeOption = 'OPEN';

  // each row: {digit: "pana", amount: "points", gameType: "SP|DP|TP"}
  final List<Map<String, String>> _bids = [];

  static const int _minBet = 10;
  static const int _maxBet = 1000;

  int walletBalance = 0;
  String accessToken = '';
  String registerId = '';
  String preferredLanguage = 'en';
  bool accountStatus = false;

  final GetStorage storage = GetStorage();
  late final StarlineBidService _bidService;

  final String _deviceId =
      GetStorage().read('deviceId')?.toString() ?? 'flutter_device';
  final String _deviceName =
      GetStorage().read('deviceName')?.toString() ?? 'Flutter_App';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  bool _isApiCalling = false;

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  @override
  void initState() {
    super.initState();
    _bidService = StarlineBidService(storage);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    // wallet safe parse
    final rawCtrl = userController.walletBalance.value;
    final rawStore = storage.read('walletBalance');
    final n = num.tryParse(rawCtrl);
    if (n != null) {
      walletBalance = n.toInt();
    } else if (rawStore != null) {
      walletBalance = int.tryParse(rawStore.toString()) ?? 0;
    } else {
      walletBalance = 0;
    }

    // live wallet sync
    storage.listenKey('walletBalance', (val) {
      final parsed = int.tryParse(val?.toString() ?? '0') ?? 0;
      if (mounted) setState(() => walletBalance = parsed);
    });
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _pannaController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
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
    return _bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
    );
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;
    if (_bids.isEmpty) {
      _showMessage('Please add bids before submitting.', isError: true);
      return;
    }

    final total = _getTotalPoints();
    if (walletBalance < total) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
        isError: true,
      );
      return;
    }

    final validRows = _bids
        .where(
          (b) =>
              (b['digit']?.isNotEmpty ?? false) &&
              (b['amount']?.isNotEmpty ?? false),
        )
        .map(
          (b) => {
            'digit': b['digit']!, // for dialog table
            'points': b['amount']!,
            'type': _selectedGameTypeOption,
            'pana': b['digit']!,
            'jodi': '',
          },
        )
        .toList();

    if (validRows.isEmpty) {
      _showMessage('No valid bids to submit.', isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.screenTitle,
        bids: validRows,
        totalBids: validRows.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - total).toString(),
        gameDate: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
        gameId: widget.gameId.toString(), // TYPE id as string
        gameType: widget.gameType, // "SPDPTP"
        onConfirm: () async {
          setState(() => _isApiCalling = true);
          await _placeFinalBids();
          if (mounted) setState(() => _isApiCalling = false);
        },
      ),
    );
  }

  Future<bool> _placeFinalBids() async {
    // Build payload: digit -> amount
    final Map<String, String> payload = {};
    int total = 0;
    for (final b in _bids) {
      final d = b['digit'] ?? '';
      final a = int.tryParse(b['amount'] ?? '0') ?? 0;
      if (d.isNotEmpty && a > 0) {
        payload[d] = a.toString();
        total += a;
      }
    }

    if (payload.isEmpty) {
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

    // Try to extract a time label like "Screen - 12:30 PM" (for UI only)
    String? sessionLabel;
    final parts = widget.screenTitle.split(' - ');
    if (parts.length > 1) {
      sessionLabel = parts.last.trim();
    }

    try {
      final isStarline = widget.screenTitle.toLowerCase().contains('starline');
      final isJackpot = widget.screenTitle.toLowerCase().contains('jackpot');

      final result = await _bidService.placeFinalBids(
        market: isStarline
            ? Market.starline
            : (isJackpot ? Market.jackpot : Market.starline),

        accessToken: accessToken,
        registerId: registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: accountStatus,
        bidAmounts: payload,
        gameId: widget.gameId, // TYPE id (int here; service sends string)
        gameType: widget.gameType, // "SPDPTP"
        totalBidAmount: total,

        // Starline extras not required by your current API spec; omitting.
        // starlineSessionId: widget.gameId,
        // starlineSessionTimeLabel: sessionLabel,
        // playDate: DateTime.now(),
      );

      if (!mounted) return false;

      if (result['status'] == true) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );

        // Prefer server wallet if present
        final data = result['data'];
        final dynamic serverBal = (data is Map)
            ? (data['updatedWalletBalance'] ?? data['wallet_balance'])
            : null;
        final newBal =
            int.tryParse(serverBal?.toString() ?? '') ??
            (walletBalance - total);

        await _bidService.updateWalletBalance(newBal);
        userController.walletBalance.value = newBal.toString();

        if (mounted) {
          setState(() {
            walletBalance = newBal;
            _bids.clear();
          });
        }
        return true;
      } else {
        final msg = result['msg']?.toString() ?? 'Something went wrong';
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(errorMessage: msg),
        );
        return false;
      }
    } catch (e) {
      log(
        'Error during bid placement: $e',
        name: 'StarlineSpDpTpScreenBidError',
      );
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

  // ---------- Bulk helpers ----------
  Future<List<String>> _fetchBulkPannaBids({
    required int digit,
    required int amount,
    required String sessionType, // 'sp' | 'dp' | 'tp'
    required String apiEndpoint,
    required String gameId,
    required String registerId,
  }) async {
    final uri = Uri.parse(apiEndpoint);

    final deviceId = storage.read('deviceId')?.toString() ?? _deviceId;
    final deviceName = storage.read('deviceName')?.toString() ?? _deviceName;
    final token = storage.read('accessToken')?.toString() ?? accessToken;
    final accessStatus = (storage.read('accountStatus') == true) ? '1' : '0';

    final headers = <String, String>{
      'deviceId': deviceId,
      'deviceName': deviceName,
      'accessStatus': accessStatus,
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      "game_id": gameId,
      "register_id": registerId,
      "session_type": sessionType,
      "digit": digit,
      "amount": amount,
    });

    try {
      final response = await http.post(uri, headers: headers, body: body);
      final responseData = json.decode(response.body);

      log("API Response from $apiEndpoint: $responseData");

      if (response.statusCode == 200 && responseData['status'] == true) {
        final List<dynamic> info = responseData['info'] ?? [];
        return info.map<String>((item) => item['pana'].toString()).toList();
      } else {
        throw 'API Error: ${responseData['msg'] ?? 'Unknown error'}';
      }
    } catch (e) {
      log("Error fetching panna bids from $apiEndpoint: $e");
      throw 'Network/API Error: $e';
    }
  }

  void _addBid() async {
    _clearMessage();
    if (_isApiCalling) return;

    // Determine SP/DP/TP (exactly one)
    String? category;
    if (_isSPSelected) category = 'SP';
    if (_isDPSelected) category = 'DP';
    if (_isTPSelected) category = 'TP';

    if (category == null) {
      _showMessage('Please select SP, DP, or TP.', isError: true);
      return;
    }

    final digitText = _pannaController.text.trim();
    final pointsText = _pointsController.text.trim();

    if (digitText.isEmpty || digitText.length != 1) {
      _showMessage('Please enter a valid single digit (0-9).', isError: true);
      return;
    }
    final digit = int.tryParse(digitText);
    if (digit == null || digit < 0 || digit > 9) {
      _showMessage('Digit must be a number from 0 to 9.', isError: true);
      return;
    }

    final points = int.tryParse(pointsText);
    if (points == null || points < _minBet || points > _maxBet) {
      _showMessage(
        'Points must be between $_minBet and $_maxBet.',
        isError: true,
      );
      return;
    }

    setState(() => _isApiCalling = true);

    try {
      final apiMap = {
        'SP': '${Constant.apiEndpoint}single-pana-bulk',
        'DP': '${Constant.apiEndpoint}double-pana-bulk',
        'TP': '${Constant.apiEndpoint}triple-pana-bulk',
      };
      final endpoint = apiMap[category]!;

      final list = await _fetchBulkPannaBids(
        digit: digit,
        amount: points,
        sessionType: category.toLowerCase(), // 'sp'|'dp'|'tp'
        apiEndpoint: endpoint,
        gameId: widget.gameId.toString(),
        registerId: registerId,
      );

      int added = 0;
      setState(() {
        for (final pana in list) {
          // merge if same (pana + gameType)
          final idx = _bids.indexWhere(
            (b) => b['digit'] == pana && b['gameType'] == category,
          );
          if (idx != -1) {
            final old = int.tryParse(_bids[idx]['amount'] ?? '0') ?? 0;
            _bids[idx]['amount'] = (old + points).toString();
            added++;
          } else {
            _bids.add({
              'digit': pana,
              'amount': points.toString(),
              'gameType': _selectedGameTypeOption, // ✅ FIX: store category here
            });
            added++;
          }
        }
        _pannaController.clear();
        _pointsController.clear();
      });

      if (added > 0) {
        _showMessage('$added bids added for $category.');
      } else {
        _showMessage('All bids already exist.', isError: true);
      }
    } catch (e) {
      _showMessage('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isApiCalling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.screenTitle,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _isSPSelected,
                                  onChanged: _isApiCalling
                                      ? null
                                      : (v) {
                                          setState(() {
                                            _isSPSelected = v ?? false;
                                            if (_isSPSelected) {
                                              _isDPSelected = false;
                                              _isTPSelected = false;
                                            }
                                            _clearMessage();
                                          });
                                        },
                                  activeColor: Colors.orange,
                                ),
                                Text(
                                  'SP',
                                  style: GoogleFonts.poppins(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _isDPSelected,
                                  onChanged: _isApiCalling
                                      ? null
                                      : (v) {
                                          setState(() {
                                            _isDPSelected = v ?? false;
                                            if (_isDPSelected) {
                                              _isSPSelected = false;
                                              _isTPSelected = false;
                                            }
                                            _clearMessage();
                                          });
                                        },
                                  activeColor: Colors.orange,
                                ),
                                Text(
                                  'DP',
                                  style: GoogleFonts.poppins(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _isTPSelected,
                                  onChanged: _isApiCalling
                                      ? null
                                      : (v) {
                                          setState(() {
                                            _isTPSelected = v ?? false;
                                            if (_isTPSelected) {
                                              _isSPSelected = false;
                                              _isDPSelected = false;
                                            }
                                            _clearMessage();
                                          });
                                        },
                                  activeColor: Colors.orange,
                                ),
                                Text(
                                  'TP',
                                  style: GoogleFonts.poppins(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Enter Single Digit:',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(
                            width: 150,
                            height: 40,
                            child: TextField(
                              cursorColor: Colors.orange,
                              controller: _pannaController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(
                                  1,
                                ), // single digit
                                FilteringTextInputFormatter.digitsOnly,
                              ],
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

                                hintText: 'Enter Single Digit',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
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
                              ),
                              onTap: _clearMessage,
                              enabled: !_isApiCalling,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Enter Points:',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(
                            width: 150,
                            height: 40,
                            child: TextField(
                              cursorColor: Colors.orange,
                              controller: _pointsController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
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

                                hintText: 'Enter Amount',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
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
                              ),
                              onTap: _clearMessage,
                              enabled: !_isApiCalling,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 150,
                          height: 45,
                          child: ElevatedButton(
                            onPressed: _isApiCalling ? null : _addBid,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isApiCalling
                                  ? Colors.grey
                                  : Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: _isApiCalling
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                : Text(
                                    "ADD",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(thickness: 1),
                if (_bids.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
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
                        Expanded(
                          child: Text(
                            'Game Type',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                if (_bids.isNotEmpty) const Divider(thickness: 1),
                Expanded(
                  child: _bids.isEmpty
                      ? Center(
                          child: Text(
                            'No Bids Placed',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _bids.length,
                          itemBuilder: (context, index) {
                            final bid = _bids[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        bid['digit']!,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        bid['amount']!,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${bid['gameType']} ($_selectedGameTypeOption)',
                                        style: GoogleFonts.poppins(
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.orange,
                                      ),
                                      onPressed: _isApiCalling
                                          ? null
                                          : () => _removeBid(index),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_bids.isNotEmpty) _buildBottomBar(),
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

  void _removeBid(int index) {
    if (_isApiCalling || index < 0 || index >= _bids.length) return;
    final removed = _bids[index];
    setState(() {
      _bids.removeAt(index);
    });
    _showMessage('Removed bid: ${removed['digit']}');
  }

  Widget _buildBottomBar() {
    final totalBids = _bids.length;
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
            onPressed: (_isApiCalling || _bids.isEmpty)
                ? null
                : _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: (_isApiCalling || _bids.isEmpty)
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

  // Unused validators (optional)
  bool _isValidSpPanna(String panna) {
    if (panna.length != 3) return false;
    return panna.split('').toSet().length == 3;
  }

  bool _isValidDpPanna(String panna) {
    if (panna.length != 3) return false;
    final digits = panna.split('');
    final freq = <String, int>{};
    for (final d in digits) {
      freq[d] = (freq[d] ?? 0) + 1;
    }
    return freq.length == 2 && freq.values.contains(2);
  }

  bool _isValidTpPanna(String panna) {
    if (panna.length != 3) return false;
    return panna[0] == panna[1] && panna[1] == panna[2];
  }
}
