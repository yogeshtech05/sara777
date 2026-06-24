// File: lib/Passbook/BidHistoryPage.dart (adjust path if different)
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../ulits/Constents.dart';

class BidHistoryPage extends StatefulWidget {
  const BidHistoryPage({Key? key}) : super(key: key);
  @override
  State<BidHistoryPage> createState() => _BidHistoryPageState();
}

class _BidHistoryPageState extends State<BidHistoryPage> {
  List<BetHistoryEntry> entries = [];
  bool loading = false;

  // Default to today's data
  DateTime _selectedFromDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetchEntries();
  }

  Future<void> fetchEntries() async {
    setState(() => loading = true);

    final storage = GetStorage();
    final token = (storage.read("accessToken") ?? '').toString();
    final registerId = (storage.read("registerId") ?? '').toString();

    final url = Uri.parse('${Constant.apiEndpoint}bet-history');

    // Format yyyy-MM-dd
    final String formattedFromDate = DateFormat(
      'yyyy-MM-dd',
    ).format(_selectedFromDate);

    final body = {
      'registerId': registerId,
      'pageIndex': 1, // pagination removed
      'recordLimit': 10000, // pagination removed
      'placeType': 'game', // general game history
      'fromDate': formattedFromDate,
    };

    log("Fetching Bid History entries...");
    log("Register Id: $registerId");
    log("Access Token: ${token.isNotEmpty ? '*' : '(empty)'}");
    log("Request Body: ${jsonEncode(body)}");

    try {
      final res = await http.post(
        url,
        headers: <String, String>{
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      log("Response Status Code: ${res.statusCode}");
      log("Response Body: ${res.body}");

      if (res.statusCode == 200) {
        Map<String, dynamic> data;
        try {
          data = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {
          debugPrint('Invalid JSON in response');
          setState(() => entries = []);
          return;
        }

        // Handle 'info' possibly being "" (empty string) from server
        final info =
            (data['info'] is String && (data['info'] as String).isEmpty)
            ? null
            : data['info'] as Map<String, dynamic>?;

        if (info != null) {
          final list = (info['list'] as List?) ?? [];
          setState(() {
            entries = list
                .map((e) => BetHistoryEntry.fromJson(e as Map<String, dynamic>))
                .toList();
          });
          log("Parsed Bid History entries count: ${entries.length}");
        } else {
          setState(() => entries = []);
          debugPrint('Info field is null or empty in API response');
        }
      } else {
        debugPrint('Error ${res.statusCode}: ${res.body}');
        setState(() => entries = []);
      }
    } catch (e) {
      debugPrint('Exception: $e');
      setState(() => entries = []);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedFromDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        if (child == null) return const SizedBox.shrink();
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ),
          child: child,
        );
      },
    );
    if (picked != null && picked != _selectedFromDate) {
      setState(() => _selectedFromDate = picked);
      await fetchEntries(); // refresh for new date
    }
  }

  @override
  void dispose() {
    // Lock orientation to portrait as you had it (note: this affects the whole app until changed again)
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd-MM-yyyy').format(_selectedFromDate);

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade300,
        elevation: 0.5,
        toolbarHeight: 64, // to comfortably fit two-line title
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Bid History\n(From: $dateLabel)",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.black),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    )
                  : entries.isEmpty
                  ? const Center(
                      child: Text(
                        "No bid entries found.",
                        style: TextStyle(color: Colors.blueGrey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: entries.length,
                      itemBuilder: (context, index) =>
                          _buildPlayedMatchCard(entries[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayedMatchCard(BetHistoryEntry entry) {
    // If server already formats these, we show as-is.
    final formattedBidDate = entry.date;
    final formattedTransactionTime = entry.transactionTime;

    // Amount formatted with grouping, if numeric:
    String displayAmount = entry.amount;
    final num? parsedAmount = num.tryParse(entry.amount);
    if (parsedAmount != null) {
      displayAmount = NumberFormat.decimalPattern().format(parsedAmount);
    }

    final statusLower = entry.status.toLowerCase();
    final isPositive =
        statusLower.contains('good luck') ||
        statusLower.contains('win') ||
        statusLower.contains('best of luck');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.white,
      child: Column(
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.gameName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.betType} (${entry.digit})',
                      style: const TextStyle(color: Colors.black, fontSize: 14),
                    ),
                  ],
                ),
                // Right
                Text(
                  "Amount\n$displayAmount",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Card Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Dates/Times
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Bid Date
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Bid Date",
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          formattedBidDate,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    // Transaction Time
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "Transaction Time",
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          formattedTransactionTime,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Bid ID
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Bid ID",
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        entry.bidId,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(color: Colors.blueGrey),

                // Status
                Text(
                  entry.status,
                  style: TextStyle(
                    color: isPositive ? Colors.green : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // (kept for future reuse)
  Widget _navButton(String label, bool enabled, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 45,
          decoration: BoxDecoration(
            color: enabled ? Colors.orange : Colors.grey,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Data model
class BetHistoryEntry {
  final String date; // "bidDate"
  final String gameName; // "title"
  final String betType; // "gameType"
  final String digit; // "selectedDigit"
  final String amount; // "bidAmount"
  final String transactionTime; // "bidTime"
  final String bidId; // "bidId"
  final String winAmount; // "winAmount"
  final String status; // "statusText"

  BetHistoryEntry({
    required this.date,
    required this.gameName,
    required this.betType,
    required this.digit,
    required this.amount,
    required this.transactionTime,
    required this.bidId,
    required this.winAmount,
    required this.status,
  });

  factory BetHistoryEntry.fromJson(Map<String, dynamic> json) {
    return BetHistoryEntry(
      date: (json['bidDate'] ?? 'Unknown Date').toString(),
      gameName: (json['title'] ?? 'Unknown Game').toString(),
      betType: (json['gameType'] ?? 'N/A').toString(),
      digit: (json['selectedDigit'] ?? 'N/A').toString(),
      amount: (json['bidAmount'] ?? '0').toString(),
      transactionTime: (json['bidTime'] ?? 'Unknown Time').toString(),
      bidId: (json['bidId'] ?? 'N/A').toString(),
      winAmount: (json['winAmount'] ?? '0').toString(),
      status: (json['statusText'] ?? 'Pending').toString(),
    );
  }
}

// import 'dart:convert';
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
//
// import '../../ulits/Constents.dart'; // For date and time formatting
//
// class BidHistoryPage extends StatefulWidget {
//   const BidHistoryPage({Key? key}) : super(key: key);
//   @override
//   State<BidHistoryPage> createState() => _BidHistoryPageState();
// }
//
// class _BidHistoryPageState extends State<BidHistoryPage> {
//   List<BetHistoryEntry> entries = [];
//   bool loading = false;
//   // Set default to current date's data
//   DateTime _selectedFromDate = DateTime.now();
//
//   @override
//   void initState() {
//     super.initState();
//     fetchEntries();
//   }
//
//   Future<void> fetchEntries() async {
//     setState(() => loading = true);
//     final url = '${Constant.apiEndpoint}bet-history'; // API URL for bet history
//     final token = GetStorage().read("accessToken") ?? '';
//     String registerId =
//         GetStorage().read("registerId") ?? ""; // Example registerId
//
//     log("Fetching Bid History entries...");
//     log("Register Id: $registerId");
//     log("Access Token: $token");
//
//     // Format the selected date to 'YYYY-MM-DD'
//     final String formattedFromDate = DateFormat(
//       'yyyy-MM-dd',
//     ).format(_selectedFromDate);
//
//     final requestBody = jsonEncode({
//       'registerId': registerId,
//       'pageIndex': 1, // Hardcoded as pagination is removed
//       'recordLimit': 10000, // Hardcoded as pagination is removed
//       'placeType': 'game', // Specific for general game history
//       'fromDate': formattedFromDate, // Made dynamic
//     });
//
//     log("Request Body: $requestBody");
//
//     try {
//       final res = await http.post(
//         Uri.parse(url),
//         headers: {
//           'deviceId': 'qwert',
//           'deviceName': 'sm2233',
//           'accessStatus': '1',
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: requestBody,
//       );
//
//       log("Response Status Code: ${res.statusCode}");
//       log("Response Body: ${res.body}");
//
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         // Handle 'info' being an empty string instead of a Map or null
//         Map<String, dynamic>? info;
//         if (data['info'] is String && data['info'].isEmpty) {
//           info = null; // Treat empty string as null
//         } else {
//           info = data['info'] as Map<String, dynamic>?;
//         }
//
//         if (info != null) {
//           final list = info['list'] as List<dynamic>? ?? [];
//
//           setState(() {
//             entries = list.map((e) => BetHistoryEntry.fromJson(e)).toList();
//           });
//           log("Parsed Bid History entries count: ${entries.length}");
//         } else {
//           setState(() {
//             entries = [];
//           });
//           debugPrint('Info field is null or empty in API response');
//         }
//       } else {
//         debugPrint('Error ${res.statusCode}: ${res.body}');
//       }
//     } catch (e) {
//       debugPrint('Exception: $e');
//     } finally {
//       setState(() => loading = false);
//     }
//   }
//
//   Future<void> _selectDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedFromDate,
//       firstDate: DateTime(2000), // Adjust as needed
//       lastDate: DateTime.now(),
//       builder: (BuildContext context, Widget? child) {
//         return Theme(
//           data: ThemeData.light().copyWith(
//             colorScheme: ColorScheme.light(
//               primary: Colors.orange, // Header background color
//               onPrimary: Colors.white, // Header text color
//               onSurface: Colors.black, // Body text color
//             ),
//             textButtonTheme: TextButtonThemeData(
//               style: TextButton.styleFrom(
//                 foregroundColor: Colors.orange, // Button text color
//               ),
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );
//     if (picked != null && picked != _selectedFromDate) {
//       setState(() {
//         _selectedFromDate = picked;
//       });
//       fetchEntries(); // Fetch entries for the new date
//     }
//   }
//
//   @override
//   void dispose() {
//     // Ensure orientation is reset to portrait when leaving the page
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitUp,
//       DeviceOrientation.portraitDown,
//     ]);
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade200, // Lighter grey background
//       appBar: AppBar(
//         backgroundColor: Colors.grey.shade300, // White app bar as in image
//         elevation: 0.5,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),
//         title: Text(
//           "Bid History\n(From: ${DateFormat('dd-MM-yyyy').format(_selectedFromDate)})", // Dynamic title
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             color: Colors.black,
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         centerTitle: true, // Center title as in image
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.calendar_month, color: Colors.black),
//             onPressed: () => _selectDate(context),
//           ),
//         ],
//       ),
//       body: SafeArea(
//         child: Column(
//           children: [
//             Expanded(
//               child: loading
//                   ? const Center(
//                       child: CircularProgressIndicator(color: Colors.orange),
//                     )
//                   : entries.isEmpty
//                   ? Center(
//                       child: Text(
//                         "No bid entries found.",
//                         style: TextStyle(color: Colors.blueGrey, fontSize: 16),
//                       ),
//                     )
//                   : ListView.builder(
//                       padding: const EdgeInsets.all(12),
//                       itemCount: entries.length,
//                       itemBuilder: (context, index) {
//                         return _buildPlayedMatchCard(entries[index]);
//                       },
//                     ),
//             ),
//             // Removed _buildPagination() from here
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPlayedMatchCard(BetHistoryEntry entry) {
//     // Format date and time
//     String formattedBidDate =
//         entry.date; // Assuming bidDate is already formatted as 'DD-MM-YYYY'
//     String formattedTransactionTime = entry
//         .transactionTime; // Assuming transactionTime is already formatted as 'HH:MM AM/PM'
//
//     return Card(
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       elevation: 2,
//       color: Colors.white,
//       child: Column(
//         children: [
//           // Card Header
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             decoration: const BoxDecoration(
//               color: Colors.orange, // Orange background for header
//               borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Column(
//                   children: [
//                     Text(
//                       entry.gameName
//                           .toUpperCase(), // Game Name (e.g., RAJDHANI DAY CLOSE)
//                       style: const TextStyle(
//                         color: Colors.black,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//
//                     Text(
//                       '${entry.betType} (${entry.digit})', // Bet Type (e.g., Single Digit)
//                       style: const TextStyle(color: Colors.black, fontSize: 14),
//                     ),
//                   ],
//                 ),
//
//                 Text(
//                   "Amount\n${entry.amount}", // Amount
//                   textAlign: TextAlign.right,
//                   style: const TextStyle(
//                     color: Colors.black,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 14,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           // Card Body
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           "Bid Date",
//                           style: TextStyle(color: Colors.grey),
//                         ),
//                         Text(
//                           formattedBidDate,
//                           style: const TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                       ],
//                     ),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.end,
//                       children: [
//                         const Text(
//                           "Transaction Time",
//                           style: TextStyle(color: Colors.grey),
//                         ),
//                         Text(
//                           formattedTransactionTime,
//                           style: const TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 12),
//                 Align(
//                   alignment: Alignment.centerLeft,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         "Bid ID",
//                         style: TextStyle(color: Colors.grey),
//                       ),
//                       Text(
//                         entry.bidId,
//                         style: const TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Divider(color: Colors.blueGrey),
//                 Text(
//                   // Changed to Text to use dynamic status
//                   entry.status, // Display the status text from API
//                   style: TextStyle(
//                     color:
//                         entry.status.toLowerCase().contains('good luck') ||
//                             entry.status.toLowerCase().contains('win') ||
//                             entry.status.toLowerCase().contains('best of luck')
//                         ? Colors.green
//                         : Colors.black, // Green for "Good Luck"
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // Removed _buildPagination() function as it's no longer needed
//   // Widget _buildPagination() { ... }
//
//   // The _navButton is no longer directly used in this UI, but keeping it in case
//   // it's used elsewhere or for future pagination re-introduction.
//   Widget _navButton(String label, bool enabled, VoidCallback onTap) {
//     return Expanded(
//       child: GestureDetector(
//         onTap: enabled ? onTap : null,
//         child: Container(
//           height: 45,
//           decoration: BoxDecoration(
//             color: enabled ? Colors.orange : Colors.grey,
//             borderRadius: BorderRadius.circular(6),
//           ),
//           child: Center(
//             child: Text(
//               label,
//               style: const TextStyle(
//                 color: Colors
//                     .white, // Changed text color to white for better contrast on amber/grey
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // Data model for Bet History entries (reused from KingJackpotHistoryScreen)
// class BetHistoryEntry {
//   final String date; // Corresponds to "Bid Date"
//   final String gameName; // Corresponds to "Game Name"
//   final String betType; // Corresponds to "Game Type"
//   final String digit; // Corresponds to "Bet"
//   final String amount; // Corresponds to "Amount"
//   final String transactionTime; // Corresponds to "Transaction Time"
//   final String bidId; // Corresponds to "Bid ID"
//   final String
//   winAmount; // Not directly shown in UI, but kept for data integrity
//   final String status; // Corresponds to "StatusText"
//
//   BetHistoryEntry({
//     required this.date,
//     required this.gameName,
//     required this.betType,
//     required this.digit,
//     required this.amount,
//     required this.transactionTime,
//     required this.bidId,
//     required this.winAmount,
//     required this.status,
//   });
//
//   factory BetHistoryEntry.fromJson(Map<String, dynamic> json) {
//     // Directly use bidDate and bidTime from the API response
//     String datePart = json['bidDate'] ?? 'Unknown Date';
//     String timePart = json['bidTime'] ?? 'Unknown Time';
//
//     return BetHistoryEntry(
//       date: datePart,
//       gameName: json['title'] ?? 'Unknown Game', // Mapped from 'title'
//       betType: json['gameType'] ?? 'N/A', // Mapped from 'gameType'
//       digit:
//           json['selectedDigit']?.toString() ??
//           'N/A', // Mapped from 'selectedDigit'
//       amount: json['bidAmount']?.toString() ?? '0', // Mapped from 'bidAmount'
//       transactionTime: timePart, // Directly using 'bidTime'
//       bidId: json['bidId'] ?? 'N/A', // Mapped from 'bidId'
//       winAmount: json['winAmount']?.toString() ?? '0',
//       status: json['statusText'] ?? 'Pending', // Mapped from 'statusText'
//     );
//   }
// }
