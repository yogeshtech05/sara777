// lib/screens/red_bracket_board_screen.dart
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

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../ulits/Constents.dart';

enum BracketType { half, full }

class RedBracketBoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId;
  final String gameType; // "redBracket"

  const RedBracketBoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameId,
    required this.gameType,
  }) : super(key: key);

  @override
  State<RedBracketBoardScreen> createState() => _RedBracketBoardScreenState();
}

class _RedBracketBoardScreenState extends State<RedBracketBoardScreen> {
  final TextEditingController _amountController = TextEditingController();

  // entries: { digit: "xy", points: "nn", source: "HALF" | "FULL" }
  final List<Map<String, String>> _bids = [];
  BracketType _bracketType = BracketType.half;

  final GetStorage _storage = GetStorage();

  String _accessToken = '';
  String _registerId = '';
  bool _accountStatus = false;
  int _walletBalance = 0;

  bool _isBusy = false;

  String get _deviceId =>
      _storage.read('deviceId')?.toString() ?? 'device_red_bracket';
  String get _deviceName =>
      _storage.read('deviceName')?.toString() ?? 'RedBracketScreen';

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  // Message bar
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _initAuthAndWallet();
  }

  Future<void> _initAuthAndWallet() async {
    _accessToken = _storage.read('accessToken')?.toString() ?? '';
    _registerId = _storage.read('registerId')?.toString() ?? '';
    _accountStatus = userController.accountStatus.value;

    final num? bal = num.tryParse(userController.walletBalance.value);
    _walletBalance = bal?.toInt() ?? 0;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  // ---------------- message bar ----------------
  void _showMessage(String msg, {bool isError = false}) {
    _dismissTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messageToShow = msg;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _messageToShow = null);
    });
  }

  void _clearMessage() {
    if (!mounted) return;
    setState(() => _messageToShow = null);
  }

  // ---------------- helpers ----------------
  int _getTotalPoints() =>
      _bids.fold(0, (s, e) => s + (int.tryParse(e['points'] ?? '0') ?? 0));

  void _mergeOrAdd(String digit, int amount, String source) {
    final i = _bids.indexWhere(
      (b) => b['digit'] == digit && b['source'] == source,
    );
    if (i >= 0) {
      final cur = int.tryParse(_bids[i]['points'] ?? '0') ?? 0;
      _bids[i]['points'] = (cur + amount).toString();
    } else {
      _bids.add({
        'digit': digit,
        'points': amount.toString(),
        'source': source,
      });
    }
  }

  // ---------------- ADD (expand) ----------------
  Future<void> _addBid() async {
    if (_isBusy) return;
    _clearMessage();

    final txt = _amountController.text.trim();
    final int? amt = int.tryParse(txt);
    if (amt == null || amt < 10 || amt > 10000) {
      _showMessage('Amount 10–10000 ke beech do.', isError: true);
      return;
    }

    if (_accessToken.isEmpty) {
      _showMessage('Auth issue — login dobara karo.', isError: true);
      return;
    }

    final String typeForApi = _bracketType == BracketType.half
        ? 'halfBracket'
        : 'fullBracket'; // <- API ko agar 'half'/'full' chahiye ho to yaha change karo
    final String sourceLabel = _bracketType == BracketType.half
        ? 'HALF'
        : 'FULL';

    final String base = Constant.apiEndpoint.endsWith('/')
        ? Constant.apiEndpoint
        : '${Constant.apiEndpoint}/';
    final String url = '${base}red-bracket-jodi';

    setState(() => _isBusy = true);
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
          'deviceId': _deviceId,
          'deviceName': _deviceName,
          'accessStatus': _accountStatus ? '1' : '0',
        },
        body: jsonEncode({'type': typeForApi, 'amount': amt}),
      );

      final Map<String, dynamic> data = json.decode(resp.body);
      log('[RedBracket] expand HTTP ${resp.statusCode}');
      log('[RedBracket] expand resp: $data');

      if (resp.statusCode == 200 && data['status'] == true) {
        final List<dynamic> info = data['info'] ?? [];
        if (info.isEmpty) {
          _showMessage('Server se koi jodi/pana nahi aaya.', isError: true);
        } else {
          // Wallet guard: tentative total check
          final temp = List<Map<String, String>>.from(_bids);
          for (final it in info) {
            final d = it['pana']?.toString() ?? '';
            final a = int.tryParse(it['amount']?.toString() ?? '0') ?? 0;
            if (d.isEmpty || a <= 0) continue;
            final idx = temp.indexWhere(
              (e) => e['digit'] == d && e['source'] == sourceLabel,
            );
            if (idx >= 0) {
              final cur = int.tryParse(temp[idx]['points'] ?? '0') ?? 0;
              temp[idx]['points'] = (cur + a).toString();
            } else {
              temp.add({
                'digit': d,
                'points': a.toString(),
                'source': sourceLabel,
              });
            }
          }
          final newTotal = temp.fold(
            0,
            (s, e) => s + (int.tryParse(e['points'] ?? '0') ?? 0),
          );
          if (_walletBalance > 0 && newTotal > _walletBalance) {
            _showMessage(
              'Itna add karoge to total wallet se zyada ho jayega.',
              isError: true,
            );
          } else {
            setState(() {
              for (final it in info) {
                final d = it['pana']?.toString() ?? '';
                final a = int.tryParse(it['amount']?.toString() ?? '0') ?? 0;
                if (d.isNotEmpty && a > 0) _mergeOrAdd(d, a, sourceLabel);
              }
              _amountController.clear();
            });
            _showMessage('Bids add ho gaye.', isError: false);
          }
        }
      } else {
        _showMessage(data['msg']?.toString() ?? 'Add failed.', isError: true);
      }
    } catch (e) {
      _showMessage('Network error. Thodi der baad try karo.', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _removeBid(int index) {
    if (_isBusy) return;
    final removed = _bids[index]['digit'];
    setState(() => _bids.removeAt(index));
    _showMessage('Removed $removed.');
  }

  // ---------------- SUBMIT ----------------
  void _openConfirmDialog() {
    _clearMessage();
    if (_isBusy) return;

    if (_bids.isEmpty) {
      _showMessage('Pehle kuch bids add karo.', isError: true);
      return;
    }

    final total = _getTotalPoints();
    if (_walletBalance < total) {
      _showMessage('Wallet balance kam hai.', isError: true);
      return;
    }

    // Dialog rows: Digits = pana, Points = amount, Game Type = RED BRACKET (HALF/FULL)
    final bidsForDialog = _bids
        .map(
          (b) => {
            'digit': b['digit']!,
            'pana': b['digit']!,
            'points': b['points']!,
            'type': 'RED BRACKET (${b['source']})',
            'jodi': b['digit']!,
          },
        )
        .toList();

    final when = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.screenTitle,
        gameDate: when,
        bids: bidsForDialog,
        totalBids: bidsForDialog.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction: _walletBalance,
        walletBalanceAfterDeduction: (_walletBalance - total).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () async {
          setState(() => _isBusy = true);
          final ok = await _submitBids(total);
          if (ok) setState(() => _bids.clear());
          if (mounted) setState(() => _isBusy = false);
        },
      ),
    );
  }

  Future<bool> _submitBids(int totalPoints) async {
    if (_accessToken.isEmpty || _registerId.isEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Auth issue — login dobara karo.',
        ),
      );
      return false;
    }

    final payload = {
      "registerId": _registerId,
      "gameId": widget.gameId, // int
      "bidAmount": totalPoints,
      "gameType": "redBracket",
      "bid": _bids
          .map(
            (b) => {
              "sessionType": "redBracket",
              "digit": b['digit'],
              "pana": b['digit'],
              "bidAmount": int.tryParse(b['points'] ?? '0') ?? 0,
            },
          )
          .toList(),
    };

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': _accountStatus ? '1' : '0',
    };

    log('[RedBracket] place-bid headers: $headers');
    log('[RedBracket] place-bid body: $payload');

    try {
      final uri = Uri.parse(
        '${Constant.apiEndpoint}${Constant.apiEndpoint.endsWith('/') ? '' : '/'}place-bid',
      );
      final resp = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      );
      final Map<String, dynamic> data = json.decode(resp.body);

      log('[RedBracket] place-bid HTTP ${resp.statusCode}');
      log('[RedBracket] place-bid resp: $data');

      if (resp.statusCode == 200 &&
          (data['status'] == true || data['status'] == 'true')) {
        final dynamic serverBal = data['updatedWalletBalance'];
        final int newBal =
            int.tryParse(serverBal?.toString() ?? '') ??
            (_walletBalance - totalPoints);

        await _storage.write('walletBalance', newBal.toString());
        userController.walletBalance.value = newBal.toString();
        setState(() => _walletBalance = newBal);

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );
        _clearMessage();
        return true;
      } else {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(
            errorMessage:
                data['msg']?.toString() ??
                'Place bid failed. Please try again later.',
          ),
        );
        return false;
      }
    } catch (e) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Network error. Internet check karo.',
        ),
      );
      return false;
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final totalBids = _bids.length;
    final totalPoints = _getTotalPoints();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF5F7F8),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.screenTitle,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 15,
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
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      _inputRow("Bracket Type", _bracketRadioGroup()),
                      const SizedBox(height: 8),
                      _inputRow("Enter Points :", _amountField()),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(flex: 2, child: SizedBox()),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              width: double.infinity,
                              height: 38,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isBusy
                                      ? Colors.grey
                                      : const Color(0xFFF9B233), // Golden orange
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _isBusy ? null : _addBid,
                                child: _isBusy
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
                                    : Text(
                                        "ADD",
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
                            "Digit",
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
                            "Points",
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
                            "Type",
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
                            "No Bids Added Yet",
                            style: GoogleFonts.poppins(
                              color: Colors.black38,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _bids.length,
                          itemBuilder: (_, i) => _bidTile(i, _bids[i]),
                        ),
                ),

                if (_bids.isNotEmpty) _bottomBar(totalBids, totalPoints),
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

  // ---------------- small widgets ----------------
  Widget _inputRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
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

  Widget _bracketRadioGroup() {
    return Row(
      children: [
        Expanded(child: _bracketRadio(BracketType.half, 'Half')),
        Expanded(child: _bracketRadio(BracketType.full, 'Full')),
      ],
    );
  }

  Widget _bracketRadio(BracketType type, String label) {
    return InkWell(
      onTap: () => setState(() => _bracketType = type),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<BracketType>(
            value: type,
            groupValue: _bracketType,
            onChanged: (v) => setState(() => _bracketType = v!),
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

  Widget _amountField() {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: _amountController,
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
        decoration: InputDecoration(
          hintText: "",
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
        ),
        onTap: _clearMessage,
        enabled: !_isBusy,
      ),
    );
  }

  Widget _bidTile(int index, Map<String, String> bid) {
    final bool isHalf = bid['source'] == 'HALF';
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
              bid['digit']!,
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
              bid['points']!,
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
              'RED ${bid['source']}',
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isHalf ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _removeBid(index),
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

  Widget _bottomBar(int totalBids, int totalPoints) {
    final canSubmit = !_isBusy && _bids.isNotEmpty;
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
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.shade300,
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
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit ? const Color(0xFFF9B233) : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                onPressed: canSubmit ? _openConfirmDialog : null,
                child: _isBusy
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
                        'SUBMIT',
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 15,
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
