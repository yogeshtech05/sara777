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

import '../../../../components/AnimatedMessageBar.dart';
import '../../../../components/BidConfirmationDialog.dart';
import '../../../../components/BidFailureDialog.dart';
import '../../../../components/BidSuccessDialog.dart';
import '../../../ulits/Constents.dart';
import '../../Helper/UserController.dart';

class PanelGroupScreen extends StatefulWidget {
  final String title; // e.g., "RADHA NIGHT"
  final String gameCategoryType; // e.g., "panelgroup"
  final int gameId;
  final String gameName; // e.g., "PANEL GROUP"

  const PanelGroupScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
  });

  @override
  State<PanelGroupScreen> createState() => _PanelGroupScreenState();
}

class _PanelGroupScreenState extends State<PanelGroupScreen> {
  // UI controllers
  final TextEditingController panaInputController =
      TextEditingController(); // "e.g., 123, 445"
  final TextEditingController pointsController = TextEditingController();

  // Fixed session for Panel Group (no selector in UI)
  static const String _sessionUpper =
      'OPEN'; // BACKEND needs OPEN/CLOSE; keep OPEN by default

  // Storage / auth / user
  final GetStorage _storage = GetStorage();
  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  late String accessToken;
  late String registerId;
  late bool accountStatus;
  late int walletBalance;

  // Device (if not present, empty strings)
  late final String _deviceId = _storage.read('deviceId') ?? '';
  late final String _deviceName = _storage.read('deviceName') ?? '';

  // State
  bool _isApiCalling = false;
  String? _message;
  bool _isError = false;
  Key _msgKey = UniqueKey();

  // Entries: each {digit, amount, type("OPEN"), gameType("panelgroup")}
  final List<Map<String, String>> _entries = [];

