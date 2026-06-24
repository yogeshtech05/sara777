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
import '../../components/GameTypeSelectorField.dart';
import '../../ulits/Constents.dart';

class SPMotorsBetScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType; // e.g. "spMotor"
  final int gameId;
  final String gameName;
  final bool selectionStatus; // if true => Open + Close; else only Close

  const SPMotorsBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
    required this.selectionStatus,
  });

  @override
  State<SPMotorsBetScreen> createState() => _SPMotorsBetScreenState();
}

class _SPMotorsBetScreenState extends State<SPMotorsBetScreen> {
  // UI state
  late String selectedGameBetType; // "Open" | "Close"
  final TextEditingController bidController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  // Auth / env
  late GetStorage storage;
  late String accessToken;
  late String registerId;
  bool accountStatus = false;
  late int walletBalance;

  // Device
  final String _deviceId = 'qwert';
  final String _deviceName = 'sm2233';

  // Entries by session; each item: {pana, amount, type("OPEN"/"CLOSE")}
  final Map<String, List<Map<String, String>>> _entriesBySession = {
    'OPEN': <Map<String, String>>[],
    'CLOSE': <Map<String, String>>[],
  };

  // Toast bar
  String? _message;
  bool _isError = false;
  Key _messageKey = UniqueKey();
  Timer? _dismissTimer;

  bool _isApiCalling = false;

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  @override
  void initState() {
    super.initState();
    storage = GetStorage();
    _loadInitialData();

    selectedGameBetType = widget.selectionStatus ? "Open" : "Close";
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;
    final num? bal = num.tryParse(userController.walletBalance.value);
    walletBalance = bal?.toInt() ?? 0;
  }

