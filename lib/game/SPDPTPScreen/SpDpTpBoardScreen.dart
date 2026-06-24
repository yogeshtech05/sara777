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
import 'package:marquee/marquee.dart';

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../components/GameTypeSelectorField.dart';
import '../../ulits/Constents.dart';

class SpDpTpBoardScreen extends StatefulWidget {
  final String screenTitle; // e.g., "RADHA NIGHT, SP DP TP"
  final int gameId; // e.g., 26
  final String gameType; // e.g., "SPDPTP"
  final bool openSessionStatus; // if OPEN session available

  const SpDpTpBoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameId,
    required this.gameType,
    required this.openSessionStatus,
  }) : super(key: key);

  @override
  State<SpDpTpBoardScreen> createState() => _SpDpTpBoardScreenState();
}

class _SpDpTpBoardScreenState extends State<SpDpTpBoardScreen> {
  // Inputs
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _leftDigitController = TextEditingController();
  final TextEditingController _middleDigitController = TextEditingController();
  final TextEditingController _rightDigitController = TextEditingController();

  // Category toggles (mutually exclusive)
  bool _isSP = true;
  bool _isDP = false;
  bool _isTP = false;

  // Session dropdown
  String? _session; // "OPEN" | "CLOSE"

  // Bids list: { digit(3), amount, gameType(SP/DP/TP), session(OPEN/CLOSE) }
  final List<Map<String, String>> _bids = [];

  // Services / State
  final storage = GetStorage();
  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  late String accessToken;
  late String registerId;
  late bool accountStatus;
  late int walletBalance;

  late final String _deviceId = storage.read('deviceId') ?? '';
  late final String _deviceName = storage.read('deviceName') ?? '';

  bool _isApiCalling = false;

  // Message bar
  String? _msg;
  bool _msgErr = false;
  Key _msgKey = UniqueKey();
  Timer? _msgTimer;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;
    final num? bal = num.tryParse(userController.walletBalance.value);
    walletBalance = bal?.toInt() ?? 0;

