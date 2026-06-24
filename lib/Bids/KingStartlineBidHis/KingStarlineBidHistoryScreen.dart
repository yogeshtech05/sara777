import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../ulits/Constents.dart'; // For date and time formatting

class KingStarlineBidHistoryScreen extends StatefulWidget {
  const KingStarlineBidHistoryScreen({Key? key}) : super(key: key);
  @override
  State<KingStarlineBidHistoryScreen> createState() =>
      _KingStarlineBidHistoryScreenState();
}

class _KingStarlineBidHistoryScreenState
    extends State<KingStarlineBidHistoryScreen> {
  List<BetHistoryEntry> entries = [];
  bool loading = false;
  // Set default to current date's data
  DateTime _selectedFromDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetchEntries();
  }

  Future<void> fetchEntries() async {
    setState(() => loading = true);
    final url = '${Constant.apiEndpoint}bet-history'; // API URL for bet history
    final token = GetStorage().read("accessToken") ?? '';
    String registerId =
        GetStorage().read("registerId") ?? ""; // Example registerId

    log("Fetching King Starline Bid History entries...");
    log("Register Id: $registerId");
    log("Access Token: $token");

    // Format the selected date to 'YYYY-MM-DD'
    final String formattedFromDate = DateFormat(
      'yyyy-MM-dd',
    ).format(_selectedFromDate);

    final requestBody = jsonEncode({
      'registerId': registerId,
      'pageIndex': 1, // Hardcoded as pagination is removed
      'recordLimit': 10000, // Hardcoded as pagination is removed
      'placeType': 'starline', // Specific for King Starline
      'fromDate': formattedFromDate, // Made dynamic
    });

    log("Request Body: $requestBody");

    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      log("Response Status Code: ${res.statusCode}");
      log("Response Body: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // Handle 'info' being an empty string instead of a Map or null
        Map<String, dynamic>? info;
        if (data['info'] is String && data['info'].isEmpty) {
          info = null; // Treat empty string as null
        } else {
          info = data['info'] as Map<String, dynamic>?;
        }

        if (info != null) {
          final list = info['list'] as List<dynamic>? ?? [];

          setState(() {
            entries = list.map((e) => BetHistoryEntry.fromJson(e)).toList();
          });
          log(
            "Parsed King Starline Bid History entries count: ${entries.length}",
          );
        } else {
          setState(() {
            entries = [];
          });
          debugPrint('Info field is null or empty in API response');
        }
      } else {
        debugPrint('Error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('Exception: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedFromDate,
      firstDate: DateTime(2000), // Adjust as needed
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedFromDate) {
      setState(() {
        _selectedFromDate = picked;
      });
      fetchEntries(); // Fetch entries for the new date
    }
  }

  @override
  void dispose() {
    // Ensure orientation is reset to portrait when leaving the page
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200, // Lighter grey background
      appBar: AppBar(
        backgroundColor: Colors.white, // White app bar as in image
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          "King Starline Bid History\n(From: ${DateFormat('dd-MM-yyyy').format(_selectedFromDate)})", // Dynamic title
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true, // Center title as in image
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
                  ? Center(
                      child: Text(
                        "No bid entries found.",
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        return _buildPlayedMatchCard(entries[index]);
                      },
                    ),
            ),
            // Removed _buildPagination() from here
          ],
        ),
      ),
    );
  }

  Widget _buildPlayedMatchCard(BetHistoryEntry entry) {
    // Format date and time
    String formattedBidDate =
        entry.date; // Assuming bidDate is already formatted as 'DD-MM-YYYY'
    String formattedTransactionTime = entry
        .transactionTime; // Assuming transactionTime is already formatted as 'HH:MM AM/PM'

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
              color: Colors.orange, // Orange background for header
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Text(
                      entry.gameName
                          .toUpperCase(), // Game Name (e.g., RAJDHANI DAY CLOSE)
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    Text(
                      '${entry.betType} (${entry.digit})', // Bet Type (e.g., Single Digit)
                      style: const TextStyle(color: Colors.black, fontSize: 14),
                    ),
                  ],
                ),

                Text(
                  "Amount\n${entry.amount}", // Amount
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                Divider(),
                Text(
                  // Changed to Text to use dynamic status
                  entry.status, // Display the status text from API
                  style: TextStyle(
                    color: entry.status.toLowerCase().contains('Best')
                        ? Colors.green
                        : Colors.black, // Green for "Good Luck"
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

  // Removed _buildPagination() function as it's no longer needed
  // Widget _buildPagination() { ... }

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
                color: Colors
                    .white, // Changed text color to white for better contrast on amber/grey
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Data model for Bet History entries (reused from KingJackpotHistoryScreen)
class BetHistoryEntry {
  final String date; // Corresponds to "Bid Date"
  final String gameName; // Corresponds to "Game Name"
  final String betType; // Corresponds to "Game Type"
  final String digit; // Corresponds to "Bet"
  final String amount; // Corresponds to "Amount"
  final String transactionTime; // Corresponds to "Transaction Time"
  final String bidId; // Corresponds to "Bid ID"
  final String
  winAmount; // Not directly shown in UI, but kept for data integrity
  final String status; // Corresponds to "StatusText"

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
    // Directly use bidDate and bidTime from the API response
    String datePart = json['bidDate'] ?? 'Unknown Date';
    String timePart = json['bidTime'] ?? 'Unknown Time';

    return BetHistoryEntry(
      date: datePart,
      gameName: json['title'] ?? 'Unknown Game', // Mapped from 'title'
      betType: json['gameType'] ?? 'N/A', // Mapped from 'gameType'
      digit:
          json['selectedDigit']?.toString() ??
          'N/A', // Mapped from 'selectedDigit'
      amount: json['bidAmount']?.toString() ?? '0', // Mapped from 'bidAmount'
      transactionTime: timePart, // Directly using 'bidTime'
      bidId: json['bidId'] ?? 'N/A', // Mapped from 'bidId'
      winAmount: json['winAmount']?.toString() ?? '0',
      status: json['statusText'] ?? 'Pending', // Mapped from 'statusText'
    );
  }
}
