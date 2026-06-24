import 'dart:convert';
import 'dart:developer'; // For log messages

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/KingStarline&Jackpot/games/StarlineJodiBidScreen.dart';
import 'package:new_sara/KingStarline&Jackpot/games/StarlineTriplePana.dart';

// Ensure these imports are correct and the files exist in your project
import '../Helper/TranslationHelper.dart';
import '../Helper/UserController.dart';
import '../ulits/Constents.dart';
import 'games/StarlineDPMotorsScreen.dart';
import 'games/StarlineOddEvenBoardScreen.dart';
import 'games/StarlineSPDPTPScreen.dart';
import 'games/StarlineSPMotorsScreen.dart';
import 'games/StarlineSingleDigit.dart';
import 'games/StarlineSinglePana.dart';

// JackpotBidType model class
class JackpotBidType {
  final int id;
  final String title;
  final String image;
  final String type;
  late String translatedTitle; // This will hold the translated title
  final bool sessionSelection;
  final bool digitJodiStatus;

  JackpotBidType({
    required this.id,
    required this.title,
    required this.image,
    required this.type,
    required this.sessionSelection,
    required this.digitJodiStatus,
    String translatedTitle =
        '', // Initialize with empty string, will be updated
  }) : this.translatedTitle = translatedTitle; // Use initializer list

  factory JackpotBidType.fromJson(Map<String, dynamic> json) {
    return JackpotBidType(
      id: json['id'] ?? 0,
      title: json['name'] ?? '',
      image: json['image'] ?? '',
      type: json['type'] ?? '',
      sessionSelection: json['sessionSelection'] ?? false,
      digitJodiStatus: json['digitJodiStatus'] ?? false,
      // Do not set translatedTitle here directly from JSON unless API provides it
      // translatedTitle will be updated after fetching
    );
  }

  // Method to update translated title after fetching
  void updateTranslatedTitle(String newTitle) {
    translatedTitle = newTitle;
  }
}

// JackpotJodiOptionsScreen widget
class JackpotJodiOptionsScreen extends StatefulWidget {
  final String gameTime;
  final int gameId;
  final String title;
  final bool digitJodiStatus;
  final bool sessionSelection;

  const JackpotJodiOptionsScreen({
    super.key,
    required this.gameTime,
    required this.gameId,
    required this.title,
    required this.digitJodiStatus,
    required this.sessionSelection,
  });

  @override
  State<JackpotJodiOptionsScreen> createState() =>
      _JackpotJodiOptionsScreenState();
}

class _JackpotJodiOptionsScreenState extends State<JackpotJodiOptionsScreen> {
  List<JackpotBidType> _options = [];
  bool _isLoading = true;

  final GetStorage _storage = GetStorage();
  late String _currentLanguageCode;
  int _walletBalance = 0;

  final Map<String, String> _translationCache = {};

  Future<String>? _translatedWalletTextFuture;
  Future<String>? _translatedNetworkErrorTextFuture;
  Future<String>? _translatedNoBidTypesTextFuture;
  Future<String>? _translatedMarketClosedTitleFuture;
  Future<String>? _translatedOkTextFuture;
  Future<String>? _translatedMarketClosedContentPrefixFuture;
  Future<String>? _translatedMarketClosedContentSuffixFuture;
  Future<String>? _translatedAuthenticationErrorTextFuture;
  Future<String>? _translatedFailedToLoadTextFuture;
  Future<String>? _translatedNoScreenConfiguredTextFuture;

  final UserController userController = Get.put(UserController());

  @override
  void initState() {
    super.initState();

    _currentLanguageCode = _storage.read('selectedLanguage') ?? 'en';

    _preTranslateFixedTexts(); // Pre-translate fixed texts

    // Listen for language changes
    _storage.listenKey('selectedLanguage', (value) {
      if (value != null && value is String) {
        if (value != _currentLanguageCode) {
          _currentLanguageCode = value;
          _translationCache.clear(); // Clear cache on language change
          _preTranslateFixedTexts(); // Re-translate fixed texts
          fetchJackpotBidTypes(); // Re-fetch and re-translate all options
        }
      }
    });

    // Listen for wallet balance changes
    double walletBalance = double.parse(userController.walletBalance.value);
    _walletBalance = walletBalance.toInt();

    fetchJackpotBidTypes(); // Initial fetch of jackpot bid types
  }

