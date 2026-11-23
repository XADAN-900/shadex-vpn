import 'dart:async';

import 'package:flutter/services.dart';

/// Uygulama arka plana alınınca Android onu birkaç saniye içinde dondurur.
/// Sunucular hazırlanırken ve bağlantı kurulurken bu sınıf, uygulamanın
/// kendi küçük Android servisini (KeepAliveService) sessiz bir bildirimle
/// açar; böylece iş arka planda da sürer. Bağlanınca VPN'in kendi servisi
/// devraldığı için kapatılır.
///
/// İkinci bir Flutter motoru açılmaz. start/stop çağrıları sıraya alınır ve
/// her seferinde yalnızca son istenen duruma göre hareket edilir.
class BackgroundGuard {
  static const _channel = MethodChannel('shadex/keepalive');
  static const _callTimeout = Duration(seconds: 5);

  // İstenen durum
  static bool _want = false;
  static String _wantText = '';

  // Gerçek durum
  static bool _on = false;
  static String? _onText;
  static bool _failed = false; // açılamadıysa her çizimde tekrar denenmesin

  static bool _working = false;
  static bool _again = false;

  /// Servis açık olsun; açıksa bildirim metnini günceller.
  static void start(String text) {
    if (_want && _wantText == text) return;
    _want = true;
    _wantText = text;
    unawaited(_schedule());
  }

  /// Servis kapansın.
  static void stop() {
    if (!_want && !_on) return;
    _want = false;
    _failed = false;
    unawaited(_schedule());
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
    try {
      if (_want) {
        if (!_on) {
          if (_failed) return;
          final ok = await _channel
              .invokeMethod<bool>('start', {'text': _wantText})
              .timeout(_callTimeout);
          _on = ok ?? false;
          _failed = !_on;
          if (_on) _onText = _wantText;
        } else if (_onText != _wantText) {
          await _channel
              .invokeMethod<bool>('update', {'text': _wantText})
              .timeout(_callTimeout);
          _onText = _wantText;
        }
      } else if (_on) {
        _on = false;
        _onText = null;
        await _channel.invokeMethod<bool>('stop').timeout(_callTimeout);
      }
    } catch (_) {
      // Servis yoksa ya da cevap vermezse uygulama yine çalışır.
    }
  }
}
