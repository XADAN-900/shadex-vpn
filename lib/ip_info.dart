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

  static Future<IpInfo?> fetch() async {
    try {
      final r = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (j is Map && j['success'] != false && j['ip'] != null) {
          return IpInfo(
            ip: '${j['ip']}',
            country: j['country']?.toString(),
            countryCode: j['country_code']?.toString(),
          );
        }
      }
    } catch (_) {}
    try {
      final r = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (j is Map && j['ip'] != null) return IpInfo(ip: '${j['ip']}');
      }
    } catch (_) {}
    return null;
  }
}
