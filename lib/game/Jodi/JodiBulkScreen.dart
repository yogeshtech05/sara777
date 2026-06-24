// imports
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

class JodiBulkScreen extends StatefulWidget {
  final String screenTitle;
  final String gameType;
  final int gameId;
  final String gameName;

  const JodiBulkScreen({
    Key? key,
    required this.screenTitle,
    required this.gameType,
    required this.gameId,
    required this.gameName,
  }) : super(key: key);

  @override
  State<JodiBulkScreen> createState() => _JodiBulkScreenState();
}

class _JodiBulkScreenState extends State<JodiBulkScreen> {
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _jodiDigitController = TextEditingController();
  final GetStorage storage = GetStorage();
  late final BidService _bidService;

  List<Map<String, String>> _bids = [];
  String _accessToken = '';
  String _registerId = '';
  bool _accountStatus = false;
  int _walletBalance = 0;
  bool _isWalletLoading = true;

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;
  bool _isSubmitting = false;

  final UserController userController = Get.put(UserController());

  final String _deviceId = 'test_device';
  final String _deviceName = 'test_device';

  @override
  void initState() {
    super.initState();
    _bidService = BidService(storage);
    double walletBalance = double.parse(userController.walletBalance.value);
    _walletBalance = walletBalance.toInt();
    _loadInitialData();
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _jodiDigitController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _accessToken = storage.read('accessToken') ?? '';
    _registerId = storage.read('registerId') ?? '';
    _accountStatus = userController.accountStatus.value;
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
    if (mounted) setState(() => _messageToShow = null);
  }

  void _addBidAutomatically() {
    _clearMessage();
    if (_isSubmitting) {
      _showMessage(
        'Please wait, a bid submission is in progress.',
        isError: true,
      );
      return;
    }

    final digit = _jodiDigitController.text.trim();
    final points = _pointsController.text.trim();

    if (digit.length != 2 || int.tryParse(digit) == null) {
      _showMessage(
        'Jodi digit must be exactly 2 numbers (00-99).',
        isError: true,
      );
      return;
    }

    final int parsedDigit = int.parse(digit);
    if (parsedDigit < 0 || parsedDigit > 99) {
      _showMessage('Jodi must be a number between 00 and 99.', isError: true);
      return;
    }

    if (points.isEmpty || int.tryParse(points) == null) {
      _showMessage('Please enter valid points.', isError: true);
      return;
    }

    final int parsedPoints = int.parse(points);
    if (parsedPoints < 10 || parsedPoints > 10000) {
      _showMessage('Points must be between 10 and 10000.', isError: true);
      return;
    }

    int currentTotalPoints = _getTotalPoints();
    bool alreadyExists = false;
    int oldPointsForThisJodi = 0;

    for (var bid in _bids) {
      if (bid['digit'] == digit && bid['gameType'] == widget.gameType) {
        alreadyExists = true;
        oldPointsForThisJodi = int.tryParse(bid['points'] ?? '0') ?? 0;
        break;
      }
    }

    int totalPointsAfterAdd =
        currentTotalPoints - oldPointsForThisJodi + parsedPoints;

    if (totalPointsAfterAdd > _walletBalance) {
      _showMessage('Insufficient wallet balance for this bid.', isError: true);
      return;
    }

    if (!alreadyExists) {
      setState(() {
        _bids.add({
          "digit": digit,
          "points": points,
          "gameType": widget.gameType,
          "type": "Jodi",
        });
        _jodiDigitController.clear();
        _showMessage('Jodi $digit with $points points added.', isError: false);
      });
    } else {
      setState(() {
        for (var i = 0; i < _bids.length; i++) {
          if (_bids[i]['digit'] == digit &&
              _bids[i]['gameType'] == widget.gameType) {
            _bids[i]['points'] = points;
            break;
          }
        }
        _jodiDigitController.clear();
        _showMessage('Jodi $digit points updated to $points.', isError: false);
      });
    }
  }

  void _removeBid(int index) {
    if (_isSubmitting) {
      _showMessage(
        'Cannot remove bid while submission is in progress.',
        isError: true,
      );
      return;
    }
    setState(() {
      final Map<String, String> removedBid = _bids.removeAt(index);
      _showMessage('Jodi ${removedBid['digit']} removed.', isError: false);
    });
  }

