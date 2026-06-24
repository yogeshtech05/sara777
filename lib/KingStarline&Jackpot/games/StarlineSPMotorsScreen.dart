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
import 'package:new_sara/KingStarline&Jackpot/StarlineBidService.dart';

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../ulits/Constents.dart';

class StarlineSPMotorsScreen extends StatefulWidget {
  final String title;
  final String gameCategoryType; // e.g., "spMotor"
  final int gameId; // type id to send
  final String gameName; // label

  const StarlineSPMotorsScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameCategoryType,
  });

  @override
  State<StarlineSPMotorsScreen> createState() => _StarlineSPMotorsScreenState();
}

class _StarlineSPMotorsScreenState extends State<StarlineSPMotorsScreen> {
  // UI-only label for starline session (API ignores this field)
  String selectedGameBetType = "Open";

  final TextEditingController bidController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  final List<Map<String, String>> addedEntries =
      []; // {digit, amount, type, gameType}

  late final GetStorage storage;
  late final StarlineBidService _bidService;

  late String accessToken;
  late String registerId;
  late String preferredLanguage;
  bool accountStatus = false;
  int walletBalance = 0;

  // device headers (storage first, fallback after)
  String get _deviceId =>
      storage.read('deviceId')?.toString() ?? 'flutter_device';
  String get _deviceName =>
      storage.read('deviceName')?.toString() ?? 'Flutter_App';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _messageDismissTimer;

  bool _isApiCalling = false;

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  static const int _minBet = 10;
  static const int _maxBet = 1000;

  @override
  void initState() {
    super.initState();
    storage = GetStorage();
    _bidService = StarlineBidService(storage);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;
    preferredLanguage = storage.read('selectedLanguage') ?? 'en';

    // wallet -> int (safe)
    final fromCtrl = num.tryParse(userController.walletBalance.value);
    final fromStore = storage.read('walletBalance');
    if (fromCtrl != null) {
      walletBalance = fromCtrl.toInt();
    } else if (fromStore != null) {
      walletBalance = int.tryParse(fromStore.toString()) ?? 0;
    } else {
      walletBalance = 0;
    }

    // live wallet sync
    storage.listenKey('walletBalance', (value) {
      final parsed = int.tryParse(value?.toString() ?? '0') ?? 0;
      if (mounted) setState(() => walletBalance = parsed);
    });
  }

  @override
  void dispose() {
    bidController.dispose();
    pointsController.dispose();
    _messageDismissTimer?.cancel();
    super.dispose();
  }

