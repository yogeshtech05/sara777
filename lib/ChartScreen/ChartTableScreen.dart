import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

import '../ulits/Constents.dart';

class ChartTableScreen extends StatefulWidget {
  final int gameId;
  final String gameType;

  const ChartTableScreen({
    super.key,
    required this.gameId,
    required this.gameType,
  });

  @override
  State<ChartTableScreen> createState() => _ChartTableScreenState();
}

class _ChartTableScreenState extends State<ChartTableScreen> {
  List<dynamic> chartData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchChartData();
  }

  Future<void> fetchChartData() async {
    final String token = GetStorage().read("accessToken") ?? "";
    final String deviceId = GetStorage().read('deviceId') ?? "";
    final String deviceName = GetStorage().read('deviceName') ?? "";

    final response = await http.post(
      Uri.parse('${Constant.apiEndpoint}table-chart'),
      headers: {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'accessStatus': '1',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'gameId': widget.gameId, 'gameType': widget.gameType}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['status'] == true) {
        setState(() {
          chartData = json['info'];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } else {
      debugPrint('API Error: ${response.statusCode}');
      setState(() => isLoading = false);
    }
  }

  Widget buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Center(
              child: Text(
                'Date',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Open',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Jodi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Close',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDataRow(Map<String, dynamic> row) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Text(
                row['date'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                row['open'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                row['digit'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ), // digit as jodi
          Expanded(
            child: Center(
              child: Text(
                row['close'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
      appBar: AppBar(
        title: const Text('Charts'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        backgroundColor: Colors.grey.shade300,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Container(
          color: Colors.grey.shade200,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  )
                : chartData.isEmpty
                ? const Center(child: Text('No chart data found.'))
                : Column(
                    children: [
                      buildHeaderRow(),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: chartData.length,
                          itemBuilder: (context, index) {
                            return buildDataRow(chartData[index]);
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
