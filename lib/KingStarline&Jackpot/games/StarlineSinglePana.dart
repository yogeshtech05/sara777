import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:new_sara/KingStarline&Jackpot/StarlineBidService.dart';

import '../../../components/AnimatedMessageBar.dart';
import '../../../components/BidConfirmationDialog.dart';
import '../../../components/BidFailureDialog.dart';
import '../../../components/BidSuccessDialog.dart';
import '../../Helper/UserController.dart';

// ---- Single Panna master list ----
const List<String> Single_Pana = [
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

class StarlineSinglePannaScreen extends StatefulWidget {
  final String title; // e.g. "Starline Single Panna"
  final int gameId; // TYPE id (send as STRING in API)
  final String gameType; // e.g. "singlePana"
  final String gameName; // label, e.g. "Starline ..." or "Jackpot ..."
  final bool selectionStatus; // true => bidding open (UI only)

  const StarlineSinglePannaScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameType,
    this.gameName = "",
    required this.selectionStatus,
  }) : super(key: key);

  @override
  State<StarlineSinglePannaScreen> createState() =>
      _StarlineSinglePannaScreenState();
}

class _StarlineSinglePannaScreenState extends State<StarlineSinglePannaScreen> {
  final TextEditingController digitController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  // UI label only (API does not use sessionType)
  final String selectedGameType = 'Open';

  // auth / device
  final GetStorage _box = GetStorage();
  late String accessToken;
  late String registerId;
  String deviceId = "flutter_device";
  String deviceName = "Flutter_App";
  bool accountStatus = false;

  // app state
  List<Map<String, String>> bids = []; // {digit, amount, type}
  int walletBalance = 0;

  // message bar
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _hideTimer;

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  static const int _minBet = 10;
  static const int _maxBet = 1000;

  bool get _biddingClosed => !widget.selectionStatus;

  @override
  void initState() {
    super.initState();
    accessToken = _box.read('accessToken') ?? '';
    registerId = _box.read('registerId') ?? '';
    print("🔐 INIT → accessToken = $accessToken");
    print("👤 INIT → registerId = $registerId");
    deviceId = _box.read('deviceId')?.toString() ?? deviceId;
    deviceName = _box.read('deviceName')?.toString() ?? deviceName;
    accountStatus = userController.accountStatus.value;

    // wallet from controller (string) -> int
    final balNum = num.tryParse(userController.walletBalance.value);
    walletBalance = (balNum ?? 0).toInt();

    // live wallet sync
    _box.listenKey('walletBalance', (value) {
      final int newBal = int.tryParse(value?.toString() ?? '0') ?? 0;
      if (mounted) setState(() => walletBalance = newBal);
    });

    _loadSavedBids();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    digitController.dispose();
    amountController.dispose();
    super.dispose();
  }

  // -------------------- storage helpers --------------------
  void _loadSavedBids() {
    final dynamic saved = _box.read('placedBids');
    if (saved is List) {
      final parsed = saved
          .whereType<Map>()
          .map(
            (e) => {
              'digit': e['digit']?.toString() ?? '',
              'amount': e['amount']?.toString() ?? '',
              'type': e['type']?.toString() ?? '',
            },
          )
          .where(
            (m) =>
                m['digit']!.isNotEmpty &&
                m['amount']!.isNotEmpty &&
                m['type']!.isNotEmpty,
          )
          .toList();
      setState(() => bids = parsed);
    }
  }

  void _saveBids() => _box.write('placedBids', bids);

