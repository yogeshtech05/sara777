import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/KingStarline&Jackpot/games/StarlineDoublePana.dart';
import 'package:new_sara/KingStarline&Jackpot/games/StarlineSPDPTPScreen.dart';
import 'package:new_sara/KingStarline&Jackpot/games/StarlineSPMotorsScreen.dart';
import 'package:new_sara/KingStarline&Jackpot/games/StarlineSinglePana.dart';

import '../Helper/TranslationHelper.dart';
import '../Helper/UserController.dart';
import '../ulits/Constents.dart';
import 'games/StarlineDPMotorsScreen.dart';
import 'games/StarlineOddEvenBoardScreen.dart';
import 'games/StarlineSingleDigit.dart';
import 'games/StarlineTriplePana.dart';

// Class to model a bid type option for King Starline games.
class KingStarlineBidType {
  final int id;
  final String title;
  final String image;
  final String type;
  final bool digitPannaStatus;
  String translatedTitle;

  KingStarlineBidType({
    required this.id,
    required this.title,
    required this.image,
    required this.type,
    required this.digitPannaStatus,
    this.translatedTitle = '',
  });

  factory KingStarlineBidType.fromJson(Map<String, dynamic> json) {
    return KingStarlineBidType(
      id: json['id'] ?? 0,
      title: json['name'] ?? '',
      image: json['image'] ?? '',
      type: json['type'] ?? '',
      digitPannaStatus: json['digitPannaStatus'] ?? false,
    );
  }

  void updateTranslatedTitle(String newTitle) {
    translatedTitle = newTitle;
  }
}

// The main screen for displaying King Starline game options.
class KingStarlineOptionScreen extends StatefulWidget {
  final String gameTime;
  final String title;
  final dynamic starlineGameId;
  final bool paanaStatus;
  final String registeredId;

  const KingStarlineOptionScreen({
    super.key,
    required this.gameTime,
    required this.title,
    required this.starlineGameId,
    required this.paanaStatus,
    required this.registeredId,
  });

  @override
  State<KingStarlineOptionScreen> createState() =>
      _KingStarlineOptionScreenState();
}

class _KingStarlineOptionScreenState extends State<KingStarlineOptionScreen> {
  List<KingStarlineBidType> _options = [];
  bool _isLoading = true;
  final GetStorage _storage = GetStorage();
  final UserController userController = Get.put(UserController());

  late String _currentLanguageCode;
  int _walletBalance = 0;

  final Map<String, String> _translationCache = {};

  Future<String>? _translatedWalletTextFuture;
  Future<String>? _translatedNetworkErrorTextFuture;
  Future<String>? _translatedNoBidTypesTextFuture;
  Future<String>? _translatedAuthenticationErrorTextFuture;
  Future<String>? _translatedFailedToLoadTextFuture;
  Future<String>? _translatedNoScreenConfiguredTextFuture;

  @override
  void initState() {
    super.initState();
    _currentLanguageCode = _storage.read('selectedLanguage') ?? 'en';

    fetchKingStarlineBidTypes();
    _preTranslateFixedTexts();
    double walletBalance = double.parse(userController.walletBalance.value);
    _walletBalance = walletBalance.toInt();

    _storage.listenKey('selectedLanguage', (value) {
      if (value != null && value is String && value != _currentLanguageCode) {
        _currentLanguageCode = value;
        _translationCache.clear();
        _preTranslateFixedTexts();
        fetchKingStarlineBidTypes();
      }
    });
  }

  void _preTranslateFixedTexts() {
    _translatedWalletTextFuture = _getTranslatedText('Wallet');
    _translatedNetworkErrorTextFuture = _getTranslatedText(
      'Network error. Please try again later.',
    );
    _translatedNoBidTypesTextFuture = _getTranslatedText(
      'No Starline games available.\nPlease try again later.',
    );
    _translatedAuthenticationErrorTextFuture = _getTranslatedText(
      'Authentication error: Please log in again.',
    );
    _translatedFailedToLoadTextFuture = _getTranslatedText(
      'Failed to load starline bid types:',
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

  Future<void> fetchKingStarlineBidTypes() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _options = [];
    });

    final url = Uri.parse('${Constant.apiEndpoint}starline-game-bid-type');
    String? bearerToken = _storage.read("accessToken");

