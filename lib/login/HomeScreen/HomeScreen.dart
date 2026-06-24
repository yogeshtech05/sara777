
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/Bids/MyBidsPage.dart';
import 'package:new_sara/ChartScreen/ChartScreen.dart';
import 'package:new_sara/Helper/Toast.dart';
import 'package:new_sara/Helper/UserController.dart';
import 'package:new_sara/Navigation/FundsFragmentContainer.dart';
import 'package:new_sara/Notice/WithdrawInfoScreen.dart';
import 'package:new_sara/Notification/NotificationScreen.dart';
import 'package:new_sara/Passbook/PassbookPage.dart';
import 'package:new_sara/SetMPIN/SetNewPinScreen.dart';
import 'package:new_sara/SettingsScreen/SettingsScreen.dart';
import 'package:new_sara/Support/ChatSupport/ChatScreenNew.dart';
import 'package:new_sara/Support/SupportPage.dart';
import 'package:new_sara/components/AppName.dart';
import 'package:new_sara/game/gameRates/GameRateScreen.dart';
import 'package:new_sara/ulits/ColorsR.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:new_sara/Support/ChatSupport/ChatService.dart';
import 'dart:async';


import '../../Video/LanguageSelectionScreen.dart';
import '../LoginWithMpinScreen.dart' show LoginWithMpinScreen;
import 'HomePage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Safe find-or-put (in case main.dart missed registering once)
  late final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController(), permanent: true);

  final GetStorage storage = GetStorage();
  
  final ChatService _chatService = ChatService();
  RxInt unreadChatCount = 0.obs;
  Timer? _chatPollingTimer;

  int _selectedIndex = 2; // Default: Home tab

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    log('HomeScreen sees UserController hash: ${userController.hashCode}');

    // ✅ First fill user → then others (avoid race)
    _bootstrapLoad();

    storage.write('isLoggedIn', true);

    // Optional: start polling so wallet/flags stay fresh
    userController.startLivePolling(interval: const Duration(seconds: 6));
    
    _startChatPolling();
  }

  void _startChatPolling() {
    _fetchUnreadCount();
    _chatPollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _fetchUnreadCount();
    });
  }

  Future<void> _fetchUnreadCount() async {
    if (!userController.accountStatus.value) return;
    final count = await _chatService.getUnreadCount();
    if (mounted) {
      unreadChatCount.value = count;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    userController.stopLivePolling();
    _chatPollingTimer?.cancel();
    super.dispose();
  }

  // App resume par light refresh
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      userController.fetchAndUpdateUserDetails();
    }
  }

  Future<void> _bootstrapLoad() async {
    try {
      // 1) Must be first (sets mobileNo, accountStatus, wallet, etc.)
      await userController.fetchAndUpdateUserDetails();

      // 2) Dependent stuff in parallel
      await Future.wait([
        userController.fetchAndUpdateFeeSettings(),
        userController.fetchAndUpdateContactDetails(),
        userController.fetchPaymentDetails(),
      ]);
    } catch (e, st) {
      log('Warm-up error: $e', stackTrace: st);
    }
  }

  // ---------- WhatsApp Helpers ----------
  String _normalizePhone(String raw, {String defaultCountryCode = '91'}) {
    var p = raw.replaceAll(RegExp(r'[^0-9]'), '');
    p = p.replaceFirst(RegExp(r'^0+'), '');
    if (p.length == 10) p = '$defaultCountryCode$p';
    return p;
  }

  /// Priority: contactWhatsapp -> contactMobile -> storage.whatsappNo -> user.mobileNo
  String? _getSupportNumber() {
    final w = userController.contactWhatsappNo.value.trim();
    if (w.isNotEmpty) return w;

    final c = userController.contactMobileNo.value.trim();
    if (c.isNotEmpty) return c;

    final s = (storage.read('whatsappNo') ?? '').toString().trim();
    if (s.isNotEmpty) return s;

    final u = userController.mobileNo.value.trim();
    if (u.isNotEmpty) return u;

    return null;
  }

  Future<void> launchWhatsAppChat({String? message}) async {
    try {
      final raw = _getSupportNumber();
      if (raw == null) {
        popToast(
          "WhatsApp number not available",
          4,
          Colors.white,
          ColorsR.appColorRed,
        );
        log("❌ WhatsApp number missing (all sources empty)");
        return;
      }

      final phone = _normalizePhone(raw);
      final encoded = (message ?? '').trim().isEmpty
          ? ''
          : Uri.encodeComponent(message!.trim());

      final nativeUri = Uri.parse(
        'whatsapp://send?phone=$phone${encoded.isNotEmpty ? '&text=$encoded' : ''}',
      );
      if (await canLaunchUrl(nativeUri)) {
        final ok = await launchUrl(
          nativeUri,
          mode: LaunchMode.externalApplication,
        );
        log(
          ok ? '✅ Launched WhatsApp (native): $nativeUri' : '❌ Failed (native)',
        );
        if (ok) return;
      }

      final webUri = Uri.parse(
        'https://wa.me/$phone${encoded.isNotEmpty ? '?text=$encoded' : ''}',
      );
      if (await canLaunchUrl(webUri)) {
        final ok = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
        log(ok ? '✅ Launched WhatsApp (web): $webUri' : '❌ Failed (web)');
        if (ok) return;
      }

      popToast(
        "Could not launch WhatsApp",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
    } catch (e, st) {
      log('❌ WhatsApp launch error: $e', stackTrace: st);
      popToast(
        "Error launching WhatsApp",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
    }
  }

  Future<void> launchTelegram() async {
    final uri = Uri.parse("https://t.me/Sara777original");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      popToast("Could not launch Telegram", 4, Colors.white, ColorsR.appColorRed);
    }
  }

  Future<void> launchWebsite() async {
    final uri = Uri.parse("https://saraa777apk.com");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      popToast("Could not launch Website", 4, Colors.white, ColorsR.appColorRed);
    }
  }

  void _showSupportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Contact Support",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.green),
                title: const Text("WhatsApp Support"),
                onTap: () {
                  Navigator.pop(context);
                  launchWhatsAppChat();
                },
              ),
              ListTile(
                leading: const Icon(Icons.telegram, color: Colors.blue),
                title: const Text("Telegram Support"),
                onTap: () {
                  Navigator.pop(context);
                  launchTelegram();
                },
              ),
              ListTile(
                leading: const Icon(Icons.language, color: Colors.orange),
                title: const Text("Official Website"),
                onTap: () {
                  Navigator.pop(context);
                  launchWebsite();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------

  List<Widget> get _screens => [
    BidScreen(), // 0
    PassbookPage(), // 1
    HomePage(), // 2 (Main Home Tab)
    FundsFragmentContainer(), // 3
    SupportPage(), // 4
    WithdrawInfoScreen(), // 5 (Notice/Rules)
    SettingsScreen(), // 6
    GameRateScreen(), // 7
    const ChatScreenNew(), // 8 (Support chat screen)
  ];

  void _onItemTapped(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() => _selectedIndex = index);
    } else {
      log("Error: Attempted to select invalid index: $index");
    }
  }

  void _navigateToNewScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _navigateToDrawerScreenAndPush(Widget screen) {
    Navigator.pop(context);
    _navigateToNewScreen(screen);
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        backgroundColor: Colors.white,
        title: const Text(
          "Really Exit?",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        content: const Text(
          "Are you sure you want to exit?",
          style: TextStyle(
            fontSize: 16,
            color: Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              "CANCEL",
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              "OK",
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 2) {
          _onItemTapped(2);
          return false;
        }
        final exit = await _showExitConfirmationDialog();
        return exit;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        drawer: _buildDrawer(),
        appBar: _buildAppBar(context),
        body: SafeArea(
          child: (_selectedIndex >= 0 && _selectedIndex < _screens.length)
              ? _screens[_selectedIndex]
              : const Center(child: Text("Error: Screen not found")),
        ),
        bottomNavigationBar: SafeArea(child: _buildBottomAppBar()),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 40,
      backgroundColor: Colors.grey.shade300,
      elevation: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            Builder(
              builder: (ctx) => SizedBox(
                width: 42,
                height: 42,
                child: IconButton(
                  icon: Image.asset(
                    "assets/images/ic_menu.png",
                    width: 24,
                    height: 24,
                    color: Colors.black,
                  ),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 150, height: 40, child: AppName()),

            const Spacer(),

            // Wallet (visible only if account active) — FULLY REACTIVE
            Obx(
              () => userController.accountStatus.value
                  ? GestureDetector(
                      onTap: () =>
                          _navigateToDrawerScreenAndPush(const PassbookPage()),
                      child: SizedBox(
                        height: 42,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Image.asset(
                              "assets/images/ic_wallet.png",
                              width: 22,
                              height: 22,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "₹${userController.walletBalance.value}",
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w200,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 12),

            // Notifications (visible only if account active)
            Obx(
              () => userController.accountStatus.value
                  ? SizedBox(
                      width: 42,
                      height: 42,
                      child: IconButton(
                        icon: Image.asset(
                          "assets/images/ic_notification.png",
                          width: 22,
                          height: 22,
                          color: Colors.black,
                        ),
                        onPressed: () =>
                            _navigateToNewScreen(const NoticeHistoryScreen()),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 45,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Obx(
                                () => Text(
                                  userController.fullName.value.isEmpty ? "User" : userController.fullName.value,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Obx(
                                () => Text(
                                  userController.mobileNoEnc.value,
                                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black87, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Items
            Expanded(
              child: Obx(
                () => ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  children: [
                    _buildDrawerItem(Icons.home_outlined, "Home", () {
                      Navigator.pop(context);
                      _onItemTapped(2);
                    }, true),
                    _buildDrawerItem(Icons.gavel, "My Bids", () {
                      Navigator.pop(context);
                      _onItemTapped(0);
                    }, userController.accountStatus.value),
                    _buildDrawerItem(Icons.lock_outline, "MPIN", () {
                      Navigator.pop(context);
                      _handleMpin();
                    }, userController.accountStatus.value),
                    _buildDrawerItem(Icons.credit_card_outlined, "Passbook", () {
                      _navigateToDrawerScreenAndPush(const PassbookPage());
                    }, userController.accountStatus.value),
                    _buildDrawerItem(Icons.chat_bubble_outline, "Chats", () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreenNew()));
                    }, userController.accountStatus.value),
                    _buildDrawerItem(Icons.account_balance_outlined, "Funds", () {
                      Navigator.pop(context);
                      _onItemTapped(3);
                    }, userController.accountStatus.value),
                    _buildDrawerItem(Icons.notifications_none, "Notification", () {
                      _navigateToDrawerScreenAndPush(const NoticeHistoryScreen());
                    }, userController.accountStatus.value),
                    _buildDrawerItem(Icons.ondemand_video, "Videos", () {
                      _navigateToDrawerScreenAndPush(const LanguageSelectionScreen());
                    }, userController.accountStatus.value),
                    _buildDrawerItem(Icons.warning_amber_rounded, "Notice Board/Rules", () {
                      _navigateToDrawerScreenAndPush(const WithdrawInfoScreen());
                    }, userController.accountStatus.value),
                    _buildDrawerItem(Icons.auto_awesome, "Game Rates", () {
                      Navigator.pop(context);
                      _onItemTapped(7);
                    }, userController.accountStatus.value),
                    _buildDrawerItem(Icons.bar_chart, "Charts", () {
                      _navigateToDrawerScreenAndPush(const ChartScreen());
                    }, userController.accountStatus.value),
                    _buildDrawerItem(Icons.lightbulb_outline, "Submit Idea", () {
                      Navigator.pop(context);
                      // TODO: Implement Submit Idea
                    }, userController.accountStatus.value),
                    _buildDrawerItem(Icons.build_outlined, "Settings", () {
                      Navigator.pop(context);
                      _onItemTapped(6);
                    }, userController.accountStatus.value),
                    _buildDrawerItem(Icons.shortcut, "Share Application", () {
                      Navigator.pop(context);
                      Share.share(
                        "I'm loving Sara 777 App\n\nDownload App now\n\nFrom:-\nhttps://saraa777apk.com",
                        subject: "Check out the Sara 777 App!",
                      );
                    }, userController.accountStatus.value),
                    _buildDrawerItem(Icons.power_settings_new, "LOGOUT", () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginWithMpinScreen()),
                      );
                    }, true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData iconData,
    String title,
    VoidCallback onTap,
    bool visible,
  ) {
    if (!visible) return const SizedBox.shrink();
    return ListTile(
      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(iconData, size: 28, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black54),
      ),
      onTap: onTap,
    );
  }

  void _handleMpin() async {
    final String mobile = userController.mobileNo.value;
    if (mobile.isEmpty) {
      log("Mobile number is not available.");
      popToast(
        "Mobile number is not available",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
      return;
    }

    log("Mobile number: $mobile");
    // Navigate directly to SetNewPinScreen without sending OTP
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SetNewPinScreen(mobile: mobile)),
    );
  }

  Widget _buildBottomAppBar() {
    return Obx(() {
      final accountStatus = userController.accountStatus.value;
      return SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(
                          "assets/images/bid_nav.png",
                          "My Bids",
                          0,
                          visible: accountStatus,
                        ),
                        _buildNavItem(
                          "assets/images/passbook.png",
                          "Passbook",
                          1,
                          visible: accountStatus,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.15),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(
                          "assets/images/funds.png",
                          "Funds",
                          3,
                          visible: accountStatus,
                        ),
                        _buildNavItem(
                          "assets/images/chat_icon.png",
                          "Support",
                          8,
                          visible: accountStatus,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Center FAB-like home button
            Positioned(
              top: 4,
              child: SizedBox(
                width: 55,
                height: 55,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _onItemTapped(2),
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.orange, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(5.0),
                        child: Icon(Icons.home_outlined, color: Colors.black, size: 30),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNavItem(
    String iconPath,
    String label,
    int index, {
    bool visible = true,
  }) {
    if (!visible) return const SizedBox.shrink();

    final isSelected = _selectedIndex == index;
    final color = isSelected ? Colors.orange.shade900 : Colors.grey.shade800;

    return GestureDetector(
      onTap: () {
        if (index == 8) {
          unreadChatCount.value = 0; // Clear badge locally right away
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreenNew()),
          );
        } else if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PassbookPage()),
          );
        } else {
          _onItemTapped(index);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Image.asset(iconPath, width: 30, height: 30, color: color),
              if (index == 8) // Chat index
                Obx(() => unreadChatCount.value > 0
                    ? Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadChatCount.value > 99
                                ? '99+'
                                : unreadChatCount.value.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : const SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