  // -------------------- messages --------------------
  void _showMessage(String msg, {bool isError = false}) {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messageToShow = msg;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _messageToShow = null);
    });
  }

  void _clearMessage() {
    _hideTimer?.cancel();
    if (mounted) setState(() => _messageToShow = null);
  }

  // -------------------- add/remove bids --------------------
  Future<void> _addBid() async {
    _clearMessage();

    if (_biddingClosed) {
      _showMessage('Bidding is closed for this slot.', isError: true);
      return;
    }

    final digit = digitController.text.trim();
    final amount = amountController.text.trim();

    if (digit.isEmpty || amount.isEmpty) {
      _showMessage('Please fill in all fields.', isError: true);
      return;
    }
    if (!Single_Pana.contains(digit)) {
      _showMessage('Please enter a valid Single Panna number.', isError: true);
      return;
    }
    final intAmount = int.tryParse(amount);
    if (intAmount == null || intAmount < _minBet || intAmount > _maxBet) {
      _showMessage(
        'Amount must be between $_minBet and $_maxBet.',
        isError: true,
      );
      return;
    }

    // wallet check with new/updated total
    final existingIdx = bids.indexWhere(
      (e) => e['digit'] == digit && e['type'] == selectedGameType,
    );
    int currentTotal = _getTotalPoints();
    if (existingIdx != -1) {
      currentTotal -= int.tryParse(bids[existingIdx]['amount'] ?? '0') ?? 0;
    }
    final nextTotal = currentTotal + intAmount;
    if (nextTotal > walletBalance) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    setState(() {
      if (existingIdx != -1) {
        final cur = int.tryParse(bids[existingIdx]['amount']!) ?? 0;
        bids[existingIdx]['amount'] = (cur + intAmount).toString();
        _showMessage('Updated amount for Panna: $digit.');
      } else {
        bids.add({
          'digit': digit,
          'amount': intAmount.toString(),
          'type': selectedGameType,
        });
        _showMessage('Added bid: Panna $digit, Amount $intAmount.');
      }
      digitController.clear();
      amountController.clear();
      FocusScope.of(context).unfocus();
      _saveBids();
    });
  }

  void _removeBid(int index) {
    _clearMessage();
    setState(() => bids.removeAt(index));
    _saveBids();
    _showMessage('Bid removed from list.');
  }

  int _getTotalPoints() =>
      bids.fold(0, (sum, e) => sum + (int.tryParse(e['amount'] ?? '0') ?? 0));

  // -------------------- confirm & submit --------------------
  void _showBidConfirmationDialog() {
    _clearMessage();

    if (bids.isEmpty) {
      _showMessage('Please add at least one bid to confirm.', isError: true);
      return;
    }
    if (_biddingClosed) {
      _showMessage('Bidding is closed for this slot.', isError: true);
      return;
    }

    final totalPoints = _getTotalPoints();
    if (totalPoints > walletBalance) {
      _showMessage('Insufficient wallet balance for all bids.', isError: true);
      return;
    }

    final when = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.title,
        gameDate: when,
        bids: bids, // {digit, amount, type} – your dialog already supports this
        totalBids: bids.length,
        totalBidsAmount: totalPoints,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
        gameId: widget.gameId.toString(), // TYPE id as string
        gameType: widget.gameType, // "singlePana"
        onConfirm: () async {
          final ok = await _placeFinalBids();
          if (ok && mounted) {
            setState(() => bids.clear());
            _saveBids();
          }
        },
      ),
    );
  }

  Market _detectMarket() {
    final s = ('${widget.title} ${widget.gameName}').toLowerCase();
    return s.contains('jackpot') ? Market.jackpot : Market.starline;
  }

  Future<bool> _placeFinalBids() async {
    if (!mounted) return false;

    // build digit->amount map for current type
    final Map<String, String> bidPayload = {};
    int batchTotal = 0;
    for (final e in bids) {
      if ((e['type'] ?? '').toUpperCase() == selectedGameType.toUpperCase()) {
        final d = e['digit'] ?? '';
        final a = int.tryParse(e['amount'] ?? '0') ?? 0;
        if (d.isNotEmpty && a > 0) {
          bidPayload[d] = a.toString();
          batchTotal += a;
        }
      }
    }

    if (bidPayload.isEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'No valid bids for the selected game type.',
        ),
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

    final service = StarlineBidService(_box); // unified: handles both endpoints
    bool success = false;
    String? err;

    try {
      final market = _detectMarket();

      final result = await service.placeFinalBids(
        market: market,
        accessToken: accessToken,
        registerId: registerId,
        deviceId: deviceId,
        deviceName: deviceName,
        accountStatus: accountStatus,
        bidAmounts: bidPayload,
        gameId: widget.gameId, // TYPE id (int here; service sends string)
        gameType: widget.gameType, // "singlePana"
        totalBidAmount: batchTotal,
      );

      if (!mounted) return false;

      success = result['status'] == true;
      if (!success) err = (result['msg'] ?? 'Something went wrong').toString();

      if (success) {
        // Prefer server wallet if available
        final dynamic updatedBalanceRaw =
            result['updatedWalletBalance'] ??
            result['data']?['updatedWalletBalance'] ??
            result['data']?['wallet_balance'];

        final int newBal =
            int.tryParse(updatedBalanceRaw?.toString() ?? '') ??
            (walletBalance - batchTotal);

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );

        setState(() => walletBalance = newBal);
        await service.updateWalletBalance(newBal);
        userController.walletBalance.value = newBal.toString();

        return true;
      }
    } catch (e) {
      log('Error during bid placement: $e', name: 'StarlineSinglePannaSubmit');
      err = 'An unexpected error occurred during bid submission.';
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidFailureDialog(errorMessage: err ?? 'Unknown error'),
    );
    // (optional) keep bids for retry; comment this if you don’t want to clear.
    // setState(() {
    //   bids.removeWhere((e) => (e['type'] ?? '').toUpperCase() == selectedGameType.toUpperCase());
    // });
    // _saveBids();
    return false;
  }

  // -------------------- UI --------------------
  Widget _inputRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          field,
        ],
      ),
    );
  }

  // Common input builder; digit field uses Autocomplete, amount normal textfield
  Widget _buildInputField(TextEditingController controller, String hint) {
    final isDigit = controller == digitController;

    if (!isDigit) {
      return SizedBox(
        height: 38, width: 150,
        child: TextFormField(
          controller: controller,
          cursorColor: Colors.orange,
          keyboardType: TextInputType.number,
          onTap: _clearMessage,
          textAlignVertical: TextAlignVertical.center,
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

            hintText: hint,
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
          style: GoogleFonts.poppins(fontSize: 14),
        ),
      );
    }

    // Digit field with Autocomplete over Single_Pana
    return SizedBox(
      height: 38, width: 150,
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue tev) {
          if (tev.text.isEmpty) return const Iterable<String>.empty();
          return Single_Pana.where((p) => p.startsWith(tev.text));
        },
        onSelected: (sel) {
          digitController.text = sel;
          _clearMessage();
          FocusScope.of(context).unfocus();
        },
        fieldViewBuilder: (context, textCtrl, focusNode, onSubmit) {
          // keep external controller in sync
          textCtrl.addListener(() {
            if (digitController.text != textCtrl.text) {
              digitController.text = textCtrl.text;
              digitController.selection = textCtrl.selection;
            }
          });
          return TextFormField(
            controller: textCtrl,
            focusNode: focusNode,
            cursorColor: Colors.orange,
            keyboardType: TextInputType.number,
            onTap: _clearMessage,
            textAlignVertical: TextAlignVertical.center,
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

              hintText: hint,
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
            style: GoogleFonts.poppins(fontSize: 14),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 150,
                height: 200,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final opt = options.elementAt(i);
                    return InkWell(
                      onTap: () => onSelected(opt),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(opt, style: GoogleFonts.poppins()),
                      ),
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

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "Panna",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Amount",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "Game Type",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus &&
            currentFocus.focusedChild != null) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xfff2f2f2),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
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
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    _inputRow(
                      "Enter Single Panna:",
                      _buildInputField(digitController, "Bid Panna"),
                    ),
                    _inputRow(
                      "Enter Points:",
                      _buildInputField(amountController, "Enter Amount"),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        height: 38, width: 150,
                        child: ElevatedButton(
                          onPressed: _addBid,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            "ADD BID",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildTableHeader(),
                    Divider(color: Colors.grey.shade300),
                    Expanded(
                      child: bids.isEmpty
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
                              itemCount: bids.length,
                              itemBuilder: (context, index) {
                                final bid = bids[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                      vertical: 10.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            bid['digit']!,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            bid['amount']!,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            bid['type']!,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 48,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.orange,
                                              size: 20,
                                            ),
                                            onPressed: () => _removeBid(index),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (bids.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total Points:",
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "${_getTotalPoints()}",
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                            SizedBox(
                              height: 40,
                              child: ElevatedButton(
                                onPressed: _showBidConfirmationDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  "CONFIRM",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_messageToShow != null)
                AnimatedMessageBar(
                  key: _messageBarKey,
                  message: _messageToShow!,
                  isError: _isErrorForMessage,
                  onDismissed: _clearMessage,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