    if (bearerToken == null || bearerToken.isEmpty) {
      log('Error: Access token not found or is empty. Cannot fetch bid types.');
      if (mounted) {
        setState(() => _isLoading = false);
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        log('Full KingStarline API Response Data: ${jsonEncode(data)}');

        if (data['status'] == true && data['info'] != null) {
          final List<dynamic> list = data['info'];
          List<KingStarlineBidType> fetchedOptions = [];

          for (var itemJson in list) {
            try {
              var option = KingStarlineBidType.fromJson(itemJson);
              fetchedOptions.add(option);
            } catch (e) {
              log(
                'Error parsing KingStarlineBidType from JSON item: $itemJson. Error: $e',
              );
            }
          }
          List<Future<void>> translationFutures = [];
          for (var option in fetchedOptions) {
            translationFutures.add(
              _getTranslatedText(option.title).then((translatedName) {
                option.updateTranslatedTitle(translatedName);
              }),
            );
          }
          await Future.wait(translationFutures);
          if (mounted) {
            setState(() {
              _options = fetchedOptions;
              _isLoading = false;
            });
          }
        } else {
          log(
            "KingStarline API Response Status Not True or Info Missing: ${json.encode(data)}",
          );
          if (mounted) {
            setState(() => _isLoading = false);
          }
          final String noBidTypesMsg =
              await _translatedNoBidTypesTextFuture ??
              'No Starline games available.\nPlease try again later.';
          _showSnackBar(noBidTypesMsg);
        }
      } else {
        log("KingStarline API Error: ${response.statusCode}, ${response.body}");
        if (mounted) {
          setState(() => _isLoading = false);
        }
        final String failedToLoadMsg =
            await _translatedFailedToLoadTextFuture ??
            'Failed to load starline bid types:';
        _showSnackBar('$failedToLoadMsg ${response.statusCode}');
      }
    } catch (e) {
      log("Exception during KingStarline API call: $e");
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
    final String appBarTitle = widget.title;

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
              appBarTitle,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
            FutureBuilder<String>(
              future: _translatedWalletTextFuture,
              builder: (context, snapshot) {
                return Text(
                  '₹ ${userController.walletBalance.value}',
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                );
              },
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
                          'No Starline games available.\nPlease try again later.',
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

  Widget _optionItem(KingStarlineBidType item) {
    final String parentScreenTitle = widget.title;
    final String nextScreenTitle =
        "$parentScreenTitle, ${item.translatedTitle}";

    return InkWell(
      onTap: () async {
        log(
          'Tapped on: ${item.translatedTitle} (Original Title: ${item.title}, Type: ${item.type})',
        );
        final gameType = item.type.toLowerCase().trim();
        Widget? destinationScreen;

        switch (gameType) {
          case 'singledigits':
            destinationScreen = StarlineSingleDigitBetScreen(
              title: nextScreenTitle,
              gameId: widget.starlineGameId,
              gameName: item.title,
              gameCategoryType: item.type,
              selectionStatus: item.digitPannaStatus,
            );
            break;

          case 'oddeven':
            destinationScreen = StarlineOddEvenBoardScreen(
              title: nextScreenTitle,
              gameId: widget.starlineGameId,
              gameName: item.title,
              gameType: item.type,
              selectionStatus: true,
            );
            break;

          case 'singlepana':
            destinationScreen = StarlineSinglePannaScreen(
              title: nextScreenTitle,
              gameId: widget.starlineGameId,
              gameName: item.title,
              gameType: item.type,
              selectionStatus: true,
            );
            break;

          case 'doublepana':
            destinationScreen = StarlineDoublePanaBetScreen(
              title: nextScreenTitle,
              gameId: widget.starlineGameId,
              gameName: item.title,
              gameCategoryType: item.type,
              selectionStatus: true,
            );
            break;

          case 'triplepana':
            destinationScreen = StarlineTPMotorsScreen(
              title: nextScreenTitle,
              gameId: widget.starlineGameId,
              gameName: item.title,
              selectionStatus: true,
              gameCategoryType: item.type,
            );
            break;

          case 'spdptp':
            destinationScreen = StarlineSpDpTpScreen(
              screenTitle: nextScreenTitle,
              gameId: widget.starlineGameId,
              gameType: item.type,
            );
            break;

          case 'spmotor':
            destinationScreen = StarlineSPMotorsScreen(
              title: nextScreenTitle,
              gameId: widget.starlineGameId,
              gameName: item.title,
              gameCategoryType: item.type,
            );
            break;

          case 'dpmotor':
            destinationScreen = StarlineDPMotorsScreen(
              title: nextScreenTitle,
              gameId: widget.starlineGameId,
              gameName: item.title,
              gameCategoryType: item.type,
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
                  log(
                    'Image load error for ${item.title}: ${item.image} | $error',
                  );
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
