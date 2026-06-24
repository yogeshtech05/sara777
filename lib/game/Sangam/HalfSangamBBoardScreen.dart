// lib/screens/half_sangam_b_board_screen.dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../BidService.dart';
import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';

class HalfSangamBBoardScreen extends StatefulWidget {
  final String screenTitle; // e.g., "SRIDEVI NIGHT, HALF SANGAM"
  final String gameType; // "halfSangamB"
  final int gameId;
  final String gameName; // e.g., "SRIDEVI NIGHT"

  const HalfSangamBBoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameType,
    required this.gameId,
    required this.gameName,
  }) : super(key: key);

  @override
  State<HalfSangamBBoardScreen> createState() => _HalfSangamBBoardScreenState();
}

class _HalfSangamBBoardScreenState extends State<HalfSangamBBoardScreen> {
  final TextEditingController _ankController = TextEditingController();
  final TextEditingController _pannaController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  final List<Map<String, String>> _bids = []; // {ank, panna, points}
  final GetStorage _storage = GetStorage();
  late final BidService _bidService;

  String _accessToken = '';
  String _registerId = '';
  String _preferredLanguage = 'en';
  bool _accountStatus = false;
  int _walletBalance = 0; // keep as int for math

  bool _isApiCalling = false;

  static const String _deviceId = 'test_device_id_flutter';
  static const String _deviceName = 'test_device_name_flutter';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  // Short pana list (agar full chahiye to HalfSangamA wali list use kar sakte ho)
  static const List<String> _allPannas = [
    "100",
    "110",
    "112",
    "113",
    "114",
    "115",
    "116",
    "117",
    "118",
    "119",
    "122",
    "133",
    "144",
    "155",
    "166",
    "177",
    "188",
    "199",
    "200",
    "220",
    "223",
    "224",
    "225",
    "226",
    "227",
    "228",
    "229",
    "233",
    "244",
    "255",
    "266",
    "277",
    "288",
    "299",
    "300",
    "330",
    "334",
    "335",
    "336",
    "337",
    "338",
    "339",
    "344",
    "355",
    "366",
    "377",
    "388",
    "399",
    "400",
    "440",
    "445",
    "446",
    "447",
    "448",
    "449",
    "455",
    "466",
    "477",
    "488",
    "499",
    "500",
    "550",
    "556",
    "557",
    "558",
    "559",
    "566",
    "577",
    "588",
    "599",
    "600",
    "660",
    "667",
    "668",
    "669",
    "677",
    "688",
    "699",
    "700",
    "770",
    "778",
    "779",
    "788",
    "799",
    "800",
    "880",
    "889",
    "899",
    "900",
    "990",
  ];

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  @override
  void initState() {
    super.initState();
    log('HalfSangamB: initState');
    _bidService = BidService(_storage);
    _loadInitialData();
    _setupStorageListeners();
  }

  @override
  void dispose() {
    log('HalfSangamB: dispose');
    _ankController.dispose();
    _pannaController.dispose();
    _pointsController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _accessToken = _storage.read('accessToken') ?? '';
    _registerId = _storage.read('registerId') ?? '';
    _accountStatus = userController.accountStatus.value;
    _preferredLanguage = _storage.read('selectedLanguage') ?? 'en';

    final num? bal = num.tryParse(userController.walletBalance.value);
    _walletBalance = bal?.toInt() ?? 0;
    if (mounted) setState(() {});
  }

  void _setupStorageListeners() {
    _storage.listenKey('accessToken', (v) {
      if (mounted) setState(() => _accessToken = (v ?? '').toString());
    });
    _storage.listenKey('registerId', (v) {
      if (mounted) setState(() => _registerId = (v ?? '').toString());
    });
    _storage.listenKey('accountStatus', (v) {
      if (mounted) setState(() => _accountStatus = v == true);
    });
    _storage.listenKey('walletBalance', (v) {
      if (!mounted) return;
      int parsed;
      if (v is int)
        parsed = v;
      else if (v is num)
        parsed = v.toInt();
      else
        parsed = int.tryParse(v?.toString() ?? '0') ?? 0;
      setState(() => _walletBalance = parsed);
    });
    _storage.listenKey('selectedLanguage', (v) {
      if (mounted) setState(() => _preferredLanguage = (v ?? 'en').toString());
    });
  }

