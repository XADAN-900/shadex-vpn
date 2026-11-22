import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Ülke kodundan bayrak emojisi (TR -> 🇹🇷). Kod yoksa 🌐.
String flagEmoji(String? code) {
  final cc = (code ?? '').toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(cc)) return '🌐';
  return String.fromCharCodes(cc.codeUnits.map((c) => 0x1F1E6 + c - 65));
}

/// Bir VPN sunucusu.
class VpnServer {
  VpnServer({
    required this.hostName,
    required this.ip,
    required this.score,
    required this.ping,
    required this.speed,
    required this.countryLong,
    required this.countryShort,
    required this.sessions,
    required this.config,
    required this.remoteHost,
    required this.remotePort,
    required this.tcp,
  });

  final String hostName;
  final String ip;
  final int score;
  final int ping; // sunucunun bildirdiği ping (ms)
  final int speed; // bit/s
  final String countryLong;
  final String countryShort;
  final int sessions;
  final String config; // .ovpn içeriği
  final String remoteHost;
  final int remotePort;
  final bool tcp;

  /// Bu cihazdan ölçülen bağlantı süresi (ms).
  /// null: ölçülmedi, -1: ulaşılamadı.
  int? latency;

  bool get reachable => latency != null && latency! >= 0;
  bool get unreachable => latency == -1;

  /// Gösterilecek ping: ölçülen varsa o, yoksa bildirilen.
  int get displayPing => reachable ? latency! : ping;

  String get flag => flagEmoji(countryShort);
  String get speedText {
    final mbps = speed / 1000000;
    return mbps >= 10
        ? '${mbps.toStringAsFixed(0)} Mbps'
        : '${mbps.toStringAsFixed(1)} Mbps';
  }
}

class ServerApi {
  static const _urls = [
    'http://www.vpngate.net/api/iphone/',
    'https://www.vpngate.net/api/iphone/',
  ];
  static const _cacheName = 'servers_v1.csv';
  static const maxServers = 200;

  // Sunucuların ortak giriş bilgisi.
  static const username = 'vpn';
  static const password = 'vpn';

  /// Önbellekteki son listeyi döner (yoksa boş).
  static Future<List<VpnServer>> loadCached() async {
    try {
      final f = await _cacheFile();
      if (!await f.exists()) return [];
      final body = await f.readAsString();
      return compute(parse, body);
    } catch (_) {
      return [];
    }
  }

