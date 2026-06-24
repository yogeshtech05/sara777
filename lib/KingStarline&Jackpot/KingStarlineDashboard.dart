import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:new_sara/Bids/KingStarlineResultHis/KingStarlineResultHis.dart';
import 'package:new_sara/KingStarline&Jackpot/KingStarlineOptionScreen.dart';

import '../components/KingJackpotBiddingClosedDialog.dart';
import '../ulits/Constents.dart';

/// ---- Data Model ----
class StarlineGame {
  final int id; // from gameId
  final String time; // from gameName (e.g., "09:30 PM")
  final String status; // from statusText
  final String result; // from result
  final bool isClosed; // !playStatus
  final String openTime; // from openTime
  final String closeTime; // from closeTime
  final String additionalInfo; // "Bid closed at <closeTime>" when closed

  StarlineGame({
    required this.id,
    required this.time,
    required this.status,
    required this.result,
    required this.isClosed,
    required this.openTime,
    required this.closeTime,
    this.additionalInfo = '',
  });

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' ||
          s == '1' ||
          s == 'open' ||
          s == 'active' ||
          s == 'running';
    }
    return false;
  }

  factory StarlineGame.fromJson(Map<String, dynamic> json) {
    final int gameId = () {
      final v = json['gameId'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }();

    final String gameName = (json['gameName'] ?? 'N/A').toString();
    final String result = (json['result'] ?? '****-*').toString();
    final String statusText = (json['statusText'] ?? 'Unknown').toString();
    final bool playStatus = _toBool(json['playStatus']); // true => open
    final String closeTime = (json['closeTime'] ?? '--:--').toString();
    final String openTime = (json['openTime'] ?? '--:--').toString();

    final bool closed = !playStatus;
    final String displayStatus = statusText.isEmpty
        ? (closed ? 'Closed' : 'Open')
        : statusText;
    final String displayAdditionalInfo = closed
        ? 'Bid closed at $closeTime'
        : '';

    return StarlineGame(
      id: gameId,
      time: gameName,
      status: displayStatus,
      result: result,
      isClosed: closed,
      openTime: openTime,
      closeTime: closeTime,
      additionalInfo: displayAdditionalInfo,
    );
  }
}

/// ---- Screen ----
class KingStarlineDashboardScreen extends StatefulWidget {
  const KingStarlineDashboardScreen({super.key});

  @override
  State<KingStarlineDashboardScreen> createState() =>
      _KingStarlineDashboardScreenState();
}