  // ---------------- messaging ----------------
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
    _messageDismissTimer?.cancel();
  }

  // ---------------- add via API (sp-motor-pana) ----------------
  Future<void> _addEntry() async {
    _clearMessage();
    if (_isApiCalling) return;

    final digit = bidController.text.trim();
    final amount = pointsController.text.trim();

    if (digit.isEmpty) {
      _showMessage('Please enter a number.', isError: true);
      return;
    }
    // 3–7 digits and numeric
    if (digit.length < 3 || digit.length > 7 || int.tryParse(digit) == null) {
      _showMessage('Please enter a valid number (3–7 digits).', isError: true);
      return;
    }
    // at least two unique digits (mirror of DP Motors logic)
    if (digit.split('').toSet().length < 2) {
      _showMessage(
        'Number must contain at least two unique digits.',
        isError: true,
      );
      return;
    }

    if (amount.isEmpty) {
      _showMessage('Please enter an Amount.', isError: true);
      return;
    }
    final parsedAmount = int.tryParse(amount);
    if (parsedAmount == null ||
        parsedAmount < _minBet ||
        parsedAmount > _maxBet) {
      _showMessage(
        'Points must be between $_minBet and $_maxBet.',
        isError: true,
      );
      return;
    }

    setState(() => _isApiCalling = true);

    try {
      final uri = Uri.parse('${Constant.apiEndpoint}sp-motor-pana');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'deviceId': _deviceId,
        'deviceName': _deviceName,
        'accessStatus': accountStatus ? '1' : '0',
      };
      final body = jsonEncode({
        "digit": int.parse(digit),
        "sessionType": selectedGameBetType.toLowerCase(), // "open"
        "amount": parsedAmount,
      });

      final response = await http.post(uri, headers: headers, body: body);
      if (!mounted) return;

      final Map<String, dynamic> res = jsonDecode(response.body);
      log('SP Motors fetch: $res');

      if (response.statusCode == 200 && res['status'] == true) {
        final List<dynamic> info = res['info'] ?? [];
        if (info.isEmpty) {
          _showMessage('No valid bids found for this number.', isError: true);
        } else {
          int added = 0;
          setState(() {
            for (final item in info) {
              final pana = item['pana']?.toString() ?? '';
              final amtStr = item['amount']?.toString() ?? amount;
              if (pana.isEmpty) continue;

              // merge duplicates: same pana + same type
              final idx = addedEntries.indexWhere(
                (e) => e['digit'] == pana && e['type'] == selectedGameBetType,
              );
              final addAmt = int.tryParse(amtStr) ?? parsedAmount;
              if (idx != -1) {
                final old =
                    int.tryParse(addedEntries[idx]['amount'] ?? '0') ?? 0;
                addedEntries[idx]['amount'] = (old + addAmt).toString();
              } else {
                addedEntries.add({
                  "digit": pana,
                  "amount": addAmt.toString(),
                  "type": selectedGameBetType, // "Open"
                  "gameType": widget.gameCategoryType,
                });
              }
              added++;
            }
            bidController.clear();
            pointsController.clear();
          });

          if (added > 0) {
            _showMessage('Added $added bids from API response.');
          } else {
            _showMessage('All bids already exist.', isError: true);
          }
        }
      } else {
        _showMessage(
          res['msg'] ?? 'Request failed with status: ${response.statusCode}',
          isError: true,
        );
      }
    } catch (e) {
      log('Error fetching bids: $e', name: 'StarlineSPMotorsScreenAPIError');
      _showMessage('An unexpected error occurred: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isApiCalling = false);
    }
  }

  // ---------------- remove ----------------
  void _removeEntry(int index) {
    _clearMessage();
    if (_isApiCalling || index < 0 || index >= addedEntries.length) return;

    final removed = addedEntries[index];
    setState(() {
      addedEntries.removeAt(index);
    });
    _showMessage(
      'Removed bid: Number ${removed['digit']}, Type ${removed['type']}.',
    );
  }

  // ---------------- totals ----------------
  int _getTotalPoints() {
    return addedEntries.fold(
      0,
      (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
    );
  }

  int _getTotalPointsForSelectedGameType() {
    return addedEntries
        .where(
          (e) =>
              (e["type"] ?? "").toUpperCase() ==
              selectedGameBetType.toUpperCase(),
        )
        .fold(
          0,
          (sum, item) => sum + (int.tryParse(item['amount'] ?? '0') ?? 0),
        );
  }

  // ---------------- confirm ----------------
  void _showConfirmationDialog() {
    _clearMessage();
    if (_isApiCalling) return;

    final int totalForType = _getTotalPointsForSelectedGameType();
    if (totalForType == 0) {
      _showMessage(
        'No bids added for the selected game type to submit.',
        isError: true,
      );
      return;
    }
    if (walletBalance < totalForType) {
      _showMessage(
        'Insufficient wallet balance for selected game type.',
        isError: true,
      );
      return;
    }

    final String when = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    final rows = addedEntries
        .where(
          (e) =>
              (e["type"] ?? "").toUpperCase() ==
              selectedGameBetType.toUpperCase(),
        )
        .map(
          (bid) => {
            "digit": bid['digit']!,
            "points": bid['amount']!,
            "type": "${bid['gameType']} (${bid['type']})",
            "pana": bid['digit']!,
            "jodi": "",
          },
        )
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.gameName,
        gameDate: when,
        bids: rows,
        totalBids: rows.length,
        totalBidsAmount: totalForType,
        walletBalanceBeforeDeduction: walletBalance,
        walletBalanceAfterDeduction: (walletBalance - totalForType).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameCategoryType,
        onConfirm: () async {
          setState(() => _isApiCalling = true);
          await _placeFinalBids();
          if (mounted) setState(() => _isApiCalling = false);
        },
      ),
    );
  }

  // ---------------- submit ----------------
  Future<bool> _placeFinalBids() async {
    final Map<String, String> bidPayload = {};
    int batchTotal = 0;

    for (final entry in addedEntries) {
      if ((entry["type"] ?? "").toUpperCase() ==
          selectedGameBetType.toUpperCase()) {
        final d = entry["digit"] ?? "";
        final a = int.tryParse(entry["amount"] ?? "0") ?? 0;
        if (d.isNotEmpty && a > 0) {
          bidPayload[d] = a.toString();
          batchTotal += a;
        }
      }
    }

    if (bidPayload.isEmpty) {
      if (!mounted) return false;
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
      if (!mounted) return false;
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
      final isStarline = widget.gameName.toLowerCase().contains('starline');
      final isJackpot = widget.gameName.toLowerCase().contains('jackpot');

      final result = await _bidService.placeFinalBids(
        market: isStarline
            ? Market.starline
            : (isJackpot ? Market.jackpot : Market.starline),

        accessToken: accessToken,
        registerId: registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: accountStatus,
        bidAmounts: bidPayload,
        gameId: widget.gameId, // type id
        gameType: widget.gameCategoryType, // e.g. "spMotor"
        totalBidAmount: batchTotal,
      );

      if (!mounted) return false;

      if (result['status'] == true) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );

        // wallet balance: prefer server field(s)
        final dynamic serverBal =
            result['updatedWalletBalance'] ??
            result['data']?['updatedWalletBalance'] ??
            result['data']?['wallet_balance'];

        final newBal =
            int.tryParse(serverBal?.toString() ?? '') ??
            (walletBalance - batchTotal);

        setState(() => walletBalance = newBal);
        await _bidService.updateWalletBalance(newBal);
        userController.walletBalance.value = newBal.toString();

        // remove submitted-type rows
        setState(() {
          addedEntries.removeWhere(
            (e) =>
                (e["type"] ?? "").toUpperCase() ==
                selectedGameBetType.toUpperCase(),
          );
        });
        return true;
      } else {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(
            errorMessage: result['msg']?.toString() ?? 'Something went wrong',
          ),
        );
        return false;
      }
    } catch (e) {
      log(
        'Error during bid placement: $e',
        name: 'StarlineSPMotorsScreenBidError',
      );
      if (!mounted) return false;
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

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
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
            child: Obx(
              () => Text(
                userController.walletBalance.value,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
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
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      _inputRow("Enter Number:", _buildBidInputField()),
                      const SizedBox(height: 12),
                      _inputRow(
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
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isApiCalling
                                ? Colors.grey
                                : Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: _isApiCalling ? null : _addEntry,
                          child: _isApiCalling
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
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
                if (addedEntries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Digit",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "Amount",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "Game Type",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                if (addedEntries.isNotEmpty) const Divider(thickness: 1),
                Expanded(
                  child: addedEntries.isEmpty
                      ? const Center(child: Text("No data added yet"))
                      : ListView.builder(
                          itemCount: addedEntries.length,
                          itemBuilder: (_, index) {
                            final entry = addedEntries[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry['digit']!,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      entry['amount']!,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${entry['gameType']} (${entry['type']})',
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
                                        : () => _removeEntry(index),
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
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
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

  Widget _buildBidInputField() {
    return SizedBox(
      width: double.infinity,
      height: 38, child: TextFormField(
        controller: bidController,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: [
          LengthLimitingTextInputFormatter(7),
          FilteringTextInputFormatter.digitsOnly,
        ],
        onTap: _clearMessage,
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

          hintText: "Enter Number",
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
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      width: 150,
      height: 38, child: TextFormField(
        controller: controller,
        cursorColor: Colors.orange,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 14),
        inputFormatters: inputFormatters,
        onTap: _clearMessage,
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
      ),
    );
  }

  Widget _buildBottomBar() {
    final int totalBids = addedEntries.length;
    final int totalPoints = _getTotalPoints();
    final int totalPointsForSelectedType = _getTotalPointsForSelectedGameType();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                '$totalBids',
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
            onPressed: (_isApiCalling || totalPointsForSelectedType == 0)
                ? null
                : _showConfirmationDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  (_isApiCalling || totalPointsForSelectedType == 0)
                  ? Colors.grey
                  : Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 3,
            ),
            child: _isApiCalling
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    );
  }
}
