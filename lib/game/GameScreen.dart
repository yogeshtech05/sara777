import 'dart:convert';
import 'dart:developer'; // For logging

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/Helper/UserController.dart';
// Import your game screens
import 'package:new_sara/game/Jodi/JodiBulkScreen.dart';
import 'package:new_sara/game/Panna/DoublePana/DoublePana.dart';
import 'package:new_sara/game/Panna/SinglePanna/SinglePanna.dart';
import 'package:new_sara/game/Panna/SinglePanna/SinglePannaBulk.dart'
    hide SingleDigitsBulkScreen;
import 'package:new_sara/game/RedBracket/RedBracketScreen.dart';
import 'package:new_sara/game/SPDPTPScreen/ChoiceSpDpTpBoardScreen.dart';
import 'package:new_sara/game/SPDPTPScreen/SPMotors.dart';
import 'package:new_sara/game/SPDPTPScreen/SpDpTpBoardScreen.dart';
import 'package:new_sara/game/SPDPTPScreen/TPMotorScreen.dart';
import 'package:new_sara/game/Sangam/FullSangamBoardScreen.dart';
import 'package:new_sara/game/Sangam/HalfSangamABoardScreen.dart';
import 'package:new_sara/game/Sangam/HalfSangamBBoardScreen.dart';

import '../Helper/TranslationHelper.dart'; // YOUR TranslationHelper
import '../ulits/Constents.dart';
import 'DigitBasedBoard/DigitBasedBoardScreen.dart';
import 'GameItem.dart';
import 'Jodi/JodiBidScreen.dart';
import 'Jodi/group_jodi_screen.dart';
import 'OddEvenBoard/OddEvenBoardScreen.dart';
import 'PannelGroup/PannelGroup.dart';
import 'SPDPTPScreen/DPMotors.dart';
import 'SingleDigitBetScreen/SingleDigitBetScreen.dart';
import 'SingleDigitBetScreen/SingleDigitsBulkScreen.dart';
import 'TwoDigitPanel/TwoDigitPanel.dart';

// ✅ Main Screen
class GameMenuScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final bool openSessionStatus;
  final bool closeSessionStatus;
  const GameMenuScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.openSessionStatus,
    required this.closeSessionStatus,
  });

  @override
  State<GameMenuScreen> createState() => _GameMenuScreenState();
}

