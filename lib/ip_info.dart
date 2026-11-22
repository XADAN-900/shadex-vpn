import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'servers.dart';

/// Dış dünyaya görünen IP adresi.
class IpInfo {
  const IpInfo({required this.ip, this.country, this.countryCode});

  final String ip;
  final String? country;
  final String? countryCode;

  String get flag => flagEmoji(countryCode);

  static const _timeout = Duration(seconds: 5);

  /// Birkaç kaynağı aynı anda sorgular; ilk geçerli cevabı döner.
  /// Hiçbiri cevap vermezse null.
  static Future<IpInfo?> fetch() {
    final done = Completer<IpInfo?>();
    final sources = <Future<IpInfo?> Function()>[
      () => _trace('https://www.cloudflare.com/cdn-cgi/trace'),
      () => _trace('https://1.1.1.1/cdn-cgi/trace'),
      _ipwho,
      _ipinfo,
      _ipify,
    ];
    var pending = sources.length;

    Future<void> run(Future<IpInfo?> Function() source) async {
      try {
        final r = await source().timeout(_timeout);
        if (r != null && r.ip.isNotEmpty && !done.isCompleted) {
          done.complete(r);
        }
      } catch (_) {
        // diğer kaynaklar dener
      } finally {
        pending--;
        if (pending == 0 && !done.isCompleted) done.complete(null);
      }
    }

    for (final s in sources) {
      unawaited(run(s));
    }
    return done.future;
  }

  static Future<IpInfo?> _trace(String url) async {
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) return null;
    String? ip;
    String? loc;
    for (final line in const LineSplitter().convert(r.body)) {
      if (line.startsWith('ip=')) ip = line.substring(3).trim();
      if (line.startsWith('loc=')) loc = line.substring(4).trim();
    }
    if (ip == null) return null;
    return IpInfo(ip: ip, countryCode: loc == 'XX' ? null : loc);
  }

  static Future<IpInfo?> _ipwho() async {
    final r = await http.get(Uri.parse('https://ipwho.is/'));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body);
    if (j is! Map || j['success'] == false || j['ip'] == null) return null;
    return IpInfo(
      ip: '${j['ip']}',
      country: j['country']?.toString(),
      countryCode: j['country_code']?.toString(),
    );
  }

  static Future<IpInfo?> _ipinfo() async {
    final r = await http.get(Uri.parse('https://ipinfo.io/json'));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body);
    if (j is! Map || j['ip'] == null) return null;
    return IpInfo(ip: '${j['ip']}', countryCode: j['country']?.toString());
  }

  static Future<IpInfo?> _ipify() async {
    final r = await http.get(Uri.parse('https://api.ipify.org?format=json'));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body);
    if (j is! Map || j['ip'] == null) return null;
    return IpInfo(ip: '${j['ip']}');
  }
}
