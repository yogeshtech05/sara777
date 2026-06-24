import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/ChartScreen/ChartTableScreen.dart';
import 'package:new_sara/ulits/Constents.dart';

class Game {
  final int gameId;
  final String gameName;
  final String gameType;

  Game({required this.gameId, required this.gameName, required this.gameType});

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      gameId: json['gameId'],
      gameName: json['gameName'],
      gameType: json['gameType'],
    );
  }
}

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  List<Game> allGames = [];
  List<Game> filteredGames = [];
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchGames();
  }

  Future<void> fetchGames() async {
    final url = '${Constant.apiEndpoint}chart-game-list';
    final String accessToken = GetStorage().read('accessToken') ?? "";
    final String registerId = GetStorage().read('registerId') ?? "";
    final String deviceId = GetStorage().read('deviceId') ?? "";
    final String deviceName = GetStorage().read('deviceName') ?? "";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'deviceId': deviceId,
          'deviceName': deviceName,
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken', // truncated for brevity
        },
      );

      if (response.statusCode == 200) {
        print("RAW RESPONSE: ${response.body}");

      //  final jsonData = json.decode(response.body);


       // final List gamesJson = jsonData['info'];
       // print("INFO LIST: $gamesJson");
        final jsonData = json.decode(response.body);
        final List gamesJson = jsonData['info'];
        print("DECODED JSON: $jsonData");
        final games = gamesJson.map((e) => Game.fromJson(e)).toList();

        setState(() {
          allGames = List<Game>.from(games);
          filteredGames = allGames;
        });
      } else {
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Exception: $e");
    }
  }

  void filterSearch(String query) {
    final filtered = allGames
        .where(
          (game) => game.gameName.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    setState(() {
      filteredGames = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Charts"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.grey.shade300,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Container(
          color: Colors.grey.shade300,
          child: Column(
            children: [
              // Search Field
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchController,
                  onChanged: filterSearch,
                  decoration: InputDecoration(
                    hintText: 'Search chart',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.orange,
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),

              // Game Grid
              Expanded(
                child: filteredGames.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredGames.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 2.4,
                            ),
                        itemBuilder: (context, index) {
                          final game = filteredGames[index];
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChartTableScreen(
                                    gameId: game.gameId,
                                    gameType: game.gameType,
                                  ),
                                ),
                              );
                              // You can navigate or handle click here
                            },
                            child: Text(
                              game.gameName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
