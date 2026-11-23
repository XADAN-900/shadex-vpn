import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home_page.dart';
import 'l10n.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ShadeXApp());
}

class ShadeXApp extends StatelessWidget {
  const ShadeXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'ShadeX VPN',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Dil telefonun diline göre seçilir; desteklenmiyorsa İngilizce.
        supportedLocales: L10n.codes.map(Locale.new).toList(),
        localeListResolutionCallback: (locales, supported) =>
            L10n.resolveList(locales),
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
    );
  }
}
