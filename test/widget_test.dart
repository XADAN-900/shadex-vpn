import 'dart:convert';

import 'package:shadex_vpn/vpngate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cfg = base64.encode(utf8.encode(
    '# yorum\r\nclient\r\ndev tun\r\nremote 1.2.3.4 1194\r\ncipher AES-128-CBC\r\n',
  ));
  final body = '*vpn_servers\n'
      '#HostName,IP,Score,Ping,Speed,CountryLong,CountryShort,NumVpnSessions,'
      'Uptime,TotalUsers,TotalTraffic,LogType,Operator,Message,'
      'OpenVPN_ConfigData_Base64\n'
      'vpn1,1.2.3.4,100,12,5000000,Japan,JP,3,1,1,1,2weeks,op,,$cfg\n'
      'vpn2,5.6.7.8,900,30,1000000,Korea Republic of,KR,3,1,1,1,2weeks,op,,$cfg\n'
      'bozuk,satir\n'
      '*\n';

  test('VPN Gate CSV ayrıştırılır ve puana göre sıralanır', () {
    final list = VpnGateApi.parse(body);
    expect(list.length, 2);
    expect(list.first.countryShort, 'KR');
    expect(list.last.ping, 12);
    expect(list.last.flag, '🇯🇵');
    expect(list.last.speedText, '5.0 Mbps');
  });

  test('yapılandırma hazırlanır', () {
    final out = VpnGateApi.prepareConfig(VpnGateApi.parse(body).first.config);
    expect(out.contains('# yorum'), isFalse);
    expect(out.contains('\r'), isFalse);
    expect(out.contains('remote 1.2.3.4 1194'), isTrue);
    expect(out.contains('data-ciphers'), isTrue);
  });
}
