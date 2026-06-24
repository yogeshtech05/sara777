import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:new_sara/ulits/Constents.dart';

class KingStarlineResultScreen extends StatefulWidget {
  const KingStarlineResultScreen({super.key});

  @override
  State<KingStarlineResultScreen> createState() =>
      _KingStarlineResultScreenState();
}

class _KingStarlineResultScreenState extends State<KingStarlineResultScreen> {
  DateTime selectedDate = DateTime.now();
  List<Map<String, String>> fullResults = [];
  bool isLoading = false;

  List<String> hours = [
    "10:00 AM",
    "11:00 AM",
    "12:00 PM",
    "01:00 PM",
    "02:00 PM",
    "03:00 PM",
    "04:00 PM",
    "05:00 PM",
    "06:00 PM",
    "07:00 PM",
    "08:00 PM",
    "09:00 PM",
  ];

  @override
  void initState() {
    super.initState();
    fetchResultsForDate(selectedDate);
  }

  Future<void> fetchResultsForDate(DateTime date) async {
    setState(() => isLoading = true);

    try {
      final url = Uri.parse('${Constant.apiEndpoint}get-results');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "env_type": "Prod",
          "date": DateFormat("yyyy-MM-dd").format(date),
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List resultList = jsonData['result'];

        List<Map<String, String>> mapped = resultList.map<Map<String, String>>((
          item,
        ) {
          return {"time": item["time"] ?? "", "result": item["result"] ?? "**"};
        }).toList();

        setState(() {
          fullResults = mapped;
        });
      }
    } catch (e) {
      debugPrint("Error fetching: $e");
    }

    setState(() => isLoading = false);
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.orange, // Header color
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

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      fetchResultsForDate(picked);
    }
  }

  String getResultForTime(String time) {
    final match = fullResults.firstWhere(
      (item) => item["time"] == time,
      orElse: () => {"result": "**"},
    );
    return match["result"]!;
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(
        title: Text(
          "KING STARLINE RESULT HISTORY",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        backgroundColor: const Color(0xFFEDEDED),
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.account_balance_wallet_outlined),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Text(
                        "Select Date",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Text(
                            DateFormat("dd/MM/yyyy").format(selectedDate),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: hours.length,
                    itemBuilder: (context, index) {
                      final time = hours[index];
                      final result = getResultForTime(time);

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 3,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(
                              time,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFF9B233),
                                fontSize: sw * 0.045,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              result,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: sw * 0.045,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