  void _preTranslateFixedTexts() {
    _translatedWalletTextFuture = _getTranslatedText('Wallet');
    _translatedNetworkErrorTextFuture = _getTranslatedText(
      'Network error. Please try again later.',
    );
    _translatedNoBidTypesTextFuture = _getTranslatedText(
      'No jackpot bid types available or failed to load.',
    );
    _translatedMarketClosedTitleFuture = _getTranslatedText('Market Closed');
    _translatedOkTextFuture = _getTranslatedText('OK');
    _translatedMarketClosedContentPrefixFuture = _getTranslatedText(
      'The market for',
    );
    _translatedMarketClosedContentSuffixFuture = _getTranslatedText(
      'is currently closed.',
    );
    _translatedAuthenticationErrorTextFuture = _getTranslatedText(
      'Authentication error: Please log in again.',
    );
    _translatedFailedToLoadTextFuture = _getTranslatedText(
      'Failed to load jackpot bid types:',
    );
    _translatedNoScreenConfiguredTextFuture = _getTranslatedText(
      'No screen configured for game type:',
    );
  }

  Future<String> _getTranslatedText(String text) async {
    if (_currentLanguageCode == 'en') {
      return text;
    }

    final cacheKey = '$text:$_currentLanguageCode';
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    final storedTranslation = _storage.read('translation_$cacheKey');
    if (storedTranslation != null && storedTranslation is String) {
      _translationCache[cacheKey] = storedTranslation;
      return storedTranslation;
    }

    try {
      final translated = await TranslationHelper.translate(
        text,
        _currentLanguageCode,
      );
      if (translated.isNotEmpty) {
        _translationCache[cacheKey] = translated;
        _storage.write('translation_$cacheKey', translated);
        return translated;
      } else {
        log(
          'TranslationHelper returned empty text for "$text". Falling back to original.',
        );
        return text;
      }
    } catch (e) {
      log('Error translating "$text": $e. Falling back to original text.');
      return text;
    }
  }