class _GameMenuScreenState extends State<GameMenuScreen> {
  late final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController(), permanent: true);

  Future<List<GameItem>>? _futureGames; // Made nullable for initial state
  final storage = GetStorage();
  late String _currentLanguageCode;
  Future<String>?
  _translatedScreenTitleFuture; // To cache the main title translation

  // Simple in-memory cache for translations
  final Map<String, String> _translationCache = {};

  @override
  void initState() {
    super.initState();
    _currentLanguageCode = storage.read('selectedLanguage') ?? 'en';
    _translatedScreenTitleFuture = _getTranslatedName(
      widget.title,
    ); // Initial translation for title
    // Listen for language changes
    storage.listenKey('selectedLanguage', (value) {
      if (value != null && value is String && value != _currentLanguageCode) {
        setState(() {
          _currentLanguageCode = value;
          _translationCache.clear(); // Clear cache on language change
          _translatedScreenTitleFuture = _getTranslatedName(
            widget.title,
          ); // Re-translate title
          _futureGames =
              fetchGameList(); // Re-trigger fetch and translation for game items
        });
      }
    });
    _futureGames = fetchGameList(); // Initial fetch
  }

  // New helper to get translation from cache or fetch
  Future<String> _getTranslatedName(String originalName) async {
    // If the target language is English, no need to translate
    if (_currentLanguageCode == 'en') {
      return originalName;
    }

    final cacheKey = '$originalName:$_currentLanguageCode';
    if (_translationCache.containsKey(cacheKey)) {
      log(
        'Returning "$originalName" translation from in-memory cache.',
        name: 'TranslationCache',
      );
      return _translationCache[cacheKey]!; // Guaranteed non-null
    }

    // Check GetStorage for cached translation
    final storedTranslation = storage.read('translation_$cacheKey');
    if (storedTranslation != null && storedTranslation is String) {
      _translationCache[cacheKey] = storedTranslation;
      log(
        'Returning "$originalName" translation from GetStorage cache.',
        name: 'TranslationCache',
      );
      return storedTranslation;
    }

    // Fetch and cache
    try {
      final translated = await TranslationHelper.translate(
        originalName,
        _currentLanguageCode,
      );
      // Check if the result from your TranslationHelper is null or empty
      if (translated.isNotEmpty) {
        _translationCache[cacheKey] = translated;
        storage.write('translation_$cacheKey', translated);
        log(
          'Fetched and cached translation for "$originalName": "$translated".',
          name: 'TranslationFetch',
        );
        return translated;
      } else {
        log(
          'TranslationHelper returned empty text for "$originalName". Falling back to original.',
          name: 'GameMenuScreen.Translation',
        );
        return originalName; // Fallback to original if translation is empty
      }
    } catch (e) {
      log(
        'Error translating "$originalName": $e. Falling back to original name.',
        name: 'GameMenuScreen.Translation',
      );
      return originalName; // Fallback to original name on any error
    }
  }

  Future<List<GameItem>> fetchGameList() async {
    String? bearerToken = storage.read('accessToken');
    if (bearerToken == null || bearerToken.isEmpty) {
      log(
        'Error: Access token not found in GetStorage or is empty.',
        name: 'GameMenuScreen.Auth',
      );
      throw Exception('Access token not found or is empty');
    }

    log('Fetching game bid types from API...', name: 'GameMenuScreen.API');
    final response = await http.get(
      Uri.parse("${Constant.apiEndpoint}game-bid-type"),
      headers: {
        'deviceId': 'qwert', // Consider making these dynamic if needed
        'deviceName': 'sm2233', // Consider making these dynamic if needed
        'accessStatus': '1',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['status'] == true && decoded['info'] != null) {
        final List data = decoded['info'];
        List<GameItem> gameItems = [];

        log("API Response Status True: ${json.encode(decoded)}");

        for (var itemJson in data) {
          GameItem gameItem = GameItem.fromJson(itemJson);
          gameItems.add(gameItem);

          // Start translation in the background for each item
          _getTranslatedName(gameItem.name)
              .then((translatedName) {
                if (mounted) {
                  // Only update state if the widget is still mounted
                  setState(() {
                    gameItem.updateDisplayName(translatedName);
                  });
                }
              })
              .catchError((e) {
                log(
                  'Error setting display name for ${gameItem.name}: $e',
                  name: 'GameMenuScreen.Translation',
                );
              });
        }
        log(
          'Successfully fetched and initialized ${gameItems.length} game items.',
          name: 'GameMenuScreen.API',
        );
        return gameItems; // Return items immediately (initially with original names)
      } else {
        log(
          "API Response Status Not True or Info Missing: ${json.encode(decoded)}",
          name: 'GameMenuScreen.API',
        );
        throw Exception(
          "No game items found in API response or status is false.",
        );
      }
    } else {
      log(
        "API Error: ${response.statusCode}, ${response.body}",
        name: 'GameMenuScreen.API',
      );
      throw Exception("Failed to load game list: ${response.statusCode}");
    }
  }

  // New method to show the market closed dialog
  Future<void> _showMarketClosedDialog(String gameName) async {
    final translatedTitle = await _getTranslatedName('Market Closed');
    final translatedOk = await _getTranslatedName('OK');
    final translatedContentPrefix = await _getTranslatedName('The market for');
    final translatedContentSuffix = await _getTranslatedName(
      'is currently closed.',
    );

    // Construct the full message using translated parts and the already translated gameName
    final String fullyTranslatedContent =
        '$translatedContentPrefix $gameName $translatedContentSuffix';

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(translatedTitle),
          content: Text(fullyTranslatedContent),
          actions: <Widget>[
            TextButton(
              child: Text(translatedOk),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Dismiss dialog
              },
            ),
          ],
        );
      },
    );
  }

  // Helper function to build routes dynamically (not used directly in current tap logic, but good to keep)
  MaterialPageRoute _buildGameRoute(
    Widget screen,
    String parentScreenTranslatedTitle,
    GameItem item,
  ) {
    return MaterialPageRoute(
      builder: (_) => screen,
      settings: RouteSettings(
        arguments: {
          'title': "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
          'gameId': item.id,
          'gameType': item.type,
          'gameName': item.name,
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7F8),
        elevation: 0,
        centerTitle: false,
        title: FutureBuilder<String>(
          future: _translatedScreenTitleFuture, // Use the cached future
          builder: (context, snapshot) {
            final titleText = snapshot.data ?? widget.title;
            return Text(
              titleText.toUpperCase(),
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Obx(
            () => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  "assets/images/ic_wallet.png",
                  width: 22,
                  height: 22,
                  color: Colors.black,
                ),
                const SizedBox(width: 5),
                Text(
                  "${userController.walletBalance.value}",
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.orange,
          onRefresh: () async {
            log('Refreshing game menu data...', name: 'GameMenuScreen.Refresh');
            setState(() {
              _translationCache.clear(); // Clear cache on refresh
              _translatedScreenTitleFuture = _getTranslatedName(
                widget.title,
              ); // Re-translate title
              _futureGames =
                  fetchGameList(); // Re-fetch all data and translations
            });
          },
          child: FutureBuilder<List<GameItem>>(
            future: _futureGames,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Error loading games: ${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.orange,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    "No games found",
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                );
              } else {
                final games = snapshot.data!;
                return Container(
                  color: Colors.white, // White background for the grid sheet to create separator lines
                  child: GridView.builder(
                    itemCount: games.length,
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 2, // Spacing creates the white horizontal line
                          crossAxisSpacing: 2, // Spacing creates the white vertical line
                          childAspectRatio: 1.38, // Aspect ratio makes cells shorter so 5 rows fit on one screen
                        ),
                    itemBuilder: (context, index) {
                      final item = games[index];
                      final gameType = item.type; // From API

                      return GestureDetector(
                        onTap: () async {
                          log(
                            "Attempting navigation for Game Type: $gameType, Name: ${item.name}, Current Display: ${item.currentDisplayName}",
                            name: 'GameMenuScreen.Tap',
                          );

                          // --- CHECK SESSION SELECTION HERE ---
                          if (widget.openSessionStatus == false &&
                              item.sessionSelection == false) {
                            await _showMarketClosedDialog(
                              item.currentDisplayName,
                            ); // Await the dialog
                            return;
                          } else {}

                          // Translate the screen title part of the destination title
                          String parentScreenTranslatedTitle =
                              await _translatedScreenTitleFuture!; // Await the cached future

                          // Dynamic routing based on gameType
                          Widget? destinationScreen;
                          try {
                            switch (gameType) {
                              case 'singleDigits':
                                destinationScreen = SingleDigitBetScreen(
                                  title:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameName: item.name,
                                  gameCategoryType: item.type,
                                  selectionStatus: widget.openSessionStatus,
                                );
                                break;

                              case 'spMotor':
                                destinationScreen = SPMotorsBetScreen(
                                  title:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameName: item.name,
                                  gameCategoryType: item.type,
                                  selectionStatus: widget.openSessionStatus,
                                );
                                break;

                              case 'doublePana':
                                destinationScreen = DoublePanaBetScreen(
                                  title:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameName: item.name,
                                  gameCategoryType: item.type,
                                  selectionStatus: widget.openSessionStatus,
                                );
                                break;
                              case 'dpMotor':
                                destinationScreen = DPMotorsBetScreen(
                                  title:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameName: item.name,
                                  gameCategoryType: item.type,
                                  selectionStatus: widget.openSessionStatus,
                                );
                                break;

                              case 'triplePana':
                                destinationScreen = TPMotorsBetScreen(
                                  title:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameName: item.name,
                                  gameCategoryType: item.type,
                                  selectionStatus: widget.openSessionStatus,
                                );
                                break;

                              case 'singleDigitsBulk':
                                destinationScreen = SingleDigitsBulkScreen(
                                  title:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameType: item.type,
                                  gameName: item.name,
                                  selectionStatus: widget.openSessionStatus,
                                );
                                break;

                              case 'doublePanaBulk':
                              case 'singlePanaBulk':
                                destinationScreen = SinglePannaBulkBoardScreen(
                                  title:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameType: item.type,
                                  gameName: item.name,
                                  selectionStatus: widget.openSessionStatus,
                                );
                                break;

                              case 'panelGroup':
                                destinationScreen = PanelGroupScreen(
                                  title:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameName: item.name,
                                  gameCategoryType: item.type,
                                );
                                break;

                              case 'jodi':
                              case 'groupDigit':
                              case 'twoDigitPanna':
                                destinationScreen = JodiBidScreen(
                                  title:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameType: item.type,
                                  gameName: item.name,
                                );
                                break;

                              case 'jodiBulk':
                                destinationScreen = JodiBulkScreen(
                                  screenTitle:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameType: item.type,
                                  gameName: item.name,
                                );
                                break;

                              case 'singlePana':
                                destinationScreen = SinglePanaScreen(
                                  title:
                                      "$parentScreenTranslatedTitle ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameType: item.type,
                                  selectionStatus: widget.openSessionStatus,
                                );
                                break;

                              case 'twoDigitsPanel':
                                  destinationScreen = TwoDigitPanelScreen(
                                    title:
                                        "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                    gameId: widget.gameId,
                                    gameType: item.type,
                                    selectionStatus: widget.openSessionStatus,
                                  );
                                break;

                              case 'groupJodi':
                                destinationScreen = GroupJodiScreen(
                                  title:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameType: item.type,
                                );
                                break;

                              case 'digitBasedJodi':
                                destinationScreen = DigitBasedBoardScreen(
                                  title:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId
                                      .toString(), // Changed to match others
                                  gameType: item.type,
                                  gameName: item.name,
                                );
                                break;

                              case 'oddEven':
                                destinationScreen = OddEvenBoardScreen(
                                  title:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameType: item.type,
                                  selectionStatus: widget.openSessionStatus,
                                );
                                break;

                              case 'choicePannaSPDP':
                                destinationScreen = ChoiceSpDpTpBoardScreen(
                                  screenTitle:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameType: item.type,
                                  gameName: item.name,
                                  selectionStatus: widget.openSessionStatus,
                                );
                                break;

                              case 'SPDPTP':
                                destinationScreen = SpDpTpBoardScreen(
                                  screenTitle:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameType: item.type,
                                  openSessionStatus: widget.openSessionStatus,
                                );
                                break;

                              case 'redBracket':
                                destinationScreen = RedBracketBoardScreen(
                                  screenTitle:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameType: item.type,
                                  );
                                break;

                              case 'halfSangamA':
                                destinationScreen = HalfSangamABoardScreen(
                                  screenTitle:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameType: item.type,
                                  gameName: item.name,
                                );
                                break;

                              case 'halfSangamB':
                                destinationScreen = HalfSangamBBoardScreen(
                                  screenTitle:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameType: item.type,
                                  gameName: item.name,
                                );
                                break;

                              case 'fullSangam':
                                destinationScreen = FullSangamBoardScreen(
                                  screenTitle:
                                      "$parentScreenTranslatedTitle, ${item.currentDisplayName}",
                                  gameId: widget.gameId,
                                  gameType: item.type,
                                  gameName: item.name,
                                );
                                break;

                              default:
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "No screen available for ${item.currentDisplayName}",
                                    ),
                                  ),
                                );
                                log(
                                  "Unhandled game type: ${item.type}",
                                  name: 'GameMenuScreen.Navigation',
                                );
                                break;
                            }

                            // Navigation
                            if (destinationScreen != null) {
                              print("Navigating to $gameType");
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => destinationScreen!,
                                ),
                              );
                            } else {
                              print("destinationScreen is null for $gameType");
                            }
                          } catch (e, st) {
                            print("Error navigating to screen: $e");
                            print("Stack trace: $st");
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Failed to navigate: ${e.toString()}",
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          color: const Color(0xFFF5F7F8), // Cell background color
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 75, // Diameter matches mockup proportions
                                height: 75,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 4,
                                      spreadRadius: 0.5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(15), // Padding inside white circle
                                child: Image.network(
                                  item.image,
                                  color: const Color(0xFFF9B233), // Golden brand color
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 30,
                                        color: Colors.grey,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 6), // Spacing
                              Text(
                                item.currentDisplayName,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 13, // Size matches layout proportion
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
