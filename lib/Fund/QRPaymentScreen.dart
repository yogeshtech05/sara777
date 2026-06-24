// The main payment screen widget
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webview_flutter/webview_flutter.dart';

class QRPaymentScreen extends StatefulWidget {
  final String paymentLink;
  final String amount;
  const QRPaymentScreen({
    super.key,
    required this.paymentLink,
    required this.amount,
  });

  @override
  State<QRPaymentScreen> createState() => _QRPaymentScreenState();
}

class _QRPaymentScreenState extends State<QRPaymentScreen> {
  bool _isLoading = false;
  String? _error;
  final box = GetStorage();
  late final String deviceId;
  late final String deviceName;
  late final String authToken;
  late final String registerId;

  final ScreenshotController _screenshotController = ScreenshotController();

  // Webview controller
  late final WebViewController _controller;

  bool _apiCallTriggered = false;

  @override
  void initState() {
    super.initState();

    deviceId = box.read('deviceId') ?? '';
    deviceName = box.read('deviceName') ?? '';
    authToken = box.read('accessToken') ?? '';
    registerId = box.read('registerId') ?? '';

    _initializeWebView();
  }

  // ================== Deep link helpers ==================

  static const _knownDeepSchemes = <String>{
    'intent',
    'upi',
    'paytmmp',
    'paytm',
    'phonepe',
    'gpay',
    'googlepay',
    'tez',
    'amazonpay',
    'whatsapp',
    'tel',
    'mailto',
    'sms',
  };

  String? _packageForScheme(String scheme, [String? host]) {
    switch (scheme) {
      case 'paytm':
      case 'paytmmp':
        return 'com.paytm.android';
      case 'phonepe':
        return 'com.phonepe.app';
      case 'gpay':
      case 'googlepay':
      case 'tez':
        return 'com.google.android.apps.nbu.paisa.user';
      case 'whatsapp':
        return 'com.whatsapp';
    }
    return null; // generic or multiple handlers (e.g., upi)
  }

  Future<void> _openPlayStore(String package) async {
    final marketUrl = 'market://details?id=$package';
    final httpsUrl = 'https://play.google.com/store/apps/details?id=$package';

    if (await canLaunchUrlString(marketUrl)) {
      await launchUrlString(marketUrl, mode: LaunchMode.externalApplication);
    } else {
      await launchUrlString(httpsUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openExternalOrStore(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      log('launchUrl failed: $e');
    }

    // Fallback to store by mapping scheme→package
    final pkg = _packageForScheme(uri.scheme.toLowerCase(), uri.host);
    if (pkg != null) {
      await _openPlayStore(pkg);
    } else {
      // last resort: show toast/snack
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No app found to open this link')),
        );
      }
    }
  }

  /// Parse and open `intent://` URLs with fallback_url / package fallback.
  Future<void> _handleIntentUrl(Uri uri) async {
    // url_launcher can sometimes handle intent:// directly on Android 12+, but not guaranteed.
    // We do manual fallbacks: look for browser_fallback_url and/or package.
    final raw = uri.toString();

    // Try native first
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      log('intent:// launch direct failed: $e');
    }

    // Fallback URL pattern in intent:// is like: ;S.browser_fallback_url=https%3A%2F%2Fexample...
    final fallbackMatch = RegExp(
      r'browser_fallback_url=([^;]+)',
    ).firstMatch(raw);
    if (fallbackMatch != null) {
      final encoded = fallbackMatch.group(1)!;
      final decoded = Uri.decodeComponent(encoded);
      if (await canLaunchUrlString(decoded)) {
        await launchUrlString(decoded, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Package pattern: ;package=com.paytm.android;
    final pkgMatch = RegExp(r';package=([a-zA-Z0-9_.]+)').firstMatch(raw);
    if (pkgMatch != null) {
      final pkg = pkgMatch.group(1)!;
      await _openPlayStore(pkg);
      return;
    }

    // As a last resort, try mapping by scheme/host
    final pkg = _packageForScheme(uri.scheme, uri.host);
    if (pkg != null) {
      await _openPlayStore(pkg);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot handle this link')),
        );
      }
    }
  }

  // ========================================================

  // Initialize the WebViewController for webview_flutter
  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            log('WebView is loading (progress : $progress%)');
            if (mounted) {
              setState(() {
                _isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (String url) {
            log('Page started loading: $url');
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            log('Page finished loading: $url');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            log('Web resource error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;
            log('Navigation request to: $url');

            Uri? uri;
            try {
              uri = Uri.parse(url);
            } catch (_) {}

            final scheme = uri?.scheme.toLowerCase() ?? '';

            // 1) intent:// deep links (covers many UPI/wallet flows)
            if (scheme == 'intent') {
              await _handleIntentUrl(uri!);
              return NavigationDecision.prevent;
            }

            // 2) Known external schemes (UPI/wallets/telephony/email/sms/wa.me)
            if (_knownDeepSchemes.contains(scheme)) {
              await _openExternalOrStore(uri!);
              return NavigationDecision.prevent;
            }

            // 2b) wa.me phone shortcut (treated as external app)
            if (url.contains('wa.me/')) {
              final wa = Uri.parse(
                'whatsapp://send?phone=${url.split('/').last}',
              );
              await _openExternalOrStore(wa);
              return NavigationDecision.prevent;
            }

            // 3) Any non-http(s) scheme → try external open (e.g., paytmmp://, phonepe://)
            if (scheme.isNotEmpty && scheme != 'http' && scheme != 'https') {
              if (uri != null) {
                await _openExternalOrStore(uri);
                return NavigationDecision.prevent;
              }
            }

            // 4) Payment status checks on regular http(s) urls
            final lowerUrl = url.toLowerCase();

            if (lowerUrl.contains('cancel') && !_apiCallTriggered) {
              _apiCallTriggered = true;
              log('Payment cancel URL detected. Navigating back.');
              if (mounted) Navigator.of(context).pop();
              return NavigationDecision.prevent;
            }

            if (lowerUrl.contains('success') && !_apiCallTriggered) {
              _apiCallTriggered = true;
              log(
                'Payment success URL detected. Perform backend confirmation here.',
              );
              // TODO: call your API to confirm, then maybe pop or show success UI
              return NavigationDecision.prevent;
            }

            if (lowerUrl.contains('fail') && !_apiCallTriggered) {
              _apiCallTriggered = true;
              log('Payment failure URL detected.');
              // TODO: show failure UI / pop
              return NavigationDecision.prevent;
            }

            // 5) Default: allow navigation
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setOnJavaScriptAlertDialog((request) async {
        log('JavaScript Alert: ${request.message}');
      })
      ..setOnJavaScriptConfirmDialog((request) async {
        log('JavaScript Confirm: ${request.message}');
        if (request.message.toLowerCase().contains('cancel')) {
          if (mounted) Navigator.of(context).pop();
          return false;
        }
        return true;
      })
      ..loadRequest(Uri.parse(widget.paymentLink));
  }

  Future<void> saveScreen() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) {
        log("Failed to capture screenshot");
        return;
      }
      final directory = await getTemporaryDirectory();
      final imagePath =
          '${directory.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(image);

      await GallerySaver.saveImage(imageFile.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Screenshot saved to gallery")),
        );
      }
    } catch (e) {
      log("Error capturing screenshot: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save screenshot")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('QR Payment'),
        backgroundColor: Colors.grey.shade300,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Screenshot(
                    controller: _screenshotController,
                    child: WebViewWidget(controller: _controller),
                  ),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveScreen,
              child: const Text("Save QR to Gallery"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
