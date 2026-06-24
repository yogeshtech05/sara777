import 'dart:async'; // For Timer

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart'; // For GoogleFonts
import 'package:intl/intl.dart';

import '../../BidService.dart'; // Assuming BidService.dart is in the parent directory
import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart'; // Assuming this component is separate
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../components/GameTypeSelectorField.dart';

// Create a simple model for a single bid entry.
// This is a good practice to keep data structured.
class BidEntry {
  final String digit;
  final String points;
  final String type;

  BidEntry({required this.digit, required this.points, required this.type});
}

class SingleDigitsBulkScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameName;
  final String gameType; // This should be like "singleDigits"
  final bool selectionStatus;

  const SingleDigitsBulkScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameType,
    required this.selectionStatus,
  }) : super(key: key);

  @override
  State<SingleDigitsBulkScreen> createState() => _SingleDigitsBulkScreenState();
}

class _SingleDigitsBulkScreenState extends State<SingleDigitsBulkScreen> {
  late String selectedGameType =
      'Open'; // This refers to sessionType (Open/Close)
  final List<String> gameTypes = ['Open', 'Close'];

  final TextEditingController pointsController = TextEditingController();

  Color dropdownBorderColor = Colors.black;
  Color textFieldBorderColor = Colors.black;

  // Change bidAmounts to store a list of BidEntry objects
  // This new structure stores all the necessary data for each bid.
  List<BidEntry> bidEntries = [];

  late GetStorage storage;
  late BidService _bidService; // Declare BidService

  late String _accessToken; // Renamed to private to match common convention
  late String _registerId; // Renamed to private
  bool _accountStatus = false; // Renamed to private
  int _walletBalance = 0; // Renamed to private, directly storing int

  // --- AnimatedMessageBar State Management ---
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer; // Initialize Timer here
  // --- End AnimatedMessageBar State Management ---

  bool _isApiCalling = false; // To show loading during API calls
  bool _isWalletLoading = true; // Added for initial wallet loading state

  // Device info (can be loaded from storage or directly assigned for testing)
  String _deviceId = 'test_device_id_flutter';
  String _deviceName = 'test_device_name_flutter';

  final UserController userController = Get.put(UserController());

  @override
  void initState() {
    super.initState();
    storage = GetStorage(); // Initialize GetStorage
    _bidService = BidService(storage); // Initialize BidService with GetStorage
    _loadInitialData();

    // Initialize walletBalance from storage as String
    double _walletBalanceDouble = double.parse(
      userController.walletBalance.value,
    );
    _walletBalance = _walletBalanceDouble.toInt();
    _loadInitialData();
  }

  // Asynchronously loads initial user data and wallet balance from GetStorage
  Future<void> _loadInitialData() async {
    _accessToken = storage.read('accessToken') ?? '';
    _registerId = storage.read('registerId') ?? '';
    _accountStatus = storage.read('accountStatus') ?? false;
  }

  @override
  void dispose() {
    pointsController.dispose();
    _messageDismissTimer?.cancel(); // Cancel the timer on dispose
    super.dispose();
  }

  // --- AnimatedMessageBar Helper Methods ---
  void _showMessage(String message, {bool isError = false}) {
    _messageDismissTimer?.cancel(); // Cancel any existing timer
    if (!mounted) return;
    setState(() {
      _messageToShow = message;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey(); // Force rebuild of message bar
    });
    // Set a timer to dismiss the message after 3 seconds, consistent with Jodi
    _messageDismissTimer = Timer(const Duration(seconds: 3), _clearMessage);
  }

  void _clearMessage() {
    if (mounted) {
      setState(() {
        _messageToShow = null;
      });
    }
    _messageDismissTimer
        ?.cancel(); // Ensure timer is cancelled when message is cleared manually
  }
  // --- End AnimatedMessageBar Helper Methods ---

