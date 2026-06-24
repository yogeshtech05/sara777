import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:new_sara/KingStarline&Jackpot/StarlineBidService.dart';

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
// ⬇️ use the unified service

class StarlineJodiBidScreen extends StatefulWidget {
  final String title;
  final String gameType; // server gameType (e.g., "jodi")
  final int gameId; // TYPE id (sent as STRING)
  final String gameName; // label

  const StarlineJodiBidScreen({
    Key? key,
    required this.title,
    required this.gameType,
    required this.gameId,
    required this.gameName,
  }) : super(key: key);

  @override
  State<StarlineJodiBidScreen> createState() => _StarlineJodiBidScreenState();
}

class _StarlineJodiBidScreenState extends State<StarlineJodiBidScreen> {
  final TextEditingController digitController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  /// Local bids: [{digit, amount}]
  final List<Map<String, String>> bids = [];
  late final GetStorage storage;
  late final StarlineBidService _bidService;

  late String accessToken;
  late String registerId;
  String walletBalance = '0'; // keep as string for UI
  bool accountStatus = false;
  bool _isSubmitting = false;

  final String _deviceId =
      GetStorage().read('deviceId')?.toString() ?? 'flutter_device';
  final String _deviceName =
      GetStorage().read('deviceName')?.toString() ?? 'Flutter_App';

  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();

  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  // 00..99
  final List<String> allJodiOptions = List.generate(
    100,
    (i) => i.toString().padLeft(2, '0'),
  );

  @override
  void initState() {
    super.initState();
    storage = GetStorage();
    _bidService = StarlineBidService(storage);

    // wallet (string) init
    final num? wb = num.tryParse(userController.walletBalance.value);
    walletBalance = (wb?.toInt() ?? 0).toString();
    _loadInitialData();
    _setupStorageListeners();
  }

  Future<void> _loadInitialData() async {
    accessToken = storage.read('accessToken') ?? '';
    registerId = storage.read('registerId') ?? '';
    accountStatus = userController.accountStatus.value;
  }

  void _setupStorageListeners() {
    storage.listenKey('walletBalance', (value) {
      if (!mounted) return;
      setState(() {
        walletBalance = value?.toString() ?? '0';
      });
    });
  }

  // -------------- market detect --------------
  Market _detectMarket() {
    final s = ('${widget.title} ${widget.gameName}').toLowerCase();
    return s.contains('jackpot') ? Market.jackpot : Market.starline;
  }

