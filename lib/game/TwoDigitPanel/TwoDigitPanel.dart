// lib/screens/two_digit_panel_screen.dart
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../components/GameTypeSelectorField.dart';
import '../../ulits/Constents.dart';

class Bid {
  final String digit; // user-entered 2-digit string (e.g. "07")
  final String amount; // per-pana points
  final String pana; // expanded pana from API
  final String type; // "Open" or "Close" session

  const Bid({
    required this.digit,
    required this.amount,
    required this.pana,
    required this.type,
  });

  Bid copyWith({String? digit, String? amount, String? pana, String? type}) {
    return Bid(
      digit: digit ?? this.digit,
      amount: amount ?? this.amount,
      pana: pana ?? this.pana,
      type: type ?? this.type,
    );
  }
}

class TwoDigitPanelScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameType; // "twoDigitsPanel"
  final bool selectionStatus;

  const TwoDigitPanelScreen({
    Key? key,
    required this.title,
    required this.gameId,
    this.gameType = "twoDigitsPanel",
    required this.selectionStatus,
  }) : super(key: key);

  @override
  State<TwoDigitPanelScreen> createState() => _TwoDigitPanelScreenState();
}

class _TwoDigitPanelScreenState extends State<TwoDigitPanelScreen> {
  final List<String> gameTypesOptions = ["Open", "Close"];
  late String selectedGameBetType;

  final TextEditingController digitController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  final List<Bid> _bids = <Bid>[];

  final GetStorage storage = GetStorage();
  late String accessToken;
  late String registerId;
  late bool accountStatus;
  late int walletBalance;

  static const String _deviceId = 'test_device_id_flutter';
  static const String _deviceName = 'test_device_name_flutter';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  bool _isAddBidApiCalling = false;
  bool _isSubmitBidApiCalling = false;

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;
    final num? bal = num.tryParse(userController.walletBalance.value);
    walletBalance = bal?.toInt() ?? 0;

