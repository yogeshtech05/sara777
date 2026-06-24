import 'dart:async'; // For Timer
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
import '../../components/GameTypeSelectorField.dart';

class SingleDigitBetScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType;
  final int gameId;
  final String gameName;
  final bool selectionStatus;

  const SingleDigitBetScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
    required this.selectionStatus,
  });

  @override
  State<SingleDigitBetScreen> createState() => _SingleDigitBetScreenState();
}

class _SingleDigitBetScreenState extends State<SingleDigitBetScreen> {
  final List<String> gameTypesOptions = ["Open", "Close"];
  late String selectedGameBetType;

  final TextEditingController digitController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();
  final List<String> digitOptions = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
  ];
  List<String> filteredDigitOptions = [];
  bool _isDigitSuggestionsVisible = false;

  List<Map<String, String>> addedEntries = [];
  late GetStorage storage = GetStorage();
  late BidService _bidService;
  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  late int walletBalance;
  bool _isApiCalling = false;

  final UserController userController = Get.put(UserController());

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  @override
  void initState() {
    super.initState();
    _bidService = BidService(storage);
    _loadInitialData();

    double _walletBalance = double.parse(userController.walletBalance.value);
    walletBalance = _walletBalance.toInt();

    digitController.addListener(_onDigitChanged);
  }

  void _onDigitChanged() {
    final text = digitController.text;
    if (text.isEmpty) {
      setState(() {
        filteredDigitOptions = [];
        _isDigitSuggestionsVisible = false;
      });
      return;
    }

    setState(() {
      filteredDigitOptions = digitOptions
          .where((option) => option.startsWith(text))
          .toList();
      _isDigitSuggestionsVisible = filteredDigitOptions.isNotEmpty;
    });
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    selectedGameBetType = widget.selectionStatus
        ? gameTypesOptions[0]
        : gameTypesOptions[1];
  }

  @override
  void dispose() {
    digitController.removeListener(_onDigitChanged);
    digitController.dispose();
    pointsController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
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
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
    _messageDismissTimer?.cancel();
  }

  void _addEntry() {
    _clearMessage();
    if (_isApiCalling) return;

    final digit = digitController.text.trim();
    final points = pointsController.text.trim();

    if (digit.isEmpty) {
      _showMessage('Please enter a digit.', isError: true);
      return;
    }

    if (digit.length != 1 || !digitOptions.contains(digit)) {
      _showMessage('Please enter a valid single digit (0-9).', isError: true);
      return;
    }

    if (points.isEmpty) {
      _showMessage('Please enter an Amount.', isError: true);
      return;
    }

    int? parsedPoints = int.tryParse(points);
    if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    int currentTotalPoints = _getTotalPoints();
    int pointsForThisBid = parsedPoints;

    final existingEntryIndex = addedEntries.indexWhere(
      (entry) =>
          entry['digit'] == digit && entry['type'] == selectedGameBetType,
    );

    if (existingEntryIndex != -1) {
      currentTotalPoints -=
          (int.tryParse(addedEntries[existingEntryIndex]['points']!) ?? 0);
    }

    int totalPointsWithNewBid = currentTotalPoints + pointsForThisBid;

    if (totalPointsWithNewBid > walletBalance) {
      _showMessage(
        'Insufficient wallet balance to place these bids.',
        isError: true,
      );
      return;
    }

    setState(() {
      if (existingEntryIndex != -1) {
        addedEntries[existingEntryIndex]['points'] = pointsForThisBid
            .toString();
        _showMessage(
          'Updated points for Digit: $digit, Type: $selectedGameBetType.',
        );
      } else {
        addedEntries.add({
          "digit": digit,
          "points": points,
          "type": selectedGameBetType,
        });
        _showMessage(
          'Added bid: Digit $digit, Points $points, Type $selectedGameBetType.',
        );
      }
      digitController.clear();
      pointsController.clear();
    });
  }

  void _removeEntry(int index) {
    _clearMessage();
    if (_isApiCalling) return;
    setState(() {
      final removedEntry = addedEntries[index];
      addedEntries.removeAt(index);
      _showMessage(
        'Removed bid: Digit ${removedEntry['digit']}, Type ${removedEntry['type']}.',
      );
    });
  }

  int _getTotalPoints() {
    return addedEntries.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (addedEntries.isEmpty) {
      _showMessage('Please add at least one bid.', isError: true);
      return;
    }

    final List<Map<String, String>> bidsForConfirmation = addedEntries.map((
      bid,
    ) {
      return {
        "digit": bid['digit']!,
        "points": bid['points']!,
        "type": bid['type']!,
        "pana": "",
      };
    }).toList();

    final int totalPointsForConfirmation = bidsForConfirmation.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );

    if (walletBalance < totalPointsForConfirmation) {
      _showMessage(
        'Insufficient wallet balance to place this bid.',
        isError: true,
      );
      return;
    }

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: widget.title,
          gameDate: formattedDate,
          bids: bidsForConfirmation,
          totalBids: bidsForConfirmation.length,
          totalBidsAmount: totalPointsForConfirmation,
          walletBalanceBeforeDeduction: walletBalance,
          walletBalanceAfterDeduction:
              (walletBalance - totalPointsForConfirmation).toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameCategoryType,
          onConfirm: () async {
            // Navigator.pop(dialogContext);
            await _placeFinalBids();
          },
        );
      },
    );
  }

  Future<void> _placeFinalBids() async {
    setState(() {
      _isApiCalling = true;
    });

    final Map<String, String> bidsToSubmit = {};
    int totalPointsForSubmission = 0;

    // The key change is to iterate over all bids, not just the last one
    for (var entry in addedEntries) {
      // The original code was incorrectly filtering by 'selectedGameBetType' here
      // which would only submit bids of a single type.
      bidsToSubmit[entry['digit']!] = entry['points']!;
      totalPointsForSubmission += (int.tryParse(entry['points']!) ?? 0);
    }

    // Check if there are any bids to submit
    if (bidsToSubmit.isEmpty) {
      _showMessage('No bids to submit.', isError: true);
      setState(() {
        _isApiCalling = false;
      });
      return;
    }

    final result = await _bidService.placeFinalBids(
      gameName: widget.title,
      accessToken: accessToken,
      registerId: registerId,
      deviceId: _deviceId,
      deviceName: _deviceName,
      accountStatus: accountStatus,
      bidAmounts: bidsToSubmit,
      selectedGameType: selectedGameBetType, // It's still good to pass the type
      gameId: widget.gameId,
      gameType: widget.gameCategoryType,
      totalBidAmount: totalPointsForSubmission,
    );

    if (!mounted) {
      _isApiCalling = false;
      return;
    }

    setState(() {
      _isApiCalling = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          log("resultour  log : $result['status']");
          if (result['status'] == true) {
            return const BidSuccessDialog();
          } else {
            return BidFailureDialog(errorMessage: result['msg']);
          }
        },
      );

      if (result['status'] && context.mounted) {
        final int newBalance = walletBalance - totalPointsForSubmission;
        setState(() {
          walletBalance = newBalance;
          // Clear all entries after a successful submission
          addedEntries.clear();
          digitController.clear();
          pointsController.clear();
          bidsToSubmit.clear();
        });
        await _bidService.updateWalletBalance(newBalance);
        _showMessage('Bids submitted successfully!');
      } else {
        _showMessage(result['msg'] ?? "Bid failed.", isError: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.title
        .replaceAll(RegExp(r',?\s*Single Digits', caseSensitive: false), ' - Single Digit Board')
        .toUpperCase();

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
          displayTitle,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      _inputRow(
                        "Select Game Type",
                        _buildDropdown(widget.selectionStatus),
                      ),
                      const SizedBox(height: 12),
                      _inputRow("Enter Single Digits :", _buildDigitInputField()),
                      const SizedBox(height: 12),
                      _inputRow(
                        "Enter Points :",
                        _buildTextField(
                          pointsController,
                          "Enter Amount",
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isApiCalling
                                      ? Colors.grey
                                      : const Color(0xFFF9B233), // Golden orange
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _isApiCalling ? null : _addEntry,
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
                if (addedEntries.isNotEmpty)
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
                        const SizedBox(width: 38), // aligns with the GestureDetector trash padding
                      ],
                    ),
                  ),
                if (addedEntries.isNotEmpty) const Divider(thickness: 1, height: 1),
                Expanded(
                  child: addedEntries.isEmpty
                      ? const Center(child: Text("No data added yet"))
                      : ListView.builder(
                          itemCount: addedEntries.length,
                          itemBuilder: (_, index) {
                            final entry = addedEntries[index];
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
                                      entry['digit']!,
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
                                      entry['points']!,
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
                                      entry['type']!.toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: entry['type']!.toLowerCase() == 'open'
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFC62828),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _isApiCalling
                                        ? null
                                        : () => _removeEntry(index),
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
                if (addedEntries.isNotEmpty) _buildBottomBar(),
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

  Widget _buildDropdown(bool selectionStatus) {
    List<String> filteredOptions = selectionStatus
        ? ['Open', 'Close']
        : ['Close'];

    if (!filteredOptions.contains(selectedGameBetType)) {
      selectedGameBetType = filteredOptions.first;
    }

    return GameTypeSelectorField(
      selectedOption: selectedGameBetType,
      options: filteredOptions,
      enabled: !_isApiCalling,
      displayTextBuilder: (val) => "${widget.gameName} $val".toUpperCase(),
      onSelected: (v) {
        setState(() {
          selectedGameBetType = v;
          _clearMessage();
        });
      },
    );
  }

  Widget _buildDigitInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
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
              LengthLimitingTextInputFormatter(1),
              FilteringTextInputFormatter.digitsOnly,
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
          ),
        ),
        if (_isDigitSuggestionsVisible)
          Container(
            width: 150,
            height: 35,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: filteredDigitOptions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  title: Text(filteredDigitOptions[index]),
                  onTap: () {
                    setState(() {
                      digitController.text = filteredDigitOptions[index];
                      _isDigitSuggestionsVisible = false;
                      FocusScope.of(context).unfocus();
                    });
                  },
                );
              },
            ),
          ),
      ],
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
      ),
    );
  }

  Widget _buildBottomBar() {
    int totalBids = addedEntries.length;
    int totalPoints = _getTotalPoints();

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
                onPressed: (_isApiCalling || addedEntries.isEmpty)
                    ? null
                    : _showConfirmationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_isApiCalling || addedEntries.isEmpty)
                      ? Colors.grey
                      : const Color(0xFFF9B233),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: _isApiCalling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
