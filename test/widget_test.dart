import 'dart:convert';
import 'dart:ui' show Locale;

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

  test('dil telefonun diline göre seçilir', () {
    for (final c in L10n.codes) {
      expect(L10n.resolve(Locale(c, 'XX')).languageCode, c);
      expect(L10n.code, c);
      expect(tr('btn_connect').isNotEmpty, isTrue);
      expect(tr('trying_next', {'n': 2, 'max': 4}).contains('2/4'), isTrue);
    }
    // Desteklenmeyen dil (Almanca) ve dil yoksa İngilizce.
    expect(L10n.resolve(const Locale('de')).languageCode, 'en');
    expect(L10n.resolve(null).languageCode, 'en');
    // Önce Almanca sonra Türkçe tanımlı telefon: Türkçe.
    expect(
      L10n.resolveList(const [Locale('de'), Locale('tr')]).languageCode,
      'tr',
    );
    expect(tr('olmayan_anahtar'), 'olmayan_anahtar');
  });

  test('hızlı DNS ayardan kapatılabilir', () {
    final cfg = ServerApi.parse(body).first.config;
    expect(ServerApi.prepareConfig(cfg).contains('dhcp-option DNS'), isTrue);
    expect(
      ServerApi.prepareConfig(cfg, fastDns: false).contains('dhcp-option'),
      isFalse,
    );
  });

  test('ölçüm durdurulabilir', () async {
    final list = ServerApi.parse(body);
    var calls = 0;
    await ServerApi.measureAll(
      list,
      parallel: 1,
      shouldStop: () => calls++ > 0, // ilk gruptan sonra dur
    );
    // İlk sunucu ölçüldü (TCP: ulaşılamaz = -1), ikincisine geçilmedi.
    expect(list[0].latency, isNotNull);
    expect(list[1].latency, isNull);
  });

  test('VPN el sıkışma paketi doğru biçimde', () {
    final p = ServerApi.hardResetPacket();
    expect(p.length, 14); // başlık + 8 oturum + 1 onay + 4 paket no
    expect(p[0], 0x38); // P_CONTROL_HARD_RESET_CLIENT_V2, key 0
    expect(p[9], 0); // onay yok
    expect(p.sublist(10), [0, 0, 0, 0]);
    expect(ServerApi.isServerReset(0x40), isTrue); // SERVER_V2
    expect(ServerApi.isServerReset(0x38), isFalse);
  });

  test('hiçbir sunucu el sıkışmazsa kapısı açıklarla devam edilir', () {
    final list = ServerApi.parse(body);
    list[0]
      ..latency = -3
      ..tcpLatency = 120;
    list[1].latency = -1;
    expect(list[0].unreachable, isTrue);
    ServerApi.applyFallback(list);
    expect(list[0].reachable, isTrue);
    expect(list[0].latency, 120);
    expect(list[1].unreachable, isTrue);
    ServerApi.handshakeCheck = true; // diğer testleri etkilemesin
  });

  test('tls-auth kullanan sunucu tanınır', () {
    expect(ServerApi.parse(body).first.tlsAuth, isFalse);
  });
}
