// same imports as before...
import 'dart:async';

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

class FullSangamBoardScreen extends StatefulWidget {
  final String screenTitle;
  final int gameId;

  /// pass EXACT backend type (e.g., "FULLSANGAM")
  final String gameType;
  final String gameName;

  const FullSangamBoardScreen({
    Key? key,
    required this.screenTitle,
    required this.gameType,
    required this.gameId,
    required this.gameName,
  }) : super(key: key);

  @override
  State<FullSangamBoardScreen> createState() => _FullSangamBoardScreenState();
}

class _FullSangamBoardScreenState extends State<FullSangamBoardScreen> {
  final TextEditingController _openPannaController = TextEditingController();
  final TextEditingController _closePannaController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  final List<Map<String, String>> _bids = [];
  final GetStorage _storage = GetStorage();
  late final BidService _bidService;

  String _accessToken = '';
  String _registerId = '';
  bool _accountStatus = false;
  int _walletBalance = 0;

  bool _isApiCalling = false;

  static const String _deviceId = 'test_device_id_flutter';
  static const String _deviceName = 'test_device_name_flutter';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

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
    _bidService = BidService(_storage);
    _loadInitialData();
  }

  @override
  void dispose() {
    _openPannaController.dispose();
    _closePannaController.dispose();
    _pointsController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _accessToken = _storage.read('accessToken') ?? '';
    _registerId = _storage.read('registerId') ?? '';
    _accountStatus = userController.accountStatus.value;

    final balStr = userController.walletBalance.value;
    final num? parsed = num.tryParse(balStr);
    _walletBalance = parsed?.toInt() ?? 0;

    if (mounted) setState(() {});
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
  }

  // ---------- Add / Remove ----------
  void _addBid() {
    if (_isApiCalling) return;
    _clearMessage();

    final openPanna = _openPannaController.text.trim();
    final closePanna = _closePannaController.text.trim();
    final points = _pointsController.text.trim();

    if (openPanna.length != 3 || !_allPannas.contains(openPanna)) {
      _showMessage('Please enter a valid 3-digit Open Panna.', isError: true);
      return;
    }
    if (closePanna.length != 3 || !_allPannas.contains(closePanna)) {
      _showMessage('Please enter a valid 3-digit Close Panna.', isError: true);
      return;
    }

    final int? parsedPoints = int.tryParse(points);
    final int minBid =
        int.tryParse(_storage.read('minBid')?.toString() ?? '10') ?? 10;
    if (parsedPoints == null || parsedPoints < minBid || parsedPoints > 1000) {
      _showMessage('Points must be between $minBid and 1000.', isError: true);
      return;
    }

    final sangam = '$openPanna-$closePanna';

    setState(() {
      final idx = _bids.indexWhere((b) => b['sangam'] == sangam);
      if (idx != -1) {
        _bids[idx]['points'] = (int.parse(_bids[idx]['points']!) + parsedPoints)
            .toString();
        _showMessage('Updated points for $sangam.');
      } else {
        _bids.add({
          "sangam": sangam,
          "points": points,
          "openPanna": openPanna,
          "closePanna": closePanna,
          "type": widget.gameType,
        });
        _showMessage('Added bid: $sangam with $points points.');
      }

      _openPannaController.clear();
      _closePannaController.clear();
      _pointsController.clear();
    });
  }

  void _removeBid(int index) {
    if (_isApiCalling) return;
    _clearMessage();
    if (index < 0 || index >= _bids.length) return;

    setState(() {
      final removedSangam = _bids[index]['sangam'];
      _bids.removeAt(index);
      _showMessage('Bid for $removedSangam removed from list.');
    });
  }

  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, b) => sum + (int.tryParse(b['points'] ?? '0') ?? 0),
    );
  }

  // ---------- Submit flow ----------
  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    if (_bids.isEmpty) {
      _showMessage('Please add at least one bid.', isError: true);
      return;
    }

    final totalPoints = _getTotalPoints();
    if (_walletBalance < totalPoints) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
        isError: true,
      );
      return;
    }

    final bidsForDialog = _bids
        .map(
          (bid) => {
            "pana": bid['openPanna']!,
            "digit": bid['closePanna']!,
            "points": bid['points']!,
            "type": '--',
            "sangam": bid['sangam']!,
            "jodi": "",
          },
        )
        .toList();

    final formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.gameName,
        gameDate: formattedDate,
        bids: bidsForDialog,
        totalBids: bidsForDialog.length,
        totalBidsAmount: totalPoints,
        walletBalanceBeforeDeduction: _walletBalance,
        walletBalanceAfterDeduction: (_walletBalance - totalPoints).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () async {
          final result = await _placeFinalBids();
          if (!mounted) return;

          if (result['status'] == true) {
            setState(() => _bids.clear());

            final int newBalance =
                (result['data']?['wallet_balance'] as num?)?.toInt() ??
                (_walletBalance - totalPoints);

            await _bidService.updateWalletBalance(newBalance);

            if (!mounted) return;
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const BidSuccessDialog(),
            );
          } else {
            if (!mounted) return;
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => BidFailureDialog(
                errorMessage:
                    result['msg'] ?? "Bid submission failed. Please try again.",
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
        return {
          'status': false,
          'msg': 'Authentication error. Please log in again.',
        };
      }

      // Build "openPanna-closePanna" -> "points" map
      final Map<String, String> bidAmountsMap = {
        for (final b in _bids)
          '${b['openPanna']!}-${b['closePanna']!}': b['points']!,
      };

      if (bidAmountsMap.isEmpty) {
        return {'status': false, 'msg': 'No valid bids to submit.'};
      }

      final totalPoints = _getTotalPoints();
      final String payloadGameType = (widget.gameType.isNotEmpty)
          ? widget.gameType
          : 'FULLSANGAM';

      final result = await _bidService.placeFinalBids(
        gameName: widget.gameName,
        accessToken: _accessToken,
        registerId: _registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: _accountStatus,
        bidAmounts: bidAmountsMap,
        selectedGameType: payloadGameType, // important: server mode
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount: totalPoints,
      );

      return result;
    } catch (e) {
      return {'status': false, 'msg': 'An unexpected error occurred: $e'};
    } finally {
      if (mounted) setState(() => _isApiCalling = false);
    }
  }

  // ---------- UI ----------
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
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    children: [
                      _inputRow("Enter Open Panna", _pannaField(_openPannaController)),
                      const SizedBox(height: 8),
                      _inputRow("Enter Close Panna", _pannaField(_closePannaController)),
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
                            final bid = _bids[i];
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
                                      bid['sangam']!,
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
                                      "OPEN",
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2E7D32),
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

  // ---------- widgets ----------
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

  Widget _pannaField(TextEditingController controller) {
    return SizedBox(
      height: 38,
      child: Autocomplete<String>(
        fieldViewBuilder:
            (context, textCtrl, focusNode, onFieldSubmitted) {
              if (textCtrl.text != controller.text) {
                textCtrl.text = controller.text;
                textCtrl.selection = TextSelection.collapsed(
                  offset: textCtrl.text.length,
                );
              }
              return TextField(
                controller: textCtrl,
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
                onChanged: (v) => controller.text = v,
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
        optionsBuilder: (TextEditingValue value) {
          final q = value.text;
          if (q.isEmpty) return const Iterable<String>.empty();
          return _allPannas.where((s) => s.startsWith(q));
        },
        onSelected: (selection) => controller.text = selection,
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

// // same imports as before...
// import 'dart:async';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
//
// import '../../BidService.dart';
// import '../../Helper/UserController.dart';
// import '../../components/AnimatedMessageBar.dart';
// import '../../components/BidConfirmationDialog.dart';
// import '../../components/BidFailureDialog.dart';
// import '../../components/BidSuccessDialog.dart';
//
// class FullSangamBoardScreen extends StatefulWidget {
//   final String screenTitle;
//   final int gameId;
//   final String gameType; // pass EXACT backend type (e.g., FULLSANGAM)
//   final String gameName;
//
//   const FullSangamBoardScreen({
//     Key? key,
//     required this.screenTitle,
//     required this.gameType,
//     required this.gameId,
//     required this.gameName,
//   }) : super(key: key);
//
//   @override
//   State<FullSangamBoardScreen> createState() => _FullSangamBoardScreenState();
// }
//
// class _FullSangamBoardScreenState extends State<FullSangamBoardScreen> {
//   final TextEditingController _openPannaController = TextEditingController();
//   final TextEditingController _closePannaController = TextEditingController();
//   final TextEditingController _pointsController = TextEditingController();
//
//   final List<Map<String, String>> _bids = [];
//   final GetStorage _storage = GetStorage();
//   late final BidService _bidService;
//
//   String _accessToken = '';
//   String _registerId = '';
//   String _preferredLanguage = 'en';
//   bool _accountStatus = false;
//   int _walletBalance = 0;
//
//   bool _isApiCalling = false;
//
//   static const String _deviceId = 'test_device_id_flutter';
//   static const String _deviceName = 'test_device_name_flutter';
//
//   String? _messageToShow;
//   bool _isErrorForMessage = false;
//   Key _messageBarKey = UniqueKey();
//   Timer? _messageDismissTimer;
//
//   static const List<String> _allPannas = [
//     "100",
//     "110",
//     "112",
//     "113",
//     "114",
//     "115",
//     "116",
//     "117",
//     "118",
//     "119",
//     "122",
//     "133",
//     "144",
//     "155",
//     "166",
//     "177",
//     "188",
//     "199",
//     "200",
//     "220",
//     "223",
//     "224",
//     "225",
//     "226",
//     "227",
//     "228",
//     "229",
//     "233",
//     "244",
//     "255",
//     "266",
//     "277",
//     "288",
//     "299",
//     "300",
//     "330",
//     "334",
//     "335",
//     "336",
//     "337",
//     "338",
//     "339",
//     "344",
//     "355",
//     "366",
//     "377",
//     "388",
//     "399",
//     "400",
//     "440",
//     "445",
//     "446",
//     "447",
//     "448",
//     "449",
//     "455",
//     "466",
//     "477",
//     "488",
//     "499",
//     "500",
//     "550",
//     "556",
//     "557",
//     "558",
//     "559",
//     "566",
//     "577",
//     "588",
//     "599",
//     "600",
//     "660",
//     "667",
//     "668",
//     "669",
//     "677",
//     "688",
//     "699",
//     "700",
//     "770",
//     "778",
//     "779",
//     "788",
//     "799",
//     "800",
//     "880",
//     "889",
//     "899",
//     "900",
//     "990",
//   ];
//
//   final UserController userController = Get.isRegistered<UserController>()
//       ? Get.find<UserController>()
//       : Get.put(UserController());
//
//   @override
//   void initState() {
//     super.initState();
//     _bidService = BidService(_storage);
//     _loadInitialData();
//   }
//
//   @override
//   void dispose() {
//     _openPannaController.dispose();
//     _closePannaController.dispose();
//     _pointsController.dispose();
//     _messageDismissTimer?.cancel();
//     super.dispose();
//   }
//
//   Future<void> _loadInitialData() async {
//     _accessToken = _storage.read('accessToken') ?? '';
//     _registerId = _storage.read('registerId') ?? '';
//     _accountStatus = userController.accountStatus.value;
//     _preferredLanguage = _storage.read('selectedLanguage') ?? 'en';
//
//     final balStr = userController.walletBalance.value;
//     final num? parsed = num.tryParse(balStr);
//     _walletBalance = parsed?.toInt() ?? 0;
//
//     if (mounted) setState(() {});
//   }
//
//   void _showMessage(String message, {bool isError = false}) {
//     _messageDismissTimer?.cancel();
//     if (!mounted) return;
//     setState(() {
//       _messageToShow = message;
//       _isErrorForMessage = isError;
//       _messageBarKey = UniqueKey();
//     });
//     _messageDismissTimer = Timer(const Duration(seconds: 3), _clearMessage);
//   }
//
//   void _clearMessage() {
//     if (!mounted) return;
//     setState(() => _messageToShow = null);
//   }
//
//   // ---------- Add / Remove ----------
//   void _addBid() {
//     if (_isApiCalling) return;
//     _clearMessage();
//
//     final openPanna = _openPannaController.text.trim();
//     final closePanna = _closePannaController.text.trim();
//     final points = _pointsController.text.trim();
//
//     if (openPanna.length != 3 || !_allPannas.contains(openPanna)) {
//       _showMessage('Please enter a valid 3-digit Open Panna.', isError: true);
//       return;
//     }
//     if (closePanna.length != 3 || !_allPannas.contains(closePanna)) {
//       _showMessage('Please enter a valid 3-digit Close Panna.', isError: true);
//       return;
//     }
//
//     final int? parsedPoints = int.tryParse(points);
//     final int minBid =
//         int.tryParse(_storage.read('minBid')?.toString() ?? '10') ?? 10;
//     if (parsedPoints == null || parsedPoints < minBid || parsedPoints > 1000) {
//       _showMessage('Points must be between $minBid and 1000.', isError: true);
//       return;
//     }
//
//     final sangam = '$openPanna-$closePanna';
//
//     setState(() {
//       final idx = _bids.indexWhere((b) => b['sangam'] == sangam);
//       if (idx != -1) {
//         _bids[idx]['points'] = (int.parse(_bids[idx]['points']!) + parsedPoints)
//             .toString();
//         _showMessage('Updated points for $sangam.');
//       } else {
//         _bids.add({
//           "sangam": sangam,
//           "points": points,
//           "openPanna": openPanna,
//           "closePanna": closePanna,
//           "type": widget.gameType,
//         });
//         _showMessage('Added bid: $sangam with $points points.');
//       }
//
//       _openPannaController.clear();
//       _closePannaController.clear();
//       _pointsController.clear();
//     });
//   }
//
//   void _removeBid(int index) {
//     if (_isApiCalling) return;
//     _clearMessage();
//     if (index < 0 || index >= _bids.length) return;
//
//     setState(() {
//       final removedSangam = _bids[index]['sangam'];
//       _bids.removeAt(index);
//       _showMessage('Bid for $removedSangam removed from list.');
//     });
//   }
//
//   int _getTotalPoints() {
//     return _bids.fold(
//       0,
//       (sum, b) => sum + (int.tryParse(b['points'] ?? '0') ?? 0),
//     );
//   }
//
//   // ---------- Submit flow ----------
//   void _showConfirmationDialog() {
//     _clearMessage();
//     if (_isApiCalling) return;
//
//     if (_bids.isEmpty) {
//       _showMessage('Please add at least one bid.', isError: true);
//       return;
//     }
//
//     final totalPoints = _getTotalPoints();
//     if (_walletBalance < totalPoints) {
//       _showMessage(
//         'Insufficient wallet balance to place this bid.',
//         isError: true,
//       );
//       return;
//     }
//
//     final bidsForDialog = _bids
//         .map(
//           (bid) => {
//             "pana": bid['openPanna']!,
//             "digit": bid['closePanna']!,
//             "points": bid['points']!,
//             "type": '--',
//             "sangam": bid['sangam']!,
//             "jodi": "",
//           },
//         )
//         .toList();
//
//     final formattedDate = DateFormat(
//       'dd MMM yyyy, hh:mm a',
//     ).format(DateTime.now());
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => BidConfirmationDialog(
//         gameTitle: widget.gameName,
//         gameDate: formattedDate,
//         bids: bidsForDialog,
//         totalBids: bidsForDialog.length,
//         totalBidsAmount: totalPoints,
//         walletBalanceBeforeDeduction: _walletBalance,
//         walletBalanceAfterDeduction: (_walletBalance - totalPoints).toString(),
//         gameId: widget.gameId.toString(),
//         gameType: widget.gameType,
//         onConfirm: () async {
//           final result = await _placeFinalBids();
//           if (!mounted) return;
//
//           if (result['status'] == true) {
//             setState(() => _bids.clear());
//             final int newBalance =
//                 (result['data']?['wallet_balance'] as num?)?.toInt() ??
//                 (_walletBalance - totalPoints);
//             await _bidService.updateWalletBalance(newBalance);
//             await showDialog(
//               context: context,
//               barrierDismissible: false,
//               builder: (_) => const BidSuccessDialog(),
//             );
//           } else {
//             await showDialog(
//               context: context,
//               barrierDismissible: false,
//               builder: (_) => BidFailureDialog(
//                 errorMessage:
//                     result['msg'] ?? "Bid submission failed. Please try again.",
//               ),
//             );
//           }
//         },
//       ),
//     );
//   }
//
//   Future<Map<String, dynamic>> _placeFinalBids() async {
//     if (!mounted) return {'status': false, 'msg': 'Screen not mounted.'};
//     setState(() => _isApiCalling = true);
//
//     try {
//       if (_accessToken.isEmpty || _registerId.isEmpty) {
//         return {
//           'status': false,
//           'msg': 'Authentication error. Please log in again.',
//         };
//       }
//
//       // Build "openPanna-closePanna" -> "points" map (already our internal format)
//       final Map<String, String> bidAmountsMap = {
//         for (final b in _bids)
//           '${b['openPanna']!}-${b['closePanna']!}': b['points']!,
//       };
//
//       if (bidAmountsMap.isEmpty) {
//         return {'status': false, 'msg': 'No valid bids to submit.'};
//       }
//
//       final totalPoints = _getTotalPoints();
//       final String payloadGameType = (widget.gameType.isNotEmpty)
//           ? widget.gameType
//           : 'FULLSANGAM';
//
//       final result = await _bidService.placeFinalBids(
//         gameName: widget.gameName,
//         accessToken: _accessToken,
//         registerId: _registerId,
//         deviceId: _deviceId,
//         deviceName: _deviceName,
//         accountStatus: _accountStatus,
//         bidAmounts: bidAmountsMap,
//         selectedGameType: payloadGameType, // important: drives split logic
//         gameId: widget.gameId,
//         gameType: widget.gameType,
//         totalBidAmount: totalPoints,
//       );
//
//       return result;
//     } catch (e) {
//       return {'status': false, 'msg': 'An unexpected error occurred: $e'};
//     } finally {
//       if (mounted) setState(() => _isApiCalling = false);
//     }
//   }
//
//   // ---------- UI ----------
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F5F5),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 1,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           widget.screenTitle,
//           style: GoogleFonts.poppins(
//             color: Colors.black,
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
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
//             child: Obx(
//               () => Text(
//                 '₹${userController.walletBalance.value}',
//                 style: GoogleFonts.poppins(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black,
//                 ),
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
//                     horizontal: 16.0,
//                     vertical: 12.0,
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _pannaField(
//                         'Enter Open Panna :',
//                         _openPannaController,
//                         hint: 'e.g., 123',
//                         onSubmitted: _addBid,
//                       ),
//                       const SizedBox(height: 16),
//                       _pannaField(
//                         'Enter Close Panna :',
//                         _closePannaController,
//                         hint: 'e.g., 456',
//                         onSubmitted: _addBid,
//                       ),
//                       const SizedBox(height: 16),
//                       _pointsField(),
//                       const SizedBox(height: 20),
//                       SizedBox(
//                         width: double.infinity,
//                         height: 45,
//                         child: ElevatedButton(
//                           onPressed: _isApiCalling ? null : _addBid,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: _isApiCalling
//                                 ? Colors.grey
//                                 : Colors.orange,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(6),
//                             ),
//                           ),
//                           child: _isApiCalling
//                               ? const SizedBox(
//                                   height: 20,
//                                   width: 20,
//                                   child: CircularProgressIndicator(
//                                     valueColor: AlwaysStoppedAnimation<Color>(
//                                       Colors.white,
//                                     ),
//                                     strokeWidth: 2,
//                                   ),
//                                 )
//                               : Text(
//                                   "ADD",
//                                   style: GoogleFonts.poppins(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.w600,
//                                     letterSpacing: .5,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const Divider(thickness: 1),
//
//                 if (_bids.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 8,
//                     ),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             'Sangam',
//                             style: GoogleFonts.poppins(
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           child: Text(
//                             'Points',
//                             style: GoogleFonts.poppins(
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 48),
//                       ],
//                     ),
//                   ),
//                 if (_bids.isNotEmpty) const Divider(thickness: 1),
//
//                 Expanded(
//                   child: _bids.isEmpty
//                       ? Center(
//                           child: Text(
//                             'No Bids Placed',
//                             style: GoogleFonts.poppins(color: Colors.grey),
//                           ),
//                         )
//                       : ListView.builder(
//                           itemCount: _bids.length,
//                           itemBuilder: (_, i) {
//                             final bid = _bids[i];
//                             return Container(
//                               margin: const EdgeInsets.symmetric(
//                                 horizontal: 10,
//                                 vertical: 4,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(8),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.grey.withOpacity(0.2),
//                                     spreadRadius: 1,
//                                     blurRadius: 3,
//                                     offset: const Offset(0, 1),
//                                   ),
//                                 ],
//                               ),
//                               child: Padding(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 16,
//                                   vertical: 8,
//                                 ),
//                                 child: Row(
//                                   children: [
//                                     Expanded(
//                                       child: Text(
//                                         bid['sangam']!,
//                                         style: GoogleFonts.poppins(),
//                                       ),
//                                     ),
//                                     Expanded(
//                                       child: Text(
//                                         bid['points']!,
//                                         style: GoogleFonts.poppins(),
//                                       ),
//                                     ),
//                                     IconButton(
//                                       icon: const Icon(
//                                         Icons.delete,
//                                         color: Colors.orange,
//                                       ),
//                                       onPressed: _isApiCalling
//                                           ? null
//                                           : () => _removeBid(i),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                 ),
//
//                 SafeArea(top: false, child: _bottomBar()),
//               ],
//             ),
//
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
//   // ---------- field builders ----------
//   Widget _pointsField() {
//     return _inputRow(
//       'Enter Points :',
//       _pointsController,
//       hintText: 'e.g., 100',
//       maxLength: 4,
//       onSubmitted: _addBid,
//     );
//   }
//
//   Widget _pannaField(
//     String label,
//     TextEditingController controller, {
//     required String hint,
//     VoidCallback? onSubmitted,
//   }) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(label, style: GoogleFonts.poppins(fontSize: 16)),
//         SizedBox(
//           width: 150,
//           height: 40,
//           child: Autocomplete<String>(
//             fieldViewBuilder: (context, textCtrl, focusNode, _) {
//               textCtrl.text = controller.text;
//               textCtrl.selection = TextSelection.fromPosition(
//                 TextPosition(offset: textCtrl.text.length),
//               );
//
//               return TextField(
//                 cursorColor: Colors.orange,
//                 controller: textCtrl,
//                 focusNode: focusNode,
//                 keyboardType: TextInputType.number,
//                 inputFormatters: [
//                   FilteringTextInputFormatter.digitsOnly,
//                   LengthLimitingTextInputFormatter(3),
//                 ],
//                 onChanged: (v) => controller.text = v,
//                 decoration: InputDecoration(
//                   hintText: hint,
//                   contentPadding: const EdgeInsets.symmetric(horizontal: 12),
//                   border: const OutlineInputBorder(
//                     borderRadius: BorderRadius.all(Radius.circular(20)),
//                     borderSide: BorderSide(color: Colors.black),
//                   ),
//                   enabledBorder: const OutlineInputBorder(
//                     borderRadius: BorderRadius.all(Radius.circular(20)),
//                     borderSide: BorderSide(color: Colors.black),
//                   ),
//                   focusedBorder: const OutlineInputBorder(
//                     borderRadius: BorderRadius.all(Radius.circular(20)),
//                     borderSide: BorderSide(color: Colors.orange, width: 2),
//                   ),
//                   suffixIcon: const Icon(
//                     Icons.arrow_forward,
//                     color: Colors.orange,
//                     size: 20,
//                   ),
//                 ),
//                 onSubmitted: (_) => onSubmitted?.call(),
//               );
//             },
//             optionsBuilder: (value) {
//               if (value.text.isEmpty) return const Iterable<String>.empty();
//               return _allPannas.where((s) => s.startsWith(value.text));
//             },
//             onSelected: (s) {
//               controller.text = s;
//               onSubmitted?.call();
//             },
//             optionsViewBuilder: (context, onSelected, options) {
//               final list = options.toList(growable: false);
//               return Align(
//                 alignment: Alignment.topLeft,
//                 child: Material(
//                   elevation: 4,
//                   child: SizedBox(
//                     height: list.length > 5 ? 200 : list.length * 48,
//                     width: 150,
//                     child: ListView.builder(
//                       padding: EdgeInsets.zero,
//                       itemCount: list.length,
//                       itemBuilder: (_, i) => ListTile(
//                         dense: true,
//                         title: Text(
//                           list[i],
//                           style: GoogleFonts.poppins(fontSize: 14),
//                         ),
//                         onTap: () => onSelected(list[i]),
//                       ),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _inputRow(
//     String label,
//     TextEditingController controller, {
//     String hintText = '',
//     int? maxLength,
//     bool enabled = true,
//     VoidCallback? onSubmitted,
//   }) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(label, style: GoogleFonts.poppins(fontSize: 16)),
//         SizedBox(
//           width: 150,
//           height: 40,
//           child: TextField(
//             cursorColor: Colors.orange,
//             controller: controller,
//             keyboardType: TextInputType.number,
//             inputFormatters: [
//               FilteringTextInputFormatter.digitsOnly,
//               if (maxLength != null)
//                 LengthLimitingTextInputFormatter(maxLength),
//             ],
//             onTap: _clearMessage,
//             enabled: enabled,
//             onSubmitted: (_) => onSubmitted?.call(),
//             decoration: InputDecoration(
//               hintText: hintText,
//               contentPadding: const EdgeInsets.symmetric(horizontal: 12),
//               border: const OutlineInputBorder(
//                 borderRadius: BorderRadius.all(Radius.circular(20)),
//                 borderSide: BorderSide(color: Colors.black),
//               ),
//               enabledBorder: const OutlineInputBorder(
//                 borderRadius: BorderRadius.all(Radius.circular(20)),
//                 borderSide: BorderSide(color: Colors.black),
//               ),
//               focusedBorder: const OutlineInputBorder(
//                 borderRadius: BorderRadius.all(Radius.circular(20)),
//                 borderSide: BorderSide(color: Colors.orange, width: 2),
//               ),
//               suffixIcon: const Icon(
//                 Icons.arrow_forward,
//                 color: Colors.orange,
//                 size: 20,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _bottomBar() {
//     final totalBids = _bids.length;
//     final totalPoints = _getTotalPoints();
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
//           _SummaryTile(title: 'Bid', value: '$totalBids'),
//           _SummaryTile(title: 'Total', value: '$totalPoints'),
//           ElevatedButton(
//             onPressed: (_isApiCalling || _bids.isEmpty)
//                 ? null
//                 : _showConfirmationDialog,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: (_isApiCalling || _bids.isEmpty)
//                   ? Colors.grey
//                   : Colors.orange,
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               elevation: 3,
//             ),
//             child: _isApiCalling
//                 ? const SizedBox(
//                     width: 18,
//                     height: 18,
//                     child: CircularProgressIndicator(
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                       strokeWidth: 2,
//                     ),
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
//
// class _SummaryTile extends StatelessWidget {
//   final String title;
//   final String value;
//   const _SummaryTile({required this.title, required this.value});
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           title,
//           style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
//         ),
//         Text(
//           value,
//           style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
//         ),
//       ],
//     );
//   }
// }
