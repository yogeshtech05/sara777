import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

import '../Helper/TranslationHelper.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GetStorage storage = GetStorage();

  bool mainNotif = true;
  bool gameNotif = true;
  bool starlineNotif = true;
  bool jackpotNotif = true;
  String selectedLang = 'en';

  final Map<String, String> languageMap = {
    'English': 'en',
    'हिंदी': 'hi',
    'తెలుగు': 'te',
    'ಕನ್ನಡ': 'kn',
  };

  Map<String, String> uiStrings = {
    "Notification Settings": "Notification Settings",
    "Main Notification": "Main Notification",
    "Game Notification": "Game Notification",
    "King Starline Notification": "King Starline Notification",
    "King Jackpot Notification": "King Jackpot Notification",
    "Language Settings": "Language Settings",
  };

  @override
  void initState() {
    super.initState();
    mainNotif = storage.read('main_notif') ?? true;
    gameNotif = storage.read('game_notif') ?? true;
    starlineNotif = storage.read('starline_notif') ?? true;
    jackpotNotif = storage.read('jackpot_notif') ?? true;
    selectedLang = storage.read('language') ?? 'en';

    _translateUI(); // initial load
  }

  Future<void> _translateUI() async {
    final lang = selectedLang;

    Future<String> tr(String text) async {
      if (lang == 'en') return text;
      return await TranslationHelper.translate(text, lang);
    }

    final updatedMap = <String, String>{};
    for (String key in uiStrings.keys) {
      updatedMap[key] = await tr(key);
    }

    if (mounted) {
      setState(() {
        uiStrings = updatedMap;
      });
    }
  }

  void _saveNotification(String key, bool value) {
    storage.write(key, value);
  }

  void _saveLanguage(String langCode) async {
    storage.write('language', langCode);
    setState(() {
      selectedLang = langCode;
    });
    await _translateUI(); // live update
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(uiStrings["Notification Settings"] ?? ""),
                _buildSwitchTile(
                  uiStrings["Main Notification"] ?? "",
                  mainNotif,
                  (val) {
                    setState(() => mainNotif = val);
                    _saveNotification('main_notif', val);
                  },
                ),
                _buildSwitchTile(
                  uiStrings["Game Notification"] ?? "",
                  gameNotif,
                  (val) {
                    setState(() => gameNotif = val);
                    _saveNotification('game_notif', val);
                  },
                ),
                _buildSwitchTile(
                  uiStrings["King Starline Notification"] ?? "",
                  starlineNotif,
                  (val) {
                    setState(() => starlineNotif = val);
                    _saveNotification('starline_notif', val);
                  },
                ),
                _buildSwitchTile(
                  uiStrings["King Jackpot Notification"] ?? "",
                  jackpotNotif,
                  (val) {
                    setState(() => jackpotNotif = val);
                    _saveNotification('jackpot_notif', val);
                  },
                ),
                const SizedBox(height: 20),
                _buildSectionHeader(uiStrings["Language Settings"] ?? ""),
                ...languageMap.entries.map(
                  (entry) => _buildRadioTile(
                    entry.key,
                    selectedLang,
                    (val) => _saveLanguage(val!),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(12), // <-- corner radius added here
      ),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.teal,
    );
  }

  Widget _buildRadioTile(
    String title,
    String groupVal,
    Function(String?) onChanged,
  ) {
    return RadioListTile<String>(
      value: languageMap[title]!,
      groupValue: groupVal,
      onChanged: onChanged,
      activeColor: Colors.teal,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(title),
    );
  }
}
