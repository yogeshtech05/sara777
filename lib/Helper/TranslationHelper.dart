import 'package:translator/translator.dart';

class TranslationHelper {
  static final GoogleTranslator translator = GoogleTranslator();

  static Future<String> translate(String text, String toLangCode) async {
    final translation = await translator.translate(text, to: toLangCode);
    return translation.text;
  }
}