  void onNumberPressed(String number) {
    _clearMessage();
    if (_isApiCalling) return; // Prevent adding bids while API is in progress

    final amount = pointsController.text.trim();
    if (amount.isEmpty) {
      _showMessage('Please enter an amount first.', isError: true);
      return;
    }

    int? parsedAmount = int.tryParse(amount);
    if (parsedAmount == null || parsedAmount < 10 || parsedAmount > 1000) {
      // Assuming a max bid of 1000, adjust as per your rules
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }

    // Check if a bid for this digit already exists with the SAME type
    final existingBidIndex = bidEntries.indexWhere(
      (bid) =>
          bid.digit == number && bid.type == selectedGameType.toUpperCase(),
    );

    // Calculate total points with the new bid to check against wallet balance
    int currentTotalPoints = _getTotalPoints();
    int pointsForThisBid = parsedAmount;

    // If the bid already exists, subtract its old points before adding new ones
    if (existingBidIndex != -1) {
      currentTotalPoints -=
          int.tryParse(bidEntries[existingBidIndex].points) ?? 0;
    }

    int totalPointsWithNewBid = currentTotalPoints + pointsForThisBid;

    if (totalPointsWithNewBid > _walletBalance) {
      _showMessage(
        'Insufficient wallet balance to place these bids.',
        isError: true,
      );
      return;
    }

    // Create a new bid entry
    final newBid = BidEntry(
      digit: number,
      points: amount,
      type: selectedGameType.toUpperCase(),
    );

    setState(() {
      if (existingBidIndex != -1) {
        // Update the existing bid entry
        bidEntries[existingBidIndex] = newBid;
        _showMessage(
          'Bid for Digit $number (${selectedGameType.toUpperCase()}) updated to $amount points.',
          isError: false,
        );
      } else {
        // Add a new bid entry
        bidEntries.add(newBid);
        _showMessage('Added bid for Digit: $number, Amount: $amount');
      }
    });
  }

  int _getTotalPoints() {
    return bidEntries
        .map((e) => int.tryParse(e.points) ?? 0)
        .fold(0, (a, b) => a + b);
  }

