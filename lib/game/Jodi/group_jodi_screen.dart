// lib/screens/group_jodi_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../Helper/UserController.dart';
import '../../components/AnimatedMessageBar.dart';
import '../../components/BidConfirmationDialog.dart';
import '../../components/BidFailureDialog.dart';
import '../../components/BidSuccessDialog.dart';
import '../../ulits/Constents.dart';

class GroupJodiScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameType; // e.g. "groupJodi"

  const GroupJodiScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameType,
  }) : super(key: key);

  @override
  State<GroupJodiScreen> createState() => _GroupJodiScreenState();
}

class _GroupJodiScreenState extends State<GroupJodiScreen> {
  final TextEditingController jodiController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  final List<Map<String, String>> _bids = []; // {jodi, points}

  final GetStorage _storage = GetStorage();
  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  late String _accessToken;
  late String _registerId;
  late bool _accountActiveStatus;
  late int _walletBalance;

  late final String _deviceId;
  late final String _deviceName;

  // AnimatedMessageBar state
  String? _msg;
  bool _msgIsError = false;
  Key _msgKey = UniqueKey();
  Timer? _msgTimer;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _accessToken = _storage.read('accessToken')?.toString() ?? '';
    _registerId = _storage.read('registerId')?.toString() ?? '';
    _accountActiveStatus = userController.accountStatus.value;

    final num? bal = num.tryParse(userController.walletBalance.value);
    _walletBalance = bal?.toInt() ?? 0;

