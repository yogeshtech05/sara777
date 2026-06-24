import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../Helper/UserController.dart';
import '../../../components/AnimatedMessageBar.dart';
import '../../../components/BidConfirmationDialog.dart';
import '../../../components/BidFailureDialog.dart';
import '../../../components/BidSuccessDialog.dart';
import '../StarlineBidService.dart';

class StarlineDoublePanaBetScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType; // "doublePana"
  final int gameId;
  final String gameName;
  final bool selectionStatus;

  const StarlineDoublePanaBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
    required this.selectionStatus,
  });

  @override
  State<StarlineDoublePanaBetScreen> createState() =>
      _StarlineDoublePanaBetScreenState();
}

class _StarlineDoublePanaBetScreenState
    extends State<StarlineDoublePanaBetScreen> {
  // ---------- session (UI only) ----------
  List<String> gameTypesOptions = [];
  String selectedGameBetType = "Open"; // default OPEN (as requested)
  String get _sessionUpper => selectedGameBetType.toUpperCase(); // OPEN/CLOSE

  // ---------- inputs ----------
  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  // valid double-pana list
  final List<String> doublePanaOptions = const [
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

  // suggestions
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  /// ✅ SINGLE ENTRY ONLY (no bulk list)
  /// {digit, amount, type:"OPEN"/"CLOSE", gameType:"doublePana"}
  Map<String, String>? _entry;

  // ---------- services / auth ----------
  late final GetStorage storage;
  late final StarlineBidService _bidService;
  late String accessToken;
  late String registerId;
  bool accountStatus = false;

  // wallet
  late int walletBalance;

  // device
  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  // msg bar
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
    storage = GetStorage();
    _bidService = StarlineBidService(storage);
    _loadInitialData();

    final num? bal = num.tryParse(userController.walletBalance.value);
    walletBalance = bal?.toInt() ?? 0;

    _setupGameTypeOptions();
    digitController.addListener(_onDigitChanged);
  }

  void _setupGameTypeOptions() {
    setState(() {
      gameTypesOptions = widget.selectionStatus ? ["Open", "Close"] : ["Close"];
      if (!gameTypesOptions.contains(selectedGameBetType)) {
        selectedGameBetType =
            gameTypesOptions.first; // still defaults to Open overall
      }
    });
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;

    final dynamic stored = storage.read('walletBalance');
    if (stored is int) {
      walletBalance = stored;
    } else if (stored is String) {
      walletBalance = int.tryParse(stored) ?? walletBalance;
    }
  }

  @override
  void didUpdateWidget(covariant StarlineDoublePanaBetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectionStatus != oldWidget.selectionStatus) {
      _setupGameTypeOptions();
    }
  }

  @override
  void dispose() {
    digitController.removeListener(_onDigitChanged);
    digitController.dispose();
    pointsController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  // ---------- helpers ----------
  void _showMessage(String msg, {bool isError = false}) {
    _messageDismissTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messageToShow = msg;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
    _messageDismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _messageToShow = null);
    });
  }

  void _onDigitChanged() {
    final q = digitController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    setState(() {
      _suggestions = doublePanaOptions.where((d) => d.startsWith(q)).toList();
      _showSuggestions = _suggestions.isNotEmpty;
    });
  }

  int _totalPoints() {
    if (_entry == null) return 0;
    return int.tryParse(_entry!['amount'] ?? '0') ?? 0;
  }

  // ---------- add/remove (SINGLE ENTRY) ----------
  void _addEntry() {
    if (_isApiCalling) return;

    final digit = digitController.text.trim();
    final pointsStr = pointsController.text.trim();

    if (digit.length != 3 ||
        int.tryParse(digit) == null ||
        !doublePanaOptions.contains(digit)) {
      _showMessage(
        'Enter a valid Double Pana (3-digit) number.',
        isError: true,
      );
      return;
    }

    final pts = int.tryParse(pointsStr);
    if (pts == null || pts < 10 || pts > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    setState(() {
      // Replace any existing entry
      _entry = {
        "digit": digit,
        "amount": pointsStr,
        "type": _sessionUpper, // "OPEN"/"CLOSE" (UI info only)
        "gameType": widget.gameCategoryType, // "doublePana"
      };
      digitController.clear();
      pointsController.clear();
      _showSuggestions = false;
    });

    _showMessage('Added: $digit ($_sessionUpper)');
  }

  void _removeEntry() {
    if (_isApiCalling) return;
    final removed = _entry?['digit'];
    setState(() => _entry = null);
    _showMessage('Removed: $removed (${_sessionUpper})');
  }

  // ---------- submit (single) ----------
  Future<void> _submitSingle() async {
    if (_entry == null) {
      _showMessage('No bid added.', isError: true);
      return;
    }

    final amt = int.tryParse(_entry!['amount'] ?? '0') ?? 0;
    if (walletBalance < amt) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Authentication error. Please log in again.',
        ),
      );
      return;
    }

    // Build confirmation rows (for your existing dialog)
    final rows = [
      {
        "digit": _entry!['digit']!, // show PANNA in Digits column
        "points": _entry!['amount']!,
        "type": _entry!['type']!, // OPEN/CLOSE (UI only)
        "pana": _entry!['digit']!, // compatibility
      },
    ];
    final totalPoints = amt;
    final whenStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    // Confirm then hit API
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: "${widget.gameName}, Double Pana",
        gameDate: whenStr,
        bids: rows,
        totalBids: 1,
        totalBidsAmount: totalPoints,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - totalPoints).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameCategoryType,
        onConfirm: () async {
          if (!mounted) return;
          setState(() => _isApiCalling = true);

          try {
            final res = await _bidService.placeFinalBids(
              market: Market.starline, // ✅ default starline
              accessToken: accessToken,
              registerId: registerId,
              deviceId: _deviceId,
              deviceName: _deviceName,
              accountStatus: accountStatus,
              bidAmounts: {_entry!['digit']!: _entry!['amount']!}, // single
              gameType: widget.gameCategoryType, // "doublePana"
              gameId: widget.gameId, // TYPE id (as int)
              totalBidAmount: totalPoints,
            );

            if (res['status'] == true) {
              // Deduct wallet & persist
              final newBal = walletBalance - totalPoints;
              setState(() {
                walletBalance = newBal;
                _entry = null; // clear after success
              });
              await _bidService.updateWalletBalance(newBal);

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
                  errorMessage: (res['msg'] ?? 'Something went wrong')
                      .toString(),
                ),
              );
            }
          } catch (_) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const BidFailureDialog(
                errorMessage:
                    'An unexpected error occurred during bid submission.',
              ),
            );
          } finally {
            if (mounted) setState(() => _isApiCalling = false);
          }
        },
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final hasEntry = _entry != null;
    final totalPoints = _totalPoints();
    final canSubmit = hasEntry && !_isApiCalling;

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey.shade300,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
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
            child: Text(
              walletBalance.toString(),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
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
                      const SizedBox(height: 12),
                      _inputRow("Enter 3-Digit Number:", _digitField()),
                      if (_showSuggestions && _suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            itemBuilder: (_, i) {
                              final s = _suggestions[i];
                              return ListTile(
                                title: Text(s),
                                onTap: () {
                                  setState(() {
                                    digitController.text = s;
                                    _showSuggestions = false;
                                    digitController.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(offset: s.length),
                                        );
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      _inputRow(
                        "Enter Points:",
                        _numberField(pointsController, "Enter Amount", [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: _isApiCalling ? null : _addEntry,
                          child: _isApiCalling
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                              : const Text(
                                  "ADD BID",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
                const Divider(thickness: 1),

                // Single item row
                Expanded(
                  child: !hasEntry
                      ? Center(
                          child: Text(
                            "No bid added yet",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                      : ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: const [
                                  Expanded(
                                    child: Text(
                                      "Digit",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      "Amount",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      "Game Type",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 48),
                                ],
                              ),
                            ),
                            const Divider(thickness: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _entry!['digit']!,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _entry!['amount']!,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _entry!['type']!,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.orange,
                                    ),
                                    onPressed: _isApiCalling
                                        ? null
                                        : _removeEntry,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),

                // Bottom bar
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
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bids',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            hasEntry ? '1' : '0',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Points',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '$totalPoints',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: canSubmit ? _submitSingle : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canSubmit
                              ? Colors.orange
                              : Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 3,
                        ),
                        child: _isApiCalling
                            ? const CircularProgressIndicator(
                                color: Colors.white,
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
                ),
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
                  onDismissed: () => setState(() => _messageToShow = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- small UI helpers ----------
  Widget _inputRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(flex: 3, child: field),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return SizedBox(
      height: 38,
      child: Container(
        padding: const EdgeInsets.only(left: 14, right: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: gameTypesOptions.contains(selectedGameBetType)
                ? selectedGameBetType
                : gameTypesOptions.first,
            icon: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFFF9B233),
                size: 20,
              ),
            ),
            onChanged: _isApiCalling
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() => selectedGameBetType = v);
                    // also update the saved entry's label if present
                    if (_entry != null) {
                      setState(() => _entry!['type'] = _sessionUpper);
                    }
                  },
            items: gameTypesOptions
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(
                      v.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _digitField() {
    return SizedBox(
      height: 38,
      child: TextFormField(
        controller: digitController,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: [
          LengthLimitingTextInputFormatter(3),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: () {
          if (digitController.text.isNotEmpty) _onDigitChanged();
        },
        onChanged: (_) => _onDigitChanged(),
        enabled: !_isApiCalling,
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
          hintText: "Enter 3-Digit Number",
          contentPadding: const EdgeInsets.only(
            left: 16,
            right: 4,
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
      ),
    );
  }

  Widget _numberField(
    TextEditingController c,
    String hint,
    List<TextInputFormatter> fmts,
  ) {
    return SizedBox(
      width: 150,
      height: 38,
      child: TextFormField(
        controller: c,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: fmts,
        enabled: !_isApiCalling,
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
          contentPadding: const EdgeInsets.only(
            left: 16,
            right: 4,
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
      ),
    );
  }
}