  @override
  void dispose() {
    bidController.dispose();
    pointsController.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  // -------------------- helpers --------------------
  void _showMessage(String msg, {bool isError = false}) {
    _dismissTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _message = msg;
      _isError = isError;
      _messageKey = UniqueKey();
    });
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = null);
    });
  }

  void _clearMessage() {
    if (mounted) setState(() => _message = null);
  }

  List<Map<String, String>> _allEntries() => [
    ..._entriesBySession['OPEN']!,
    ..._entriesBySession['CLOSE']!,
  ];

  int _totalPointsAll() => _allEntries().fold(
    0,
    (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0),
  );

  int _totalPointsFor(String sessionUpper) => _entriesBySession[sessionUpper]!
      .fold(0, (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0));

  bool _hasEntries(String sessionUpper) =>
      _entriesBySession[sessionUpper]!.isNotEmpty;

  // -------------------- ADD (expand via API) --------------------
  Future<void> _addEntry() async {
    _clearMessage();
    if (_isApiCalling) return;

    final raw = bidController.text.trim();
    final amtStr = pointsController.text.trim();

    if (raw.isEmpty) {
      _showMessage('Please enter a number.', isError: true);
      return;
    }
    // SP Motor input: 3–7 digits allowed (keep your rule)
    if (raw.length < 3 || raw.length > 7 || int.tryParse(raw) == null) {
      _showMessage(
        'Please enter a valid number (minimum 3 digits).',
        isError: true,
      );
      return;
    }

    final amt = int.tryParse(amtStr);
    if (amt == null || amt < 10 || amt > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      _showMessage('Authentication error. Please log in again.', isError: true);
      return;
    }

    setState(() => _isApiCalling = true);
    try {
      // IMPORTANT: send digit as STRING to keep leading zeros!
      final resp = await http
          .post(
            Uri.parse('${Constant.apiEndpoint}sp-motor-pana'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
              'deviceId': _deviceId,
              'deviceName': _deviceName,
              'accessStatus': accountStatus ? '1' : '0',
            },
            body: jsonEncode({
              "digit": raw, // <-- string, NOT int.parse(raw)
              "sessionType": selectedGameBetType.toLowerCase(),
              "amount": amt,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final map = jsonDecode(resp.body);
      log('[sp-motor-pana] ${resp.statusCode} $map', name: 'SPMotor');

      if (resp.statusCode == 200 && map['status'] == true) {
        final info = (map['info'] ?? []) as List<dynamic>;
        if (info.isEmpty) {
          _showMessage('No valid bids found for this number.', isError: true);
        } else {
          final session = selectedGameBetType.toUpperCase();
          setState(() {
            for (final item in info) {
              final pana = item['pana']?.toString() ?? '';
              final itemAmt =
                  int.tryParse(item['amount']?.toString() ?? '') ?? amt;
              if (pana.isEmpty) continue;

              final list = _entriesBySession[session]!;
              final idx = list.indexWhere((e) => e['pana'] == pana);
              if (idx != -1) {
                final cur = int.tryParse(list[idx]['amount'] ?? '0') ?? 0;
                list[idx]['amount'] = (cur + itemAmt).toString();
              } else {
                list.add({
                  "pana": pana,
                  "amount": itemAmt.toString(),
                  "type": session, // OPEN/CLOSE
                });
              }
            }
          });
          _showMessage('Bids added from API.');
        }
        setState(() {
          bidController.clear();
          pointsController.clear();
        });
      } else {
        _showMessage(
          map['msg']?.toString() ?? 'Request failed.',
          isError: true,
        );
      }
    } catch (e) {
      log('sp-motor-pana error: $e', name: 'SPMotor');
      _showMessage('Network error. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isApiCalling = false);
    }
  }

  void _removeEntry(String sessionUpper, int index) {
    if (_isApiCalling) return;
    final list = _entriesBySession[sessionUpper]!;
    final removed = list[index]['pana'];
    setState(() => list.removeAt(index));
    _showMessage('Removed: $removed ($sessionUpper)');
  }

  // -------------------- CONFIRM & SUBMIT --------------------
  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    final all = _allEntries();
    if (all.isEmpty) {
      _showMessage('Please add at least one bid.', isError: true);
      return;
    }
    final total = _totalPointsAll();
    if (walletBalance < total) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    final whenStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.gameName,
        gameDate: whenStr,
        bids: all
            .map(
              (e) => {
                "digit": e['pana']!, // show as Digit
                "points": e['amount']!,
                "type": e['type']!, // OPEN / CLOSE
                "pana": e['pana']!,
              },
            )
            .toList(growable: false),
        totalBids: all.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - total).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameCategoryType,
        onConfirm: () async {
          if (!mounted) return;
          setState(() => _isApiCalling = true);

          bool ok = true;
          if (_hasEntries('OPEN')) ok = await _placeFinalForSession('OPEN');
          if (ok && _hasEntries('CLOSE'))
            ok = await _placeFinalForSession('CLOSE');

          if (mounted) setState(() => _isApiCalling = false);
          if (ok) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const BidSuccessDialog(),
            );
          }
        },
      ),
    );
  }

  Future<bool> _placeFinalForSession(String sessionUpper) async {
    final list = _entriesBySession[sessionUpper]!;
    if (list.isEmpty) return true;

    final totalSession = list.fold<int>(
      0,
      (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0),
    );
    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    // CRITICAL: send PANA (not digit) for SP Motor
    final List<Map<String, dynamic>> bidRows = list.map((e) {
      final amt = int.tryParse(e['amount'] ?? '0') ?? 0;
      final pana = e['pana'] ?? '';
      return {
        "sessionType": sessionUpper, // "OPEN"/"CLOSE"
        "digit": "", // keep empty; API uses 'pana'
        "pana": pana,
        "bidAmount": amt,
      };
    }).toList();

    final gameTypeLower =
        widget.gameCategoryType; // keep exactly what backend expects
    final body = jsonEncode({
      "registerId": registerId,
      "gameId": widget.gameId.toString(),
      "bidAmount": totalSession,
      "gameType": gameTypeLower, // e.g. "spMotor"
      "bid": bidRows,
    });

    log('[BidAPI] Headers: $headers', name: 'BidAPI');
    log('[BidAPI] Body   : $body', name: 'BidAPI');

    try {
      final resp = await http.post(
        Uri.parse('${Constant.apiEndpoint}place-bid'),
        headers: headers,
        body: body,
      );
      log('[BidAPI] HTTP ${resp.statusCode}', name: 'BidAPI');

      final map = jsonDecode(resp.body);
      log('[BidAPI] Resp: $map', name: 'BidAPI');

      if (resp.statusCode == 200 &&
          (map['status'] == true || map['status'] == 'true')) {
        // update wallet locally
        final newBal = walletBalance - totalSession;
        await storage.write('walletBalance', newBal);
        setState(() {
          walletBalance = newBal;
          _entriesBySession[sessionUpper]!.clear();
        });
        return true;
      } else {
        final msg = map['msg']?.toString() ?? 'Place bid failed.';
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
  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    // dynamic dropdown values
    final options = <String>[if (widget.selectionStatus) "Open", "Close"];

    // keep selected valid if selectionStatus changed
    if (!options.contains(selectedGameBetType)) {
      selectedGameBetType = options.first;
    }

    final all = _allEntries();
    final canSubmitAny = all.isNotEmpty && !_isApiCalling;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF5F7F8),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title.toUpperCase(),
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 16,
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
            child: Text(
              walletBalance.toString(),
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
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
                          options: options,
                          enabled: !_isApiCalling,
                          displayTextBuilder: (val) => "${widget.gameName} $val".toUpperCase(),
                          onSelected: (v) {
                            setState(() {
                              selectedGameBetType = v;
                              _clearMessage();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _row("Enter Number:", _buildBidInputField()),
                      const SizedBox(height: 12),
                      _row(
                        "Enter Points:",
                        _buildAmountField(pointsController, "Enter Amount"),
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

                if (all.isNotEmpty)
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
                if (all.isNotEmpty) const Divider(thickness: 1, height: 1),

                Expanded(
                  child: all.isEmpty
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
                          itemCount: all.length,
                          itemBuilder: (_, i) {
                            final e = all[i];
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
                                      e['pana']!,
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
                                      e['amount']!,
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
                                      e['type']!.toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: e['type']!.toLowerCase() == 'open'
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFC62828),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _isApiCalling
                                        ? null
                                        : () {
                                            final sess = e['type']!.toUpperCase();
                                            final idx = _entriesBySession[sess]!.indexOf(e);
                                            if (idx != -1) {
                                              _removeEntry(sess, idx);
                                            }
                                          },
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

                if (all.isNotEmpty) _buildBottomBar(canSubmitAny),
              ],
            ),

            if (_message != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedMessageBar(
                  key: _messageKey,
                  message: _message!,
                  isError: _isError,
                  onDismissed: _clearMessage,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // -------------------- small widgets --------------------
  Widget _row(String label, Widget field) {
    String cleanedLabel = label;
    if (label.contains('Select Game Type')) {
      cleanedLabel = 'Select Game Type';
    } else if (label.contains('Enter Number') || label.contains('Number')) {
      cleanedLabel = 'Enter Number';
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

  Widget _buildBidInputField() {
    return SizedBox(
      height: 38,
      child: TextFormField(
        controller: bidController,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        inputFormatters: [
          LengthLimitingTextInputFormatter(7),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: _clearMessage,
        enabled: !_isApiCalling,
        decoration: _tfDecoration("Enter Number"),
      ),
    );
  }

  Widget _buildAmountField(TextEditingController c, String hint) {
    return SizedBox(
      height: 38,
      child: TextFormField(
        controller: c,
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
        onTap: _clearMessage,
        enabled: !_isApiCalling,
        decoration: _tfDecoration(hint),
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
    final totalBids = _allEntries().length;
    final totalPoints = _totalPointsAll();

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
                onPressed: canSubmitAny ? _showConfirmationDialog : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmitAny ? const Color(0xFFF9B233) : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: Text(
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