  // ---------------- messaging ----------------
  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _messageToShow = msg;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
  }

  void _clearMessage() {
    if (!mounted) return;
    setState(() => _messageToShow = null);
  }

  // ---------------- data helpers ----------------
  int _getTotalPoints() {
    return bids.fold(
      0,
      (sum, b) => sum + (int.tryParse(b['amount'] ?? '0') ?? 0),
    );
  }

  Map<String, String> _buildBidMap() {
    final map = <String, String>{};
    for (final b in bids) {
      final d = b['digit'] ?? '';
      final a = b['amount'] ?? '0';
      if (d.isNotEmpty && int.tryParse(a) != null) map[d] = a;
    }
    return map;
  }

  // ---------------- add/remove ----------------
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
    if (_isSubmitting || idx < 0 || idx >= bids.length) return;
    setState(() {
      final removed = bids[idx]['digit'];
      bids.removeAt(idx);
      _showMessage('Bid for Jodi $removed removed.');
    });
  }

  // ---------------- confirm & submit ----------------
  void _showConfirmationDialog(int total) {
    _clearMessage();
    if (bids.isEmpty) {
      _showMessage('No bids added yet.', isError: true);
      return;
    }

    final currentBal = int.tryParse(walletBalance) ?? 0;
    if (total > currentBal) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    final date = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    final rows = bids
        .map(
          (b) => {
            'digit': b['digit'] ?? '',
            'points': b['amount'] ?? '0',
            'type': 'Open', // UI label only
            'pana': '', // not applicable for jodi
            'jodi': b['digit'] ?? '',
          },
        )
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.gameName,
        gameDate: date,
        bids: rows,
        totalBids: rows.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction: currentBal,
        walletBalanceAfterDeduction: (currentBal - total).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: _placeFinalBids,
      ),
    );
  }

  Future<bool> _placeFinalBids() async {
    if (!mounted) return false;
    setState(() => _isSubmitting = true);

    final total = _getTotalPoints();
    final bidMap = _buildBidMap();

    if (bidMap.isEmpty) {
      setState(() => _isSubmitting = false);
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const BidFailureDialog(errorMessage: 'No valid bids to submit.'),
      );
      return false;
    }

    if (accessToken.isEmpty || registerId.isEmpty) {
      setState(() => _isSubmitting = false);
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
      final market = _detectMarket();

      final result = await _bidService.placeFinalBids(
        market: market,
        accessToken: accessToken,
        registerId: registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: accountStatus,
        bidAmounts: bidMap,
        gameType: widget.gameType, // e.g. "jodi"
        gameId: widget.gameId, // TYPE id (sent as STRING)
        totalBidAmount: total,
      );

      if (!mounted) return false;

      if (result['status'] == true) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const BidSuccessDialog(),
        );

        // Prefer server wallet if present
        final dynamic serverBal =
            result['updatedWalletBalance'] ??
            result['data']?['updatedWalletBalance'] ??
            result['data']?['wallet_balance'];

        final int newBal =
            int.tryParse(serverBal?.toString() ?? '') ??
            ((int.tryParse(walletBalance) ?? 0) - total);

        setState(() {
          bids.clear();
          walletBalance = newBal.toString();
        });
        await _bidService.updateWalletBalance(newBal);
        userController.walletBalance.value = newBal.toString();

        _showMessage("Bid placed successfully!");
        setState(() => _isSubmitting = false);
        return true;
      } else {
        final err = (result['msg'] ?? 'Something went wrong').toString();
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(errorMessage: err),
        );
        _showMessage(err, isError: true);
        setState(() => _isSubmitting = false);
        return false;
      }
    } catch (e) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'An unexpected error occurred during bid submission.',
        ),
      );
      _showMessage('Unexpected error: $e', isError: true);
      setState(() => _isSubmitting = false);
      return false;
    }
  }

  @override
  void dispose() {
    digitController.dispose();
    amountController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final total = _getTotalPoints();

    return Scaffold(
      backgroundColor: const Color(0xfff2f2f2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
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
                    style: const TextStyle(color: Colors.black),
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
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _inputRow(
                        "Enter Jodi:",
                        _buildInputField(
                          controller: digitController,
                          hint: "Enter Jodi",
                          borderColor: Colors.orange,
                          selected: 'digit',
                        ),
                      ),
                      _inputRow(
                        "Enter Points:",
                        _buildInputField(
                          controller: amountController,
                          hint: "Enter Amount",
                          borderColor: Colors.orange,
                          selected: 'amount',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _addBid,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isSubmitting
                                ? Colors.grey
                                : Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "ADD BID",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                _buildTableHeader(),
                const Divider(),
                Expanded(
                  child: bids.isEmpty
                      ? Center(
                          child: Text(
                            'No bids yet. Add some data!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: bids.length,
                          itemBuilder: (_, idx) =>
                              _buildBidItem(bids[idx], idx),
                        ),
                ),
                if (bids.isNotEmpty) _buildBottomBar(),
              ],
            ),

            // message bar
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: field),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required Color borderColor,
    required String selected,
  }) {
    if (selected == 'digit') {
      return RawAutocomplete<String>(
        textEditingController: controller,
        focusNode: FocusNode(),
        optionsBuilder: (textEditingValue) {
          if (textEditingValue.text.isEmpty)
            return const Iterable<String>.empty();
          return allJodiOptions.where(
            (opt) => opt.startsWith(textEditingValue.text),
          );
        },
        fieldViewBuilder: (context, c, focusNode, _) {
          return SizedBox(
            height: 38,
            child: TextField(
              controller: c,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              maxLength: 2,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              cursorColor: Colors.orange,
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
                counterText: "",
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      title: Text(option),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
        onSelected: (val) => controller.text = val,
      );
    } else {
      return SizedBox(
        height: 38,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          cursorColor: Colors.orange,
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
            counterText: "",
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: const [
          Expanded(
            child: Text('Digit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(
              'Points',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              'Game Type',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildBidItem(Map<String, String> bid, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(bid['digit'] ?? '')),
          Expanded(child: Text(bid['amount'] ?? '')),
          Expanded(
            child: Text(
              widget.gameType.toUpperCase(),
              style: const TextStyle(color: Colors.green),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.orange),
            onPressed: () => _removeBid(index),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final total = _getTotalPoints();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Bids:\n${bids.length}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            'Total Amount:\n$total',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () => _showConfirmationDialog(total),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'SUBMIT BID',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
