import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';
import 'l10n.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  try {
    final prefs = await SharedPreferences.getInstance();
    L10n.preference.value = prefs.getString('language');
  } catch (_) {}
  runApp(const ShadeXApp());
}

class ShadeXApp extends StatelessWidget {
  const ShadeXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: L10n.preference,
      builder: (context, _, __) => MaterialApp(
        title: 'ShadeX VPN',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: L10n.locale,
        supportedLocales: L10n.codes.map(Locale.new).toList(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Çok büyük sistem yazı boyutunda düzen bozulmasın.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.15,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const HomePage(),
      ),
    );
  }
}