//
// import '../../BidService.dart';
// import '../../components/AnimatedMessageBar.dart';
// import '../../components/BidConfirmationDialog.dart';
// import '../../components/BidFailureDialog.dart';
// import '../../components/BidSuccessDialog.dart';
//
// class SingleDigitBetScreen extends StatefulWidget {
//   final String title;
//   final String gameCategoryType;
//   final int gameId;
//   final String gameName;
//   final bool selectionStatus;
//
//   const SingleDigitBetScreen({
//     super.key,
//     required this.title,
//     required this.gameId,
//     required this.gameName,
//     required this.gameCategoryType,
//     required this.selectionStatus,
//   });
//
//   @override
//   State<SingleDigitBetScreen> createState() => _SingleDigitBetScreenState();
// }
//
// class _SingleDigitBetScreenState extends State<SingleDigitBetScreen> {
//   final List<String> gameTypesOptions = ["Open", "Close"];
//   late String selectedGameBetType;
//
//   final TextEditingController digitController = TextEditingController();
//   final TextEditingController pointsController = TextEditingController();
//   final List<String> digitOptions = [
//     '0',
//     '1',
//     '2',
//     '3',
//     '4',
//     '5',
//     '6',
//     '7',
//     '8',
//     '9',
//   ];
//   List<String> filteredDigitOptions = [];
//   bool _isDigitSuggestionsVisible = false;
//
//   List<Map<String, String>> addedEntries = [];
//   late GetStorage storage = GetStorage();
//   late BidService _bidService;
//   late String accessToken;
//   late String registerId;
//   late String preferredLanguage;
//   bool accountStatus = false;
//   late int walletBalance;
//   bool _isApiCalling = false;
//
//   final String _deviceId = 'test_device_id_flutter';
//   final String _deviceName = 'test_device_name_flutter';
//
//   String? _messageToShow;
//   bool _isErrorForMessage = false;
//   Key _messageBarKey = UniqueKey();
//   Timer? _messageDismissTimer;
//
//   @override
//   void initState() {
//     super.initState();
//     _bidService = BidService(storage);
//     _loadInitialData();
//     _setupStorageListeners();
//     digitController.addListener(_onDigitChanged);
//   }
//
//   void _onDigitChanged() {
//     final text = digitController.text;
//     if (text.isEmpty) {
//       setState(() {
//         filteredDigitOptions = [];
//         _isDigitSuggestionsVisible = false;
//       });
//       return;
//     }
//
//     setState(() {
//       filteredDigitOptions = digitOptions
//           .where((option) => option.startsWith(text))
//           .toList();
//       _isDigitSuggestionsVisible = filteredDigitOptions.isNotEmpty;
//     });
//   }
//
//   Future<void> _loadInitialData() async {
//     accessToken = storage.read('accessToken') ?? '';
//     registerId = storage.read('registerId') ?? '';
//     accountStatus = storage.read('accountStatus') ?? false;
//     preferredLanguage = storage.read('selectedLanguage') ?? 'en';
//
//     final dynamic storedWalletBalance = storage.read('walletBalance');
//     if (storedWalletBalance is int) {
//       walletBalance = storedWalletBalance;
//     } else if (storedWalletBalance is String) {
//       walletBalance = int.tryParse(storedWalletBalance) ?? 0;
//     } else {
//       walletBalance = 0;
//     }
//
//     selectedGameBetType = widget.selectionStatus
//         ? gameTypesOptions[0]
//         : gameTypesOptions[1];
//   }
//
//   void _setupStorageListeners() {
//     storage.listenKey('accessToken', (value) {
//       if (mounted) setState(() => accessToken = value ?? '');
//     });
//     storage.listenKey('registerId', (value) {
//       if (mounted) setState(() => registerId = value ?? '');
//     });
//     storage.listenKey('accountStatus', (value) {
//       if (mounted) setState(() => accountStatus = value ?? false);
//     });
//     storage.listenKey('selectedLanguage', (value) {
//       if (mounted) setState(() => preferredLanguage = value ?? 'en');
//     });
//     storage.listenKey('walletBalance', (value) {
//       if (mounted) {
//         setState(() {
//           if (value is int) {
//             walletBalance = value;
//           } else if (value is String) {
//             walletBalance = int.tryParse(value) ?? 0;
//           } else {
//             walletBalance = 0;
//           }
//         });
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     digitController.removeListener(_onDigitChanged);
//     digitController.dispose();
//     pointsController.dispose();
//     _messageDismissTimer?.cancel();
//     super.dispose();
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
//     if (mounted) {
//       setState(() {
//         _messageToShow = null;
//       });
//     }
//     _messageDismissTimer?.cancel();
//   }
//
//   void _addEntry() {
//     _clearMessage();
//     if (_isApiCalling) return;
//
//     final digit = digitController.text.trim();
//     final points = pointsController.text.trim();
//
//     if (digit.isEmpty) {
//       _showMessage('Please enter a digit.', isError: true);
//       return;
//     }
//
//     if (digit.length != 1 || !digitOptions.contains(digit)) {
//       _showMessage('Please enter a valid single digit (0-9).', isError: true);
//       return;
//     }
//
//     if (points.isEmpty) {
//       _showMessage('Please enter an Amount.', isError: true);
//       return;
//     }
//
//     int? parsedPoints = int.tryParse(points);
//     if (parsedPoints == null || parsedPoints < 10 || parsedPoints > 1000) {
//       _showMessage('Points must be between 10 and 1000.', isError: true);
//       return;
//     }
//
//     int currentTotalPoints = _getTotalPoints();
//     int pointsForThisBid = parsedPoints;
//
//     final existingEntryIndex = addedEntries.indexWhere(
//       (entry) =>
//           entry['digit'] == digit && entry['type'] == selectedGameBetType,
//     );
//
//     if (existingEntryIndex != -1) {
//       currentTotalPoints -=
//           (int.tryParse(addedEntries[existingEntryIndex]['points']!) ?? 0);
//     }
//
//     int totalPointsWithNewBid = currentTotalPoints + pointsForThisBid;
//
//     if (totalPointsWithNewBid > walletBalance) {
//       _showMessage(
//         'Insufficient wallet balance to place these bids.',
//         isError: true,
//       );
//       return;
//     }
//
//     setState(() {
//       if (existingEntryIndex != -1) {
//         addedEntries[existingEntryIndex]['points'] = pointsForThisBid
//             .toString();
//         _showMessage(
//           'Updated points for Digit: $digit, Type: $selectedGameBetType.',
//         );
//       } else {
//         addedEntries.add({
//           "digit": digit,
//           "points": points,
//           "type": selectedGameBetType,
//         });
//         _showMessage(
//           'Added bid: Digit $digit, Points $points, Type $selectedGameBetType.',
//         );
//       }
//       digitController.clear();
//       pointsController.clear();
//     });
//   }
//
//   void _removeEntry(int index) {
//     _clearMessage();
//     if (_isApiCalling) return;
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
//     if (addedEntries.isEmpty) {
//       _showMessage('Please add at least one bid.', isError: true);
//       return;
//     }
//
//     final List<Map<String, String>> bidsForConfirmation = addedEntries.map((
//       bid,
//     ) {
//       return {
//         "digit": bid['digit']!,
//         "points": bid['points']!,
//         "type": bid['type']!,
//         "pana": "",
//       };
//     }).toList();
//
//     final int totalPointsForConfirmation = bidsForConfirmation.fold(
//       0,
//       (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
//     );
//
//     if (walletBalance < totalPointsForConfirmation) {
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
//           gameTitle: widget.title,
//           gameDate: formattedDate,
//           bids: bidsForConfirmation,
//           totalBids: bidsForConfirmation.length,
//           totalBidsAmount: totalPointsForConfirmation,
//           walletBalanceBeforeDeduction: walletBalance,
//           walletBalanceAfterDeduction:
//               (walletBalance - totalPointsForConfirmation).toString(),
//           gameId: widget.gameId.toString(),
//           gameType: widget.gameCategoryType,
//           onConfirm: () async {
//             Navigator.pop(dialogContext);
//             await _placeFinalBids();
//           },
//         );
//       },
//     );
//   }
//
//   Future<void> _placeFinalBids() async {
//     setState(() {
//       _isApiCalling = true;
//     });
//
//     final Map<String, String> bidsToSubmit = {};
//     int totalPointsForSubmission = 0;
//
//     for (var entry in addedEntries) {
//       if (entry['type'] == selectedGameBetType) {
//         bidsToSubmit[entry['digit']!] = entry['points']!;
//         totalPointsForSubmission += (int.tryParse(entry['points']!) ?? 0);
//       }
//     }
//
//     if (bidsToSubmit.isEmpty) {
//       _showMessage(
//         'No bids to submit for the selected game type.',
//         isError: true,
//       );
//       setState(() {
//         _isApiCalling = false;
//       });
//       return;
//     }
//
//     final result = await _bidService.placeFinalBids(
//       gameName: widget.title,
//       accessToken: accessToken,
//       registerId: registerId,
//       deviceId: _deviceId,
//       deviceName: _deviceName,
//       accountStatus: accountStatus,
//       bidAmounts: bidsToSubmit,
//       selectedGameType: selectedGameBetType,
//       gameId: widget.gameId,
//       gameType: widget.gameCategoryType,
//       totalBidAmount: totalPointsForSubmission,
//     );
//
//     if (!mounted) {
//       _isApiCalling = false;
//       return;
//     }
//
//     setState(() {
//       _isApiCalling = false;
//     });
//
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       if (!context.mounted) return;
//
//       await showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (ctx) {
//           log("resultour  log : $result['status']");
//           if (result['status'] == true) {
//             return const BidSuccessDialog();
//           } else {
//             return BidFailureDialog(errorMessage: result['msg']);
//           }
//         },
//       );
//
//       if (result['status'] && context.mounted) {
//         final int newBalance = walletBalance - totalPointsForSubmission;
//         setState(() {
//           walletBalance = newBalance;
//           addedEntries.removeWhere(
//             (entry) => entry['type'] == selectedGameBetType,
//           );
//           digitController.clear();
//           pointsController.clear();
//           bidsToSubmit.clear();
//         });
//         await _bidService.updateWalletBalance(newBalance);
//         _showMessage('Bids submitted successfully!');
//       } else {
//         _showMessage(result['msg'] ?? "Bid failed.", isError: true);
//       }
//     });
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
//           widget.title,
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
//               walletBalance.toString(),
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
//                       _inputRow(
//                         "Select Game Type:",
//                         _buildDropdown(widget.selectionStatus),
//                       ),
//                       const SizedBox(height: 12),
//                       _inputRow("Enter Single Digit:", _buildDigitInputField()),
//                       const SizedBox(height: 12),
//                       _inputRow(
//                         "Enter Points:",
//                         _buildTextField(
//                           pointsController,
//                           "Enter Amount",
//                           inputFormatters: [
//                             FilteringTextInputFormatter.digitsOnly,
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 20),
//                       SizedBox(
//                         width: double.infinity,
//                         height: 45,
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: _isApiCalling
//                                 ? Colors.grey
//                                 : Colors.orange,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(6),
//                             ),
//                           ),
//                           onPressed: _isApiCalling ? null : _addEntry,
//                           child: _isApiCalling
//                               ? const SizedBox(
//                                   width: 20,
//                                   height: 20,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                     valueColor: AlwaysStoppedAnimation<Color>(
//                                       Colors.white,
//                                     ),
//                                   ),
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
//                 if (addedEntries.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 8,
//                     ),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             "Digit",
//                             style: GoogleFonts.poppins(
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           child: Text(
//                             "Amount",
//                             style: GoogleFonts.poppins(
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         Expanded(
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
//                                     child: Text(
//                                       entry['digit']!,
//                                       style: GoogleFonts.poppins(),
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: Text(
//                                       entry['points']!,
//                                       style: GoogleFonts.poppins(),
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: Text(
//                                       entry['type']!,
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
//                                         : () => _removeEntry(index),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           },
//                         ),
//                 ),
//                 if (addedEntries.isNotEmpty) _buildBottomBar(),
//               ],
//             ),
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
//   Widget _inputRow(String label, Widget field) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 1),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(
//             flex: 2,
//             child: Padding(
//               padding: const EdgeInsets.only(top: 8.0),
//               child: Text(
//                 label,
//                 style: GoogleFonts.poppins(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ),
//           ),
//           Expanded(flex: 3, child: field),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDropdown(bool selectionStatus) {
//     List<String> filteredOptions = selectionStatus
//         ? ['Open', 'Close']
//         : ['Close'];
//
//     if (!filteredOptions.contains(selectedGameBetType)) {
//       selectedGameBetType = filteredOptions.first;
//     }
//
//     return SizedBox(
//       width: 150,
//       height: 35,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           border: Border.all(color: Colors.black54),
//           borderRadius: BorderRadius.circular(30),
//         ),
//         child: DropdownButtonHideUnderline(
//           child: DropdownButton<String>(
//             isExpanded: true,
//             value: selectedGameBetType,
//             icon: const Icon(Icons.keyboard_arrow_down),
//             onChanged: _isApiCalling
//                 ? null
//                 : (String? newValue) {
//                     setState(() {
//                       selectedGameBetType = newValue!;
//                       _clearMessage();
//                     });
//                   },
//             items: filteredOptions.map<DropdownMenuItem<String>>((
//               String value,
//             ) {
//               return DropdownMenuItem<String>(
//                 value: value,
//                 child: Text(value, style: GoogleFonts.poppins(fontSize: 14)),
//               );
//             }).toList(),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDigitInputField() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(
//           width: double.infinity,
//           height: 35,
//           child: TextFormField(
//             controller: digitController,
//             cursorColor: Colors.orange,
//             keyboardType: TextInputType.number,
//             style: GoogleFonts.poppins(fontSize: 14),
//             inputFormatters: [
//               LengthLimitingTextInputFormatter(1),
//               FilteringTextInputFormatter.digitsOnly,
//             ],
//             onTap: _clearMessage,
//             enabled: !_isApiCalling,
//             decoration: InputDecoration(
//               hintText: "Enter Digit",
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
//           ),
//         ),
//         if (_isDigitSuggestionsVisible)
//           Container(
//             width: 150,
//             height: 35,
//             margin: const EdgeInsets.only(top: 4),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(8),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.2),
//                   spreadRadius: 1,
//                   blurRadius: 3,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: ListView.builder(
//               padding: EdgeInsets.zero,
//               shrinkWrap: true,
//               itemCount: filteredDigitOptions.length,
//               itemBuilder: (context, index) {
//                 return ListTile(
//                   dense: true,
//                   title: Text(filteredDigitOptions[index]),
//                   onTap: () {
//                     setState(() {
//                       digitController.text = filteredDigitOptions[index];
//                       _isDigitSuggestionsVisible = false;
//                       FocusScope.of(context).unfocus();
//                     });
//                   },
//                 );
//               },
//             ),
//           ),
//       ],
//     );
//   }
//
//   Widget _buildTextField(
//     TextEditingController controller,
//     String hint, {
//     List<TextInputFormatter>? inputFormatters,
//   }) {
//     return SizedBox(
//       width: 150,
//       height: 35,
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
//       ),
//     );
//   }
//
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
//             onPressed: (_isApiCalling || addedEntries.isEmpty)
//                 ? null
//                 : _showConfirmationDialog,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: (_isApiCalling || addedEntries.isEmpty)
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
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