    // default session
    _session = widget.openSessionStatus ? 'OPEN' : 'CLOSE';
    setState(() {});
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _leftDigitController.dispose();
    _middleDigitController.dispose();
    _rightDigitController.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  // --- helpers ---
  void _showMsg(String m, {bool err = false}) {
    _msgTimer?.cancel();
    setState(() {
      _msg = m;
      _msgErr = err;
      _msgKey = UniqueKey();
    });
    _msgTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _msg = null);
    });
  }

  void _clearMsg() {
    if (!mounted) return;
    setState(() => _msg = null);
  }

  String? _selectedCategory() {
    if (_isSP) return 'SP';
    if (_isDP) return 'DP';
    if (_isTP) return 'TP';
    return null;
  }

  int _totalPoints() =>
      _bids.fold(0, (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0));

  // --- API: bulk expand SP/DP/TP by a single digit into pannas ---
  Future<List<String>> _fetchBulk({
    required String category, // SP|DP|TP
    required int seed, // 0..9
    required int amount, // server may ignore
    required String session, // open|close
  }) async {
    final String endpoint = category == 'SP'
        ? 'single-pana-bulk'
        : category == 'DP'
        ? 'double-pana-bulk'
        : 'triple-pana-bulk';

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final body = jsonEncode({
      "game_id": widget.gameId.toString(),
      "register_id": registerId,
      "session_type": session, // MUST be "open"/"close"
      "digit": seed,
      "amount": amount,
    });

    final uri = Uri.parse('${Constant.apiEndpoint}$endpoint');
    final resp = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 25));
    final map = jsonDecode(resp.body);

    log(
      '[BULK $category] $session seed=$seed → ${resp.statusCode} | $map',
      name: 'SPDPTP',
    );

    if (resp.statusCode == 200 && map['status'] == true) {
      final List<dynamic> info = (map['info'] ?? []) as List<dynamic>;
      return info
          .map((e) => e['pana']?.toString())
          .whereType<String>()
          .where((s) => s.length == 3)
          .toList();
    } else {
      final msg = map['msg']?.toString() ?? 'Failed to fetch bulk pannas';
      throw Exception(msg);
    }
  }

  // --- Add flow ---
  Future<void> _onAdd() async {
    _clearMsg();
    if (_isApiCalling) return;

    final cat = _selectedCategory();
    if (cat == null) {
      _showMsg('Please select SP, DP or TP.', err: true);
      return;
    }
    if (_session == null) {
      _showMsg('Select session OPEN/CLOSE.', err: true);
      return;
    }
    final leftTxt = _leftDigitController.text.trim();
    final middleTxt = _middleDigitController.text.trim();
    final rightTxt = _rightDigitController.text.trim();
    final pTxt = _pointsController.text.trim();

    int totalSum = 0;
    int enteredCount = 0;

    if (leftTxt.isNotEmpty) {
      final val = int.tryParse(leftTxt);
      if (val == null || val < 0 || val > 9) {
        _showMsg('Digits must be between 0 and 9.', err: true);
        return;
      }
      totalSum += val;
      enteredCount++;
    }
    if (middleTxt.isNotEmpty) {
      final val = int.tryParse(middleTxt);
      if (val == null || val < 0 || val > 9) {
        _showMsg('Digits must be between 0 and 9.', err: true);
        return;
      }
      totalSum += val;
      enteredCount++;
    }
    if (rightTxt.isNotEmpty) {
      final val = int.tryParse(rightTxt);
      if (val == null || val < 0 || val > 9) {
        _showMsg('Digits must be between 0 and 9.', err: true);
        return;
      }
      totalSum += val;
      enteredCount++;
    }

    if (enteredCount == 0) {
      _showMsg('Please enter at least one digit.', err: true);
      return;
    }

    final seed = totalSum % 10;

    final pts = int.tryParse(pTxt);
    if (pts == null || pts < 10 || pts > 1000) {
      _showMsg('Points must be between 10 and 1000.', err: true);
      return;
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      _showMsg('Authentication error. Please log in again.', err: true);
      return;
    }

    setState(() => _isApiCalling = true);
    try {
      // bulk API expects open/close
      final pannas = await _fetchBulk(
        category: cat,
        seed: seed,
        amount: pts,
        session: _session!.toLowerCase(),
      );

      if (pannas.isEmpty) {
        _showMsg('No panna found for the selection.', err: true);
      } else {
        // merge by (panna + category + session)
        setState(() {
          for (final p in pannas) {
            final idx = _bids.indexWhere(
              (e) =>
                  e['digit'] == p &&
                  e['gameType'] == cat &&
                  e['session'] == _session,
            );
            if (idx != -1) {
              final curr = int.tryParse(_bids[idx]['amount'] ?? '0') ?? 0;
              _bids[idx]['amount'] = (curr + pts).toString();
            } else {
              _bids.add({
                'digit': p,
                'amount': pts.toString(),
                'gameType': cat, // SP|DP|TP
                'session': _session!, // OPEN|CLOSE
              });
            }
          }
        });
        _showMsg('Added ${pannas.length} bid(s).');
      }
    } catch (e) {
      _showMsg(e.toString(), err: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _isApiCalling = false;
        _leftDigitController.clear();
        _middleDigitController.clear();
        _rightDigitController.clear();
        _pointsController.clear();
      });
    }
  }

  void _remove(int index) {
    if (_isApiCalling) return;
    final removed = _bids[index];
    setState(() => _bids.removeAt(index));
    _showMsg('Removed ${removed['digit']} (${removed['gameType']})');
  }

  // --- Confirm & Submit ---
  void _confirm() {
    _clearMsg();
    if (_isApiCalling) return;

    if (_bids.isEmpty) {
      _showMsg('Please add at least one bid.', err: true);
      return;
    }

    final int total = _totalPoints();
    if (walletBalance < total) {
      _showMsg('Insufficient wallet balance.', err: true);
      return;
    }

    final rows = _bids
        .map(
          (b) => {
            "digit": b['digit']!,
            "points": b['amount']!,
            "type": "${b['gameType']} (${b['session']})",
            "pana": b['digit']!,
            "jodi": "",
          },
        )
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.screenTitle,
        gameDate: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
        bids: rows,
        totalBids: rows.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - total).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () async {
          setState(() => _isApiCalling = true);
          final ok = await _submit();
          if (!mounted) return;
          setState(() => _isApiCalling = false);
          if (ok) setState(() => _bids.clear());
        },
      ),
    );
  }

  Future<bool> _submit() async {
    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final bidRows = _bids
        .map(
          (b) => {
            "sessionType": b['session'], // OPEN/CLOSE
            "digit": b['digit'], // 3-digit panna
            "pana": b['digit'], // backend expects filled
            "bidAmount": int.tryParse(b['amount'] ?? '0') ?? 0,
          },
        )
        .toList();

    final int total = _totalPoints();

    final body = jsonEncode({
      "registerId": registerId,
      "gameId": widget.gameId.toString(),
      "bidAmount": total,
      "gameType": widget.gameType, // "SPDPTP"
      "bid": bidRows,
    });

    final url = '${Constant.apiEndpoint}place-bid';
    log('[BidAPI] Headers: $headers');
    log('[BidAPI] Body   : $body');

    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      log('[BidAPI] HTTP ${resp.statusCode}');
      final map = jsonDecode(resp.body);
      log('[BidAPI] Resp: $map');

      if (resp.statusCode == 200 &&
          (map['status'] == true || map['status'] == 'true')) {
        final newBal = walletBalance - total;
        await storage.write('walletBalance', newBal);
        if (!mounted) return true;
        setState(() => walletBalance = newBal);
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );
        _clearMsg();
        return true;
      } else {
        final msg =
            map['msg']?.toString() ??
            'Place bid failed. Please try again later.';
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(errorMessage: msg),
        );
        return false;
      }
    } catch (e) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Network error. Please check your internet connection.',
        ),
      );
      return false;
    }
  }

  // --- UI helpers ---
  Widget _row(String label, Widget field) {
    String cleanedLabel = label;
    if (label.contains('Select Game Type')) {
      cleanedLabel = 'Select Game Type';
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

  Widget _buildDigitBox(String hint, TextEditingController c) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: c,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          filled: true,
          fillColor: Colors.white,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFFF9B233), width: 1.2),
          ),
        ),
        onTap: _clearMsg,
        enabled: !_isApiCalling,
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
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: Color(0xFFF9B233), width: 1.2),
    ),
  );

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final marketName = widget.screenTitle.contains(' - ')
        ? widget.screenTitle.split(' - ').first
        : widget.screenTitle;

    // Pre-calc footer values to avoid closure-prints
    final int totalBids = _bids.length;
    final int totalPoints = _totalPoints();
    final bool canSubmit = !_isApiCalling && _bids.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
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
            width: 20,
            height: 20,
            color: Colors.black,
          ),
          const SizedBox(width: 6),
          Center(
            child: Text(
              walletBalance.toString(),
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
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
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Session row
                      _row(
                        "Select Game Type",
                        GameTypeSelectorField(
                          selectedOption: _session ?? 'CLOSE',
                          options: widget.openSessionStatus ? const ['OPEN', 'CLOSE'] : const ['CLOSE'],
                          enabled: !_isApiCalling,
                          displayTextBuilder: (val) => "$marketName $val".toUpperCase(),
                          onSelected: (v) {
                            setState(() {
                              _session = v;
                              _clearMsg();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Category toggles
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _isSP,
                                    onChanged: _isApiCalling
                                        ? null
                                        : (v) {
                                            setState(() {
                                              _isSP = v ?? false;
                                              if (_isSP) {
                                                _isDP = false;
                                                _isTP = false;
                                              }
                                            });
                                          },
                                    activeColor: const Color(0xFFF9B233),
                                    checkColor: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'SP',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _isDP,
                                    onChanged: _isApiCalling
                                        ? null
                                        : (v) {
                                            setState(() {
                                              _isDP = v ?? false;
                                              if (_isDP) {
                                                _isSP = false;
                                                _isTP = false;
                                              }
                                            });
                                          },
                                    activeColor: const Color(0xFFF9B233),
                                    checkColor: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'DP',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _isTP,
                                    onChanged: _isApiCalling
                                        ? null
                                        : (v) {
                                            setState(() {
                                              _isTP = v ?? false;
                                              if (_isTP) {
                                                _isSP = false;
                                                _isDP = false;
                                              }
                                            });
                                          },
                                    activeColor: const Color(0xFFF9B233),
                                    checkColor: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'TP',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Digit boxes
                      Row(
                        children: [
                          Expanded(
                            child: _buildDigitBox('Left Digit', _leftDigitController),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDigitBox('Middle Digit', _middleDigitController),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDigitBox('Right Digit', _rightDigitController),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Points
                      _row(
                        "Enter Points:",
                        SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _pointsController,
                            cursorColor: Colors.orange,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            onTap: _clearMsg,
                            enabled: !_isApiCalling,
                            decoration: _tfDecoration('Enter Amount'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

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
                                onPressed: _isApiCalling ? null : _onAdd,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isApiCalling
                                      ? Colors.grey
                                      : const Color(0xFFF9B233),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isApiCalling
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.black,
                                          strokeWidth: 2,
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
                            'Digit',
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
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),

                Expanded(
                  child: _bids.isEmpty
                      ? Center(
                          child: Text(
                            'No Bids Placed',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 0, bottom: 8),
                          itemCount: _bids.length,
                          itemBuilder: (_, i) {
                            final b = _bids[i];
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
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
                                      b['digit']!,
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
                                      b['amount']!,
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
                                      '${b['gameType']} (${b['session']})'.toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: b['session']?.toUpperCase() == 'OPEN'
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFC62828),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _isApiCalling
                                        ? null
                                        : () => _remove(i),
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

                // ---------- FIXED FOOTER (matches your old design) ----------
                if (_bids.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Bids
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bids',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$totalBids',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Points
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Points',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$totalPoints',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Submit button
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: canSubmit ? _confirm : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canSubmit
                                  ? Colors.orange
                                  : Colors.grey,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 3,
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
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            if (_msg != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedMessageBar(
                  key: _msgKey,
                  message: _msg!,
                  isError: _msgErr,
                  onDismissed: _clearMsg,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