    _deviceId = _storage.read('deviceId')?.toString() ?? 'flutter_device';
    _deviceName = _storage.read('deviceName')?.toString() ?? 'Flutter_App';
  }

  @override
  void dispose() {
    jodiController.dispose();
    pointsController.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  // ---------------- Message Bar ----------------
  void _showBar(String m, {bool error = false}) {
    _msgTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _msg = m;
      _msgIsError = error;
      _msgKey = UniqueKey();
    });
    _msgTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _msg = null);
    });
  }

  void _clearBar() {
    if (!mounted) return;
    setState(() => _msg = null);
  }

  // ---------------- Utils ----------------
  int _totalPoints() =>
      _bids.fold(0, (s, e) => s + (int.tryParse(e['points'] ?? '0') ?? 0));

  String _cutDigit(String d) {
    final v = int.parse(d);
    return ((v + 5) % 10).toString();
  }

  void _mergeOrAdd(String jodi, int pts) {
    final i = _bids.indexWhere((e) => e['jodi'] == jodi);
    if (i != -1) {
      final curr = int.tryParse(_bids[i]['points'] ?? '0') ?? 0;
      _bids[i]['points'] = (curr + pts).toString();
    } else {
      _bids.add({'jodi': jodi, 'points': pts.toString()});
    }
  }

  // ---------------- Add Bid (local generation) ----------------
  void _addBid() {
    _clearBar();
    if (_isSubmitting) return;

    final jodi = jodiController.text.trim();
    final pointsText = pointsController.text.trim();

    if (jodi.length != 2 || int.tryParse(jodi) == null) {
      _showBar('Please enter a valid 2-digit Jodi (00-99).', error: true);
      return;
    }
    final int? pts = int.tryParse(pointsText);
    if (pts == null || pts < 10) {
      _showBar('Points must be at least 10.', error: true);
      return;
    }

    // Generate group using cut-digit logic (8 unique combos)
    final d1 = jodi[0];
    final d2 = jodi[1];
    final c1 = _cutDigit(d1);
    final c2 = _cutDigit(d2);

    final Set<String> generated = {
      '$d1$d2',
      '$d1$c2',
      '$c1$d2',
      '$c1$c2',
      '$d2$d1',
      '$d2$c1',
      '$c2$d1',
      '$c2$c1',
    };

    // Wallet guard (no deduction now; just ensure future total <= wallet)
    int addTotal = 0;
    for (final g in generated) {
      final i = _bids.indexWhere((e) => e['jodi'] == g);
      if (i != -1) {
        // will increase by pts
        addTotal += pts;
      } else {
        addTotal += pts;
      }
    }
    if (_totalPoints() + addTotal > _walletBalance) {
      _showBar('Insufficient wallet balance for these bids.', error: true);
      return;
    }

    setState(() {
      for (final g in generated) {
        _mergeOrAdd(g, pts);
      }
      jodiController.clear();
      pointsController.clear();
    });

    _showBar('Jodis added successfully!');
  }

  void _removeBid(int index) {
    if (_isSubmitting) return;
    final removed = _bids[index];
    setState(() {
      _bids.removeAt(index);
    });
    _showBar('Removed ${removed['jodi']}.');
  }

  // ---------------- Confirm & Submit ----------------
  void _confirm() {
    _clearBar();
    if (_bids.isEmpty) {
      _showBar('Please add bids before submitting.', error: true);
      return;
    }
    final total = _totalPoints();
    if (total > _walletBalance) {
      _showBar('Insufficient wallet balance.', error: true);
      return;
    }

    final dialogBids = _bids
        .map(
          (e) => {
            'digit': e['jodi']!,
            'points': e['points']!,
            'type': 'Group Jodi',
            'pana': e['jodi']!,
          },
        )
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: widget.title,
        bids: dialogBids,
        totalBids: dialogBids.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction: _walletBalance,
        walletBalanceAfterDeduction: (_walletBalance - total).toString(),
        gameDate: DateTime.now().toLocal().toString().split(' ').first,
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () async {
          if (!mounted) return;
          setState(() => _isSubmitting = true);
          final ok = await _submitFinal();
          if (mounted) setState(() => _isSubmitting = false);

          if (ok) {
            setState(() => _bids.clear());
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

  Future<bool> _submitFinal() async {
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

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': _accountActiveStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };

    final total = _totalPoints();

    // EXACT payload as requested
    final List<Map<String, dynamic>> bidList = _bids
        .map(
          (e) => {
            'sessionType': widget.gameType, // "groupJodi"
            'digit': e['jodi'],
            'pana': e['jodi'],
            'bidAmount': int.tryParse(e['points'] ?? '0') ?? 0,
          },
        )
        .toList();

    final body = jsonEncode({
      'registerId': _registerId,
      'gameId': widget.gameId, // int
      'bidAmount': total,
      'gameType': widget.gameType, // "groupJodi"
      'bid': bidList,
    });

    log('[place-bid] Headers: $headers', name: 'GroupJodiSubmit');
    log('[place-bid] Body   : $body', name: 'GroupJodiSubmit');

    try {
      final uri = Uri.parse('${Constant.apiEndpoint}place-bid');
      final res = await http.post(uri, headers: headers, body: body);
      final Map<String, dynamic> resp = json.decode(res.body);

      log('[place-bid] HTTP ${res.statusCode}', name: 'GroupJodiSubmit');
      log('[place-bid] Resp: $resp', name: 'GroupJodiSubmit');

      if (res.statusCode == 200 &&
          (resp['status'] == true || resp['status'] == 'true')) {
        // Prefer server balance, else local deduction
        final updatedRaw = resp['updatedWalletBalance'];
        final newBal =
            int.tryParse(updatedRaw?.toString() ?? '') ??
            (_walletBalance - total);

        await _storage.write('walletBalance', newBal);
        userController.walletBalance.value = newBal.toString();
        if (mounted) setState(() => _walletBalance = newBal);

        _clearBar();
        return true;
      } else {
        final msg =
            resp['msg']?.toString() ??
            'Place bid failed. Please try again later.';
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BidFailureDialog(errorMessage: msg),
        );
        return false;
      }
    } catch (e) {
      log('Error submit: $e', name: 'GroupJodiSubmit');
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BidFailureDialog(
          errorMessage: 'Network error. Please check your internet connection.',
        ),
      );
      return false;
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final totalPts = _totalPoints();
    final totalBids = _bids.length;

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
                        'Enter Jodi',
                        SizedBox(
                          height: 38,
                          child: TextFormField(
                            controller: jodiController,
                            cursorColor: Colors.orange,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: _tfDecoration('Enter 2-digit Jodi'),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _row(
                        'Enter Points :',
                        SizedBox(
                          height: 38,
                          child: TextFormField(
                            controller: pointsController,
                            cursorColor: Colors.orange,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _tfDecoration('Enter Points'),
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
                            return _buildEntryItem(b['jodi']!, b['points']!, i);
                          },
                        ),
                ),
                if (_bids.isNotEmpty) _buildBottomBar(totalBids, totalPts),
              ],
            ),
            if (_msg != null)
              AnimatedMessageBar(
                key: _msgKey,
                message: _msg!,
                isError: _msgIsError,
                onDismissed: _clearBar,
              ),
          ],
        ),
      ),
    );
  }

  // ---------------- Widgets ----------------
  Widget _row(String label, Widget field) {
    String cleanedLabel = label;
    if (label.contains('Enter Jodi')) {
      cleanedLabel = 'Enter Jodi';
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

  Widget _buildEntryItem(String jodi, String points, int index) {
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
              jodi,
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
          GestureDetector(
            onTap: _isSubmitting ? null : () => _removeBid(index),
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

  Widget _buildBottomBar(int totalBids, int totalPoints) {
    final canSubmit = !_isSubmitting && _bids.isNotEmpty;
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
                onPressed: canSubmit ? _confirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit ? const Color(0xFFF9B233) : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
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
