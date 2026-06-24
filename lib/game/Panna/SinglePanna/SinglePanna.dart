import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../BidService.dart';
import '../../../Helper/UserController.dart';
import '../../../components/AnimatedMessageBar.dart';
import '../../../components/BidConfirmationDialog.dart';
import '../../../components/BidFailureDialog.dart';
import '../../../components/BidSuccessDialog.dart';
import '../../../components/GameTypeSelectorField.dart';

const List<String> kSinglePana = [
  "120",
  "123",
  "124",
  "125",
  "126",
  "127",
  "128",
  "129",
  "130",
  "134",
  "135",
  "136",
  "137",
  "138",
  "139",
  "140",
  "145",
  "146",
  "147",
  "148",
  "149",
  "150",
  "156",
  "157",
  "158",
  "159",
  "160",
  "167",
  "168",
  "169",
  "170",
  "178",
  "179",
  "180",
  "189",
  "190",
  "230",
  "234",
  "235",
  "236",
  "237",
  "238",
  "239",
  "240",
  "245",
  "246",
  "247",
  "248",
  "249",
  "250",
  "256",
  "257",
  "258",
  "259",
  "260",
  "267",
  "268",
  "269",
  "270",
  "278",
  "279",
  "280",
  "289",
  "290",
  "340",
  "345",
  "346",
  "347",
  "348",
  "349",
  "350",
  "356",
  "357",
  "358",
  "359",
  "360",
  "367",
  "368",
  "369",
  "370",
  "378",
  "379",
  "380",
  "389",
  "390",
  "450",
  "456",
  "457",
  "458",
  "459",
  "460",
  "467",
  "468",
  "469",
  "470",
  "478",
  "479",
  "480",
  "489",
  "490",
  "560",
  "567",
  "568",
  "569",
  "570",
  "578",
  "579",
  "580",
  "589",
  "590",
  "670",
  "678",
  "679",
  "680",
  "689",
  "690",
  "780",
  "789",
  "790",
  "890",
];

class SinglePanaScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameType; // e.g. "singlePana" (exact backend key)
  final String gameName; // for title
  final bool selectionStatus; // true => OPEN allowed

  const SinglePanaScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameType,
    this.gameName = "",
    required this.selectionStatus,
  }) : super(key: key);

  @override
  State<SinglePanaScreen> createState() => _SinglePanaScreenState();
}

class _SinglePanaScreenState extends State<SinglePanaScreen> {
  final TextEditingController _panaCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();

  // { digit: "120", amount: "10", type: "Open"/"Close" }
  final List<Map<String, String>> _bids = [];

  final GetStorage _storage = GetStorage();
  late final BidService _bidService;

  String _accessToken = '';
  String _registerId = '';
  bool _accountStatus = false;

  int _walletBalance = 0;
  bool _isApiCalling = false;

  String _selectedType = 'Open'; // dropdown value

  // message bar
  String? _msg;
  bool _msgError = false;
  Key _msgKey = UniqueKey();
  Timer? _msgTimer;

  final userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  @override
  void initState() {
    super.initState();
    _bidService = BidService(_storage);
    _loadInitial();
  }

  void _loadInitial() {
    _accessToken = _storage.read('accessToken') ?? '';
    _registerId = _storage.read('registerId') ?? '';
    _accountStatus = userController.accountStatus.value;

    final num? bal = num.tryParse(userController.walletBalance.value);
    _walletBalance = bal?.toInt() ?? 0;

    // ensure dropdown respects selectionStatus
    if (!widget.selectionStatus) _selectedType = 'Close';
  }