  // Valid list (Panel Group allows the standard 3-digit space)
  final Set<String> _validDigits = {
    "000",
    "100",
    "110",
    "111",
    "112",
    "113",
    "114",
    "115",
    "116",
    "117",
    "118",
    "119",
    "120",
    "122",
    "123",
    "124",
    "125",
    "126",
    "127",
    "128",
    "129",
    "130",
    "133",
    "134",
    "135",
    "136",
    "137",
    "138",
    "139",
    "140",
    "144",
    "145",
    "146",
    "147",
    "148",
    "149",
    "150",
    "155",
    "156",
    "157",
    "158",
    "159",
    "160",
    "166",
    "167",
    "168",
    "169",
    "170",
    "177",
    "178",
    "179",
    "180",
    "188",
    "189",
    "190",
    "199",
    "200",
    "220",
    "222",
    "223",
    "224",
    "225",
    "226",
    "227",
    "228",
    "229",
    "230",
    "233",
    "234",
    "235",
    "236",
    "237",
    "238",
    "239",
    "240",
    "244",
    "245",
    "246",
    "247",
    "248",
    "249",
    "250",
    "255",
    "256",
    "257",
    "258",
    "259",
    "260",
    "266",
    "267",
    "268",
    "269",
    "270",
    "277",
    "278",
    "279",
    "280",
    "288",
    "289",
    "290",
    "299",
    "300",
    "330",
    "333",
    "334",
    "335",
    "336",
    "337",
    "338",
    "339",
    "340",
    "344",
    "345",
    "346",
    "347",
    "348",
    "349",
    "350",
    "355",
    "356",
    "357",
    "358",
    "359",
    "360",
    "366",
    "367",
    "368",
    "369",
    "370",
    "377",
    "378",
    "379",
    "380",
    "388",
    "389",
    "390",
    "399",
    "400",
    "440",
    "444",
    "445",
    "446",
    "447",
    "448",
    "449",
    "450",
    "455",
    "456",
    "457",
    "458",
    "459",
    "460",
    "466",
    "467",
    "468",
    "469",
    "470",
    "477",
    "478",
    "479",
    "480",
    "488",
    "489",
    "490",
    "499",
    "500",
    "550",
    "555",
    "556",
    "557",
    "558",
    "559",
    "560",
    "566",
    "567",
    "568",
    "569",
    "570",
    "577",
    "578",
    "579",
    "580",
    "588",
    "589",
    "590",
    "599",
    "600",
    "660",
    "666",
    "667",
    "668",
    "669",
    "670",
    "677",
    "678",
    "679",
    "680",
    "688",
    "689",
    "690",
    "699",
    "700",
    "770",
    "777",
    "778",
    "779",
    "780",
    "788",
    "789",
    "790",
    "799",
    "800",
    "880",
    "888",
    "889",
    "890",
    "899",
    "900",
    "990",
    "999",
  };

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    accessToken = _storage.read('accessToken') ?? '';
    registerId = _storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;
    final num? bal = num.tryParse(userController.walletBalance.value);
    walletBalance = bal?.toInt() ?? 0;
    setState(() {});
  }

  @override
  void dispose() {
    panaInputController.dispose();
    pointsController.dispose();
    super.dispose();
  }

  // -------- UI helpers --------
  void _showMsg(String m, {bool err = false}) {
    setState(() {
      _message = m;
      _isError = err;
      _msgKey = UniqueKey();
    });
  }

  void _clearMsg() {
    if (!mounted) return;
    setState(() => _message = null);
  }

  int _totalPoints() =>
      _entries.fold(0, (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0));

  // -------- Add flow: parse input -> call expand API -> merge into list --------
  Future<void> _onAddBid() async {
    _clearMsg();
    if (_isApiCalling) return;

    final raw = panaInputController.text.trim();
    final ptsStr = pointsController.text.trim();

    if (raw.isEmpty) {
      _showMsg('Please enter at least one 3-digit pana number.', err: true);
      return;
    }
    final pts = int.tryParse(ptsStr);
    if (pts == null || pts < 10 || pts > 1000) {
      _showMsg('Points must be between 10 and 1000.', err: true);
      return;
    }
    if (accessToken.isEmpty || registerId.isEmpty) {
      _showMsg('Authentication error. Please log in again.', err: true);
      return;
    }

    // Support multiple comma/space separated inputs: "123, 445 128"
    final seeds = raw
        .split(RegExp(r'[,\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Quick validation for seeds (must be 3-digit and in allowed space)
    for (final s in seeds) {
      if (s.length != 3 ||
          int.tryParse(s) == null ||
          !_validDigits.contains(s)) {
        _showMsg('Invalid pana: $s', err: true);
        return;
      }
    }

    setState(() => _isApiCalling = true);
    try {
      // Expand each seed via API (panel-group-pana)
      final List<String> allPanas = [];
      for (final seed in seeds) {
        final expanded = await _expandPanelGroup(seed);
        allPanas.addAll(expanded);
      }

      if (allPanas.isEmpty) {
        _showMsg('No valid panas returned from server.', err: true);
      } else {
        // Merge into list (dedupe by digit, add points)
        setState(() {
          for (final d in allPanas) {
            final i = _entries.indexWhere((e) => e['digit'] == d);
            if (i != -1) {
              final curr = int.tryParse(_entries[i]['amount'] ?? '0') ?? 0;
              _entries[i]['amount'] = (curr + pts).toString();
            } else {
              _entries.add({
                'digit': d,
                'amount': pts.toString(),
                'type': _sessionUpper, // "OPEN"
                'gameType': widget.gameCategoryType, // "panelgroup"
              });
            }
          }
        });
        _showMsg('Added ${allPanas.length} bid(s).');
      }
    } catch (e) {
      _showMsg(e.toString(), err: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _isApiCalling = false;
        // Clear fields after add
        pointsController.clear();
        // keep the last pana input so user can tweak if needed
        panaInputController.clear();
      });
    }
  }

  Future<List<String>> _expandPanelGroup(String digit) async {
    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final body = jsonEncode({
      'digit': digit,
      'sessionType':
          'open', // backend needs something; fixed OPEN for Panel Group
      'amount': 0, // server ignores amount here (we add locally)
    });

    final resp = await http
        .post(
          Uri.parse('${Constant.apiEndpoint}panel-group-pana'),
          headers: headers,
          body: body,
        )
        .timeout(const Duration(seconds: 25));

    final map = jsonDecode(resp.body);
    log(
      'panel-group-pana [$digit] → ${resp.statusCode} | $map',
      name: 'PanelGroup',
    );

    if (resp.statusCode == 200 && map['status'] == true) {
      final List<dynamic> info = (map['info'] ?? []) as List<dynamic>;
      return info
          .map((e) => e['pana']?.toString())
          .whereType<String>()
          .where((s) => s.length == 3)
          .toList();
    } else {
      final msg = map['msg']?.toString() ?? 'Failed to expand pana';
      throw Exception(msg);
    }
  }

  void _removeAt(int index) {
    if (_isApiCalling) return;
    final removed = _entries[index]['digit'];
    setState(() => _entries.removeAt(index));
    _showMsg('Removed $removed');
  }

  // -------- Submit flow --------
  void _confirmSubmit() {
    _clearMsg();
    if (_isApiCalling) return;

    if (_entries.isEmpty) {
      _showMsg('Please add at least one bid.', err: true);
      return;
    }

    final total = _totalPoints();
    if (walletBalance < total) {
      _showMsg('Insufficient wallet balance.', err: true);
      return;
    }

    final when = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: "${widget.title}, PANEL GROUP",
        gameDate: when,
        bids: _entries
            .map(
              (e) => {
                "digit": e['digit']!,
                "points": e['amount']!,
                "type": e['type']!, // shows OPEN
                "pana": e['digit']!,
              },
            )
            .toList(),
        totalBids: _entries.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - total).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameCategoryType,
        onConfirm: () async {
          setState(() => _isApiCalling = true);
          final ok = await _placeFinalBids();
          if (!mounted) return;
          setState(() => _isApiCalling = false);
          if (ok) {
            setState(() => _entries.clear());
          }
        },
      ),
    );
  }

  Future<bool> _placeFinalBids() async {
    final cat = widget.gameCategoryType.toLowerCase();
    final String url = cat.contains('jackpot')
        ? '${Constant.apiEndpoint}place-jackpot-bid'
        : cat.contains('starline')
        ? '${Constant.apiEndpoint}place-starline-bid'
        : '${Constant.apiEndpoint}place-bid';

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

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final List<Map<String, dynamic>> bidRows = _entries.map((e) {
      final amt = int.tryParse(e['amount'] ?? '0') ?? 0;
      final digit = e['digit'] ?? '';
      return {
        "sessionType": _sessionUpper, // "OPEN"
        "digit": digit,
        "pana": digit,
        "bidAmount": amt,
      };
    }).toList();

    final body = jsonEncode({
      "registerId": registerId,
      "gameId": widget.gameId,
      "bidAmount": _totalPoints(),
      "gameType": cat, // "panelgroup"
      "bid": bidRows,
    });

    log('place-bid → $url');
    log('headers: $headers');
    log('body: $body');

    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      final map = jsonDecode(resp.body);
      log('place-bid resp ${resp.statusCode} | $map');

      if (resp.statusCode == 200 &&
          (map['status'] == true || map['status'] == 'true')) {
        final newBal = walletBalance - _totalPoints();
        await _storage.write('walletBalance', newBal);
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
        final msg = map['msg']?.toString() ?? 'Unknown error.';
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(errorMessage: msg),
        );
        return false;
      }
    } catch (e) {
      log('place-bid error: $e');
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

  // -------- UI --------
  @override
  Widget build(BuildContext context) {
    final totalBids = _entries.length;
    final totalPoints = _totalPoints();

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
          "${widget.title}, PANEL GROUP",
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
                fontWeight: FontWeight.w500,
                fontSize: 14.5,
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
                      _row("Enter Pana Number", _panaField()),
                      const SizedBox(height: 12),
                      _row("Enter Points :", _pointsField()),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(flex: 2, child: SizedBox()),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 38,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF9B233),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _isApiCalling ? null : _onAddBid,
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
                if (_entries.isNotEmpty) const Divider(thickness: 1, height: 1),

                Expanded(
                  child: _entries.isEmpty
                      ? Center(
                          child: Text(
                            "No Bids Added",
                            style: GoogleFonts.poppins(
                              color: Colors.black38,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (_, i) {
                            final e = _entries[i];
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
                                      e['digit']!,
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
                                        color: const Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _removeAt(i),
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

                if (_entries.isNotEmpty) _bottomBar(),
              ],
            ),

            if (_message != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedMessageBar(
                  key: _msgKey,
                  message: _message!,
                  isError: _isError,
                  onDismissed: _clearMsg,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ------- Small widgets -------
  Widget _row(String label, Widget field) {
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

  Widget _panaField() {
    return SizedBox(
      height: 38,
      child: TextFormField(
        controller: panaInputController,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.text,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(r'[0-9,\s]'),
          ), // allow digits, comma, space
          LengthLimitingTextInputFormatter(200),
        ],
        onTap: _clearMsg,
        decoration: _tfDecoration("e.g., 123, 445"),
      ),
    );
  }

  Widget _pointsField() {
    return SizedBox(
      height: 38,
      child: TextFormField(
        controller: pointsController,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        onTap: _clearMsg,
        decoration: _tfDecoration("Enter amount"),
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

  Widget _bottomBar() {
    final totalBids = _entries.length;
    final totalPoints = _totalPoints();
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
                onPressed: canSubmit ? _confirmSubmit : null,
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

// import 'dart:async'; // For Timer
// import 'dart:convert'; // For jsonEncode, json.decode
// import 'dart:developer'; // For log
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // For TextInputFormatter
// import 'package:get/get.dart';
// import 'package:get_storage/get_storage.dart'; // Required for wallet balance and tokens
// import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
// import 'package:http/http.dart' as http; // Import for making HTTP requests
// // Marquee is not directly visible in the image, but often used for market names.
// // I'll omit it for simplicity as it's not explicitly requested for this screen's UI.
// // import 'package:marquee/marquee.dart';
// import 'package:intl/intl.dart'; // For date formatting in dialog
//
// import '../../../../components/AnimatedMessageBar.dart';
// import '../../../../components/BidConfirmationDialog.dart';
// import '../../../../components/BidFailureDialog.dart';
// import '../../../../components/BidSuccessDialog.dart';
// import '../../../ulits/Constents.dart';
// import '../../Helper/UserController.dart'; // Retained your original import path
//
// class PanelGroupScreen extends StatefulWidget {
//   final String title; // e.g., "RADHA MORNING"
//   final String gameCategoryType; // e.g., "panelgroup"
//   final int gameId;
//   final String gameName; // e.g., "Panel Group"
//
//   const PanelGroupScreen({
//     super.key,
//     required this.title,
//     required this.gameId,
//     required this.gameName,
//     required this.gameCategoryType,
//   });
//
//   @override
//   State<PanelGroupScreen> createState() => _PanelGroupScreenState();
// }
//
// class _PanelGroupScreenState extends State<PanelGroupScreen> {
//   // Game types options, though not explicitly shown in the image for this screen,
//   // it's a common pattern in betting apps. Assuming "Open" is default.
//   final List<String> gameTypesOptions = const ["Open", "Close"];
//   late String selectedGameBetType; // Default to "Open"
//
//   final TextEditingController digitController = TextEditingController();
//   final TextEditingController pointsController = TextEditingController();
//
//   final String _deviceId = GetStorage().read('deviceId') ?? '';
//   final String _deviceName = GetStorage().read('deviceName') ?? '';
//
//   final UserController userController = Get.put(UserController());
//
//   List<Map<String, String>> addedEntries = []; // List to store the added bids
//
//   final Set<String> validDigits = {
//     "000",
//     "100",
//     "110",
//     "111",
//     "112",
//     "113",
//     "114",
//     "115",
//     "116",
//     "117",
//     "118",
//     "119",
//     "120",
//     "122",
//     "123",
//     "124",
//     "125",
//     "126",
//     "127",
//     "128",
//     "129",
//     "130",
//     "133",
//     "134",
//     "135",
//     "136",
//     "137",
//     "138",
//     "139",
//     "140",
//     "144",
//     "145",
//     "146",
//     "147",
//     "148",
//     "149",
//     "150",
//     "155",
//     "156",
//     "157",
//     "158",
//     "159",
//     "160",
//     "166",
//     "167",
//     "168",
//     "169",
//     "170",
//     "177",
//     "178",
//     "179",
//     "180",
//     "188",
//     "189",
//     "190",
//     "199",
//     "200",
//     "220",
//     "222",
//     "223",
//     "224",
//     "225",
//     "226",
//     "227",
//     "228",
//     "229",
//     "230",
//     "233",
//     "234",
//     "235",
//     "236",
//     "237",
//     "238",
//     "239",
//     "240",
//     "244",
//     "245",
//     "246",
//     "247",
//     "248",
//     "249",
//     "250",
//     "255",
//     "256",
//     "257",
//     "258",
//     "259",
//     "260",
//     "266",
//     "267",
//     "268",
//     "269",
//     "270",
//     "277",
//     "278",
//     "279",
//     "280",
//     "288",
//     "289",
//     "290",
//     "299",
//     "300",
//     "330",
//     "333",
//     "334",
//     "335",
//     "336",
//     "337",
//     "338",
//     "339",
//     "340",
//     "344",
//     "345",
//     "346",
//     "347",
//     "348",
//     "349",
//     "350",
//     "355",
//     "356",
//     "357",
//     "358",
//     "359",
//     "360",
//     "366",
//     "367",
//     "368",
//     "369",
//     "370",
//     "377",
//     "378",
//     "379",
//     "380",
//     "388",
//     "389",
//     "390",
//     "399",
//     "400",
//     "440",
//     "444",
//     "445",
//     "446",
//     "447",
//     "448",
//     "449",
//     "450",
//     "455",
//     "456",
//     "457",
//     "458",
//     "459",
//     "460",
//     "466",
//     "467",
//     "468",
//     "469",
//     "470",
//     "477",
//     "478",
//     "479",
//     "480",
//     "488",
//     "489",
//     "490",
//     "499",
//     "500",
//     "550",
//     "555",
//     "556",
//     "557",
//     "558",
//     "559",
//     "560",
//     "566",
//     "567",
//     "568",
//     "569",
//     "570",
//     "577",
//     "578",
//     "579",
//     "580",
//     "588",
//     "589",
//     "590",
//     "599",
//     "600",
//     "660",
//     "666",
//     "667",
//     "668",
//     "669",
//     "670",
//     "677",
//     "678",
//     "679",
//     "680",
//     "688",
//     "689",
//     "690",
//     "699",
//     "700",
//     "770",
//     "777",
//     "778",
//     "779",
//     "780",
//     "788",
//     "789",
//     "790",
//     "799",
//     "800",
//     "880",
//     "888",
//     "889",
//     "890",
//     "899",
//     "900",
//     "990",
//     "999",
//   };
//
//   // Wallet and user data from GetStorage
//   late int walletBalance; // Changed to int for consistency with GetStorage
//   final GetStorage _storage = GetStorage();
//   late String accessToken;
//   late String registerId;
//   bool accountStatus = false;
//   late String preferredLanguage;
//
//   // State management for AnimatedMessageBar
//   String? _messageToShow;
//   bool _isErrorForMessage = false;
//   Key _messageBarKey = UniqueKey();
//
//   // State variable to track API call status
//   bool _isApiCalling = false;
//
//   @override
//   void initState() {
//     super.initState();
//     selectedGameBetType = gameTypesOptions[0]; // Default to "Open"
//     _loadInitialData();
//   }
//
//   Future<void> _loadInitialData() async {
//     accessToken = _storage.read('accessToken') ?? '';
//     registerId = _storage.read('registerId') ?? '';
//     accountStatus = userController.accountStatus.value;
//     preferredLanguage = _storage.read('selectedLanguage') ?? 'en';
//
//     double _walletBalance = double.parse(userController.walletBalance.value);
//     walletBalance = _walletBalance.toInt();
//   }
//
//   @override
//   void dispose() {
//     digitController.dispose();
//     pointsController.dispose();
//     super.dispose();
//   }
//
//   void _showMessage(String message, {bool isError = false}) {
//     setState(() {
//       _messageToShow = message;
//       _isErrorForMessage = isError;
//       _messageBarKey = UniqueKey();
//     });
//   }
//
//   void _clearMessage() {
//     if (mounted) {
//       setState(() {
//         _messageToShow = null;
//       });
//     }
//   }
//
//   Future<void> _addEntry() async {
//     if (!mounted) return;
//
//     if (_isApiCalling) {
//       _showMessage('An operation is already in progress.', isError: true);
//       return;
//     }
//
//     final String digit = digitController.text.trim();
//     final String points = pointsController.text.trim();
//
//     if (digit.isEmpty || digit.length != 3 || int.tryParse(digit) == null) {
//       _showMessage('Please enter a valid 3-digit number.', isError: true);
//       return;
//     }
//
//     if (!validDigits.contains(digit)) {
//       _showMessage(
//         'Invalid digit. The entered 3-digit number is not in the allowed list.',
//         isError: true,
//       );
//       return;
//     }
//
//     final int? parsedPoints = int.tryParse(points);
//     if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
//       _showMessage(
//         'Points must be a number between 10 and 1000.',
//         isError: true,
//       );
//       return;
//     }
//
//     if (accessToken == null || accessToken.isEmpty) {
//       _showMessage('Authentication error. Please log in again.', isError: true);
//       log(
//         'Error: Access token is missing in _addEntry.',
//         name: 'PanelGroupAddEntry',
//       );
//       return;
//     }
//
//     if (_deviceId == null || _deviceId.isEmpty) {
//       log(
//         'Warning: Device ID is missing in _addEntry. API call might fail.',
//         name: 'PanelGroupAddEntry',
//       );
//     }
//
//     if (!mounted) return;
//
//     setState(() => _isApiCalling = true);
//
//     try {
//       final List<Map<String, String>> newEntries = await _callAddEntryApi(
//         digit: digit,
//         points: parsedPoints,
//       );
//
//       if (mounted) {
//         if (newEntries.isNotEmpty) {
//           setState(() => addedEntries.addAll(newEntries));
//           _showMessage('Added ${newEntries.length} bid(s) successfully.');
//         } else {
//           _showMessage(
//             'API returned data, but no valid panas to add.',
//             isError: false,
//           );
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         _showMessage(e.toString(), isError: true);
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isApiCalling = false;
//           digitController.clear();
//           pointsController.clear();
//         });
//       }
//     }
//   }
//
//   Future<List<Map<String, String>>> _callAddEntryApi({
//     required String digit,
//     required int points,
//   }) async {
//     final headers = {
//       'deviceId': _deviceId ?? '',
//       'deviceName': _deviceName ?? '',
//       'accessStatus': accountStatus == true ? '1' : '0',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $accessToken',
//     };
//
//     final body = jsonEncode({
//       'digit': digit,
//       'sessionType': selectedGameBetType?.toLowerCase() ?? 'open',
//       'amount': points,
//     });
//
//     log(
//       "API Call to panel-group-pana: Headers: $headers, Body: $body",
//       name: "PanelGroupAddEntry",
//     );
//
//     final response = await http
//         .post(
//           Uri.parse('${Constant.apiEndpoint}panel-group-pana'),
//           headers: headers,
//           body: body,
//         )
//         .timeout(const Duration(seconds: 30));
//
//     final responseData = jsonDecode(response.body);
//     log(
//       "API Response panel-group-pana (Status ${response.statusCode}): $responseData",
//       name: "PanelGroupAddEntry",
//     );
//
//     if (response.statusCode == 200 && responseData['status'] == true) {
//       final List<dynamic>? info = responseData['info'] as List<dynamic>?;
//       if (info == null || info.isEmpty) {
//         throw Exception(
//           'No bids returned from the server for the provided digit.',
//         );
//       }
//
//       final List<Map<String, String>> newEntries = [];
//       for (var item in info) {
//         final String? panaValue = item['pana']?.toString();
//         if (panaValue != null && panaValue.isNotEmpty) {
//           newEntries.add({
//             'digit': panaValue,
//             'points': points.toString(),
//             'type': selectedGameBetType ?? 'Unknown',
//           });
//         } else {
//           log(
//             "Warning: API response item missing 'pana': $item",
//             name: "PanelGroupAddEntry",
//           );
//         }
//       }
//
//       return newEntries;
//     } else {
//       final errorMessage =
//           responseData['msg']?.toString() ?? 'Unknown API error occurred.';
//       throw Exception(
//         'API error: $errorMessage (Status: ${response.statusCode})',
//       );
//     }
//   }
//
//   void _removeEntry(int index) {
//     if (_isApiCalling) return;
//
//     setState(() {
//       final removedEntry = addedEntries[index];
//       addedEntries.removeAt(index);
//       _showMessage(
//         'Removed bid: Digit ${removedEntry['digit']}, Type ${removedEntry['type']}.',
//       );
//     });
//   }
//
//   int _getTotalPoints() {
//     return addedEntries.fold(
//       0,
//       (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
//     );
//   }
//
//   void _showConfirmationDialog() {
//     _clearMessage();
//     if (_isApiCalling) return;
//
//     if (addedEntries.isEmpty) {
//       _showMessage('Please add at least one bid.', isError: true);
//       return;
//     }
//
//     final int totalPoints = _getTotalPoints();
//
//     if (walletBalance < totalPoints) {
//       _showMessage(
//         'Insufficient wallet balance to place this bid.',
//         isError: true,
//       );
//       return;
//     }
//
//     final String formattedDate = DateFormat(
//       'dd MMM yyyy, hh:mm a',
//     ).format(DateTime.now());
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return BidConfirmationDialog(
//           gameTitle: widget.gameName,
//           gameDate: formattedDate,
//           bids: addedEntries.map((bid) {
//             return {
//               "digit": bid['digit']!,
//               "points": bid['points']!,
//               "type": bid['type']!,
//               "pana": bid['digit']!,
//               "jodi": "",
//             };
//           }).toList(),
//           totalBids: addedEntries.length,
//           totalBidsAmount: totalPoints,
//           walletBalanceBeforeDeduction: walletBalance,
//           walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
//           gameId: widget.gameId.toString(),
//           gameType: widget.gameCategoryType,
//           onConfirm: () async {
//             // Navigator.pop(dialogContext);
//             setState(() {
//               _isApiCalling = true;
//             });
//             bool success = await _placeFinalBids();
//             if (success) {
//               setState(() {
//                 addedEntries.clear();
//               });
//             }
//             if (mounted) {
//               setState(() {
//                 _isApiCalling = false;
//               });
//             }
//           },
//         );
//       },
//     );
//   }
//
//   Future<bool> _placeFinalBids() async {
//     String url;
//     final gameCategory = widget.gameCategoryType.toLowerCase();
//
//     if (gameCategory.contains('jackpot')) {
//       url = '${Constant.apiEndpoint}place-jackpot-bid';
//     } else if (gameCategory.contains('starline')) {
//       url = '${Constant.apiEndpoint}place-starline-bid';
//     } else {
//       url = '${Constant.apiEndpoint}place-bid';
//     }
//
//     if (accessToken.isEmpty || registerId.isEmpty) {
//       if (mounted) {
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (BuildContext context) {
//             return const BidFailureDialog(
//               errorMessage: 'Authentication error. Please log in again.',
//             );
//           },
//         );
//       }
//       return false;
//     }
//
//     final headers = {
//       'deviceId': _deviceId,
//       'deviceName': _deviceName,
//       'accessStatus': accountStatus ? '1' : '0',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $accessToken',
//     };
//
//     final List<Map<String, dynamic>> bidPayload = addedEntries.map((entry) {
//       final String bidDigit = entry['digit'] ?? '';
//       final int bidAmount = int.tryParse(entry['points'] ?? '0') ?? 0;
//
//       return {
//         "sessionType": entry['type']?.toUpperCase() ?? '',
//         "digit": bidDigit,
//         "pana":
//             bidDigit, // For single digit, pana is often the same as the digit
//         "bidAmount": bidAmount,
//       };
//     }).toList();
//
//     final body = jsonEncode({
//       "registerId": registerId,
//       "gameId": widget.gameId,
//       "bidAmount": _getTotalPoints(),
//       "gameType": gameCategory,
//       "bid": bidPayload,
//     });
//
//     log('Placing bid to URL: $url');
//     log('Request Headers: $headers');
//     log('Request Body: $body');
//
//     try {
//       final response = await http.post(
//         Uri.parse(url),
//         headers: headers,
//         body: body,
//       );
//
//       final Map<String, dynamic> responseBody = json.decode(response.body);
//       log('API Response: $responseBody');
//
//       if (response.statusCode == 200 &&
//           (responseBody['status'] == true ||
//               responseBody['status'] == 'true')) {
//         int newWalletBalance = walletBalance - _getTotalPoints();
//         await _storage.write('walletBalance', newWalletBalance);
//
//         if (mounted) {
//           setState(() {
//             walletBalance = newWalletBalance;
//           });
//           await showDialog(
//             context: context,
//             barrierDismissible: false,
//             builder: (BuildContext context) {
//               return const BidSuccessDialog();
//             },
//           );
//           _clearMessage(); // Clear message after success dialog
//         }
//         return true;
//       } else {
//         String errorMessage = responseBody['msg'] ?? "Unknown error occurred.";
//         if (mounted) {
//           await showDialog(
//             context: context,
//             barrierDismissible: false,
//             builder: (BuildContext context) {
//               return BidFailureDialog(errorMessage: errorMessage);
//             },
//           );
//         }
//         return false;
//       }
//     } catch (e) {
//       log('Error during bid submission: $e');
//       if (mounted) {
//         await showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (BuildContext context) {
//             return const BidFailureDialog(
//               errorMessage:
//                   'Network error. Please check your internet connection.',
//             );
//           },
//         );
//       }
//       return false;
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade200,
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.grey.shade300,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           // Use widget.title for the dynamic market name
//           "${widget.title}, PANEL GROUP",
//           style: GoogleFonts.poppins(
//             color: Colors.black,
//             fontWeight: FontWeight.w600,
//             fontSize: 15,
//           ),
//         ),
//         actions: [
//           Image.asset(
//             "assets/images/ic_wallet.png",
//             width: 22,
//             height: 22,
//             color: Colors.black,
//           ),
//           const SizedBox(width: 6),
//           Center(
//             child: Text(
//               userController.walletBalance.value,
//               style: const TextStyle(
//                 color: Colors.black,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//         ],
//       ),
//       body: SafeArea(
//         child: Stack(
//           children: [
//             Column(
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 12,
//                   ),
//                   child: Column(
//                     children: [
//                       // Enter Points Row
//                       _buildInputRow(
//                         "Enter Points:",
//                         _buildTextField(
//                           pointsController,
//                           "Enter Amount",
//                           inputFormatters: [
//                             FilteringTextInputFormatter.digitsOnly,
//                             LengthLimitingTextInputFormatter(
//                               4,
//                             ), // Max 4 digits for points
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       // Enter Single Digit Row
//                       _buildInputRow(
//                         "Enter Panna:",
//                         _buildTextField(
//                           digitController,
//                           "Panna Digits",
//                           inputFormatters: [
//                             FilteringTextInputFormatter.digitsOnly,
//                             LengthLimitingTextInputFormatter(
//                               3,
//                             ), // Single digit input
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 20),
//                       SizedBox(
//                         width: double.infinity,
//                         height: 45,
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.orange,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(6),
//                             ),
//                           ),
//                           onPressed: _isApiCalling
//                               ? null
//                               : _addEntry, // Disable if API is calling
//                           child: _isApiCalling
//                               ? const CircularProgressIndicator(
//                                   color: Colors.white,
//                                   strokeWidth: 2,
//                                 )
//                               : const Text(
//                                   "ADD BID",
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                         ),
//                       ),
//                       const SizedBox(height: 18),
//                     ],
//                   ),
//                 ),
//                 const Divider(thickness: 1),
//                 // List Headers
//                 if (addedEntries.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 8,
//                     ),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           flex: 2,
//                           child: Text(
//                             "Digit",
//                             style: GoogleFonts.poppins(
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           flex: 2,
//                           child: Text(
//                             "Amount",
//                             style: GoogleFonts.poppins(
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           flex: 3,
//                           child: Text(
//                             "Game Type",
//                             style: GoogleFonts.poppins(
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 48),
//                       ],
//                     ),
//                   ),
//                 if (addedEntries.isNotEmpty) const Divider(thickness: 1),
//                 // List of Added Entries
//                 Expanded(
//                   child: addedEntries.isEmpty
//                       ? const Center(child: Text("No data added yet"))
//                       : ListView.builder(
//                           itemCount: addedEntries.length,
//                           itemBuilder: (_, index) {
//                             final entry = addedEntries[index];
//                             return Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 16,
//                                 vertical: 6,
//                               ),
//                               child: Row(
//                                 children: [
//                                   Expanded(
//                                     flex: 2,
//                                     child: Text(
//                                       entry['digit']!,
//                                       style: GoogleFonts.poppins(),
//                                     ),
//                                   ),
//                                   Expanded(
//                                     flex: 2,
//                                     child: Text(
//                                       entry['points']!,
//                                       style: GoogleFonts.poppins(),
//                                     ),
//                                   ),
//                                   Expanded(
//                                     flex: 3,
//                                     child: Text(
//                                       entry['type']!, // This will be "Open" or "Close"
//                                       style: GoogleFonts.poppins(),
//                                     ),
//                                   ),
//                                   IconButton(
//                                     icon: const Icon(
//                                       Icons.delete,
//                                       color: Colors.orange,
//                                     ),
//                                     onPressed: _isApiCalling
//                                         ? null
//                                         : () => _removeEntry(
//                                             index,
//                                           ), // Disable if API is calling
//                                   ),
//                                 ],
//                               ),
//                             );
//                           },
//                         ),
//                 ),
//                 // Bottom Summary Bar (conditional on addedEntries)
//                 if (addedEntries.isNotEmpty) _buildBottomBar(),
//               ],
//             ),
//             // Animated Message Bar
//             if (_messageToShow != null)
//               Positioned(
//                 top: 0,
//                 left: 0,
//                 right: 0,
//                 child: AnimatedMessageBar(
//                   key: _messageBarKey,
//                   message: _messageToShow!,
//                   isError: _isErrorForMessage,
//                   onDismissed: _clearMessage,
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Helper method for input rows (label + field)
//   Widget _buildInputRow(String label, Widget field) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       crossAxisAlignment: CrossAxisAlignment.center, // Center align items
//       children: [
//         Expanded(
//           flex: 2,
//           child: Text(
//             label,
//             style: GoogleFonts.poppins(
//               fontSize: 15, // Slightly larger font for labels
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ),
//         const SizedBox(width: 10),
//         Expanded(flex: 3, child: field),
//       ],
//     );
//   }
//
//   // Generic TextField builder for consistency
//   Widget _buildTextField(
//     TextEditingController controller,
//     String hint, {
//     List<TextInputFormatter>? inputFormatters,
//   }) {
//     return SizedBox(
//       width: double.infinity, // Take full width of the expanded parent
//       height: 40, // Consistent height for text fields
//       child: TextFormField(
//         controller: controller,
//         cursorColor: Colors.orange,
//         keyboardType: TextInputType.number,
//         style: GoogleFonts.poppins(fontSize: 14),
//         inputFormatters: inputFormatters,
//         onTap: _clearMessage,
//         enabled: !_isApiCalling,
//         decoration: InputDecoration(
//           hintText: hint,
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: 0,
//           ),
//           filled: true,
//           fillColor: Colors.white,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30), // Rounded corners
//             borderSide: const BorderSide(color: Colors.black),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.black),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
//             borderSide: const BorderSide(color: Colors.orange, width: 2),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Bottom bar with total bids/points and submit button
//   Widget _buildBottomBar() {
//     int totalBids = addedEntries.length;
//     int totalPoints = _getTotalPoints();
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.3),
//             spreadRadius: 2,
//             blurRadius: 5,
//             offset: const Offset(0, -3),
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Bids',
//                 style: GoogleFonts.poppins(
//                   fontSize: 14,
//                   color: Colors.grey[700],
//                 ),
//               ),
//               Text(
//                 '$totalBids',
//                 style: GoogleFonts.poppins(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Points',
//                 style: GoogleFonts.poppins(
//                   fontSize: 14,
//                   color: Colors.grey[700],
//                 ),
//               ),
//               Text(
//                 '$totalPoints',
//                 style: GoogleFonts.poppins(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           ElevatedButton(
//             onPressed: _isApiCalling
//                 ? null
//                 : _showConfirmationDialog, // Disable if API is calling
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _isApiCalling
//                   ? Colors.grey
//                   : Colors.orange, // Dim if disabled
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               elevation: 3,
//             ),
//             child: _isApiCalling
//                 ? const CircularProgressIndicator(
//                     color: Colors.white,
//                     strokeWidth: 2,
//                   )
//                 : Text(
//                     'SUBMIT',
//                     style: GoogleFonts.poppins(
//                       color: Colors.white,
//                       fontSize: 16,
//                     ),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }
