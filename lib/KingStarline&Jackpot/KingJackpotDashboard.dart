import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/Bids/KingJackpotResultHis/KingJackpotResultScreen.dart';
import 'package:new_sara/KingStarline&Jackpot/JackpotJodiOptionsScreen.dart';
import 'package:new_sara/components/KingJackpotBiddingClosedDialog.dart';

import '../Helper/TranslationHelper.dart';
import '../ulits/Constents.dart';

class KingJackpotDashboard extends StatefulWidget {
  const KingJackpotDashboard({super.key});

  @override
  State<KingJackpotDashboard> createState() => _KingJackpotDashboardState();
}

class _KingJackpotDashboardState extends State<KingJackpotDashboard> {
  static const Color kCardBg = Colors.white;
  static const Color kPrimaryDark = Color(0xFF1D2232);

  bool isNotificationOn = true;
  late Future<JackpotGameData> futureGameData;

  final String toLang = GetStorage().read('language') ?? 'en';
  Map<String, String> _i18n = {};
  int _totalJodiElements = 0;

  // Game rates data
  Map<String, dynamic>? _gameRates;

  @override
  void initState() {
    super.initState();
    futureGameData = fetchGameData();
    _loadTranslations();
    _fetchGameRates(); // Fetch game rates when initializing
  }

  String tr(String key) => _i18n[key] ?? key;

