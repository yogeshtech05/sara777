import 'package:flutter/material.dart';

class ColorsR {
  static MaterialColor appColor = const MaterialColor(
    0xff2a0a3b,
    <int, Color>{
      50: Color(0xff2a0a3b),
      100: Color(0xff2a0a3b),
      200: Color(0xff2a0a3b),
      300: Color(0xff2a0a3b),
      400: Color(0xff2a0a3b),
      500: Color(0xff2a0a3b),
      600: Color(0xff2a0a3b),
      700: Color(0xff2a0a3b),
      800: Color(0xff2a0a3b),
      900: Color(0xff2a0a3b),
    },
  );

  static Color mycolor1light = const Color(0xff85b7f4);
  static Color mycolor2light = const Color(0xff85b7f4);

  static Color mycolor1dark = const Color(0xff0a113d);

  static Color appColorLight = const Color.fromARGB(255, 238, 246, 255);
  static Color appColorLightHalfTransparent = const Color(0x2655AE7B);
  static Color appColorDark = const Color(0xff184d34);

  static Color gradient1 = const Color(0xff78c797);
  static Color gradient2 = const Color(0xff55AE7B);

  static Color defaultPageInnerCircle = const Color(0x1A999999);
  static Color defaultPageOuterCircle = const Color(0x0d999999);

  static Color mainTextColor = const Color(0xde000000);
  static Color subTitleMainTextColor = const Color(0x94000000);

  static Color mainIconColor = Colors.white;

  static Color bgColorLight = const Color(0xfff7f7f7);
  static Color bgColorDark = const Color(0xff141A1F);

  static Color cardColorLight = const Color(0xffffffff);
  static Color cardColorDark = const Color(0xff202934);

  static Color lightThemeTextColor = const Color(0xde000000);
  static Color darkThemeTextColor = const Color(0xdeffffff);

  static Color subTitleTextColorLight = const Color(0x94000000);
  static Color subTitleTextColorDark = const Color(0x94ffffff);

  static Color grey = Colors.grey;
  static Color appGreyLight = const Color.fromARGB(255, 225, 225, 225);

  static Color appColorWhite = Colors.white;
  static Color appColorBlack = ColorsR.appColor;
  static Color appColorRed = Colors.red;
  static Color appColorGreen = Colors.green;

  // text color

  static Color textcolor = const Color(0xFF9CE6E0);

  static Color greyBox = const Color(0x0a000000);
  static Color lightGreyBox = const Color.fromARGB(9, 213, 212, 212);

  //It will be same for both theme
  static Color shimmerBaseColor = Colors.white;
  static Color shimmerHighlightColor = Colors.white;
  static Color shimmerContentColor = Colors.white;

  //Dark theme shimmer color
  static Color shimmerBaseColorDark = Colors.grey.withOpacity(0.05);
  static Color shimmerHighlightColorDark = Colors.grey.withOpacity(0.005);
  static Color shimmerContentColorDark = ColorsR.appColor;

  //Light theme shimmer color
  static Color shimmerBaseColorLight = ColorsR.appColor.withOpacity(0.05);
  static Color shimmerHighlightColorLight = ColorsR.appColor.withOpacity(0.005);
  static Color shimmerContentColorLight = Colors.white;

  static ThemeData lightTheme = ThemeData(
    primaryColor: appColor,
    brightness: Brightness.light,
    scaffoldBackgroundColor: bgColorLight,
    cardColor: cardColorLight,
    iconTheme: IconThemeData(
      color: grey,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: grey,
      iconTheme: IconThemeData(
        color: grey,
      ),
    ),
    colorScheme:
    ColorScheme.fromSwatch(primarySwatch: ColorsR.appColor).copyWith(
      surface: bgColorLight,
      brightness: Brightness.light,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    primaryColor: appColor,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgColorDark,
    cardColor: cardColorDark,
    iconTheme: IconThemeData(
      color: grey,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: grey,
      iconTheme: IconThemeData(
        color: grey,
      ),
    ),
    colorScheme:
    ColorScheme.fromSwatch(primarySwatch: ColorsR.appColor).copyWith(
      surface: bgColorDark,
      brightness: Brightness.dark,
    ),
  );
}