  // ---------------- message bar ----------------
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
  }

  // ---------------- helpers ----------------
  int _getTotalPoints() =>
      _bids.fold(0, (s, e) => s + (int.tryParse(e['points'] ?? '0') ?? 0));

  // ---------------- add / remove ----------------
  void _addBid() {
    log('HalfSangamB: _addBid');
    _clearMessage();
    if (_isApiCalling) return;

    final ank = _ankController.text.trim();
    final panna = _pannaController.text.trim();
    final points = _pointsController.text.trim();

    if (ank.length != 1 || int.tryParse(ank) == null) {
      _showMessage('Ank 1 digit ka do (0–9).', isError: true);
      return;
    }
    final ankVal = int.parse(ank);
    if (ankVal < 0 || ankVal > 9) {
      _showMessage('Ank 0 se 9 ke beech do.', isError: true);
      return;
    }

    if (panna.length != 3) {
      _showMessage('Valid 3-digit Panna do (e.g. 119).', isError: true);
      return;
    }

    final int? pts = int.tryParse(points);
    final int minBid =
        int.tryParse(_storage.read('minBid')?.toString() ?? '10') ?? 10;
    if (pts == null || pts < minBid || pts > 1000) {
      _showMessage('Points $minBid se 1000 ke beech do.', isError: true);
      return;
    }

    // Optional guard: tentative total vs wallet
    final nextTotal = _getTotalPoints() + pts;
    if (_walletBalance > 0 && nextTotal > _walletBalance) {
      _showMessage(
        'Itna add karne se total wallet se zyada ho jayega.',
        isError: true,
      );
      return;
    }

    setState(() {
      final idx = _bids.indexWhere(
        (b) => b['ank'] == ank && b['panna'] == panna,
      );
      if (idx != -1) {
        final cur = int.tryParse(_bids[idx]['points'] ?? '0') ?? 0;
        _bids[idx]['points'] = (cur + pts).toString();
        _showMessage('Updated: $ank-$panna.');
      } else {
        _bids.add({"ank": ank, "panna": panna, "points": pts.toString()});
        _showMessage('Added: $ank-$panna — $pts pts.');
      }
      _ankController.clear();
      _pannaController.clear();
      _pointsController.clear();
    });
  }

  void _removeBid(int index) {
    _clearMessage();
    if (_isApiCalling) return;
    if (index < 0 || index >= _bids.length) return;

    setState(() {
      final removed = '${_bids[index]['ank']}-${_bids[index]['panna']}';
      _bids.removeAt(index);
      _showMessage('Removed $removed.');
    });
  }

  // ---------------- confirm & submit ----------------
  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    if (_bids.isEmpty) {
      _showMessage('Pehle kam se kam 1 bid add karo.', isError: true);
      return;
    }

    // refresh wallet from controller
    final num? wb = num.tryParse(userController.walletBalance.value);
    _walletBalance = wb?.toInt() ?? _walletBalance;

    final totalPoints = _getTotalPoints();
    if (_walletBalance < totalPoints) {
      _showMessage('Wallet balance kam hai.', isError: true);
      return;
    }

    // Dialog mapping: Digits = Panna, Game Type = Half Sangam B, Points = amount
    final dialogBids = _bids
        .map(
          (b) => {
            "digit": b['panna']!, // show pana in digits col
            "pana": "",
            "points": b['points']!,
            "type": "Half Sangam B", // show readable type
            "sangam": "${b['ank']}-${b['panna']}",
            "jodi": "",
          },
        )
        .toList();

    final when = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.gameName,
        gameDate: when,
        bids: dialogBids,
        totalBids: dialogBids.length,
        totalBidsAmount: totalPoints,
        walletBalanceBeforeDeduction: _walletBalance,
        walletBalanceAfterDeduction: (_walletBalance - totalPoints).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () async {
          final res = await _placeFinalBids();
          if (!mounted) return;

          if (res['status'] == true) {
            setState(() => _bids.clear());

            final int newBal =
                (res['data']?['wallet_balance'] as num?)?.toInt() ??
                (_walletBalance - totalPoints);

            await _bidService.updateWalletBalance(newBal);
            setState(() => _walletBalance = newBal);

            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const BidSuccessDialog(),
            );
          } else {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => BidFailureDialog(
                errorMessage:
                    res['msg'] ?? 'Bid submission failed. Please try again.',
              ),
            );
          }
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _placeFinalBids() async {
    if (!mounted) return {'status': false, 'msg': 'Screen not mounted.'};
    setState(() => _isApiCalling = true);

    try {
      if (_accessToken.isEmpty || _registerId.isEmpty) {
        return {'status': false, 'msg': 'Auth issue — login dobara karo.'};
      }

      // Key format expected by BidService: "ank-panna"
      final Map<String, String> bidAmounts = {};
      for (final b in _bids) {
        bidAmounts['${b['ank']}-${b['panna']}'] = b['points']!;
      }
      if (bidAmounts.isEmpty) {
        return {'status': false, 'msg': 'No valid bids to submit.'};
      }

      final total = _getTotalPoints();

      // 🔴 Half Sangam B => sessionType = CLOSE (A me OPEN, B me CLOSE)
      const selectedSessionType = "CLOSE";

      final result = await _bidService.placeFinalBids(
        gameName: widget.gameName,
        accessToken: _accessToken,
        registerId: _registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: _accountStatus,
        bidAmounts: bidAmounts,
        selectedGameType: selectedSessionType,
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount: total,
      );

      // local fallback update (agar service ne na kiya ho)
      if (result['status'] == true) {
        final int newBal =
            (result['data']?['wallet_balance'] as num?)?.toInt() ??
            (_walletBalance - total);
        await _bidService.updateWalletBalance(newBal);
        if (mounted) setState(() => _walletBalance = newBal);
      }

      return result;
    } catch (e) {
      return {'status': false, 'msg': 'Unexpected error: $e'};
    } finally {
      if (mounted) setState(() => _isApiCalling = false);
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
            child: Obx(() {
              // show live wallet from controller for header UI
              return Text(
                userController.walletBalance.value,
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              );
            }),
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
                      _inputRow("Enter Open Panna", _pannaField()),
                      const SizedBox(height: 8),
                      _inputRow("Enter Close Ank", _ankField()),
                      const SizedBox(height: 8),
                      _inputRow("Enter Points :", _pointsField()),
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
                                  backgroundColor: _isApiCalling
                                      ? Colors.grey
                                      : const Color(0xFFF9B233), // Golden orange
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _isApiCalling ? null : _addBid,
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
                          itemBuilder: (_, i) {
                            final b = _bids[i];
                            final label = '${b['panna']!} - ${b['ank']!}';
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
                                      label,
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
                                      b['points']!,
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
                                      "CLOSE",
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFC62828),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _removeBid(i),
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

  // ---------------- widgets ----------------
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

  Widget _ankField() {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: _ankController,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        onTap: _clearMessage,
        enabled: !_isApiCalling,
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
      ),
    );
  }

  Widget _pannaField() {
    return SizedBox(
      height: 38,
      child: Autocomplete<String>(
        fieldViewBuilder: (context, tec, focusNode, onFieldSubmitted) {
          if (tec.text != _pannaController.text) {
            tec.text = _pannaController.text;
            tec.selection = TextSelection.collapsed(
              offset: tec.text.length,
            );
          }
          return TextField(
            controller: tec,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (v) => _pannaController.text = v,
            onTap: _clearMessage,
            enabled: !_isApiCalling,
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
            onSubmitted: (_) => onFieldSubmitted(),
          );
        },
        optionsBuilder: (TextEditingValue v) {
          final q = v.text;
          if (q.isEmpty) return const Iterable<String>.empty();
          return _allPannas.where((s) => s.startsWith(q));
        },
        onSelected: (s) => _pannaController.text = s,
        optionsViewBuilder: (context, onSelected, options) {
          final opts = options.toList(growable: false);
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: opts.length > 5 ? 200 : opts.length * 48,
                width: 200,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: opts.length,
                  itemBuilder: (_, i) {
                    final option = opts[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        option,
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pointsField() {
    return SizedBox(
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
        onTap: _clearMessage,
        enabled: !_isApiCalling,
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
      ),
    );
  }

  Widget _bottomBar(int totalBids, int totalPoints) {
    final canSubmit = !_isApiCalling && _bids.isNotEmpty;
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
                onPressed: canSubmit ? _showConfirmationDialog : null,
                child: _isApiCalling
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