class _KingStarlineDashboardScreenState
    extends State<KingStarlineDashboardScreen> {
  bool _notificationsEnabled = true;
  List<StarlineGame> _gameTimes = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final GetStorage _storage = GetStorage();

  // Non-nullable registeredId (loaded from local storage)
  String _registeredId = '';

  // Game rates data
  Map<String, dynamic>? _gameRates;

  @override
  void initState() {
    super.initState();
    _loadAuthData();
    _fetchGameList();
    _fetchGameRates(); // Fetch game rates when initializing
  }

  void _loadAuthData() {
    // Signup/Login par jo save kiya tha, wahi se seedha utha rahe hain
    final rid = _storage.read('registerId')?.toString() ?? '';
    _registeredId = rid;
    log(
      'RegisteredId loaded: ${_registeredId.isEmpty ? "(empty)" : _registeredId}',
    );
  }

  Map<String, String> _buildHeaders(
    String accessToken, {
    String? deviceId,
    String? deviceName,
    bool accountStatus = true,
  }) {
    final now = DateTime.now();
    return {
      'deviceId':
          deviceId ??
          (_storage.read('deviceId')?.toString() ?? 'unknown_device'),
      'deviceName':
          deviceName ??
          (_storage.read('deviceName')?.toString() ?? 'unknown_model'),
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
      // helpful for backend time reconciliation
      'x-client-time': now.toIso8601String(),
      'x-tz-offset-mins': now.timeZoneOffset.inMinutes.toString(),
      'x-tz-name': now.timeZoneName,
    };
  }

  Future<void> _fetchGameList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final String? accessToken = _storage.read('accessToken');
    final String? registerId = _storage.read('registerId');
    final bool accountStatus = (_storage.read('accountStatus') ?? true) == true;

    if (accessToken == null || accessToken.isEmpty) {
      log('Error: Access token not found. Cannot fetch Starline game list.');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Access token not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    if (registerId == null || registerId.isEmpty) {
      log('Error: Register ID not found. Cannot fetch Starline game list.');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Register ID not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    final url = Uri.parse('${Constant.apiEndpoint}starline-game-list');
    final headers = _buildHeaders(accessToken, accountStatus: accountStatus);
    final body = jsonEncode({'registerId': registerId});

    try {
      final response = await http.post(url, headers: headers, body: body);

      log('Starline Game List API Status: ${response.statusCode}');
      log('Starline Game List API Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData =
            json.decode(response.body) as Map<String, dynamic>;

        if (responseData['status'] == true && responseData['info'] is List) {
          final List rawList = responseData['info'] as List;
          final games = rawList
              .map(
                (e) =>
                    StarlineGame.fromJson((e as Map).cast<String, dynamic>()),
              )
              .toList();

          // Sort by time if parseable (hh:mm a)
          final fmt = DateFormat('hh:mm a');
          games.sort((a, b) {
            DateTime? ta, tb;
            try {
              final pa = fmt.parse(a.time);
              ta = DateTime(1970, 1, 1, pa.hour, pa.minute);
            } catch (_) {}
            try {
              final pb = fmt.parse(b.time);
              tb = DateTime(1970, 1, 1, pb.hour, pb.minute);
            } catch (_) {}
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return ta.compareTo(tb);
          });

          if (!mounted) return;
          setState(() {
            _gameTimes = games;
            _isLoading = false;
          });
        } else {
          final msg = (responseData['msg'] ?? 'Failed to load game data.')
              .toString();
          log('Starline Game List API Error: $msg');
          if (!mounted) return;
          setState(() {
            _errorMessage = msg;
            _isLoading = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Error ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}\n${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      log('Exception during Starline Game List API call: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  // Fetch game rates from the API
  Future<void> _fetchGameRates() async {
    final String? accessToken = _storage.read('accessToken');
    
    if (accessToken == null || accessToken.isEmpty) {
      log('Error: Access token not found. Cannot fetch game rates.');
      return;
    }

    final url = Uri.parse('${Constant.apiEndpoint}game-rate');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'deviceId': _storage.read('deviceId')?.toString() ?? 'unknown_device',
          'deviceName': _storage.read('deviceName')?.toString() ?? 'unknown_model',
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
        log('Failed to load game rates: ${response.statusCode}');
      }
    } catch (e) {
      log('Exception during Game Rates API call: $e');
    }
  }

  void _onPlayTap(StarlineGame game) {
    log(
      'Play Game tapped => id=${game.id}, time=${game.time}, status=${game.status}, isClosed=${game.isClosed}',
    );

    if (game.isClosed) {
      showDialog(
        context: context,
        builder: (_) => KingJackpotBiddingClosedDialog(
          time: game.time,
          resultTime: game.openTime,
          bidLastTime: game.closeTime,
        ),
      );
      return;
    }

    // BEST PRACTICE: registeredId must be non-empty, warna navigate mat karo
    if (_registeredId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Register ID missing. Please log in again.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KingStarlineOptionScreen(
          title: 'King Starline',
          gameTime: game.time,
          starlineGameId: game.id, // session/game id
          paanaStatus: !game.isClosed, // open/close info
          registeredId: _registeredId, // non-null String
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade300,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'King Starline Dashboard',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      //   Navigate to the history
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => KingStarlineResultScreen(),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 4.0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 5),
                          Icon(
                            Icons.calendar_month,
                            color: Colors.black,
                            size: 24,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'History',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(color: Colors.black, fontSize: 14),
                      ),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: _notificationsEnabled,
                          onChanged: (v) =>
                              setState(() => _notificationsEnabled = v),
                          activeTrackColor: Colors.teal[300],
                          activeColor: Colors.teal,
                          inactiveTrackColor: Colors.grey[300],
                          inactiveThumbColor: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey[200]),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0),
              child: Column(
                children: [
                  // Display game rates if available
                  if (_gameRates != null && _gameRates!['starlineGameRate'] != null)
                    _buildGameRatesSection(_gameRates!['starlineGameRate'])
                  else
                    // Fallback to static cards if API data is not available
                    Column(
                      children: [
                        Row(
                          children: [
                            _buildInfoCard('Single Digit', '10-100'),
                            const SizedBox(width: 5),
                            _buildInfoCard('Double Pana', '10-3200'),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            _buildInfoCard('Single Pana', '10-1600'),
                            const SizedBox(width: 5), // Changed from 10 to 5 for consistency
                            _buildInfoCard('Triple Pana', '10-10000'),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              )
            else if (_errorMessage.isNotEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _gameTimes.length,
                  itemBuilder: (_, i) {
                    final g = _gameTimes[i];
                    return _buildGameTimeListItem(game: g);
                  },
                ),
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
        rowChildren.add(_buildInfoCard(label, displayEntries[startIndex]!.value.toString()));
      } else {
        rowChildren.add(_buildInfoCard('', ''));
      }
      
      // Spacing between cards
      rowChildren.add(const SizedBox(width: 5));
      
      // Second card in row
      if (displayEntries[startIndex + 1] != null) {
        String label = _formatLabel(displayEntries[startIndex + 1]!.key);
        rowChildren.add(_buildInfoCard(label, displayEntries[startIndex + 1]!.value.toString()));
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
                    fontSize: 13,
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

  Widget _buildGameTimeListItem({required StarlineGame game}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 5),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onPlayTap(game),
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    game.isClosed
                        ? 'assets/images/ic_clock_closed.png'
                        : 'assets/images/ic_clock_active.png',
                    color: game.isClosed ? Colors.grey[600] : Colors.orange[700],
                    height: 38,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game.time,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          game.status,
                          style: TextStyle(
                            fontSize: 13,
                            color: game.isClosed
                                ? Colors.orange[700]
                                : Colors.green[700],
                            fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                     game.result,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 5),
                    Container(
                      width: 45,
                      height: 45,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.grey.shade600,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Play Game',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 5),
              ],
            ),
            if (game.additionalInfo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 0, left: 55.0, bottom: 3),
                child: Text(
                  game.additionalInfo,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
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