import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadex_vpn/l10n.dart';
import 'package:shadex_vpn/servers.dart';

void main() {
  String cfg(String remote) => base64.encode(utf8.encode(
        '# yorum\r\n#auth-user-pass\r\nclient\r\ndev tun\r\nproto tcp\r\n'
        '$remote\r\ncipher AES-128-CBC\r\n<ca>\r\nABC\r\n</ca>\r\n',
      ));

  final body = '*vpn_servers\n'
      '#HostName,IP,Score,Ping,Speed,CountryLong,CountryShort,NumVpnSessions,'
      'Uptime,TotalUsers,TotalTraffic,LogType,Operator,Message,'
      'OpenVPN_ConfigData_Base64\n'
      'vpn1,1.2.3.4,100,12,5000000,Japan,JP,3,1,1,1,2weeks,op,,'
      '${cfg('remote 1.2.3.4 443')}\n'
      'vpn2,5.6.7.8,900,30,1000000,Korea Republic of,KR,3,1,1,1,2weeks,op,,'
      '${cfg('remote 5.6.7.8 1194')}\n'
      'bozuk,satir\n'
      '*\n';

  test('liste ayrıştırılır ve puana göre sıralanır', () {
    final list = ServerApi.parse(body);
    expect(list.length, 2);
    expect(list.first.countryShort, 'KR');
    expect(list.last.ping, 12);
    expect(list.last.flag, '🇯🇵');
    expect(list.last.speedText, '5.0 Mbps');
    expect(list.last.remoteHost, '1.2.3.4');
    expect(list.last.remotePort, 443);
    expect(list.last.tcp, isTrue);
  });

  test('yapılandırma bağlanmaya hazırlanır', () {
    final out = ServerApi.prepareConfig(ServerApi.parse(body).first.config);
    final lines = out.split('\n');
    expect(out.contains('# yorum'), isFalse);
    expect(out.contains('\r'), isFalse);
    expect(lines.contains('auth-user-pass'), isTrue);
    expect(lines.contains('connect-timeout 8'), isTrue);
    expect(lines.indexOf('auth-user-pass') < lines.indexOf('<ca>'), isTrue);
    expect(out.contains('data-ciphers'), isFalse);
  });

  test('önerilen sıralama ulaşılabilir ve hızlıyı öne alır', () {
    final list = ServerApi.parse(body);
    list[0].latency = -1; // KR kapalı
    list[1].latency = 80; // JP açık
    final ranked = ServerApi.ranked(list);
    expect(ranked.first.countryShort, 'JP');
    expect(ranked.last.countryShort, 'KR');
  });

  test('7 dilin hepsinde metinler dolu', () {
    for (final c in L10n.codes) {
      L10n.preference.value = c;
      expect(L10n.code, c);
      expect(tr('btn_connect').isNotEmpty, isTrue);
      expect(tr('trying_next', {'n': 2, 'max': 4}).contains('2/4'), isTrue);
      expect(tr('olmayan_anahtar'), 'olmayan_anahtar');
    }
    L10n.preference.value = null;
    expect(L10n.code, 'en'); // ilk açılış İngilizce
  });

  test('hızlı DNS ayardan kapatılabilir', () {
    final cfg = ServerApi.parse(body).first.config;
    expect(ServerApi.prepareConfig(cfg).contains('dhcp-option DNS'), isTrue);
    expect(
      ServerApi.prepareConfig(cfg, fastDns: false).contains('dhcp-option'),
      isFalse,
    );
  });
}
