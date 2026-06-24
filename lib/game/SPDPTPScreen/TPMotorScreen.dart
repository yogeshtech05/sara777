import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../BidService.dart'; // Import BidService
import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../components/GameTypeSelectorField.dart';

class TPMotorsBetScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType; // e.g. "triplePanna" or your key for TP Motors
  final int gameId;
  final String gameName;
  final bool
  selectionStatus; // controls whether "Open" is available along with "Close"

  const TPMotorsBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
    required this.selectionStatus,
  });

  @override
  State<TPMotorsBetScreen> createState() => _TPMotorsBetScreenState();
}

class _TPMotorsBetScreenState extends State<TPMotorsBetScreen> {
  // -------- Session selection (UI only) --------
  late String selectedGameBetType; // "Open" | "Close"

  // -------- Inputs --------
  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  // Valid Triple Panna list
  final List<String> triplePanaOptions = const [
    "111",
    "222",
    "333",
    "444",
    "555",
    "666",
    "777",
    "888",
    "999",
    "000",
  ];
  List<String> filteredDigitOptions = [];
  bool _isDigitSuggestionsVisible = false;

  // Keep entries with session
  // each item: {digit, amount, type: OPEN/CLOSE, gameType}
  final Map<String, List<Map<String, String>>> _entriesBySession = {
    'OPEN': <Map<String, String>>[],
    'CLOSE': <Map<String, String>>[],
  };

  // -------- Services / Auth / Wallet --------
  late GetStorage storage;
  late BidService _bidService;

  late String accessToken;
  late String registerId;
  bool accountStatus = false;
  late int walletBalance; // keep as int for arithmetic

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  // -------- Snackbar/Message bar --------
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  bool _isApiCalling = false;

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  // -------- Lifecycle --------
  @override
  void initState() {
    super.initState();
    storage = GetStorage();
    _bidService = BidService(storage);
    _loadInitialData();

    // Parse wallet safely
    final num? bal = num.tryParse(userController.walletBalance.value);
    walletBalance = bal?.toInt() ?? 0;

    digitController.addListener(_onDigitChanged);
    selectedGameBetType = widget.selectionStatus ? "Open" : "Close";
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    // Prefer controller flag if available; fall back to storage
    accountStatus =
        userController.accountStatus.value ||
        (storage.read('accountStatus') ?? false);
  }