    selectedGameBetType = widget.selectionStatus
        ? gameTypesOptions[0]
        : gameTypesOptions[1];
  }

  @override
  void dispose() {
    digitController.dispose();
    amountController.dispose();
    super.dispose();
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _messageToShow = msg;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
  }

  void _clearMessage() {
    if (!mounted) return;
    setState(() => _messageToShow = null);
  }

  int get _totalPoints =>
      _bids.fold(0, (sum, b) => sum + (int.tryParse(b.amount) ?? 0));

  /// ---------------- ADD (Expand panas) ----------------
  Future<void> addBid() async {
    _clearMessage();
    if (_isAddBidApiCalling || _isSubmitBidApiCalling) return;

    final String twoDigit = digitController.text.trim(); // keep "07"
    final String amountText = amountController.text.trim();

    if (twoDigit.isEmpty ||
        twoDigit.length != 2 ||
        int.tryParse(twoDigit) == null) {
      _showMessage('2 digit number do (00–99).', isError: true);
      return;
    }
    final int? perPana = int.tryParse(amountText);
    if (perPana == null || perPana < 10 || perPana > 10000) {
      _showMessage('Points 10 se 10000 ke beech me do.', isError: true);
      return;
    }
    if (accessToken.isEmpty || registerId.isEmpty) {
      _showMessage('Auth issue — dobara login karo.', isError: true);
      return;
    }

    setState(() => _isAddBidApiCalling = true);

    final url = Uri.parse('${Constant.apiEndpoint}two-digits-panel-pana');
    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    // ✅ IMPORTANT: sessionType hata diya (server error de raha tha)
    final body = jsonEncode({
      "digit": twoDigit, // string to keep leading zero
      "amount": perPana,
    });

    log('[TwoDigitsPanel] Expand URL : $url');
    log('[TwoDigitsPanel] Headers    : $headers');
    log('[TwoDigitsPanel] Body       : $body');

    try {
      final resp = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      final map = jsonDecode(resp.body);
      log('[TwoDigitsPanel] Expand HTTP ${resp.statusCode}');
      log('[TwoDigitsPanel] Expand Resp: $map');

      if (resp.statusCode == 200 && map['status'] == true) {
        final List<dynamic> info = (map['info'] ?? []) as List<dynamic>;
        if (info.isEmpty) {
          _showMessage('Is 2 digit ke liye koi pana nahi mila.', isError: true);
          return;
        }

        final temp = List<Bid>.from(_bids);
        int inserted = 0;

        for (final it in info) {
          final String pana = it['pana']?.toString() ?? '';
          final String panaAmount =
              it['amount']?.toString() ?? perPana.toString();
          if (pana.isEmpty) continue;

          final idx = temp.indexWhere(
            (e) => e.pana == pana && e.type == selectedGameBetType,
          );
          if (idx >= 0) {
            temp[idx] = temp[idx].copyWith(
              amount: panaAmount,
              digit: twoDigit,
              type: selectedGameBetType,
            );
          } else {
            temp.add(
              Bid(
                digit: twoDigit,
                amount: panaAmount,
                pana: pana,
                type: selectedGameBetType,
              ),
            );
            inserted++;
          }
        }

        final int newTotal = temp.fold(
          0,
          (s, b) => s + (int.tryParse(b.amount) ?? 0),
        );
        if (walletBalance > 0 && newTotal > walletBalance) {
          _showMessage('Wallet me itne points nahi hai.', isError: true);
          return;
        }

        setState(() {
          _bids
            ..clear()
            ..addAll(temp);
          digitController.clear();
          amountController.clear();
        });

        _showMessage(
          inserted > 0 ? '$inserted pana add hue.' : 'Amounts update ho gaye.',
          isError: false,
        );
      } else {
        _showMessage(
          map['msg']?.toString() ?? 'Pana fetch fail.',
          isError: true,
        );
      }
    } catch (e) {
      log('[TwoDigitsPanel] Expand error: $e');
      _showMessage('Network error. Thodi der baad try karo.', isError: true);
    } finally {
      if (mounted) setState(() => _isAddBidApiCalling = false);
    }
  }

  /// ---------------- DELETE ----------------
  void deleteBid(int index) {
    _clearMessage();
    if (_isAddBidApiCalling || _isSubmitBidApiCalling) return;
    final removed = _bids[index].pana;
    setState(() => _bids.removeAt(index));
    _showMessage('Pana $removed remove ho gaya.');
  }

  /// ---------------- CONFIRM (Dialog) ----------------
  void _showConfirmationDialog() {
    _clearMessage();
    if (_bids.isEmpty) {
      _showMessage('Submit se pehle kuch pana add karo.', isError: true);
      return;
    }
    if (walletBalance < _totalPoints) {
      _showMessage('Wallet balance kam hai.', isError: true);
      return;
    }

    // Dialog rows — `points` key chahiye
    final rows = _bids
        .map(
          (b) => {
            "digit": b.pana, // digits column me pana dikhana hai
            "points": b.amount, // dialog needs 'points'
            "type": b.type,
            "pana": b.pana,
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
        totalBids: _bids.length,
        totalBidsAmount: _totalPoints,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - _totalPoints).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType, // "twoDigitsPanel"
        onConfirm: () async {
          setState(() => _isSubmitBidApiCalling = true);
          final ok = await _placeFinalBids();
          if (mounted) setState(() => _isSubmitBidApiCalling = false);

          if (ok && mounted) {
            await showDialog(
              context: context,
              barrierDismissible: true,
              builder: (_) => const BidSuccessDialog(),
            );
            setState(() => _bids.clear());
          } else if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: true,
              builder: (_) => BidFailureDialog(
                errorMessage: _messageToShow ?? 'Bid submit fail ho gaya.',
              ),
            );
          }
        },
      ),
    );
  }

  /// ---------------- SUBMIT (place-bid) ----------------
  Future<bool> _placeFinalBids() async {
    final url = '${Constant.apiEndpoint}place-bid';

    if (accessToken.isEmpty || registerId.isEmpty) {
      _showMessage('Auth issue — dobara login karo.', isError: true);
      return false;
    }

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    // ✅ Tumhari requirement ke hisaab se: pana-only submit
    final List<Map<String, dynamic>> bidPayload = _bids
        .map(
          (b) => {
            "sessionType": b.type.toUpperCase(),
            "digit": b.pana, // pana
            "pana": b.pana, // pana
            "bidAmount": int.tryParse(b.amount) ?? 0,
          },
        )
        .toList();

    final int total = bidPayload.fold(0, (s, m) => s + (m['bidAmount'] as int));

    final body = jsonEncode({
      "registerId": registerId,
      "gameId": widget.gameId,
      "bidAmount": total,
      "gameType": widget.gameType, // "twoDigitsPanel"
      "bid": bidPayload,
    });

    log('[TwoDigitsPanel] Submit URL : $url');
    log('[TwoDigitsPanel] Headers    : $headers');
    log('[TwoDigitsPanel] Body       : $body');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      final map = jsonDecode(response.body);
      log('[TwoDigitsPanel] Submit HTTP ${response.statusCode}');
      log('[TwoDigitsPanel] Submit Resp: $map');

      if (response.statusCode == 200 &&
          (map['status'] == true || map['status'] == 'true')) {
        final newBal = walletBalance - total;
        await storage.write('walletBalance', newBal.toString());
        if (mounted) setState(() => walletBalance = newBal);
        _clearMessage();
        _showMessage('Sab bids successfully submit ho gaye!');
        return true;
      } else {
        _showMessage(
          map['msg']?.toString() ?? 'Place bid failed.',
          isError: true,
        );
        return false;
      }
    } catch (e) {
      log('[TwoDigitsPanel] Submit error: $e');
      _showMessage(
        'Network error aaya. Thodi der baad try karo.',
        isError: true,
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAnyApiCalling = _isAddBidApiCalling || _isSubmitBidApiCalling;
    final filteredOptions = widget.selectionStatus ? ['Open', 'Close'] : ['Close'];
    if (!filteredOptions.contains(selectedGameBetType)) {
      selectedGameBetType = filteredOptions.first;
    }

    final canSubmitAny = _bids.isNotEmpty && !isAnyApiCalling;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: Text(
          widget.title.toUpperCase(),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        backgroundColor: const Color(0xFFF5F7F8),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
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
            child: Text(
              walletBalance.toString(),
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      _row(
                        "Select Game Type:",
                        GameTypeSelectorField(
                          selectedOption: selectedGameBetType,
                          options: filteredOptions,
                          enabled: !isAnyApiCalling,
                          displayTextBuilder: (val) => "${widget.title} $val".toUpperCase(),
                          onSelected: (v) {
                            setState(() {
                              selectedGameBetType = v;
                              _clearMessage();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _row(
                        "Enter Two Digits:",
                        SizedBox(
                          height: 38,
                          child: TextField(
                            controller: digitController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            onTap: _clearMessage,
                            enabled: !isAnyApiCalling,
                            decoration: _tfDecoration('Bid Digits'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _row(
                        "Enter Points:",
                        SizedBox(
                          height: 38,
                          child: TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                            onTap: _clearMessage,
                            enabled: !isAnyApiCalling,
                            decoration: _tfDecoration('Enter Amount'),
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
                                onPressed: isAnyApiCalling ? null : addBid,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isAnyApiCalling
                                      ? Colors.grey
                                      : const Color(0xFFF9B233),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isAddBidApiCalling
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.black,
                                          ),
                                        ),
                                      )
                                    : Text(
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

                const Divider(height: 1, thickness: 1),

                if (_bids.isNotEmpty)
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
                            'Pana',
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
                if (_bids.isNotEmpty) const Divider(thickness: 1, height: 1),

                Expanded(
                  child: _bids.isEmpty
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
                          itemCount: _bids.length,
                          itemBuilder: (context, index) {
                            final b = _bids[index];
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
                                      b.pana,
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
                                      b.amount,
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
                                      b.type.toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: b.type.toLowerCase() == 'open'
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFC62828),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: isAnyApiCalling
                                        ? null
                                        : () => deleteBid(index),
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
                          },
                        ),
                ),

                if (_bids.isNotEmpty) _buildBottomBar(canSubmitAny),
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

  Widget _row(String label, Widget field) {
    String cleanedLabel = label;
    if (label.contains('Select Game Type')) {
      cleanedLabel = 'Select Game Type';
    } else if (label.contains('Enter Two Digits') || label.contains('Digits')) {
      cleanedLabel = 'Enter Two Digits';
    } else if (label.contains('Enter Points') || label.contains('Points')) {
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

  Widget _buildBottomBar(bool canSubmitAny) {
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
                  '${_bids.length}',
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
                  '$_totalPoints',
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
                onPressed: canSubmitAny ? _showConfirmationDialog : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmitAny ? const Color(0xFFF9B233) : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitBidApiCalling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
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