  Future<void> fetchJackpotBidTypes() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _options = []; // Clear previous options when fetching new ones
    });

    final url = Uri.parse('${Constant.apiEndpoint}jackpot-game-bid-type');
    String? bearerToken = _storage.read("accessToken");

    if (bearerToken == null || bearerToken.isEmpty) {
      log('Error: Access token not found or is empty.');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      final String authErrorMsg =
          await _translatedAuthenticationErrorTextFuture ??
          'Authentication error: Please log in again.';
      _showSnackBar(authErrorMsg);
      return;
    }

    final headers = {
      'deviceId': 'qwerr',
      'deviceName': 'sm2233',
      'accessStatus': '1',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $bearerToken',
    };

    try {
      final response = await http.get(url, headers: headers);

      if (!mounted) return; // Check mounted status after async operation

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        log('Full Jackpot API Response Data: ${jsonEncode(data)}');

        if (data['status'] == true && data['info'] != null) {
          final List<dynamic> list = data['info'];
          List<JackpotBidType> fetchedOptions = [];

          for (var itemJson in list) {
            try {
              var option = JackpotBidType.fromJson(itemJson);
              fetchedOptions.add(option);
            } catch (e) {
              log(
                'Error parsing JackpotBidType from JSON item: $itemJson. Error: $e',
              );
            }
          }

          List<JackpotBidType> translatedOptions = await Future.wait(
            fetchedOptions.map((option) async {
              // Ensure translation is done on the 'title' property
              option.updateTranslatedTitle(
                await _getTranslatedText(option.title),
              );
              return option;
            }).toList(),
          );

          if (mounted) {
            setState(() {
              _options = translatedOptions;
              _isLoading = false;
            });
          }
        } else {
          log(
            "Jackpot API Response Status Not True or Info Missing: ${json.encode(data)}",
          );
          if (mounted) {
            setState(() {
              _options = [];
              _isLoading = false;
            });
          }
          final String noBidTypesMsg =
              await _translatedNoBidTypesTextFuture ??
              'No jackpot bid types available or failed to load.';
          _showSnackBar(noBidTypesMsg);
        }
      } else {
        log("Jackpot API Error: ${response.statusCode}, ${response.body}");
        if (mounted) {
          setState(() => _isLoading = false);
        }
        final String failedToLoadMsg =
            await _translatedFailedToLoadTextFuture ??
            'Failed to load jackpot bid types:';
        _showSnackBar('$failedToLoadMsg ${response.statusCode}');
      }
    } catch (e) {
      log("Exception during Jackpot API call: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
      final String networkErrorMsg =
          await _translatedNetworkErrorTextFuture ??
          'Network error. Please try again later.';
      _showSnackBar(networkErrorMsg);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey.shade300,
        elevation: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
            ),
            const SizedBox(width: 8),
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w200,
              ),
            ),
            const Spacer(),
            Image.asset(
              "assets/images/ic_wallet.png",
              width: 22,
              height: 22,
              color: Colors.black,
            ),
            const SizedBox(width: 4),
            Text(
              "₹ ${userController.walletBalance.value}",
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              )
            : _options.isEmpty
            ? Center(
                child: FutureBuilder<String>(
                  future: _translatedNoBidTypesTextFuture,
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ??
                          'No jackpot bid types available or failed to load.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    );
                  },
                ),
              )
            : Container(
                color: Colors.white,
                child: GridView.builder(
                  itemCount: _options.length,
                  physics: const AlwaysScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    childAspectRatio: 1.38,
                  ),
                  itemBuilder: (context, index) {
                    return _optionItem(_options[index]);
                  },
                ),
              ),
      ),
    );
  }

  Widget _optionItem(JackpotBidType item) {
    return InkWell(
      onTap: () async {
        log(
          'Tapped on: ${item.translatedTitle} (Original: ${item.title}), Type: ${item.type}',
        );

        final String nextScreenTitle =
            "${widget.title}, ${item.translatedTitle}";

        Widget? destinationScreen;
        final String normalizedItemType = item.type.toLowerCase().trim();
        log('Normalized Item Type for switch: $normalizedItemType');

        switch (normalizedItemType) {
          case 'singledigits':
            destinationScreen = StarlineSingleDigitBetScreen(
              title: nextScreenTitle,
              gameId: widget.gameId,
              gameName: item.title,
              gameCategoryType: item.type,
              selectionStatus: true,
            );
            break;

          case 'oddeven':
            destinationScreen = StarlineOddEvenBoardScreen(
              title: nextScreenTitle,
              gameId: widget.gameId,
              gameName: item.title,
              gameType: item.type,
              selectionStatus: true,
            );
            break;

          case 'singlepana':
            destinationScreen = StarlineSinglePannaScreen(
              title: nextScreenTitle,
              gameId: widget.gameId,
              gameName: item.title,
              gameType: item.type,
              selectionStatus: true,
            );
            break;

          case 'doublepana':
            destinationScreen = StarlineDPMotorsScreen(
              title: nextScreenTitle,
              gameId: widget.gameId,
              gameName: item.title,
              gameCategoryType: item.type,
            );
            break;

          case 'triplepana':
            destinationScreen = StarlineTPMotorsScreen(
              title: nextScreenTitle,
              gameId: widget.gameId,
              gameName: item.title,
              selectionStatus: true,
              gameCategoryType: item.type,
            );
            break;

          case 'spdptp':
            destinationScreen = StarlineSpDpTpScreen(
              screenTitle: nextScreenTitle,
              gameId: widget.gameId,
              gameType: item.type,
            );
            break;

          case 'spmotor':
            destinationScreen = StarlineSPMotorsScreen(
              title: nextScreenTitle,
              gameId: widget.gameId,
              gameName: item.title,
              gameCategoryType: item.type,
            );
            break;

          case 'dpmotor':
            destinationScreen = StarlineDPMotorsScreen(
              title: nextScreenTitle,
              gameId: widget.gameId,
              gameName: item.title,
              gameCategoryType: item.type,
            );
            break;

          case 'jodi':
            // You need to replace `StarlineJodiScreen` with your actual Jodi betting screen.
            // This is a placeholder. Make sure you have this screen created and imported.
            destinationScreen = StarlineJodiBidScreen(
              title: nextScreenTitle,
              gameId: widget.gameId,
              gameName: item.title,
              gameType: item.type,
            );
            break;

          default:
            final String noScreenConfiguredMsg =
                await _translatedNoScreenConfiguredTextFuture ??
                'No screen configured for game type:';
            _showSnackBar("$noScreenConfiguredMsg '${item.type}'");
            log("Unhandled game type: ${item.type}");
            break;
        }

        if (destinationScreen != null) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destinationScreen!),
          );
        }
      },
      child: Container(
        color: const Color(0xFFF5F7F8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 75,
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
              padding: const EdgeInsets.all(15),
              child: Image.network(
                item.image,
                color: const Color(0xFFF9B233),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  log('Image load error: ${item.image} | $error');
                  return const Icon(
                    Icons.broken_image,
                    size: 30,
                    color: Colors.grey,
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.translatedTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// import 'dart:convert';
// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:http/http.dart' as http;
//
// import '../Helper/TranslationHelper.dart';
// import '../game/DigitBasedBoard/DigitBasedBoardScreen.dart';
// import '../game/Jodi/JodiBidScreen.dart';
// import '../game/Jodi/JodiBulkScreen.dart';
// import '../game/Jodi/group_jodi_screen.dart';
// import '../game/OddEvenBoard/OddEvenBoardScreen.dart';
// import '../game/Panna/SinglePanna/SinglePanna.dart';
// import '../game/Panna/SinglePanna/SinglePannaBulk.dart';
// import '../game/PannelGroup/PannelGroup.dart';
// import '../game/RedBracket/RedBracketScreen.dart';
// import '../game/SPDPTPScreen/ChoiceSpDpTpBoardScreen.dart';
// import '../game/SPDPTPScreen/DPMotors.dart';
// import '../game/SPDPTPScreen/SPMotors.dart';
// import '../game/SPDPTPScreen/SpDpTpBoardScreen.dart';
// import '../game/SPDPTPScreen/TPMotorScreen.dart';
// import '../game/Sangam/FullSangamBoardScreen.dart';
// import '../game/Sangam/HalfSangamABoardScreen.dart';
// import '../game/Sangam/HalfSangamBBoardScreen.dart';
// import '../game/SingleDigitBetScreen/SingleDigitBetScreen.dart';
// import '../game/SingleDigitBetScreen/SingleDigitsBulkScreen.dart';
// import '../game/TwoDigitPanel/TwoDigitPanel.dart';
//
// class JackpotBidType {
//   final int id;
//   final String title;
//   final String image;
//   final String type;
//   String translatedTitle; // This will hold the translated title
//   final bool sessionSelection;
//   final bool digitJodiStatus;
//
//   JackpotBidType({
//     required this.id,
//     required this.title,
//     required this.image,
//     required this.type,
//     required this.sessionSelection,
//     required this.digitJodiStatus,
//     this.translatedTitle = '', // Initialize with empty string
//   });
//
//   factory JackpotBidType.fromJson(Map<String, dynamic> json) {
//     return JackpotBidType(
//       id: json['id'] ?? 0,
//       title: json['name'] ?? '',
//       image: json['image'] ?? '',
//       type: json['type'] ?? '',
//       sessionSelection: json['sessionSelection'] ?? false,
//       digitJodiStatus: json['digitJodiStatus'] ?? false,
//       translatedTitle: json['translatedTitle'] ?? '',
//     );
//   }
//
//   // Method to update translated title after fetching
//   void updateTranslatedTitle(String newTitle) {
//     translatedTitle = newTitle;
//   }
// }
//
// class JackpotJodiOptionsScreen extends StatefulWidget {
//   final String
//   gameTime; // This is actually the game title like "Jackpot Time 1"
//   final int gameId;
//   final String title;
//   final bool digitJodiStatus;
//   final bool sessionSelection;
//
//   const JackpotJodiOptionsScreen({
//     super.key,
//     required this.gameTime,
//     required this.gameId,
//     required this.title,
//     required this.digitJodiStatus,
//     required this.sessionSelection,
//   });
//
//   @override
//   State<JackpotJodiOptionsScreen> createState() =>
//       _JackpotJodiOptionsScreenState();
// }
//
// class _JackpotJodiOptionsScreenState extends State<JackpotJodiOptionsScreen> {
//   List<JackpotBidType> options = [];
//   bool isLoading = true;
//
//   final GetStorage _storage = GetStorage();
//   late String _currentLanguageCode; // Renamed for clarity
//   int _walletBalance = 0; // Renamed for clarity and private
//
//   // In-memory cache for translations within this screen's scope
//   final Map<String, String> _translationCache = {};
//
//   // Futures for dynamically translated texts
//   Future<String>? _translatedWalletTextFuture;
//   Future<String>? _translatedNetworkErrorTextFuture;
//   Future<String>? _translatedNoBidTypesTextFuture;
//   Future<String>? _translatedMarketClosedTitleFuture;
//   Future<String>? _translatedOkTextFuture;
//   Future<String>? _translatedMarketClosedContentPrefixFuture;
//   Future<String>? _translatedMarketClosedContentSuffixFuture;
//   Future<String>? _translatedAuthenticationErrorTextFuture;
//   Future<String>? _translatedFailedToLoadTextFuture;
//   Future<String>? _translatedNoScreenConfiguredTextFuture;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _currentLanguageCode = _storage.read('selectedLanguage') ?? 'en';
//     _loadWalletBalance(); // Initial load of wallet balance
//
//     _preTranslateFixedTexts(); // Pre-translate fixed texts
//
//     // Listen for language changes
//     _storage.listenKey('selectedLanguage', (value) {
//       if (value != null && value is String) {
//         if (value != _currentLanguageCode) {
//           setState(() {
//             _currentLanguageCode = value;
//             _translationCache.clear(); // Clear cache on language change
//             _preTranslateFixedTexts(); // Re-translate fixed texts
//             // Re-fetch and re-translate all options
//             fetchJackpotBidTypes();
//           });
//         }
//       }
//     });
//
//     // Listen for wallet balance changes
//     _storage.listenKey('walletBalance', (value) {
//       if (mounted) {
//         // Ensure widget is still mounted before setState
//         setState(() {
//           _loadWalletBalance(); // Reload wallet balance on change
//         });
//       }
//     });
//
//     fetchJackpotBidTypes(); // Initial fetch
//   }
//
//   // New: Pre-translate fixed strings used in the UI
//   void _preTranslateFixedTexts() {
//     _translatedWalletTextFuture = _getTranslatedText('Wallet');
//     _translatedNetworkErrorTextFuture = _getTranslatedText(
//       'Network error. Please try again later.',
//     );
//     _translatedNoBidTypesTextFuture = _getTranslatedText(
//       'No jackpot bid types available or failed to load.',
//     );
//     _translatedMarketClosedTitleFuture = _getTranslatedText('Market Closed');
//     _translatedOkTextFuture = _getTranslatedText('OK');
//     _translatedMarketClosedContentPrefixFuture = _getTranslatedText(
//       'The market for',
//     );
//     _translatedMarketClosedContentSuffixFuture = _getTranslatedText(
//       'is currently closed.',
//     );
//     _translatedAuthenticationErrorTextFuture = _getTranslatedText(
//       'Authentication error: Please log in again.',
//     );
//     _translatedFailedToLoadTextFuture = _getTranslatedText(
//       'Failed to load jackpot bid types:',
//     );
//     _translatedNoScreenConfiguredTextFuture = _getTranslatedText(
//       'No screen configured for game type:',
//     );
//   }
//
//   void _loadWalletBalance() {
//     final storedWallet = _storage.read('walletBalance');
//     if (storedWallet is int) {
//       _walletBalance = storedWallet;
//     } else if (storedWallet is String) {
//       _walletBalance = int.tryParse(storedWallet) ?? 0;
//     } else {
//       _walletBalance = 0;
//     }
//   }
//
//   // Helper method to get translated text, leveraging cache
//   Future<String> _getTranslatedText(String text) async {
//     // If target language is English, no need to translate
//     if (_currentLanguageCode == 'en') {
//       return text;
//     }
//
//     final cacheKey = '$text:$_currentLanguageCode';
//     if (_translationCache.containsKey(cacheKey)) {
//       return _translationCache[cacheKey]!;
//     }
//
//     // Check GetStorage for cached translation (persistent cache)
//     final storedTranslation = _storage.read('translation_$cacheKey');
//     if (storedTranslation != null && storedTranslation is String) {
//       _translationCache[cacheKey] = storedTranslation;
//       return storedTranslation;
//     }
//
//     try {
//       final translated = await TranslationHelper.translate(
//         text,
//         _currentLanguageCode,
//       );
//       if (translated.isNotEmpty) {
//         _translationCache[cacheKey] = translated;
//         _storage.write(
//           'translation_$cacheKey',
//           translated,
//         ); // Store in GetStorage
//         return translated;
//       } else {
//         log(
//           'TranslationHelper returned empty text for "$text". Falling back to original.',
//         );
//         return text;
//       }
//     } catch (e) {
//       log('Error translating "$text": $e. Falling back to original text.');
//       return text;
//     }
//   }
//
//   Future<void> fetchJackpotBidTypes() async {
//     setState(() {
//       isLoading = true; // Set loading state to true before fetching
//     });
//
//     final url = Uri.parse('https://sara777.win/api/v1/jackpot-game-bid-type');
//     String? bearerToken = _storage.read("accessToken"); // Use _storage instance
//
//     if (bearerToken == null || bearerToken.isEmpty) {
//       log('Error: Access token not found or is empty.');
//       if (mounted) {
//         setState(() {
//           isLoading = false;
//         });
//       }
//       // Optionally show an error message to the user
//       final String authErrorMsg =
//           await _translatedAuthenticationErrorTextFuture ??
//           'Authentication error: Please log in again.';
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text(authErrorMsg)));
//       return;
//     }
//
//     final headers = {
//       'deviceId': 'qwerr',
//       'deviceName': 'sm2233',
//       'accessStatus': '1',
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $bearerToken',
//     };
//
//     try {
//       final response = await http.get(url, headers: headers);
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         log('Full Jackpot API Response Data: ${jsonEncode(data)}');
//
//         if (data['status'] == true && data['info'] != null) {
//           final List<dynamic> list = data['info'];
//           List<JackpotBidType> fetchedOptions = [];
//
//           for (var itemJson in list) {
//             try {
//               var option = JackpotBidType.fromJson(itemJson);
//               fetchedOptions.add(option);
//             } catch (e) {
//               log(
//                 'Error parsing JackpotBidType from JSON item: $itemJson. Error: $e',
//               );
//             }
//           }
//
//           // Trigger translation for all fetched items
//           List<JackpotBidType> translatedOptions = await Future.wait(
//             fetchedOptions.map((option) async {
//               option.updateTranslatedTitle(
//                 await _getTranslatedText(option.title),
//               );
//               return option;
//             }).toList(),
//           );
//
//           if (mounted) {
//             setState(() {
//               options = translatedOptions;
//               isLoading = false;
//             });
//           }
//         } else {
//           log(
//             "Jackpot API Response Status Not True or Info Missing: ${json.encode(data)}",
//           );
//           if (mounted) {
//             setState(() {
//               options =
//                   []; // Clear options if API status is false or info is missing
//               isLoading = false;
//             });
//           }
//           final String noBidTypesMsg =
//               await _translatedNoBidTypesTextFuture ??
//               'No jackpot bid types available or failed to load.';
//           ScaffoldMessenger.of(
//             context,
//           ).showSnackBar(SnackBar(content: Text(noBidTypesMsg)));
//         }
//       } else {
//         log("Jackpot API Error: ${response.statusCode}, ${response.body}");
//         if (mounted) {
//           setState(() => isLoading = false);
//         }
//         final String failedToLoadMsg =
//             await _translatedFailedToLoadTextFuture ??
//             'Failed to load jackpot bid types:';
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('$failedToLoadMsg ${response.statusCode}')),
//         );
//       }
//     } catch (e) {
//       log("Exception during Jackpot API call: $e");
//       if (mounted) {
//         setState(() => isLoading = false);
//       }
//       final String networkErrorMsg =
//           await _translatedNetworkErrorTextFuture ??
//           'Network error. Please try again later.';
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text(networkErrorMsg)));
//     }
//   }
//
//   // --- New method to show the market closed dialog ---
//   Future<void> _showMarketClosedDialog(String gameName) async {
//     final translatedTitle =
//         await _translatedMarketClosedTitleFuture ?? 'Market Closed';
//     final translatedOk = await _translatedOkTextFuture ?? 'OK';
//     final translatedContentPrefix =
//         await _translatedMarketClosedContentPrefixFuture ?? 'The market for';
//     final translatedContentSuffix =
//         await _translatedMarketClosedContentSuffixFuture ??
//         'is currently closed.';
//
//     // Construct the full message using translated parts and the already translated gameName
//     final String fullyTranslatedContent =
//         '$translatedContentPrefix $gameName $translatedContentSuffix';
//
//     return showDialog<void>(
//       context: context,
//       barrierDismissible: false, // User must tap a button
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: Text(translatedTitle),
//           content: Text(fullyTranslatedContent),
//           actions: <Widget>[
//             TextButton(
//               child: Text(translatedOk),
//               onPressed: () {
//                 Navigator.of(dialogContext).pop(); // Dismiss dialog
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade300,
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         backgroundColor: Colors.grey.shade300,
//         elevation: 0,
//         title: Row(
//           children: [
//             GestureDetector(
//               onTap: () => Navigator.pop(context),
//               child: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
//             ),
//             const SizedBox(width: 8),
//             Text(
//               widget.title, // This is already the dynamic game time/title
//               style: const TextStyle(
//                 color: Colors.black,
//                 fontSize: 18,
//                 fontWeight: FontWeight.w200,
//               ),
//             ),
//             const Spacer(),
//             Image.asset(
//               "assets/images/wallet_icon.png",
//               color: Colors.black,
//               width: 24,
//               height: 24,
//             ),
//             const SizedBox(width: 4),
//             Text(
//               "₹ $_walletBalance", // Use the private wallet balance
//               style: const TextStyle(color: Colors.black, fontSize: 16),
//             ),
//           ],
//         ),
//       ),
//       body: SafeArea(
//         child: isLoading
//             ? const Center(
//                 child: CircularProgressIndicator(color: Colors.orange),
//               )
//             : options.isEmpty
//             ? Center(
//                 child: FutureBuilder<String>(
//                   future: _translatedNoBidTypesTextFuture,
//                   builder: (context, snapshot) {
//                     return Text(
//                       snapshot.data ??
//                           'No jackpot bid types available or failed to load.',
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         color: Colors.black54,
//                       ),
//                     );
//                   },
//                 ),
//               )
//             : Padding(
//                 padding: const EdgeInsets.all(40),
//                 child: GridView.count(
//                   crossAxisCount: 2,
//                   mainAxisSpacing: 16,
//                   crossAxisSpacing: 16,
//                   children: options.map((item) => _optionItem(item)).toList(),
//                 ),
//               ),
//       ),
//     );
//   }
//
//   Widget _optionItem(JackpotBidType item) {
//     // Dynamically translate "Jackpot Game" or use a static one if confirmed not to change
//     // For consistency with GameMenuScreen, it's better to treat `widget.gameTime`
//     // (which is like the parent title, e.g., "Jackpot Time 1") as the screenTitle.
//     // The individual bid type's title (item.translatedTitle) then becomes the sub-title.
//     final String parentScreenTitle =
//         widget.gameTime; // Use the gameTime passed to this screen
//
//     return InkWell(
//       onTap: () async {
//         // Make onTap async
//         log('Tapped on: ${item.translatedTitle} (Original: ${item.title})');
//
//         // Use item.type.toLowerCase().trim() for robust comparison
//         switch (item.type.toLowerCase().trim()) {
//           case 'singledigits':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => SingleDigitBetScreen(
//                   title: widget.title + ", " + item.title,
//                   gameId: item.id,
//                   gameName: item.title,
//                   gameCategoryType: item.type,
//                   selectionStatus: item.sessionSelection,
//                 ),
//               ),
//             );
//             break;
//
//           case 'spmotor':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => SPMotorsBetScreen(
//                   title: widget.title + ", " + item.title,
//                   gameId: item.id,
//                   gameName: item.title,
//                   gameCategoryType: item.type,
//                 ),
//               ),
//             );
//             break;
//
//           case 'dpmotor':
//           case 'doublepana': // Assuming doublepana also goes to DPMotorsBetScreen
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => DPMotorsBetScreen(
//                   title: widget.title + ", " + item.title,
//                   gameId: item.id,
//                   gameName: item.title,
//                   gameCategoryType: item.type,
//                 ),
//               ),
//             );
//             break;
//
//           case 'triplepana':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => TPMotorsBetScreen(
//                   title: widget.title + ", " + item.title,
//                   gameId: item.id,
//                   gameName: item.title,
//                   gameCategoryType: item.type,
//                 ),
//               ),
//             );
//             break;
//
//           case 'singledigitsbulk':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => SingleDigitsBulkScreen(
//                   title: widget.title + ", " + item.title,
//                   gameName: item.title,
//                   gameType: item.type,
//                   gameId: item.id,
//                   selectionStatus: item.sessionSelection,
//                 ),
//               ),
//             );
//             break;
//
//           case 'singlepanabulk':
//           case 'doublepanabulk': // Renamed from 'doublePanaBulk' to match consistency with 'singlePanaBulk'
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => SinglePannaBulkBoardScreen(
//                   title: widget.title + ", " + item.title,
//                   gameId: item.id,
//                   gameType: item.type,
//                   gameName: item.title,
//                 ),
//               ),
//             );
//             break;
//
//           case 'jodi':
//           case 'groupdigit':
//           case 'twodigitpanna': // This case should be handled by TwoDigitPanelScreen, not JodiBidScreen based on previous code.
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => JodiBidScreen(
//                   title: widget.title + ", " + item.title,
//                   gameType: item.type,
//                   gameId: item.id,
//                   gameName: item.title,
//                 ),
//               ),
//             );
//             break;
//           case 'panelgroup': // This also has a dedicated screen
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => PanelGroupScreen(
//                   title: widget.title + ", " + item.title,
//                   gameId: item.id,
//                   gameName: item.title,
//                   gameCategoryType: item.type,
//                 ),
//               ),
//             );
//             break;
//
//           case 'jodibulk':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => JodiBulkScreen(
//                   screenTitle: widget.title + ", " + item.title,
//                   gameType: item.type,
//                   gameId: item.id,
//                   gameName: item.title,
//                 ),
//               ),
//             );
//             break;
//
//           case 'singlepana':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => SinglePannaScreen(
//                   title: widget.title + ", " + item.title,
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           case 'twodigitspanel':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => TwoDigitPanelScreen(
//                   title: widget.title + ", " + item.title,
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           case 'groupjodi':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => GroupJodiScreen(
//                   title: widget.title + ", " + item.title,
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           case 'digitbasedjodi':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => DigitBasedBoardScreen(
//                   title: widget.title + ", " + item.title,
//                   gameId: item.id.toString(), // Ensure String
//                   gameType: item.type,
//                   gameName: item.title,
//                 ),
//               ),
//             );
//             break;
//
//           case 'oddeven':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => OddEvenBoardScreen(
//                   title: widget.title + ", " + item.title,
//                   gameType: item.type,
//                   gameId: item.id,
//                 ),
//               ),
//             );
//             break;
//
//           case 'choicepannaspdp':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => ChoiceSpDpTpBoardScreen(
//                   screenTitle: widget.title + ", " + item.title,
//                   gameId: item.id,
//                   gameType: item.type,
//                   gameName: widget.title + ", " + item.title,
//                 ),
//               ),
//             );
//             break;
//
//           case 'spdptp':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => SpDpTpBoardScreen(
//                   screenTitle: widget.title + ", " + item.title,
//                   gameId: item.id,
//                   gameType: item.type,
//                 ),
//               ),
//             );
//             break;
//
//           case 'redbracket':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => RedBracketBoardScreen(
//                   screenTitle: widget.title + ", " + item.title,
//                   gameId: item.id,
//                   gameType: item.type,
//                 ),
//               ),
//             );
//             break;
//
//           case 'halfsangama':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => HalfSangamABoardScreen(
//                   screenTitle: widget.title + ", " + item.title,
//                   gameId: item.id,
//                   gameType: item.type,
//                   gameName: item.title,
//                 ),
//               ),
//             );
//             break;
//
//           case 'halfsangamb':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => HalfSangamBBoardScreen(
//                   screenTitle: widget.title + ", " + item.title,
//                   gameId: item.id,
//                   gameType: item.type,
//                   gameName: item.title,
//                 ),
//               ),
//             );
//             break;
//
//           case 'fullsangam':
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => FullSangamBoardScreen(
//                   screenTitle: widget.title + ", " + item.title,
//                   gameId: item.id,
//                   gameType: item.type,
//                 ),
//               ),
//             );
//             break;
//
//           default:
//             final String noScreenConfiguredMsg =
//                 await _translatedNoScreenConfiguredTextFuture ??
//                 'No screen configured for game type:';
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text(
//                   "$noScreenConfiguredMsg '${item.type}' (Original: '${item.title}')",
//                 ),
//               ),
//             );
//             log(
//               "Unhandled game type: ${item.type} (Original title: ${item.title})",
//             );
//         }
//       },
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.grey.shade300,
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 6,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               width: 80,
//               height: 80,
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 shape: BoxShape.circle,
//                 border: Border.all(color: Colors.grey.shade300),
//               ),
//               child: Image.network(
//                 item.image,
//                 width: 40,
//                 height: 40,
//                 fit: BoxFit.contain,
//                 errorBuilder: (context, error, stackTrace) {
//                   log('Image load error: ${item.image} | $error');
//                   return const Icon(
//                     Icons.broken_image,
//                     size: 40,
//                     color: Colors.orange,
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 12),
//             Text(
//               item.translatedTitle,
//               textAlign: TextAlign.center,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black87,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