  @override
  void dispose() {
    digitController.removeListener(_onDigitChanged);
    digitController.dispose();
    pointsController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  // -------- Helpers --------
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

  void _onDigitChanged() {
    final query = digitController.text.trim();
    if (query.isEmpty) {
      setState(() {
        filteredDigitOptions = [];
        _isDigitSuggestionsVisible = false;
      });
      return;
    }
    setState(() {
      filteredDigitOptions = triplePanaOptions
          .where((d) => d.startsWith(query))
          .toList();
      _isDigitSuggestionsVisible = filteredDigitOptions.isNotEmpty;
    });
  }

  List<Map<String, String>> _allEntries() => [
    ..._entriesBySession['OPEN']!,
    ..._entriesBySession['CLOSE']!,
  ];

  int _totalPointsAll() => _allEntries().fold(
    0,
    (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0),
  );

  int _totalPointsForSession(String sessionUpper) =>
      _entriesBySession[sessionUpper]!.fold(
        0,
        (s, e) => s + (int.tryParse(e['amount'] ?? '0') ?? 0),
      );

  bool _hasEntries(String sessionUpper) =>
      _entriesBySession[sessionUpper]!.isNotEmpty;

  // -------- Add / Remove --------
  void _addEntry() {
    _clearMessage();
    if (_isApiCalling) return;

    final digit = digitController.text.trim();
    final pointsStr = pointsController.text.trim();

    if (digit.length != 3 || int.tryParse(digit) == null) {
      _showMessage('Enter a valid 3-digit number.', isError: true);
      return;
    }
    if (!triplePanaOptions.contains(digit)) {
      _showMessage('Invalid Triple Panna number.', isError: true);
      return;
    }

    final pts = int.tryParse(pointsStr);
    if (pts == null || pts < 10 || pts > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    final sessionUpper = selectedGameBetType.toUpperCase();
    final list = _entriesBySession[sessionUpper]!;
    final idx = list.indexWhere((e) => e['digit'] == digit);

    setState(() {
      if (idx != -1) {
        final curr = int.tryParse(list[idx]['amount'] ?? '0') ?? 0;
        list[idx]['amount'] = (curr + pts).toString();
        _showMessage("Updated: $digit ($sessionUpper)");
      } else {
        list.add({
          "digit": digit,
          "amount": pointsStr,
          "type": sessionUpper, // OPEN / CLOSE
          "gameType": widget.gameCategoryType, // your game type key
        });
        _showMessage("Added: $digit ($sessionUpper)");
      }
      digitController.clear();
      pointsController.clear();
      _isDigitSuggestionsVisible = false;
    });
  }

  void _removeEntry(String sessionUpper, int index) {
    _clearMessage();
    if (_isApiCalling) return;
    final list = _entriesBySession[sessionUpper]!;
    final removed = list[index]['digit'];
    setState(() {
      list.removeAt(index);
    });
    _showMessage("Removed: $removed ($sessionUpper)");
  }

  // -------- Submit (per session) --------
  Future<bool> _placeBidsForSession(String sessionUpper) async {
    final list = _entriesBySession[sessionUpper]!;
    if (list.isEmpty) return true; // nothing to submit for this session

    final Map<String, String> bidPayload = {};
    int totalForSession = 0;

    for (final e in list) {
      final digit = e['digit'] ?? '';
      final amt = int.tryParse(e['amount'] ?? '0') ?? 0;
      if (digit.isEmpty || amt <= 0) continue;
      bidPayload.update(
        digit,
        (old) => (int.parse(old) + amt).toString(),
        ifAbsent: () => amt.toString(),
      );
      totalForSession += amt;
    }

    log(
      '[$sessionUpper] payload: $bidPayload | total: $totalForSession',
      name: 'TPMotors',
    );

    if (bidPayload.isEmpty) return true;

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

    try {
      final result = await _bidService.placeFinalBids(
        gameName: widget.gameName,
        accessToken: accessToken,
        registerId: registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: accountStatus,
        bidAmounts: bidPayload,
        selectedGameType: sessionUpper, // "OPEN" / "CLOSE"
        gameId: widget.gameId,
        gameType: widget.gameCategoryType,
        totalBidAmount: totalForSession,
      );

      if (result['status'] == true) {
        // Deduct wallet; prefer server's updated balance if provided
        final dynamic updatedRaw = result['updatedWalletBalance'];
        final int updatedBalance =
            int.tryParse(updatedRaw?.toString() ?? '') ??
            (walletBalance - totalForSession);

        setState(() => walletBalance = updatedBalance);
        _bidService.updateWalletBalance(updatedBalance);

        // Clear only this session's entries
        setState(() => _entriesBySession[sessionUpper]!.clear());
        return true;
      } else {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(
            errorMessage: result['msg'] ?? 'Something went wrong',
          ),
        );
        return false;
      }
    } catch (e) {
      log(
        'Error during $sessionUpper bid placement: $e',
        name: 'TPMotorsBetScreen',
      );
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'An unexpected error occurred during bid submission.',
        ),
      );
      return false;
    }
  }

  // -------- Unified confirmation (both sessions together) --------
  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    final all = _allEntries();
    final totalAll = _totalPointsAll();

    if (all.isEmpty) {
      _showMessage("No bids added.", isError: true);
      return;
    }
    if (walletBalance < totalAll) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    final String whenStr = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    final List<Map<String, String>> dialogRows = all
        .map(
          (e) => {
            "digit": e['digit']!,
            "points": e['amount']!,
            "type": e['type']!, // OPEN / CLOSE
            "pana": e['digit']!, // compatibility
          },
        )
        .toList(growable: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: "${widget.gameName}, Triple Panna",
        gameDate: whenStr,
        bids: dialogRows,
        totalBids: dialogRows.length,
        totalBidsAmount: totalAll,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - totalAll).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameCategoryType,
        onConfirm: () async {
          if (!mounted) return;
          setState(() => _isApiCalling = true);

          bool ok = true;
          if (_hasEntries('OPEN')) ok = await _placeBidsForSession('OPEN');
          if (ok && _hasEntries('CLOSE'))
            ok = await _placeBidsForSession('CLOSE');

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

  // -------- UI --------
  @override
  Widget build(BuildContext context) {
    // Dynamically compute available options
    final List<String> availableGameTypes = [
      if (widget.selectionStatus) "Open",
      "Close",
    ];

    // Ensure current selection is valid if widget.selectionStatus changed
    if (!availableGameTypes.contains(selectedGameBetType)) {
      selectedGameBetType = availableGameTypes.first;
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
                          options: availableGameTypes,
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
                      _row(
                        "Enter 3-Digit Triple Panna:",
                        _buildDigitInputField(),
                      ),
                      if (_isDigitSuggestionsVisible &&
                          filteredDigitOptions.isNotEmpty)
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
                            itemCount: filteredDigitOptions.length,
                            itemBuilder: (context, index) {
                              final suggestion = filteredDigitOptions[index];
                              return ListTile(
                                title: Text(suggestion),
                                onTap: () {
                                  setState(() {
                                    digitController.text = suggestion;
                                    _isDigitSuggestionsVisible = false;
                                    digitController.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(
                                            offset: digitController.text.length,
                                          ),
                                        );
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      _row(
                        "Enter Points:",
                        _buildTextField(
                          pointsController,
                          "Enter Amount",
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
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
                          itemBuilder: (_, index) {
                            final e = all[index];
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
                                            final session = e['type']!.toUpperCase();
                                            final idx = _entriesBySession[session]!.indexOf(e);
                                            if (idx != -1) {
                                              _removeEntry(session, idx);
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

  // -------- Small UI helpers --------
  Widget _row(String label, Widget field) {
    String cleanedLabel = label;
    if (label.contains('Select Game Type')) {
      cleanedLabel = 'Select Game Type';
    } else if (label.contains('Triple Panna') || label.contains('Digit')) {
      cleanedLabel = 'Triple Panna';
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

  Widget _buildDigitInputField() {
    return SizedBox(
      height: 38,
      child: TextFormField(
        controller: digitController,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        inputFormatters: [
          LengthLimitingTextInputFormatter(3),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: () {
          _clearMessage();
          _onDigitChanged();
        },
        onChanged: (_) => _onDigitChanged(),
        enabled: !_isApiCalling,
        decoration: _tfDecoration("Bid Pana"),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      height: 38,
      child: TextFormField(
        controller: controller,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        inputFormatters: inputFormatters,
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
