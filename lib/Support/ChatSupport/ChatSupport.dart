import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Helper/UserController.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static const Color _supportYellow = Color(0xFFFFB300);
  static const Color _supportYellowLight = Color(0xFFFFF8E1);

  late final UserController userController;
  final GetStorage box = GetStorage();

  String phoneNumber = '';
  bool hasLaunched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    userController = Get.find<UserController>();
    phoneNumber = box.read('whatsappNumber') ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchWhatsAppChat();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Close the screen when user returns from WhatsApp
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _launchWhatsAppChat() async {
    if (hasLaunched) return; // Prevent duplicate calls
    hasLaunched = true;

    if (phoneNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WhatsApp number not found.'),
            backgroundColor: _supportYellow,
          ),
        );
      }
      return;
    }

    final cleanNumber = phoneNumber.replaceAll('+', '').trim();
    log('Launching WhatsApp with number: $cleanNumber');

    final Uri whatsappUrl = Uri.parse('https://wa.me/$cleanNumber');

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp. Please install the app.'),
            backgroundColor: _supportYellow,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _supportYellowLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chat Support',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _supportYellow,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: _supportYellow),
            const SizedBox(height: 20),
            const Text(
              'Redirecting to WhatsApp...',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _launchWhatsAppChat,
              child: Text(
                'Click here if it doesn\'t open',
                style: TextStyle(color: _supportYellow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
