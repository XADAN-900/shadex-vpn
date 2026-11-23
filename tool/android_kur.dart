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
  _nativeKeepAlive();
  stdout.writeln('✓ Android ayarları tamam.');
}

void _manifest() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  var s = f.readAsStringSync();

  const perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.POST_NOTIFICATIONS',
    // Arka planda hazırlık/bağlanma sürsün diye ön plan servisi.
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_DATA_SYNC',
    'android.permission.WAKE_LOCK',
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

  // Uygulamanın kendi arka plan servisi (Android 14+ tür bildirimi zorunlu).
  if (!s.contains('.KeepAliveService')) {
    s = s.replaceFirst(
      '</application>',
      '    <service\n'
      '            android:name=".KeepAliveService"\n'
      '            android:foregroundServiceType="dataSync"\n'
      '            android:stopWithTask="true"\n'
      '            android:exported="false" />\n'
      '    </application>',
    );
  }
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
  // Bildirimdeki "bağlantıyı kes" düğmesi, telefonun diline göre.
  const texts = {
    'values': 'Disconnect',
    'values-tr': 'Bağlantıyı kes',
    'values-fr': 'Déconnecter',
    'values-es': 'Desconectar',
    'values-pt': 'Desconectar',
    'values-ru': 'Отключить',
    'values-ar': 'قطع الاتصال',
  };
  texts.forEach((folder, text) {
    final f = File('android/app/src/main/res/$folder/strings.xml');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync('<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <string name="cancel_connection">$text</string>\n'
        '</resources>\n');
  });
  stdout.writeln('  • bildirim ikonu ve metni');
}

/// MainActivity'ye "shadex/keepalive" kanalını ekler ve hafif bir ön plan
/// servisi yazar. İkinci bir Flutter motoru açılmaz.
void _nativeKeepAlive() {
  final roots = [
    Directory('android/app/src/main/kotlin'),
    Directory('android/app/src/main/java'),
  ];
  File? activity;
  for (final r in roots) {
    if (!r.existsSync()) continue;
    for (final e in r.listSync(recursive: true)) {
      if (e is File && e.path.endsWith('MainActivity.kt')) activity = e;
    }
  }
  if (activity == null) {
    stderr.writeln('MainActivity.kt bulunamadı.');
    exit(1);
  }
  final pkg = RegExp(r'^package\s+([\w.]+)', multiLine: true)
      .firstMatch(activity.readAsStringSync())
      ?.group(1);
  if (pkg == null) {
    stderr.writeln('MainActivity paket adı okunamadı.');
    exit(1);
  }

  activity.writeAsStringSync('''package $pkg

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shadex/keepalive")
            .setMethodCallHandler { call, result ->
                try {
                    val text = call.argument<String>("text") ?: "ShadeX VPN"
                    when (call.method) {
                        "start" -> {
                            val intent = Intent(this, KeepAliveService::class.java)
                                .putExtra(KeepAliveService.EXTRA_TEXT, text)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        }
                        "update" -> {
                            KeepAliveService.update(this, text)
                            result.success(true)
                        }
                        "stop" -> {
                            stopService(Intent(this, KeepAliveService::class.java))
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.success(false)
                }
            }
    }
}
''');

  File('${activity.parent.path}/KeepAliveService.kt').writeAsStringSync('''package $pkg

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/// Sunucu hazırlığı ve bağlanma sırasında uygulamanın arka planda
/// dondurulmaması için sessiz bildirimli ön plan servisi.
class KeepAliveService : Service() {
    companion object {
        const val CHANNEL_ID = "shadex_work"
        const val NOTIFICATION_ID = 7301
        const val EXTRA_TEXT = "text"

        fun build(context: Context, text: String): Notification {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, "ShadeX", NotificationManager.IMPORTANCE_LOW)
                )
            }
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            @Suppress("DEPRECATION")
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                Notification.Builder(context)
            }
            builder
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle("ShadeX VPN")
                .setContentText(text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
            if (launch != null) {
                builder.setContentIntent(PendingIntent.getActivity(context, 0, launch, flags))
            }
            return builder.build()
        }

        fun update(context: Context, text: String) {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, build(context, text))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: "ShadeX VPN"
        try {
            val notification = build(this, text)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }
}
''');
  stdout.writeln('  • arka plan servisi (KeepAliveService)');
}