  Future<void> _loadTranslations() async {
    // Translate once, then setState once
    final keys = <String>[
      'King Jackpot',
      'History',
      'Notifications',
      'Jodi',
      'Closed',
      'Running',
      'Play Game',
      'No data available.',
      'Error:',
      'Retry',
    ];

    try {
      final results = await Future.wait(
        keys.map((k) => TranslationHelper.translate(k, toLang)),
      );
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < keys.length; i++) {
          _i18n[keys[i]] = results[i];
        }
      });
    } catch (_) {
      // If translation fails, keep English labels silently
    }
  }

  Future<JackpotGameData> fetchGameData() async {
    final storage = GetStorage();
    final String accessToken = storage.read('accessToken') ?? '';
    final String registerId = storage.read('registerId') ?? '';
    final String deviceId =
        storage.read('deviceId')?.toString() ?? 'unknown_device';
    final String deviceName =
        storage.read('deviceName')?.toString() ?? 'unknown_model';
    final bool accountStatus = (storage.read('accountStatus') ?? true) == true;

    dev.log('[Jackpot] Fetching...', name: 'KingJackpot');
    dev.log(
      '[Jackpot] AccessToken: ${accessToken.isNotEmpty}',
      name: 'KingJackpot',
    );
    dev.log('[Jackpot] RegisterId: $registerId', name: 'KingJackpot');

    try {
      final now = DateTime.now();
      final uri = Uri.parse('${Constant.apiEndpoint}jackpot-game-list');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
              'deviceId': deviceId,
              'deviceName': deviceName,
              'accessStatus': accountStatus ? '1' : '0',
              'Authorization': 'Bearer $accessToken',
              // timezone/context headers (helpful server-side)
              'x-client-time': now.toIso8601String(),
              'x-tz-offset-mins': now.timeZoneOffset.inMinutes.toString(),
              'x-tz-name': now.timeZoneName,
            },
            body: json.encode({'registerId': registerId}),
          )
          .timeout(const Duration(seconds: 20));

      dev.log('[Jackpot] Status: ${res.statusCode}', name: 'KingJackpot');
      dev.log('[Jackpot] Body: ${res.body}', name: 'KingJackpot');

      if (res.statusCode == 200) {
        final data = jackpotGameDataFromJson(res.body);

        if (data.info != null) {
          final count = data.info!.length;
          dev.log('[Jackpot] Total Jodi Elements: $count', name: 'KingJackpot');
          if (mounted) setState(() => _totalJodiElements = count);
        }
        return data;
      }

      throw Exception(
        'Failed to load jackpot game data: ${res.statusCode} - ${res.body}',
      );
    } catch (e) {
      dev.log('[Jackpot] Error: $e', name: 'KingJackpot');
      rethrow;
    }
  }

  // Fetch game rates from the API
  Future<void> _fetchGameRates() async {
    final storage = GetStorage();
    final String? accessToken = storage.read('accessToken');

    if (accessToken == null || accessToken.isEmpty) {
      dev.log('Error: Access token not found. Cannot fetch game rates.');
      return;
    }

    final url = Uri.parse('${Constant.apiEndpoint}game-rate');

    try {
      final response = await http.get(
        url,
        headers: {
          'deviceId': storage.read('deviceId')?.toString() ?? 'unknown_device',
          'deviceName':
              storage.read('deviceName')?.toString() ?? 'unknown_model',
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == true && responseData['info'] != null) {
          if (!mounted) return;
          setState(() {
            _gameRates = responseData['info'];
          });
        }
      } else {
        dev.log('Failed to load game rates: ${response.statusCode}');
      }
    } catch (e) {
      dev.log('Exception during Game Rates API call: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildChips(),
            const SizedBox(height: 5),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6), // Reduced horizontal padding
                child: RefreshIndicator(
                  color: Colors.orange,
                  onRefresh: () async {
                    setState(() => futureGameData = fetchGameData());
                    await futureGameData;
                  },
                  child: FutureBuilder<JackpotGameData>(
                    future: futureGameData,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.orange,
                          ),
                        );
                      }

                      if (snap.hasError) {
                        return _errorView(
                          context,
                          message: '${tr("Error:")} ${snap.error}',
                          onRetry: () =>
                              setState(() => futureGameData = fetchGameData()),
                        );
                      }

                      final info = snap.data?.info;
                      if (info == null || info.isEmpty) {
                        return Center(
                          child: Text(
                            tr('No data available.'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      }

                      return GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 40, top: 8), // Added bottom padding to prevent cutoff
                        itemCount: info.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 155, // Adjusted to match square-ish look
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemBuilder: (context, i) {
                          final g = info[i];
                          return _buildGameCard(
                            gameId: g.gameId,
                            timeLabel: g.gameName,
                            result: g.result,
                            statusText: g.statusText,
                            closeTime: g.closeTime,
                            openTime: g.openTime,
                            playStatus: g.playStatus,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 30, color: Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Text(
                tr('King Jackpot'),
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => KingJackpotResultScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 4.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined, // Closer to screenshot
                        color: Colors.black54,
                        size: 24,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tr('History'),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    tr('Notifications'),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: isNotificationOn,
                    onChanged: (v) => setState(() => isNotificationOn = v),
                    activeColor: Colors.teal,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('Jodi'),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '1-10', // Or dynamic: '1 - $_totalJodiElements', based on screenshot it's "1-10"
                style: const TextStyle(
                  color: Color(0xFFF9B233), // Orange
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required int gameId,
    required String timeLabel,
    required String result,
    required String statusText,
    required String closeTime,
    required String openTime,
    required bool playStatus,
  }) {
    final statusLower = statusText.toLowerCase().trim();
    final isClosedByText = statusLower == 'closed' || statusLower == 'closed for today';
    final canPlay = playStatus && !isClosedByText;

    final Color statusColor = canPlay ? Colors.green : Colors.red;
    final String displayStatusText = canPlay ? 'Running Now' : 'Closed for Today';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: InkWell(
        onTap: () => _onPlayPressed(
          canPlay: canPlay,
          timeLabel: timeLabel,
          closeTime: closeTime,
          openTime: openTime,
          gameId: gameId,
        ),
        borderRadius: BorderRadius.circular(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          timeLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        Image.asset(
                          canPlay
                              ? 'assets/images/ic_clock_active.png'
                              : 'assets/images/ic_clock_closed.png',
                          color: canPlay ? const Color(0xFFF9B233) : const Color(0xFF6A7285),
                          height: 32,
                          errorBuilder: (c, e, s) => Icon(
                            canPlay ? Icons.alarm_on : Icons.alarm_off,
                            color: canPlay ? const Color(0xFFF9B233) : const Color(0xFF6A7285),
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CircleAvatar(
                      backgroundColor: Colors.black,
                      radius: 18, // Increased size
                      child: Text(
                        result.trim().isEmpty ? '**' : result.trim(),
                        style: const TextStyle(
                          color: Color(0xFFF9B233),
                          fontSize: 14, // Increased font size
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      displayStatusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: canPlay ? const Color(0xFFF9B233) : const Color(0xFF343d4d),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4), // Match card border radius
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32, // Increased size further
                    height: 32, // Increased size further
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      size: 24, // Increased icon size further
                      color: canPlay ? const Color(0xFFF9B233) : const Color(0xFF343d4d),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('Play Game'),
                    style: TextStyle(
                      color: canPlay ? Colors.black87 : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPlayPressed({
    required bool canPlay,
    required String timeLabel,
    required String closeTime,
    required String openTime,
    required int gameId,
  }) {
    if (!canPlay) {
      showDialog(
        context: context,
        builder: (_) => KingJackpotBiddingClosedDialog(
          time: timeLabel,
          resultTime: openTime,
          bidLastTime: closeTime,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JackpotJodiOptionsScreen(
          title: 'King Jackpot, $timeLabel',
          gameTime: timeLabel,
          gameId: gameId,
          digitJodiStatus: false,
          sessionSelection: true,
        ),
      ),
    );
  }

  Widget _errorView(
    BuildContext context, {
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text(tr('Retry')),
            ),
          ],
        ),
      ),
    );
  }

  // Build game rates section dynamically from API data
  Widget _buildGameRatesSection(Map<String, dynamic> rates) {
    // Convert map entries to list for easier manipulation
    List<MapEntry<String, dynamic>> entries = rates.entries.toList();

    // Create a list with exactly 4 items (pad with empty slots if needed)
    List<MapEntry<String, dynamic>?> displayEntries = List.filled(4, null);

    // Fill available entries (up to 4)
    for (int i = 0; i < entries.length && i < 4; i++) {
      displayEntries[i] = entries[i];
    }

    List<Widget> rows = [];

    // Create 2 rows with 2 cards each
    for (int rowIndex = 0; rowIndex < 2; rowIndex++) {
      int startIndex = rowIndex * 2;

      List<Widget> rowChildren = [];

      // First card in row
      if (displayEntries[startIndex] != null) {
        String label = _formatLabel(displayEntries[startIndex]!.key);
        rowChildren.add(
          _buildInfoCard(label, displayEntries[startIndex]!.value.toString()),
        );
      } else {
        rowChildren.add(_buildInfoCard('', ''));
      }

      // Spacing between cards
      rowChildren.add(const SizedBox(width: 5));

      // Second card in row
      if (displayEntries[startIndex + 1] != null) {
        String label = _formatLabel(displayEntries[startIndex + 1]!.key);
        rowChildren.add(
          _buildInfoCard(
            label,
            displayEntries[startIndex + 1]!.value.toString(),
          ),
        );
      } else {
        rowChildren.add(_buildInfoCard('', ''));
      }

      rows.add(Row(children: rowChildren));
      rows.add(const SizedBox(height: 5));
    }

    return Column(children: rows);
  }

  // Format labels for game rates
  String _formatLabel(String key) {
    switch (key) {
      case 'singleDigit':
        return 'Single Digit';
      case 'jodi':
        return 'Jodi';
      case 'singlePanna':
        return 'Single Pana';
      case 'doublePanna':
        return 'Double Pana';
      case 'triplePanna':
        return 'Triple Pana';
      default:
        return key;
    }
  }

  // Build info card for game rates
  Widget _buildInfoCard(String title, String value) {
    // Handle empty cards
    if (title.isEmpty && value.isEmpty) {
      return Expanded(
        child: Card(
          color: Colors.transparent,
          elevation: 0,
          child: Container(),
        ),
      );
    }

    return Expanded(
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= MODELS =======================

JackpotGameData jackpotGameDataFromJson(String str) =>
    JackpotGameData.fromJson(json.decode(str) as Map<String, dynamic>);

String jackpotGameDataToJson(JackpotGameData data) =>
    json.encode(data.toJson());

class JackpotGameData {
  final bool status;
  final String msg;
  final List<JackpotGameInfo>? info;

  JackpotGameData({required this.status, required this.msg, this.info});

  factory JackpotGameData.fromJson(Map<String, dynamic> json) {
    final rawInfo = json['info'];
    List<JackpotGameInfo>? parsedInfo;
    if (rawInfo is List) {
      parsedInfo = rawInfo
          .map(
            (x) => JackpotGameInfo.fromJson((x as Map).cast<String, dynamic>()),
          )
          .toList();
    }

    final dynamic s = json['status'];
    final status = s == true || s == 1 || s == '1';

    return JackpotGameData(
      status: status,
      msg: (json['msg'] ?? '').toString(),
      info: parsedInfo,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'msg': msg,
    'info': info?.map((x) => x.toJson()).toList(),
  };
}

class JackpotGameInfo {
  final int gameId;
  final String gameName;
  final String openTime;
  final String closeTime;
  final String result;
  final String statusText;
  final bool playStatus;

  JackpotGameInfo({
    required this.gameId,
    required this.gameName,
    required this.openTime,
    required this.closeTime,
    required this.result,
    required this.statusText,
    required this.playStatus,
  });

  factory JackpotGameInfo.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    bool parseBool(dynamic v) {
      if (v is bool) return v;
      final s = v?.toString().toLowerCase().trim();
      return s == '1' ||
          s == 'true' ||
          s == 'yes' ||
          s == 'open' ||
          s == 'running';
    }

    return JackpotGameInfo(
      gameId: parseInt(json['gameId']),
      gameName: (json['gameName'] ?? '').toString(),
      openTime: (json['openTime'] ?? '').toString(),
      closeTime: (json['closeTime'] ?? '').toString(),
      result: (json['result'] ?? '').toString(),
      statusText: (json['statusText'] ?? '').toString(),
      playStatus: parseBool(json['playStatus']),
    );
  }

  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'gameName': gameName,
    'openTime': openTime,
    'closeTime': closeTime,
    'result': result,
    'statusText': statusText,
    'playStatus': playStatus,
  };
}