  @override
  void dispose() {
    _panaCtrl.dispose();
    _amountCtrl.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  void _showMsg(String m, {bool err = false}) {
    _msgTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _msg = m;
      _msgError = err;
      _msgKey = UniqueKey();
    });
    _msgTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _msg = null);
    });
  }

  void _addBid() {
    if (_isApiCalling) return;
    final pana = _panaCtrl.text.trim();
    final amt = _amountCtrl.text.trim();

    if (pana.length != 3) {
      _showMsg('Please enter a valid 3-digit Pana.', err: true);
      return;
    }
    final int? parsed = int.tryParse(amt);
    if (parsed == null || parsed < 10 || parsed > 1000000) {
      _showMsg('Amount must be at least 10.', err: true);
      return;
    }

    setState(() {
      final idx = _bids.indexWhere(
        (b) => b['digit'] == pana && b['type'] == _selectedType,
      );
      if (idx != -1) {
        final current = int.tryParse(_bids[idx]['amount']!) ?? 0;
        _bids[idx]['amount'] = (current + parsed).toString();
      } else {
        _bids.add({'digit': pana, 'amount': amt, 'type': _selectedType});
      }
      _panaCtrl.clear();
      _amountCtrl.clear();
    });

    _showMsg('Added: $pana ($_selectedType) – ₹$amt');
  }

  void _removeBid(int i) {
    if (_isApiCalling) return;
    if (i < 0 || i >= _bids.length) return;
    setState(() => _bids.removeAt(i));
  }

  int _total() =>
      _bids.fold(0, (s, b) => s + (int.tryParse(b['amount'] ?? '0') ?? 0));

  void _confirm() {
    if (_bids.isEmpty) {
      _showMsg('Please add at least one bid.', err: true);
      return;
    }
    final total = _total();
    if (_walletBalance < total) {
      _showMsg('Insufficient wallet balance.', err: true);
      return;
    }

    // IMPORTANT: Dialog me "Digits" column dikhane ke liye hum digit me hi pana bhej rahe
    final dialogRows = _bids
        .map(
          (b) => {
            'digit': b['digit']!, // <-- show this in dialog
            'pana': b['digit']!, // (optional) if dialog ever uses pana column
            'points': b['amount']!,
            'type': b['type']!, // Open / Close (UI)
          },
        )
        .toList();

    final dateText = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.title,
        gameDate: dateText,
        bids: dialogRows,
        totalBids: dialogRows.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction: _walletBalance,
        walletBalanceAfterDeduction: (_walletBalance - total).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () async {
          final ok = await _submitBySession();
          if (ok && mounted) setState(() => _bids.clear());
        },
      ),
    );
  }

  /// Split into up to two requests: OPEN and CLOSE (if both present).
  Future<bool> _submitBySession() async {
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

    // Prepare request maps
    Map<String, String> openMap = {};
    Map<String, String> closeMap = {};
    for (final b in _bids) {
      final d = b['digit']!;
      final a = b['amount']!;
      if (b['type'] == 'Open') {
        openMap[d] = a;
      } else {
        closeMap[d] = a;
      }
    }

    Future<bool> send(String session, Map<String, String> map) async {
      if (map.isEmpty) return true;
      final sum = map.values.fold<int>(0, (s, v) => s + (int.tryParse(v) ?? 0));

      final res = await _bidService.placeFinalBids(
        gameName: widget.title,
        accessToken: _accessToken,
        registerId: _registerId,
        deviceId: 'test_device_id_flutter',
        deviceName: 'test_device_name_flutter',
        accountStatus: _accountStatus,
        bidAmounts: map, // keys are PANAs ("120"), values amounts
        selectedGameType: session, // "OPEN" or "CLOSE"
        gameId: widget.gameId,
        gameType: widget.gameType, // "singlePana" (backend exact key)
        totalBidAmount: sum,
      );

      log('SinglePana -> $session resp: $res');
      if (res['status'] == true) return true;

      final msg = res['msg'] ?? 'Place bid failed.';
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => BidFailureDialog(errorMessage: msg),
      );
      return false;
    }

    if (!mounted) return false;
    setState(() => _isApiCalling = true);

    final ok1 = await send('OPEN', openMap);
    final ok2 = await send('CLOSE', closeMap);

    if (!mounted) return false;
    setState(() => _isApiCalling = false);

    final ok = ok1 && ok2;
    if (ok) {
      final newBal = _walletBalance - _total();
      await _bidService.updateWalletBalance(newBal);
      if (mounted) {
        setState(() => _walletBalance = newBal);
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );
      }
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final types = widget.selectionStatus
        ? const ['Open', 'Close']
        : const ['Close'];

    // keep selection valid
    if (!types.contains(_selectedType)) _selectedType = types.first;

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
                        'Select Game Type:',
                        GameTypeSelectorField(
                          selectedOption: _selectedType,
                          options: types,
                          enabled: !_isApiCalling,
                          displayTextBuilder: (val) => "${widget.title} $val".toUpperCase(),
                          onSelected: (v) {
                            setState(() {
                              _selectedType = v;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _row(
                        'Enter Single Pana:',
                        SizedBox(
                          height: 38,
                          child: Autocomplete<String>(
                            optionsBuilder: (tv) {
                              if (tv.text.isEmpty)
                                return const Iterable<String>.empty();
                              return kSinglePana.where(
                                (p) => p.startsWith(tv.text),
                              );
                            },
                            onSelected: (s) => _panaCtrl.text = s,
                            fieldViewBuilder: (_, textCtrl, focusNode, __) {
                              textCtrl.addListener(
                                () => _panaCtrl.text = textCtrl.text,
                              );
                              return TextFormField(
                                controller: textCtrl,
                                focusNode: focusNode,
                                cursorColor: Colors.orange,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                decoration: _tfDecoration('Bid Pana'),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              );
                            },
                            optionsViewBuilder: (_, onSelected, options) {
                              final list = options.toList();
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 180,
                                    height: list.length > 6
                                        ? 200
                                        : list.length * 40,
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: list.length,
                                      itemBuilder: (_, i) => ListTile(
                                        dense: true,
                                        title: Text(list[i]),
                                        onTap: () => onSelected(list[i]),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _row(
                        'Enter Points:',
                        SizedBox(
                          height: 38,
                          child: TextFormField(
                            controller: _amountCtrl,
                            cursorColor: Colors.orange,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _tfDecoration('Enter Amount'),
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
                                onPressed: _isApiCalling ? null : _addBid,
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
                          itemBuilder: (_, i) {
                            final b = _bids[i];
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
                                      b['type']!.toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: b['type']!.toLowerCase() == 'open'
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFC62828),
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
                if (_bids.isNotEmpty) _buildBottomBar(),
              ],
            ),
            if (_msg != null)
              AnimatedMessageBar(
                key: _msgKey,
                message: _msg!,
                isError: _msgError,
                onDismissed: () => setState(() => _msg = null),
              ),
          ],
        ),
      ),
    );
  }

  // UI helpers
  Widget _row(String label, Widget field) {
    String cleanedLabel = label;
    if (label.contains('Select Game Type')) {
      cleanedLabel = 'Select Game Type';
    } else if (label.contains('Enter Single Pana')) {
      cleanedLabel = 'Enter Single Pana';
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

  Widget _buildBottomBar() {
    int totalBids = _bids.length;
    int totalPoints = _total();

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
                onPressed: _isApiCalling ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isApiCalling ? Colors.grey : const Color(0xFFF9B233),
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

// import 'dart:async';
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
//
// import '../../../BidService.dart';
// import '../../../Helper/UserController.dart';
// import '../../../components/AnimatedMessageBar.dart';
// import '../../../components/BidConfirmationDialog.dart';
// import '../../../components/BidFailureDialog.dart';
// import '../../../components/BidSuccessDialog.dart';
//
// // Allowed Single Pana list
// const List<String> Single_Pana = [
//   "120",
//   "123",
//   "124",
//   "125",
//   "126",
//   "127",
//   "128",
//   "129",
//   "130",
//   "134",
//   "135",
//   "136",
//   "137",
//   "138",
//   "139",
//   "140",
//   "145",
//   "146",
//   "147",
//   "148",
//   "149",
//   "150",
//   "156",
//   "157",
//   "158",
//   "159",
//   "160",
//   "167",
//   "168",
//   "169",
//   "170",
//   "178",
//   "179",
//   "180",
//   "189",
//   "190",
//   "230",
//   "234",
//   "235",
//   "236",
//   "237",
//   "238",
//   "239",
//   "240",
//   "245",
//   "246",
//   "247",
//   "248",
//   "249",
//   "250",
//   "256",
//   "257",
//   "258",
//   "259",
//   "260",
//   "267",
//   "268",
//   "269",
//   "270",
//   "278",
//   "279",
//   "280",
//   "289",
//   "290",
//   "340",
//   "345",
//   "346",
//   "347",
//   "348",
//   "349",
//   "350",
//   "356",
//   "357",
//   "358",
//   "359",
//   "360",
//   "367",
//   "368",
//   "369",
//   "370",
//   "378",
//   "379",
//   "380",
//   "389",
//   "390",
//   "450",
//   "456",
//   "457",
//   "458",
//   "459",
//   "460",
//   "467",
//   "468",
//   "469",
//   "470",
//   "478",
//   "479",
//   "480",
//   "489",
//   "490",
//   "560",
//   "567",
//   "568",
//   "569",
//   "570",
//   "578",
//   "579",
//   "580",
//   "589",
//   "590",
//   "670",
//   "678",
//   "679",
//   "680",
//   "689",
//   "690",
//   "780",
//   "789",
//   "790",
//   "890",
// ];
//
// class SinglePanaScreen extends StatefulWidget {
//   final String title;
//   final int gameId;
//   final String gameType; // e.g. "singlePana"
//   final String gameName;
//   final bool selectionStatus; // true => OPEN available, false => only CLOSE
//
//   const SinglePanaScreen({
//     Key? key,
//     required this.title,
//     required this.gameId,
//     required this.gameType,
//     this.gameName = "",
//     required this.selectionStatus,
//   }) : super(key: key);
//
//   @override
//   State<SinglePanaScreen> createState() => _SinglePanaScreenState();
// }
//
// class _SinglePanaScreenState extends State<SinglePanaScreen> {
//   final TextEditingController digitController = TextEditingController();
//   final TextEditingController amountController = TextEditingController();
//
//   final GetStorage storage = GetStorage();
//   final UserController userController = Get.isRegistered<UserController>()
//       ? Get.find<UserController>()
//       : Get.put(UserController());
//   late final BidService _bidService;
//
//   // Local state
//   List<Map<String, String>> bids = []; // [{digit, amount, type}]
//   String selectedGameType = 'Open'; // shown to user; API will receive UPPERCASE
//   int walletBalance = 0;
//   late String accessToken;
//   late String registerId;
//   late bool accountStatus;
//
//   // Messages
//   String? _messageToShow;
//   bool _isErrorForMessage = false;
//   Key _messageBarKey = UniqueKey();
//   Timer? _msgTimer;
//
//   // Fake device IDs (replace if you have real ones)
//   static const String deviceId = 'test_device_id_flutter';
//   static const String deviceName = 'test_device_name_flutter';
//
//   @override
//   void initState() {
//     super.initState();
//     _bidService = BidService(storage);
//
//     // Read auth + wallet
//     accessToken = storage.read('accessToken') ?? '';
//     registerId = storage.read('registerId') ?? '';
//     accountStatus = userController.accountStatus.value;
//     final num? bal = num.tryParse(userController.walletBalance.value);
//     walletBalance = bal?.toInt() ?? 0;
//
//     // If OPEN isn't allowed, force CLOSE
//     if (!widget.selectionStatus) {
//       selectedGameType = 'Close';
//     }
//   }
//
//   @override
//   void dispose() {
//     _msgTimer?.cancel();
//     digitController.dispose();
//     amountController.dispose();
//     super.dispose();
//   }
//
//   void _showMessage(String message, {bool isError = false}) {
//     _msgTimer?.cancel();
//     if (!mounted) return;
//     setState(() {
//       _messageToShow = message;
//       _isErrorForMessage = isError;
//       _messageBarKey = UniqueKey();
//     });
//     _msgTimer = Timer(const Duration(seconds: 3), () {
//       if (mounted) setState(() => _messageToShow = null);
//     });
//   }
//
//   void _clearMessage() {
//     if (!mounted) return;
//     if (_messageToShow != null) setState(() => _messageToShow = null);
//   }
//
//   // Add/merge a bid
//   void _addBid() {
//     _clearMessage();
//
//     final pana = digitController.text.trim();
//     final amountStr = amountController.text.trim();
//
//     if (pana.isEmpty || amountStr.isEmpty) {
//       _showMessage('Please fill in all fields.', isError: true);
//       return;
//     }
//     if (!Single_Pana.contains(pana)) {
//       _showMessage('Please enter a valid Single Pana number.', isError: true);
//       return;
//     }
//     final amount = int.tryParse(amountStr);
//     if (amount == null || amount < 10) {
//       _showMessage('Minimum amount is 10.', isError: true);
//       return;
//     }
//
//     final existing = bids.indexWhere(
//       (b) => b['digit'] == pana && b['type'] == selectedGameType,
//     );
//
//     setState(() {
//       if (existing != -1) {
//         final current = int.tryParse(bids[existing]['amount'] ?? '0') ?? 0;
//         bids[existing]['amount'] = (current + amount).toString();
//         _showMessage('Updated: $pana ($selectedGameType).');
//       } else {
//         bids.add({
//           'digit': pana,
//           'amount': amount.toString(),
//           'type': selectedGameType,
//         });
//         _showMessage('Added: $pana ($selectedGameType).');
//       }
//       digitController.clear();
//       amountController.clear();
//       FocusScope.of(context).unfocus();
//     });
//   }
//
//   void _removeBid(int index) {
//     _clearMessage();
//     setState(() => bids.removeAt(index));
//     _showMessage('Bid removed.');
//   }
//
//   int _getTotalPoints() {
//     return bids.fold(0, (s, b) => s + (int.tryParse(b['amount'] ?? '0') ?? 0));
//   }
//
//   void _showBidConfirmationDialog() {
//     _clearMessage();
//     if (bids.isEmpty) {
//       _showMessage('Please add at least one bid.', isError: true);
//       return;
//     }
//     final total = _getTotalPoints();
//     if (total > walletBalance) {
//       _showMessage('Insufficient wallet balance.', isError: true);
//       return;
//     }
//
//     final String formattedDate = DateFormat(
//       'dd MMM yyyy, hh:mm a',
//     ).format(DateTime.now());
//
//     // Dialog expects digit/pana/points/type keys – we’ll show as pana
//     final List<Map<String, String>> dialogBids = bids
//         .map(
//           (b) => {
//             'digit': '', // for visual we can leave empty
//             'pana': b['digit'] ?? '', // show as pana
//             'points': b['amount'] ?? '0',
//             'type': b['type'] ?? '',
//           },
//         )
//         .toList();
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => BidConfirmationDialog(
//         gameTitle: widget.title,
//         gameDate: formattedDate,
//         bids: dialogBids,
//         totalBids: dialogBids.length,
//         totalBidsAmount: total,
//         walletBalanceBeforeDeduction: walletBalance,
//         walletBalanceAfterDeduction: (walletBalance - total).toString(),
//         gameId: widget.gameId.toString(),
//         gameType: widget.gameType,
//         onConfirm: () async {
//           final ok = await _placeFinalBids();
//           if (ok && mounted) setState(() => bids.clear());
//         },
//       ),
//     );
//   }
//
//   Future<bool> _placeFinalBids() async {
//     if (accessToken.isEmpty || registerId.isEmpty) {
//       if (!mounted) return false;
//       await showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => const BidFailureDialog(
//           errorMessage: 'Authentication error. Please log in again.',
//         ),
//       );
//       return false;
//     }
//
//     // Build map for the currently selected session (Open/Close)
//     final String session = selectedGameType.toUpperCase();
//     final Map<String, String> payload = {};
//     int batchTotal = 0;
//
//     for (final b in bids) {
//       if ((b['type'] ?? '').toUpperCase() == session) {
//         final pana = b['digit'] ?? ''; // this is the 3-digit pana value
//         final amt = int.tryParse(b['amount'] ?? '0') ?? 0;
//         if (pana.isNotEmpty && amt > 0) {
//           payload[pana] = amt
//               .toString(); // BidService will map pana->"pana" field
//           batchTotal += amt;
//         }
//       }
//     }
//
//     if (payload.isEmpty) {
//       if (!mounted) return false;
//       await showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => const BidFailureDialog(
//           errorMessage: 'No valid bids for the selected session.',
//         ),
//       );
//       return false;
//     }
//
//     try {
//       final result = await _bidService.placeFinalBids(
//         gameName: widget.title,
//         accessToken: accessToken,
//         registerId: registerId,
//         deviceId: deviceId,
//         deviceName: deviceName,
//         accountStatus: accountStatus,
//         bidAmounts: payload,
//         selectedGameType: session, // OPEN / CLOSE
//         gameId: widget.gameId,
//         gameType: widget.gameType, // "singlePana" -> BidService maps to pana
//         totalBidAmount: batchTotal,
//       );
//
//       if (!mounted) return false;
//
//       if (result['status'] == true) {
//         // Update wallet
//         final newBal = walletBalance - batchTotal;
//         await _bidService.updateWalletBalance(newBal);
//         setState(() => walletBalance = newBal);
//
//         await showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (_) => const BidSuccessDialog(),
//         );
//         return true;
//       } else {
//         final msg =
//             (result['msg'] ?? 'Place bid failed. Please try again later.')
//                 .toString();
//         await showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (_) => BidFailureDialog(errorMessage: msg),
//         );
//         return false;
//       }
//     } catch (e) {
//       log('SinglePana submission error: $e', name: 'SinglePanaScreen');
//       if (!mounted) return false;
//       await showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (_) => const BidFailureDialog(
//           errorMessage: 'Network error. Please try again.',
//         ),
//       );
//       return false;
//     }
//   }
//
//   // ---------- UI ----------
//   Widget _inputRow(String label, Widget field) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: GoogleFonts.poppins(
//               fontSize: 13,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           field,
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDropdown() {
//     final List<String> types = widget.selectionStatus
//         ? ['Open', 'Close']
//         : ['Close'];
//     if (!types.contains(selectedGameType)) selectedGameType = types.first;
//
//     return SizedBox(
//       height: 35,
//       width: 150,
//       child: DropdownButtonFormField<String>(
//         value: selectedGameType,
//         isDense: true,
//         decoration: InputDecoration(
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 12,
//             vertical: 0,
//           ),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
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
//         items: types
//             .map(
//               (t) => DropdownMenuItem(
//                 value: t,
//                 child: Text(t, style: GoogleFonts.poppins(fontSize: 14)),
//               ),
//             )
//             .toList(),
//         onChanged: (v) => setState(() => selectedGameType = v ?? types.first),
//       ),
//     );
//   }
//
//   Widget _panaField() {
//     return SizedBox(
//       height: 35,
//       width: 150,
//       child: Autocomplete<String>(
//         optionsBuilder: (val) {
//           if (val.text.isEmpty) return const Iterable<String>.empty();
//           return Single_Pana.where((p) => p.startsWith(val.text));
//         },
//         onSelected: (s) => digitController.text = s,
//         fieldViewBuilder: (context, textCtrl, focusNode, _) {
//           textCtrl.text = digitController.text;
//           return TextFormField(
//             controller: textCtrl,
//             focusNode: focusNode,
//             cursorColor: Colors.orange,
//             keyboardType: TextInputType.number,
//             decoration: InputDecoration(
//               hintText: 'Bid Pana',
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 16,
//                 vertical: 0,
//               ),
//               filled: true,
//               fillColor: Colors.white,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(30),
//                 borderSide: const BorderSide(color: Colors.black),
//               ),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(30),
//                 borderSide: const BorderSide(color: Colors.black),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(30),
//                 borderSide: const BorderSide(color: Colors.orange, width: 2),
//               ),
//             ),
//             style: GoogleFonts.poppins(fontSize: 14),
//             onChanged: (v) => digitController.text = v,
//           );
//         },
//         optionsViewBuilder: (context, onSelected, options) => Align(
//           alignment: Alignment.topLeft,
//           child: Material(
//             elevation: 4,
//             borderRadius: BorderRadius.circular(8),
//             child: SizedBox(
//               width: 150,
//               height: 200,
//               child: ListView.builder(
//                 padding: EdgeInsets.zero,
//                 itemCount: options.length,
//                 itemBuilder: (_, i) => InkWell(
//                   onTap: () => onSelected(options.elementAt(i)),
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 12,
//                     ),
//                     child: Text(
//                       options.elementAt(i),
//                       style: GoogleFonts.poppins(),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _amountField() {
//     return SizedBox(
//       height: 35,
//       width: 150,
//       child: TextFormField(
//         controller: amountController,
//         cursorColor: Colors.orange,
//         keyboardType: TextInputType.number,
//         decoration: InputDecoration(
//           hintText: 'Enter Amount',
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: 0,
//           ),
//           filled: true,
//           fillColor: Colors.white,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(30),
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
//         style: GoogleFonts.poppins(fontSize: 14),
//         onTap: _clearMessage,
//       ),
//     );
//   }
//
//   Widget _tableHeader() {
//     return Padding(
//       padding: const EdgeInsets.only(top: 20, bottom: 8),
//       child: Row(
//         children: [
//           Expanded(
//             flex: 2,
//             child: Text(
//               "Pana",
//               textAlign: TextAlign.center,
//               style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
//             ),
//           ),
//           Expanded(
//             flex: 2,
//             child: Text(
//               "Amount",
//               textAlign: TextAlign.center,
//               style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
//             ),
//           ),
//           Expanded(
//             flex: 3,
//             child: Text(
//               "Game Type",
//               textAlign: TextAlign.center,
//               style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
//             ),
//           ),
//           const SizedBox(width: 48),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xfff2f2f2),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           widget.title,
//           style: GoogleFonts.poppins(
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//             color: Colors.black,
//           ),
//         ),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 16),
//             child: Row(
//               children: [
//                 Image.asset(
//                   "assets/images/ic_wallet.png",
//                   width: 22,
//                   height: 22,
//                   color: Colors.black,
//                 ),
//                 const SizedBox(width: 4),
//                 Obx(
//                   () => Text(
//                     userController.walletBalance.value,
//                     style: GoogleFonts.poppins(
//                       color: Colors.black,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//       body: SafeArea(
//         child: Stack(
//           children: [
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//               child: Column(
//                 children: [
//                   _inputRow("Select Game Type:", _buildDropdown()),
//                   _inputRow("Enter Single Pana:", _panaField()),
//                   _inputRow("Enter Points:", _amountField()),
//                   const SizedBox(height: 10),
//                   Align(
//                     alignment: Alignment.centerRight,
//                     child: SizedBox(
//                       height: 35,
//                       width: 150,
//                       child: ElevatedButton(
//                         onPressed: _addBid,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.orange,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                         ),
//                         child: Text(
//                           "ADD BID",
//                           style: GoogleFonts.poppins(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                   _tableHeader(),
//                   Divider(color: Colors.grey.shade300),
//                   Expanded(
//                     child: bids.isEmpty
//                         ? Center(
//                             child: Text(
//                               "No Bids Added",
//                               style: GoogleFonts.poppins(
//                                 color: Colors.black38,
//                                 fontSize: 16,
//                               ),
//                             ),
//                           )
//                         : ListView.builder(
//                             itemCount: bids.length,
//                             itemBuilder: (context, index) {
//                               final b = bids[index];
//                               return Card(
//                                 margin: const EdgeInsets.symmetric(vertical: 4),
//                                 elevation: 1,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 child: Padding(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 12.0,
//                                     vertical: 10.0,
//                                   ),
//                                   child: Row(
//                                     children: [
//                                       Expanded(
//                                         flex: 2,
//                                         child: Text(
//                                           b['digit']!,
//                                           textAlign: TextAlign.center,
//                                           style: GoogleFonts.poppins(),
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 2,
//                                         child: Text(
//                                           b['amount']!,
//                                           textAlign: TextAlign.center,
//                                           style: GoogleFonts.poppins(),
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 3,
//                                         child: Text(
//                                           b['type']!,
//                                           textAlign: TextAlign.center,
//                                           style: GoogleFonts.poppins(),
//                                         ),
//                                       ),
//                                       SizedBox(
//                                         width: 48,
//                                         child: IconButton(
//                                           icon: const Icon(
//                                             Icons.delete,
//                                             color: Colors.orange,
//                                             size: 20,
//                                           ),
//                                           onPressed: () => _removeBid(index),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               );
//                             },
//                           ),
//                   ),
//                   if (bids.isNotEmpty)
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: 12,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(10),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.grey.withOpacity(0.2),
//                             spreadRadius: 1,
//                             blurRadius: 3,
//                             offset: const Offset(0, 2),
//                           ),
//                         ],
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Column(
//                             children: [
//                               Text(
//                                 "Total Bids:",
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 15,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                               Text(
//                                 "${bids.length}",
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 15,
//                                   fontWeight: FontWeight.w600,
//                                   color: Colors.green.shade700,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           Column(
//                             children: [
//                               Text(
//                                 "Total Points:",
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 15,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                               Text(
//                                 "${_getTotalPoints()}",
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 15,
//                                   fontWeight: FontWeight.w600,
//                                   color: Colors.green.shade700,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           SizedBox(
//                             height: 40,
//                             child: ElevatedButton(
//                               onPressed: _showBidConfirmationDialog,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.orange,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                               ),
//                               child: Text(
//                                 "Submit",
//                                 style: GoogleFonts.poppins(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//             if (_messageToShow != null)
//               AnimatedMessageBar(
//                 key: _messageBarKey,
//                 message: _messageToShow!,
//                 isError: _isErrorForMessage,
//                 onDismissed: _clearMessage,
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
