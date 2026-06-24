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

import '../../../BidService.dart';
import '../../../Helper/UserController.dart';
import '../../../components/AnimatedMessageBar.dart';
import '../../../components/BidConfirmationDialog.dart';
import '../../../components/BidFailureDialog.dart';
import '../../../components/BidSuccessDialog.dart';
import '../../../components/GameTypeSelectorField.dart';
import '../../../ulits/Constents.dart';

enum PattiDayType { open, close }

class SinglePannaBulkBoardScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final String gameName;
  final String gameType; // e.g. "singlePana"
  final bool selectionStatus;

  const SinglePannaBulkBoardScreen({
    Key? key,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.gameType,
    required this.selectionStatus,
  }) : super(key: key);

  @override
  State<SinglePannaBulkBoardScreen> createState() =>
      _SinglePannaBulkBoardScreenState();
}

class _SinglePannaBulkBoardScreenState
    extends State<SinglePannaBulkBoardScreen> {
  // UI state
  PattiDayType _selectedPattiDayType = PattiDayType.close;
  late String _selectedGameTypeLabel; // "Open"/"Close"

  final TextEditingController _pointsController = TextEditingController();
  bool _isApiCalling = false;

  /// pana -> {"points": "...", "dayType": "OPEN"/"CLOSE"}
  final Map<String, Map<String, String>> _bids = {};

  // storage / user
  final GetStorage _storage = GetStorage();
  final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());

  String _accessToken = '';
  String _registerId = '';
  bool _accountStatus = false;
  int _walletBalance = 0;
  StreamSubscription<String>? _walletBalanceSub;

  // device
  final String _deviceId =
      GetStorage().read('deviceId') ?? 'test_device_id_flutter';
  final String _deviceName =
      GetStorage().read('deviceName') ?? 'test_device_name_flutter';

  // message bar
  String? _messageToShow;
  bool _isErrorForMessage = false;
  Key _messageBarKey = UniqueKey();
  Timer? _msgTimer;

  int _parseWalletBalance(dynamic value) {
    final num? parsed = num.tryParse(value?.toString() ?? '0');
    return parsed?.toInt() ?? 0;
  }

  @override
  void initState() {
    super.initState();

    if (widget.selectionStatus) {
      _selectedPattiDayType = PattiDayType.open;
      _selectedGameTypeLabel = 'Open';
    } else {
      _selectedPattiDayType = PattiDayType.close;
      _selectedGameTypeLabel = 'Close';
    }

    _accessToken = _storage.read('accessToken') ?? '';
    _registerId = _storage.read('registerId') ?? '';
    _accountStatus = userController.accountStatus.value;
    _walletBalance = _parseWalletBalance(userController.walletBalance.value);

    _storage.listenKey('walletBalance', (value) {
      final int newBal = _parseWalletBalance(value);
      if (mounted) setState(() => _walletBalance = newBal);
    });

    _walletBalanceSub = userController.walletBalance.listen((value) {
      final int newBal = _parseWalletBalance(value);
      if (mounted) setState(() => _walletBalance = newBal);
    });
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _msgTimer?.cancel();
    _walletBalanceSub?.cancel();
    super.dispose();
  }

  // -------------------- helpers: messages --------------------
  void _showMessage(String msg, {bool isError = false}) {
    _msgTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _messageToShow = msg;
      _isErrorForMessage = isError;
      _messageBarKey = UniqueKey();
    });
    _msgTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _messageToShow = null);
    });
  }

  void _clearMessage() {
    if (!mounted) return;
    if (_messageToShow != null) setState(() => _messageToShow = null);
  }

  // -------------------- API: bulk add on number tap --------------------
  Future<void> _onNumberPressed(String digit) async {
    _clearMessage();
    if (_isApiCalling) return;

    final ptsStr = _pointsController.text.trim();
    final int? pts = int.tryParse(ptsStr);
    if (pts == null || pts < 10 || pts > 1000) {
      _showMessage('Points must be between 10 and 1000.', isError: true);
      return;
    }
    if (_walletBalance != 0 && pts > _walletBalance) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    setState(() => _isApiCalling = true);

    final String requestSessionType = _selectedPattiDayType == PattiDayType.open
        ? 'open'
        : 'close';

    late final Uri url;
    if (widget.title.toLowerCase().contains('single')) {
      url = Uri.parse('${Constant.apiEndpoint}single-pana-bulk');
    } else {
      url = Uri.parse('${Constant.apiEndpoint}double-pana-bulk');
    }

    final headers = {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'accessStatus': _accountStatus ? '1' : '0',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };

    final body = jsonEncode({
      "game_id": widget.gameId,
      "register_id": _registerId,
      "session_type": requestSessionType, // open/close (lowercase for this API)
      "digit": digit,
      "amount": pts,
    });

    try {
      final res = await http.post(url, headers: headers, body: body);
      final Map<String, dynamic> jsonBody =
      json.decode(res.body) as Map<String, dynamic>;

      log('Bulk Resp: $jsonBody', name: 'SinglePannaBulk');

      if (res.statusCode == 200 && jsonBody['status'] == true) {
        final List info = (jsonBody['info'] as List?) ?? const [];
        if (info.isEmpty) {
          _showMessage('No panas returned for this digit.', isError: true);
        } else {
          setState(() {
            for (final it in info) {
              final pana = '${it['pana']}';
              final amount = '${it['amount']}';
              final rawSession =
              (it['sessionType'] ??
                  it['session_type'] ??
                  requestSessionType)
                  .toString()
                  .trim();
              final sessionUpper =
              (rawSession.isEmpty ? requestSessionType : rawSession)
                  .toUpperCase(); // OPEN/CLOSE

              _bids[pana] = {
                "points": amount,
                "dayType": sessionUpper, // stored per pana
              };
            }
          });
          _showMessage('${info.length} bids for digit $digit added!');
        }
      } else {
        _showMessage(
          jsonBody['msg']?.toString() ?? 'Failed to add bulk bids.',
          isError: true,
        );
      }
    } catch (e) {
      _showMessage('Network error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isApiCalling = false);
    }
  }

  // -------------------- submit flow --------------------
  int _getTotalPoints() => _bids.values.fold(
    0,
        (s, m) => s + (int.tryParse(m['points'] ?? '0') ?? 0),
  );

  void _removeBid(String pana) {
    _clearMessage();
    if (_isApiCalling) return;
    setState(() => _bids.remove(pana));
    _showMessage('Bid for Pana $pana removed.');
  }

  void _showConfirmationDialogAndSubmitBids() {
    _clearMessage();
    if (_isApiCalling) return;

    if (_bids.isEmpty) {
      _showMessage('No bids to submit.', isError: true);
      return;
    }

    final total = _getTotalPoints();
    if (total > _walletBalance) {
      _showMessage('Insufficient wallet balance.', isError: true);
      return;
    }

    // Popup rows: show pana in “Digits” col + per-row type
    final bidsForDialog = _bids.entries.map((e) {
      final pana = e.key;
      final m = e.value;
      final type =
      (m['dayType'] ??
          (_selectedPattiDayType == PattiDayType.open
              ? 'OPEN'
              : 'CLOSE'))
          .toString()
          .toUpperCase();
      return {
        "digit": pana, // show pana
        "points": m['points']!,
        "type": type, // OPEN/CLOSE
        "pana": pana,
      };
    }).toList();

    final String formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BidConfirmationDialog(
        gameTitle: '${widget.gameName} ${widget.title}',
        gameDate: formattedDate,
        bids: bidsForDialog,
        totalBids: _bids.length,
        totalBidsAmount: total,
        walletBalanceBeforeDeduction: _walletBalance,
        walletBalanceAfterDeduction: (_walletBalance - total).toString(),
        gameId: widget.gameId.toString(),
        gameType: widget.gameType,
        onConfirm: () async {
          if (!mounted) return;
          setState(() => _isApiCalling = true);
          try {
            final ok = await _placeFinalBidsSplitBySession();
            if (!mounted) return;
            if (ok) {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const BidSuccessDialog(),
              );
              setState(() => _bids.clear());
            } else {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => BidFailureDialog(
                  errorMessage:
                  "Some or all bids failed to submit. Please try again.",
                ),
              );
            }
          } finally {
            if (mounted) setState(() => _isApiCalling = false);
          }
        },
      ),
    );
  }

  /// ✅ FIX: Split by each bid’s own dayType (OPEN/CLOSE) and send two calls.
  Future<bool> _placeFinalBidsSplitBySession() async {
    if (_accessToken.isEmpty || _registerId.isEmpty) {
      _showMessage('Authentication error. Please log in again.', isError: true);
      return false;
    }
    if (_bids.isEmpty) {
      _showMessage('No bids to submit.', isError: true);
      return false;
    }

    // Separate maps
    final Map<String, String> openMap = {};
    final Map<String, String> closeMap = {};
    _bids.forEach((pana, data) {
      final pts = data['points'] ?? '0';
      final type = (data['dayType'] ?? '').toUpperCase();
      if (type == 'OPEN') {
        openMap[pana] = pts;
      } else {
        closeMap[pana] = pts;
      }
    });

    if (openMap.isEmpty && closeMap.isEmpty) {
      _showMessage('No valid bids to submit.', isError: true);
      return false;
    }

    final svc = BidService(_storage);
    int totalDeducted = 0;

    Future<bool> sendBatch(String session, Map<String, String> map) async {
      if (map.isEmpty) return true;
      final int sum = map.values.fold<int>(
        0,
            (s, v) => s + (int.tryParse(v) ?? 0),
      );
      final result = await svc.placeFinalBids(
        gameName: widget.gameName,
        accessToken: _accessToken,
        registerId: _registerId,
        deviceId: _deviceId,
        deviceName: _deviceName,
        accountStatus: _accountStatus,
        bidAmounts: map,
        selectedGameType: session, // OPEN / CLOSE
        gameId: widget.gameId,
        gameType: widget.gameType,
        totalBidAmount: sum,
      );
      if (result['status'] == true) {
        totalDeducted += sum;
        return true;
      } else {
        final msg = result['msg']?.toString() ?? 'Submission failed.';
        _showMessage('$session bids failed: $msg', isError: true);
        return false;
      }
    }

    final okOpen = await sendBatch('OPEN', openMap);
    final okClose = await sendBatch('CLOSE', closeMap);

    final allOk = okOpen && okClose;
    if (allOk && totalDeducted > 0) {
      final newBal = _walletBalance - totalDeducted;
      await svc.updateWalletBalance(newBal);
      if (mounted) setState(() => _walletBalance = newBal);
      _showMessage('All bids submitted successfully!');
    }
    return allOk;
  }

  // -------------------- UI --------------------
  Widget _buildDropdown() {
    final List<String> types = widget.selectionStatus
        ? ['Open', 'Close']
        : ['Close'];

    if (!types.contains(_selectedGameTypeLabel)) {
      _selectedGameTypeLabel = types.first;
      _selectedPattiDayType = _selectedGameTypeLabel == 'Open'
          ? PattiDayType.open
          : PattiDayType.close;
    }

    return GameTypeSelectorField(
      selectedOption: _selectedGameTypeLabel,
      options: types,
      enabled: !_isApiCalling,
      displayTextBuilder: (val) => "${widget.gameName} $val".toUpperCase(),
      onSelected: (val) {
        setState(() {
          _selectedGameTypeLabel = val;
          _selectedPattiDayType = val == 'Open'
              ? PattiDayType.open
              : PattiDayType.close;
        });
        _clearMessage();
      },
    );
  }

  Widget _buildNumberPad() {
    const numbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: numbers.map((n) {
        return GestureDetector(
          onTap: _isApiCalling ? null : () => _onNumberPressed(n),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _isApiCalling ? Colors.grey.shade300 : const Color(0xFFF9B233),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              n,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _bidRow(String pana, String points, String type) {
    final t =
        (type.isEmpty
                ? (_selectedPattiDayType == PattiDayType.open
                    ? 'OPEN'
                    : 'CLOSE')
                : type)
            .toUpperCase();
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
              pana,
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
              t,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: t == 'OPEN'
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828),
              ),
            ),
          ),
          GestureDetector(
            onTap: _isApiCalling ? null : () => _removeBid(pana),
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

  Widget _bottomBar() {
    final totalBids = _bids.length;
    final totalPoints = _getTotalPoints();
    final canSubmit = !_isApiCalling && _bids.isNotEmpty;

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
                onPressed: canSubmit
                    ? _showConfirmationDialogAndSubmitBids
                    : null,
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

  @override
  Widget build(BuildContext context) {
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          children: [
                            _row(
                              'Select Game Type',
                              SizedBox(
                                height: 38,
                                child: _buildDropdown(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _row(
                              'Enter Points :',
                              SizedBox(
                                height: 38,
                                child: TextFormField(
                                  controller: _pointsController,
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
                                  onTap: _clearMessage,
                                  enabled: !_isApiCalling,
                                  decoration: _tfDecoration('Enter Amount'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: _isApiCalling
                                  ? const CircularProgressIndicator(
                                      color: Colors.orange,
                                    )
                                  : _buildNumberPad(),
                            ),
                          ],
                        ),
                      ),
                      if (_bids.isNotEmpty) ...[
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
                                  'Pana',
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
                          children: _bids.keys.map((pana) {
                            final m = _bids[pana]!;
                            final type = (m['dayType'] ??
                                    (_selectedPattiDayType ==
                                            PattiDayType.open
                                        ? 'OPEN'
                                        : 'CLOSE'))
                                .toString();
                            return _bidRow(pana, m['points']!, type);
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
                      if (_bids.isEmpty) ...[
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
                        _bottomBar(),
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
}

