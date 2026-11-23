import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Uygulama arka plana alınınca Android onu birkaç saniye içinde dondurur.
/// Sunucular hazırlanırken ve bağlantı kurulurken bu sınıf sessiz bir
/// bildirimle ön plan servisi açar; böylece iş arka planda da sürer.
/// Bağlantı kurulunca VPN'in kendi servisi devraldığı için kapatılır.
///
/// start/stop çağrıları sıraya alınır ve her seferinde yalnızca son istenen
/// duruma göre hareket edilir; hızlı aç-kapa yarışında servis açık kalmaz.
class BackgroundGuard {
  static bool _initialized = false;

  // İstenen durum
  static bool _want = false;
  static String _wantText = '';

  // Gerçek durum
  static bool _on = false;
  static String? _onText;

  static bool _working = false;
  static bool _again = false;

  /// Servis açık olsun; açıksa bildirim metnini günceller.
  static void start(String text) {
    if (_want && _wantText == text) return;
    _want = true;
    _wantText = text;
    _schedule();
  }

  /// Servis kapansın.
  static void stop() {
    if (!_want) return;
    _want = false;
    _schedule();
  }

  static Future<void> _schedule() async {
    if (_working) {
      _again = true;
      return;
    }
    _working = true;
    try {
      do {
        _again = false;
        await _reconcile();
      } while (_again);
    } finally {
      _working = false;
    }
  }

  static Future<void> _reconcile() async {
    _init();
    try {
      if (_want) {
        if (!_on) {
          // Zaten açıksa (eski oturumdan kalma) hata döner; yine de açık say.
          await FlutterForegroundTask.startService(
            serviceId: 7301,
            serviceTypes: [ForegroundServiceTypes.dataSync],
            notificationTitle: 'ShadeX VPN',
            notificationText: _wantText,
          );
          _on = true;
          _onText = _wantText;
        } else if (_onText != _wantText) {
          await FlutterForegroundTask.updateService(
            notificationTitle: 'ShadeX VPN',
            notificationText: _wantText,
          );
          _onText = _wantText;
        }
      } else if (_on) {
        await FlutterForegroundTask.stopService();
        _on = false;
        _onText = null;
      }
    } catch (_) {
      // Servis açılamazsa uygulama yine çalışır, sadece arka planda durabilir.
    }
  }

  static void _init() {
    if (_initialized) return;
    _initialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'shadex_work',
        channelName: 'ShadeX',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowAutoRestart: false,
        autoRunOnBoot: false,
        stopWithTask: true,
      ),
    );
  }
}
