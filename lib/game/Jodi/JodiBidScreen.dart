import 'package:flutter/material.dart';
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

class JodiBidScreen extends StatefulWidget {
  final String title;
  final String gameType;
  final int gameId;
  final String gameName;

  const JodiBidScreen({
    Key? key,
    required this.title,
    required this.gameType,
    required this.gameId,
    required this.gameName,
  }) : super(key: key);

  @override
  State<JodiBidScreen> createState() => _JodiBidScreenState();
}

class _JodiBidScreenState extends State<JodiBidScreen> {
  final TextEditingController digitController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  List<Map<String, String>> bids = [];
  late GetStorage storage;
  late BidService _bidService;

  late String accessToken;
  late String registerId;
  String walletBalance = '0'; // Changed to String
  bool accountStatus = false;
  bool _isSubmitting = false;

  final String _deviceId = 'test_device_id_flutter';
  final String _deviceName = 'test_device_name_flutter';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  final UserController userController = Get.put(UserController());

  final List<String> allJodiOptions = List.generate(
    100,
    (i) => i.toString().padLeft(2, '0'),
  );

  @override
  void initState() {
    super.initState();
    storage = GetStorage();
    _bidService = BidService(storage);
    // Initialize walletBalance from storage as String
    double _walletBalance = double.parse(userController.walletBalance.value);
    int _walletBalanceInt = _walletBalance.toInt();
    walletBalance = _walletBalanceInt.toString();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _messageToShow = msg;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
  }

  void _clearMessage() {
    if (mounted) setState(() => _messageToShow = null);
  }

  void _addBid() {
    _clearMessage();
    if (_isSubmitting) return;

    final jodi = digitController.text.trim();
    final amount = amountController.text.trim();

    if (jodi.length != 2 || int.tryParse(jodi) == null) {
      _showMessage('Please enter a valid 2-digit Jodi.', isError: true);
      return;
    }
    final amt = int.tryParse(amount);
    if (amt == null || amt < 10 || amt > 1000) {
      _showMessage('Amount must be between 10 and 1000.', isError: true);
      return;
    }
    if (bids.any((b) => b['digit'] == jodi)) {
      _showMessage('Jodi $jodi already exists.', isError: true);
      return;
    }

    setState(() {
      bids.add({'digit': jodi, 'amount': amount});
      digitController.clear();
      amountController.clear();
      _showMessage('Bid for Jodi $jodi added successfully!');
    });
  }

  void _removeBid(int idx) {
    if (_isSubmitting) return;
    setState(() {
      final removed = bids[idx]['digit'];
      bids.removeAt(idx);
      _showMessage('Bid for Jodi $removed removed.', isError: false);
    });
  }

  int _getTotalPoints() {
    return bids.fold(0, (sum, b) => sum + (int.tryParse(b['amount']!) ?? 0));
  }

  Future<void> _submitBidViaService(int total) async {
    setState(() => _isSubmitting = true);
    final bidMap = {for (var b in bids) b['digit']!: b['amount']!};

    final result = await _bidService.placeFinalBids(
      gameName: widget.gameName,
      accessToken: accessToken,
      registerId: registerId,
      deviceId: _deviceId,
      deviceName: _deviceName,
      accountStatus: accountStatus,
      bidAmounts: bidMap,
      selectedGameType: "OPEN",
      gameId: widget.gameId,
      gameType: widget.gameType,
      totalBidAmount: total,
    );

    if (result['status'] == true) {
      // Parse current walletBalance to int for calculation
      final currentWalletBalanceInt = int.tryParse(walletBalance) ?? 0;
      final newBalInt = currentWalletBalanceInt - total;
      await _bidService.updateWalletBalance(
        newBalInt,
      ); // update GetStorage with int
      setState(() {
        bids.clear();
        walletBalance = newBalInt
            .toString(); // Convert back to String for state
      });
      showDialog(context: context, builder: (_) => const BidSuccessDialog());
      _showMessage("Bid placed successfully!");
    } else {
      showDialog(
        context: context,
        builder: (_) =>
            BidFailureDialog(errorMessage: result['msg'] ?? "Error"),
      );
      _showMessage(result['msg'] ?? "Bid failed.", isError: true);
    }

    setState(() => _isSubmitting = false);
  }

