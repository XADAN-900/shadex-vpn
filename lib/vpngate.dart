import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Ülke kodundan bayrak emojisi (TR -> 🇹🇷). Kod yoksa 🌐.
String flagEmoji(String? code) {
  final cc = (code ?? '').toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(cc)) return '🌐';
  return String.fromCharCodes(cc.codeUnits.map((c) => 0x1F1E6 + c - 65));
}

/// VPN Gate (Tsukuba Üniversitesi) gönüllü sunucularından biri.
class VpnServer {
  const VpnServer({
    required this.hostName,
    required this.ip,
    required this.score,
    required this.ping,
    required this.speed,
    required this.countryLong,
    required this.countryShort,
    required this.sessions,
    required this.operatorName,
    required this.config,
  });

  final String hostName;
  final String ip;
  final int score;
  final int ping; // ms
  final int speed; // bit/s
  final String countryLong;
  final String countryShort;
  final int sessions;
  final String operatorName;
  final String config; // .ovpn içeriği

  String get flag => flagEmoji(countryShort);

  String get speedText => '${(speed / 1000000).toStringAsFixed(1)} Mbps';
  String get pingText => ping > 0 ? '$ping ms' : '-';
}

class VpnGateApi {
  static const _urls = [
    'http://www.vpngate.net/api/iphone/',
    'https://www.vpngate.net/api/iphone/',
  ];

  /// Sunucu listesini indirir, en iyi puanlı olan başta olacak şekilde döner.
  static Future<List<VpnServer>> fetchServers() async {
    Object? lastError;
    for (final url in _urls) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 25));
        if (res.statusCode != 200) {
          lastError = 'HTTP ${res.statusCode}';
          continue;
        }
        final list = parse(utf8.decode(res.bodyBytes, allowMalformed: true));
        if (list.isNotEmpty) return list;
        lastError = 'liste boş geldi';
      } on TimeoutException {
        lastError = 'zaman aşımı';
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('Sunucu listesi alınamadı ($lastError)');
  }

  /// VPN Gate CSV formatı:
  /// HostName,IP,Score,Ping,Speed,CountryLong,CountryShort,NumVpnSessions,
  /// Uptime,TotalUsers,TotalTraffic,LogType,Operator,Message,OpenVPN_ConfigData_Base64
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
      if (!config.contains('remote ')) continue;

      servers.add(VpnServer(
        hostName: f[0],
        ip: f[1],
        score: int.tryParse(f[2]) ?? 0,
        ping: int.tryParse(f[3]) ?? 0,
        speed: int.tryParse(f[4]) ?? 0,
        countryLong: f[5],
        countryShort: f[6],
        sessions: int.tryParse(f[7]) ?? 0,
        operatorName: f[12],
        config: config,
      ));
    }
    servers.sort((a, b) => b.score.compareTo(a.score));
    return servers;
  }

  /// Yorum satırlarını atar ve VPN Gate'in eski şifre ayarıyla uyumluluk ekler.
  static String prepareConfig(String config) {
    final lines = config
        .replaceAll('\r\n', '\n')
        .split('\n')
        .where((l) {
          final t = l.trimLeft();
          return !(t.startsWith('#') || t.startsWith(';'));
        })
        .toList();
    var out = lines.join('\n').trim();
    if (!out.contains('data-ciphers')) {
      out += '\ndata-ciphers AES-128-CBC:AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305';
    }
    return '$out\n';
  }
}