  /// Güncel listeyi indirir, önbelleğe yazar.
  static Future<List<VpnServer>> fetch() async {
    Object? lastError;
    for (final url in _urls) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 20));
        if (res.statusCode != 200) {
          lastError = 'HTTP ${res.statusCode}';
          continue;
        }
        final body = utf8.decode(res.bodyBytes, allowMalformed: true);
        final list = await compute(parse, body);
        if (list.isNotEmpty) {
          unawaited(_writeCache(body));
          return list;
        }
        lastError = 'liste boş';
      } on TimeoutException {
        lastError = 'zaman aşımı';
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('Sunucu listesi alınamadı ($lastError)');
  }

  static Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_cacheName');
  }

  static Future<void> _writeCache(String body) async {
    try {
      await (await _cacheFile()).writeAsString(body, flush: true);
    } catch (_) {}
  }

  /// CSV listesini ayrıştırır, puana göre sıralar.
  /// Alanlar: HostName,IP,Score,Ping,Speed,CountryLong,CountryShort,
  /// NumVpnSessions,Uptime,TotalUsers,TotalTraffic,LogType,Operator,Message,Config
  static List<VpnServer> parse(String body) {
    final servers = <VpnServer>[];
    for (final raw in const LineSplitter().convert(body)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('*') || line.startsWith('#')) {
        continue;
      }
      final f = line.split(',');
      if (f.length < 15) continue;
      final b64 = f.last.trim();
      if (b64.isEmpty) continue;

      String config;
      try {
        config = utf8.decode(
          base64.decode(base64.normalize(b64)),
          allowMalformed: true,
        );
      } catch (_) {
        continue;
      }

      String? host;
      var port = 1194;
      var tcp = false;
      for (final l in const LineSplitter().convert(config)) {
        final t = l.trim();
        if (t.startsWith('#') || t.startsWith(';')) continue;
        final parts = t.split(RegExp(r'\s+'));
        if (parts.first == 'remote' && parts.length >= 2 && host == null) {
          host = parts[1];
          if (parts.length >= 3) port = int.tryParse(parts[2]) ?? port;
          if (parts.length >= 4) tcp = parts[3].startsWith('tcp');
        } else if (parts.first == 'proto' && parts.length >= 2) {
          tcp = parts[1].startsWith('tcp');
        }
      }
      if (host == null) continue;

      servers.add(VpnServer(
        hostName: f[0],
        ip: f[1],
        score: int.tryParse(f[2]) ?? 0,
        ping: int.tryParse(f[3]) ?? 0,
        speed: int.tryParse(f[4]) ?? 0,
        countryLong: f[5],
        countryShort: f[6],
        sessions: int.tryParse(f[7]) ?? 0,
        config: config,
        remoteHost: host,
        remotePort: port,
        tcp: tcp,
      ));
    }
    servers.sort((a, b) => b.score.compareTo(a.score));
    return servers.length > maxServers
        ? servers.sublist(0, maxServers)
        : servers;
  }

  /// Bağlanmaya hazır yapılandırma: yorumları atar, giriş bilgisini,
  /// kısa bağlantı zaman aşımını ve istenirse hızlı DNS'i ekler.
  static String prepareConfig(String config, {bool fastDns = true}) {
    final lines = config
        .replaceAll('\r\n', '\n')
        .split('\n')
        .where((l) {
          final t = l.trimLeft();
          return t.isNotEmpty && !(t.startsWith('#') || t.startsWith(';'));
        })
        .toList();
    bool has(String opt) =>
        lines.any((l) => l.trimLeft().split(RegExp(r'\s+')).first == opt);

    final extra = <String>[
      if (!has('auth-user-pass')) 'auth-user-pass',
      if (!has('connect-timeout')) 'connect-timeout 8',
      if (fastDns) ...[
        'dhcp-option DNS 1.1.1.1',
        'dhcp-option DNS 8.8.8.8',
      ],
    ];
    // Seçenekler satır içi blokların (<ca>, <cert>…) önüne eklenir.
    final firstBlock = lines.indexWhere((l) => l.trimLeft().startsWith('<'));
    if (firstBlock < 0) {
      lines.addAll(extra);
    } else {
      lines.insertAll(firstBlock, extra);
    }
    return '${lines.join('\n')}\n';
  }

  /// Sunucuya TCP bağlantısı kurma süresini ölçer. UDP sunucularda
  /// adresin çözülebildiğini kontrol eder.
  static Future<int> measure(
    VpnServer s, {
    Duration timeout = const Duration(milliseconds: 1800),
  }) async {
    final sw = Stopwatch()..start();
    try {
      if (s.tcp) {
        final socket = await Socket.connect(
          s.remoteHost,
          s.remotePort,
          timeout: timeout,
        );
        sw.stop();
        socket.destroy();
        return sw.elapsedMilliseconds;
      }
      return -2; // UDP: ölçülemez
    } catch (_) {
      return -1;
    }
  }

  /// İlk [count] sunucuyu paralel ölçer; [onProgress] her sonuçta çağrılır.
  static Future<void> measureAll(
    List<VpnServer> servers, {
    int count = 60,
    int parallel = 20,
    VoidCallback? onProgress,
  }) async {
    final targets = servers.take(count).toList();
    for (var i = 0; i < targets.length; i += parallel) {
      final batch = targets.skip(i).take(parallel);
      await Future.wait(batch.map((s) async {
        final r = await measure(s);
        s.latency = r == -2 ? null : r;
        onProgress?.call();
      }));
    }
  }

  /// Önerilen sıralama: ulaşılabilir sunucular kalite puanına göre başta,
  /// ölçülmeyenler ortada, ulaşılamayanlar sonda.
  /// Kalite: yüksek hız iyi, düşük gecikme iyi, kalabalık sunucu kötü.
  static List<VpnServer> ranked(Iterable<VpnServer> servers) {
    final list = servers.toList();
    int tier(VpnServer s) {
      if (s.unreachable) return 3;
      if (!s.reachable) return 2;
      return s.speed < 3000000 ? 1 : 0; // 3 Mbps altı yavaş
    }

    double quality(VpnServer s) {
      final mbps = (s.speed / 1000000).clamp(0, 300).toDouble();
      final perUser = mbps / (1 + s.sessions / 8);
      return perUser * 2 + mbps * 0.5 - s.latency! / 15;
    }

    list.sort((a, b) {
      final t = tier(a).compareTo(tier(b));
      if (t != 0) return t;
      if (a.reachable) return quality(b).compareTo(quality(a));
      return b.score.compareTo(a.score);
    });
    return list;
  }
}