  void _showConfirmationDialog(int total) {
    if (bids.isEmpty) {
      _showMessage('No bids added yet.', isError: true);
      return;
    }
    // Parse walletBalance to int for comparison
    if (total > (int.tryParse(walletBalance) ?? 0)) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    final date = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    // No change here, walletBalance is already a String,
    // (int.tryParse(walletBalance) ?? 0) - total) is calculated as int then converted to string
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: "${widget.gameName}, ${widget.gameType}",
        gameDate: date,
        bids: bids,
        totalBids: bids.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction:
            int.tryParse(walletBalance) ??
            0, // walletBalance, // Already a String
        walletBalanceAfterDeduction:
            ((int.tryParse(walletBalance) ?? 0) - total).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () => _placeFinalBids(),
      ),
    );
  }

  Future<bool> _placeFinalBids() async {
    final result = await _bidService.placeFinalBids(
      gameName: widget.gameName,
      accessToken: accessToken,
      registerId: registerId,
      deviceId: _deviceId,
      deviceName: _deviceName,
      accountStatus: accountStatus,
      bidAmounts: _bidService.getBidAmounts(bids),
      selectedGameType: "OPEN",
      gameId: widget.gameId,
      gameType: widget.gameType,
      totalBidAmount: _getTotalPoints(),
    );

    if (!mounted) return false;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => result['status']
            ? const BidSuccessDialog()
            : BidFailureDialog(errorMessage: result['msg']),
      );

      bids.clear();

      if (result['status'] && context.mounted) {
        // Parse current walletBalance to int for calculation
        final currentWalletBalanceInt = int.tryParse(walletBalance) ?? 0;
        final newBalanceInt = currentWalletBalanceInt - _getTotalPoints();
        setState(() {
          walletBalance = newBalanceInt
              .toString(); // Convert back to String for state
        });
        await _bidService.updateWalletBalance(
          newBalanceInt,
        ); // Update GetStorage with int
      }
    });

    return result['status'] == true;
  }

  @override
  void dispose() {
    digitController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _getTotalPoints();
    final canSubmitAny = bids.isNotEmpty && !_isSubmitting;

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
            child: Text(
              walletBalance,
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
                        "Enter Jodi:",
                        _buildInputField(
                          controller: digitController,
                          hint: "Enter Jodi",
                          selected: 'digit',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _row(
                        "Enter Points:",
                        _buildInputField(
                          controller: amountController,
                          hint: "Enter Amount",
                          selected: 'amount',
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
                                onPressed: _isSubmitting ? null : _addBid,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isSubmitting
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
                if (bids.isNotEmpty)
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
                if (bids.isNotEmpty) const Divider(thickness: 1, height: 1),
                Expanded(
                  child: bids.isEmpty
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
                          itemCount: bids.length,
                          itemBuilder: (_, idx) =>
                              _buildBidItem(bids[idx], idx),
                        ),
                ),
                if (bids.isNotEmpty) _buildBottomBar(canSubmitAny, total),
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
    if (label.contains('Enter Jodi') || label.contains('Jodi')) {
      cleanedLabel = 'Enter Jodi';
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required String selected,
  }) {
    if (selected == 'digit') {
      return SizedBox(
        height: 38,
        child: RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: FocusNode(),
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty)
              return const Iterable<String>.empty();
            return allJodiOptions.where(
              (opt) => opt.startsWith(textEditingValue.text),
            );
          },
          fieldViewBuilder: (context, controller, focusNode, _) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              maxLength: 2,
              cursorColor: Colors.orange,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              decoration: _tfDecoration(hint).copyWith(counterText: ""),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 180,
                  height: options.length > 6 ? 200 : options.length * 40,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(option, style: GoogleFonts.poppins(fontSize: 13)),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          onSelected: (val) => controller.text = val,
        ),
      );
    } else {
      return SizedBox(
        height: 38,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          cursorColor: Colors.orange,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          decoration: _tfDecoration(hint).copyWith(counterText: ""),
        ),
      );
    }
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

  Widget _buildBidItem(Map<String, String> bid, int index) {
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
              bid['amount'] ?? '',
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
              widget.gameType.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _removeBid(index),
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

  Widget _buildBottomBar(bool canSubmitAny, int total) {
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
                  '${bids.length}',
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
                  '$total',
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
                onPressed: canSubmitAny ? () => _showConfirmationDialog(total) : null,
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