  void _showConfirmationDialog() {
    _clearMessage();
    if (_bids.isEmpty) {
      _showMessage(
        'Please add at least one bid before submitting.',
        isError: true,
      );
      return;
    }

    final int totalPoints = _getTotalPoints();
    final int currentWalletBalance = _walletBalance;

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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BidConfirmationDialog(
          gameTitle: "${widget.gameName} - ${widget.gameType}",
          gameDate: formattedDate,
          bids: _bids
              .map(
                (bid) => {
                  "digit": bid['digit']!,
                  "points": bid['points']!,
                  "type": bid['type']!,
                },
              )
              .toList(),
          totalBids: _bids.length,
          totalBidsAmount: totalPoints,
          walletBalanceBeforeDeduction: currentWalletBalance,
          walletBalanceAfterDeduction: (currentWalletBalance - totalPoints)
              .toString(),
          gameId: widget.gameId.toString(),
          gameType: widget.gameType,
          onConfirm: () async {
            await Future.delayed(const Duration(milliseconds: 200));

            _showMessage('Submitting your bids...', isError: false);
            if (mounted) {
              await _placeFinalBids();
            }
          },
        );
      },
    );
  }

  Future<void> _placeFinalBids() async {
    if (!mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _bidService.placeFinalBids(
        gameName: widget.gameName,
        accessToken: _accessToken,
        registerId: _registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: _accountStatus,
        bidAmounts: {for (var bid in _bids) bid['digit']!: bid['points']!},
        selectedGameType: "OPEN",
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount: _getTotalPoints(),
      );

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => result['status'] == true
              ? const BidSuccessDialog()
              : BidFailureDialog(
                  errorMessage: result['msg'] ?? "An unknown error occurred.",
                ),
        );

        if (result['status'] == true) {
          final int totalDeductedPoints = _getTotalPoints();
          final int newBalance = _walletBalance - totalDeductedPoints;
          setState(() {
            _walletBalance = newBalance;
            _bids.clear();
            _pointsController.clear();
            _jodiDigitController.clear();
          });
          await _bidService.updateWalletBalance(newBalance);
          _showMessage("Bids submitted successfully!", isError: false);
        } else {
          _showMessage(
            result['msg'] ?? "Bid failed. Please try again.",
            isError: true,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage('An unexpected error occurred: $e', isError: true);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => BidFailureDialog(
            errorMessage: 'Network error or unexpected issue: $e',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  int _getTotalPoints() {
    return _bids.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['points'] ?? '0') ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalBidsCount = _bids.length;
    int totalPoints = _getTotalPoints();
    final canSubmit = !_isSubmitting && _bids.isNotEmpty;

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
          widget.screenTitle.toUpperCase(),
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
              userController.walletBalance.value,
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
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
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    children: [
                      _row(
                        'Enter Points:',
                        _buildPointsField(),
                      ),
                      const SizedBox(height: 12),
                      _row(
                        'Enter Jodi Digit:',
                        _buildJodiDigitField(),
                      ),
                      const SizedBox(height: 12),
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
                            'Jodi',
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
                          itemBuilder: (context, index) {
                            final bid = _bids[index];
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
                                      bid['digit'] ?? '',
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
                                      bid['points'] ?? '',
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
                                      (bid['type'] ?? bid['gameType'] ?? '').toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _isSubmitting
                                        ? null
                                        : () => _removeBid(index),
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
                if (_bids.isNotEmpty) _buildBottomBar(canSubmit, totalBidsCount, totalPoints),
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

  Widget _row(String label, Widget field) {
    String cleanedLabel = label;
    if (label.contains('Enter Points') || label.contains('Points')) {
      cleanedLabel = 'Enter Points :';
    } else if (label.contains('Jodi Digit') || label.contains('Jodi') || label.contains('Digit')) {
      cleanedLabel = 'Enter Jodi Digit';
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

  Widget _buildPointsField() {
    return SizedBox(
      height: 38,
      child: TextField(
        cursorColor: Colors.orange,
        controller: _pointsController,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
        onTap: _clearMessage,
        enabled: !_isSubmitting,
        decoration: _tfDecoration('Enter Amount'),
      ),
    );
  }

  Widget _buildJodiDigitField() {
    return SizedBox(
      height: 38,
      child: TextField(
        cursorColor: Colors.orange,
        controller: _jodiDigitController,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        inputFormatters: [
          LengthLimitingTextInputFormatter(2),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: _clearMessage,
        onChanged: (value) {
          if (value.length == 2 &&
              _pointsController.text.isNotEmpty) {
            _addBidAutomatically();
          }
        },
        enabled: !_isSubmitting,
        decoration: _tfDecoration('Bid Digits'),
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

  Widget _buildBottomBar(bool canSubmit, int totalBids, int totalPoints) {
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
                onPressed: canSubmit ? _showConfirmationDialog : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit ? const Color(0xFFF9B233) : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
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