  // --- Confirmation Dialog and Final Bid Submission (Modified) ---
  void _showConfirmationDialog() {
    _clearMessage();
    if (bidEntries.isEmpty) {
      _showMessage(
        'Please add at least one bid before submitting.',
        isError: true,
      );
      return;
    }

    final int totalPoints = _getTotalPoints();
    final int currentWalletBalance =
        _walletBalance; // _walletBalance is already int

    if (currentWalletBalance < totalPoints) {
      _showMessage(
        'Insufficient wallet balance to place these bids.',
        isError: true,
      );
      return;
    }

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    // Transform bidEntries into a List of Maps for the dialog.
    // This will include all bids, regardless of their type.
    List<Map<String, String>> bidsForDialog = bidEntries.map((bid) {
      return {
        "digit": bid.digit,
        "points": bid.points,
        "type": bid.type, // Use the stored type
        "pana": "", // pana should be empty for single digits
      };
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: "${widget.gameName} - ${widget.gameType}",
          gameDate: formattedDate,
          bids: bidsForDialog, // Pass the entire list of bids
          totalBids: bidEntries.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: currentWalletBalance,
          walletBalanceAfterDeduction: (currentWalletBalance - totalPoints)
              .toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () {
            // Dismiss the confirmation dialog before showing success/failure
            _placeFinalBids(); // Call the bid placement method
            // Navigator.pop(dialogContext);
          },
        );
      },
    );
  }

  Future<bool> _placeFinalBids() async {
    setState(() {
      _isApiCalling = true; // Set loading state to true
    });

    // Create the Map<String, String> in the correct format: digit -> points
    // The key should be the digit, and the value should be the points.
    final Map<String, String> bidsForService = {};
    for (var bid in bidEntries) {
      // The key is the digit, the value is the points.
      // The type is not part of the key here.
      bidsForService[bid.digit] = bid.points;
    }

    // Call the bid service with the formatted map and the selectedGameType.
    final result = await _bidService.placeFinalBids(
      gameName: widget.gameName,
      accessToken: _accessToken,
      registerId: _registerId,
      deviceId: _deviceId,
      deviceName: _deviceName,
      accountStatus: _accountStatus,
      bidAmounts: bidsForService, // Passing the corrected map of bids
      gameId: widget.gameId,
      gameType: widget.gameType,
      totalBidAmount: _getTotalPoints(),
      selectedGameType:
          selectedGameType, // This parameter is handled correctly by your BidService
    );

    if (!mounted) {
      setState(() {
        _isApiCalling = false;
      });
      return false;
    }

    // Ensure context is still valid before showing final dialog
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => result['status']
            ? const BidSuccessDialog()
            : BidFailureDialog(errorMessage: result['msg']),
      );

      if (result['status'] && context.mounted) {
        final int newBalance = _walletBalance - _getTotalPoints();
        setState(() {
          _walletBalance = newBalance;
          bidEntries.clear(); // Clear bids on successful submission
          pointsController.clear(); // Clear points text field
        });
        await _bidService.updateWalletBalance(newBalance);
        _showMessage('Bids submitted successfully!'); // Show success message
      }
    });

    // Update loading state after the dialog is shown
    setState(() {
      _isApiCalling = false;
    });

    return result['status'] == true;
  }

  Widget _buildDropdown(bool selectionStatus) {
    final List<String> gameTypesOptions = ['OPEN', 'CLOSE'];

    final List<String> filteredOptions = selectionStatus
        ? gameTypesOptions
        : gameTypesOptions
              .where((opt) => opt.toLowerCase() == 'close')
              .toList();

    if (!filteredOptions.contains(selectedGameType.toUpperCase())) {
      selectedGameType = filteredOptions.first;
    }

    return GameTypeSelectorField(
      selectedOption: selectedGameType,
      options: filteredOptions,
      enabled: !_isApiCalling,
      displayTextBuilder: (val) => "${widget.gameName} $val".toUpperCase(),
      onSelected: (v) {
        setState(() {
          selectedGameType = v;
          _clearMessage();
        });
      },
    );
  }

  Widget _buildTextField() {
    return TextFormField(
      controller: pointsController,
      cursorColor: Colors.orange,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
      decoration: _tfDecoration('Enter Amount'),
      onTap: () {
        setState(() {
          textFieldBorderColor = Colors.orange;
          _clearMessage();
        });
      },
      enabled: !_isApiCalling,
    );
  }

  Widget _row(String label, Widget field) {
    String cleanedLabel = label;
    if (label.contains('Select Game Type')) {
      cleanedLabel = 'Select Game Type';
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

  InputDecoration _ddDecoration() => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.only(left: 14, right: 6),
        filled: true,
        fillColor: Colors.white,
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

  Widget _buildNumberPad() {
    final numbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: numbers.map((number) {
        final bid = bidEntries.firstWhereOrNull(
          (element) =>
              element.digit == number &&
              element.type == selectedGameType.toUpperCase(),
        );

        return GestureDetector(
          onTap: _isApiCalling
              ? null
              : () => onNumberPressed(number),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isApiCalling
                      ? Colors.grey.shade300
                      : const Color(0xFFF9B233),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  number,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              if (bid != null)
                Positioned(
                  top: 4,
                  right: 6,
                  child: Text(
                    bid.points,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalAmount = _getTotalPoints();
    final canSubmit = !_isApiCalling && bidEntries.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7F8),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
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
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          children: [
                            _row(
                              'Select Game Type',
                              SizedBox(
                                height: 38,
                                child: _buildDropdown(widget.selectionStatus),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _row(
                              'Enter Points :',
                              SizedBox(
                                height: 38,
                                child: _buildTextField(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: _buildNumberPad(),
                            ),
                          ],
                        ),
                      ),
                      if (bidEntries.isNotEmpty) ...[
                        const Divider(thickness: 1, height: 1),
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
                                flex: 3,
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
                        const Divider(thickness: 1, height: 1),
                        Column(
                          children: bidEntries.map((bid) {
                            return _buildBidEntryItem(
                              bid.digit,
                              bid.points,
                              bid.type,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (bidEntries.isEmpty) ...[
                        const Spacer(),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Text(
                              'No Bids Added',
                              style: GoogleFonts.poppins(
                                color: Colors.black38,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                      ] else ...[
                        const Spacer(),
                        _buildBottomBar(totalAmount, canSubmit),
                      ],
                    ],
                  ),
                ),
              ],
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
    );
  }

  Widget _buildBidEntryItem(String digit, String points, String type) {
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
              digit,
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              points,
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
              type.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: type.toLowerCase() == 'open'
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828),
              ),
            ),
          ),
          GestureDetector(
            onTap: _isApiCalling
                ? null
                : () {
                    setState(() {
                      final indexToRemove = bidEntries.indexWhere(
                        (bid) => bid.digit == digit && bid.type == type,
                      );
                      if (indexToRemove != -1) {
                        final removedBid = bidEntries.removeAt(indexToRemove);
                        _showMessage(
                          'Removed bid for Digit: ${removedBid.digit}, Amount: ${removedBid.points}.',
                        );
                      }
                    });
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
  }

  Widget _buildBottomBar(int totalAmount, bool canSubmit) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
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
                  "Bids",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${bidEntries.length}",
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
                  "Points",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "$totalAmount",
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
                onPressed: canSubmit ? _showConfirmationDialog : null,
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
                        "SUBMIT",
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

// Add this extension for convenience to find an element or return null
extension IterableExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
