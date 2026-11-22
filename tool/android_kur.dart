// `flutter create` ile üretilen android/ klasörünü VPN için ayarlar.
// Kullanım (proje kökünde): dart run tool/android_kur.dart
// Birden çok kez çalıştırmak güvenlidir.
import 'dart:io';

void main() {
  if (!Directory('android/app').existsSync()) {
    stderr.writeln('android/ klasörü yok. Önce şunu çalıştır:\n'
        '  flutter create --platforms=android --org com.shadex '
        '--project-name shadex_vpn .');
    exit(1);
  }
  _manifest();
  _appGradle();
  _rootGradle();
  _networkSecurityConfig();
  _proguard();
  _notificationResources();
  stdout.writeln('✓ Android ayarları tamam.');
}

void _manifest() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  var s = f.readAsStringSync();

  const perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.POST_NOTIFICATIONS',
  ];
  final missing = perms.where((p) => !s.contains('"$p"')).toList();
  if (missing.isNotEmpty) {
    s = s.replaceFirstMapped(RegExp(r'([ \t]*)<application'), (m) {
      final ind = m[1]!;
      final lines = missing
          .map((p) => '$ind<uses-permission android:name="$p" />\n')
          .join();
      return '$lines$ind<application';
    });
  }

  if (!s.contains('networkSecurityConfig')) {
    s = s.replaceFirst(
      '<application',
      '<application\n        android:networkSecurityConfig="@xml/network_security_config"',
    );
  }

  s = s.replaceFirst(
    RegExp(r'android:label="[^"]*"'),
    'android:label="ShadeX VPN"',
  );
  f.writeAsStringSync(s);
  stdout.writeln('  • AndroidManifest.xml');
}

void _appGradle() {
  final kts = File('android/app/build.gradle.kts');
  final isKts = kts.existsSync();
  final f = isKts ? kts : File('android/app/build.gradle');
  if (!f.existsSync()) {
    stderr.writeln('android/app/build.gradle(.kts) bulunamadı.');
    exit(1);
  }
  var s = f.readAsStringSync();

  // openvpn_flutter: yerel kütüphaneler APK'dan çıkarılmalı.
  if (!s.contains('useLegacyPackaging')) {
    s = s.replaceFirst(
      RegExp(r'^android\s*\{', multiLine: true),
      'android {\n'
      '    packaging {\n'
      '        jniLibs {\n'
      '            useLegacyPackaging = true\n'
      '        }\n'
      '    }\n',
    );
  }

  // R8 küçültmesi OpenVPN sınıflarını silmesin.
  final minifyKey = isKts ? 'isMinifyEnabled' : 'minifyEnabled';
  if (!s.contains(minifyKey)) {
    s = s.replaceFirstMapped(
      RegExp(r'^([ \t]*)signingConfig\b.*debug.*$', multiLine: true),
      (m) {
        final ind = m[1]!;
        final extra = isKts
            ? '\n${ind}isMinifyEnabled = false\n${ind}isShrinkResources = false'
            : '\n${ind}minifyEnabled false\n${ind}shrinkResources false';
        return '${m[0]}$extra';
      },
    );
  }
  f.writeAsStringSync(s);
  stdout.writeln('  • ${f.path}');
}

void _rootGradle() {
  final kts = File('android/build.gradle.kts');
  final isKts = kts.existsSync();
  final f = isKts ? kts : File('android/build.gradle');
  if (!f.existsSync()) return;
  var s = f.readAsStringSync();
  if (s.contains('jitpack.io')) return;

  final all = s.indexOf('allprojects');
  final central = all < 0 ? -1 : s.indexOf('mavenCentral()', all);
  if (central < 0) return;
  final end = central + 'mavenCentral()'.length;
  final repo = isKts
      ? '\n        maven { url = uri("https://jitpack.io") }'
      : "\n        maven { url 'https://jitpack.io' }";
  s = s.substring(0, end) + repo + s.substring(end);
  f.writeAsStringSync(s);
  stdout.writeln('  • ${f.path}');
}

void _networkSecurityConfig() {
  final f = File('android/app/src/main/res/xml/network_security_config.xml');
  f.parent.createSync(recursive: true);
  f.writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<!-- Sunucu listesi düz HTTP üzerinden de alınabilsin. -->
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">vpngate.net</domain>
    </domain-config>
</network-security-config>
''');
  stdout.writeln('  • network_security_config.xml');
}

void _proguard() {
  final f = File('android/app/proguard-rules.pro');
  if (f.existsSync() && f.readAsStringSync().contains('de.blinkt')) return;
  f.writeAsStringSync('''
-keep class de.blinkt.openvpn.** { *; }
-keep class id.laskarmedia.** { *; }
-dontwarn de.blinkt.openvpn.**
''', mode: FileMode.append);
  stdout.writeln('  • proguard-rules.pro');
}

/// openvpn_flutter bildirimi için ikon ve Türkçe "bağlantıyı kes" metni.
void _notificationResources() {
  final icon = File('tool/res/ic_notification.png');
  if (icon.existsSync()) {
    final dir = Directory('android/app/src/main/res/drawable')
      ..createSync(recursive: true);
    icon.copySync('${dir.path}/ic_notification.png');
  }
  final strings = File('android/app/src/main/res/values/strings.xml');
  if (!strings.existsSync()) {
    strings.parent.createSync(recursive: true);
    strings.writeAsStringSync('<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <string name="cancel_connection">Bağlantıyı kes</string>\n'
        '</resources>\n');
  }
  stdout.writeln('  • bildirim ikonu ve metni');
}
