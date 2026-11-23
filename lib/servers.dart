import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
    this.tlsAuth = false,
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

  /// tls-auth / tls-crypt kullanıyorsa el sıkışma kontrolü yapılamaz.
  final bool tlsAuth;

  /// Bu cihazdan ölçülen VPN el sıkışma süresi (ms).
  /// null: ölçülmedi, -1: ulaşılamadı,
  /// -3: kapı açık ama VPN cevap vermedi.
  int? latency;

  /// Yalnızca TCP bağlantı süresi (yedek ölçüm için).
  int? tcpLatency;

  /// Son kontrol zamanı.
  DateTime? checkedAt;

  /// Sunucu şu an kesin çalışıyor (VPN el sıkışması başarılı).
  bool get reachable => latency != null && latency! >= 0;
  bool get unreachable => latency == -1 || latency == -3;

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
        tlsAuth: config.contains('<tls-auth>') ||
            config.contains('<tls-crypt') ||
            RegExp(r'^\s*tls-(auth|crypt)', multiLine: true).hasMatch(config),
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

  /// true: sunucuya gerçek VPN el sıkışması denenir.
  /// false: yalnızca kapının açık olduğuna bakılır (yedek mod).
  static bool handshakeCheck = true;

  /// OpenVPN P_CONTROL_HARD_RESET_CLIENT_V2 paketi (tls-auth yok):
  /// başlık + 8 bayt oturum kimliği + 0 onay + 4 bayt paket numarası.
  static Uint8List hardResetPacket() {
    final rnd = Random();
    final b = BytesBuilder()
      ..addByte((7 << 3) | 0); // opcode 7, key_id 0
    for (var i = 0; i < 8; i++) {
      b.addByte(rnd.nextInt(256));
    }
    b
      ..addByte(0) // onay listesi boş
      ..add(const [0, 0, 0, 0]); // paket numarası 0
    return b.toBytes();
  }

  /// Sunucunun cevabı P_CONTROL_HARD_RESET_SERVER_V2 mi?
  static bool isServerReset(int firstByte) => (firstByte >> 3) == 8;

  /// Sunucuyu kontrol eder. Dönüş: el sıkışma süresi (ms),
  /// -1 ulaşılamadı, -3 kapı açık ama VPN cevap vermedi, -2 ölçülemez.
  static Future<int> measure(
    VpnServer s, {
    Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    if (!handshakeCheck || s.tlsAuth) {
      return s.tcp ? _tcpOnly(s, timeout) : -2;
    }
    return s.tcp ? _probeTcp(s, timeout) : _probeUdp(s, timeout);
  }

  static Future<int> _tcpOnly(VpnServer s, Duration timeout) async {
    final sw = Stopwatch()..start();
    try {
      final socket =
          await Socket.connect(s.remoteHost, s.remotePort, timeout: timeout);
      sw.stop();
      socket.destroy();
      s.tcpLatency = sw.elapsedMilliseconds;
      return sw.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  static Future<int> _probeTcp(VpnServer s, Duration timeout) async {
    final sw = Stopwatch()..start();
    Socket? connected;
    try {
      connected =
          await Socket.connect(s.remoteHost, s.remotePort, timeout: timeout);
    } catch (_) {
      return -1;
    }
    final socket = connected!;
    s.tcpLatency = sw.elapsedMilliseconds;
    StreamSubscription<Uint8List>? sub;
    try {
      final pkt = hardResetPacket();
      final got = <int>[];
      final reply = Completer<int>();
      sub = socket.listen(
        (data) {
          got.addAll(data);
          // TCP'de ilk 2 bayt uzunluk, 3. bayt başlık.
          if (got.length >= 3 && !reply.isCompleted) reply.complete(got[2]);
        },
        onError: (Object _) {
          if (!reply.isCompleted) reply.complete(-1);
        },
        onDone: () {
          if (!reply.isCompleted) reply.complete(-1);
        },
        cancelOnError: true,
      );
      socket.add([pkt.length >> 8, pkt.length & 0xff, ...pkt]);
      final first = await reply.future.timeout(timeout, onTimeout: () => -1);
      sw.stop();
      if (first >= 0 && isServerReset(first)) return sw.elapsedMilliseconds;
      return -3;
    } catch (_) {
      return -3;
    } finally {
      await sub?.cancel();
      socket.destroy();
    }
  }

  static Future<int> _probeUdp(VpnServer s, Duration timeout) async {
    RawDatagramSocket? socket;
    try {
      final addrs = await InternetAddress.lookup(s.remoteHost).timeout(timeout);
      if (addrs.isEmpty) return -1;
      final addr = addrs.first;
      final sock = await RawDatagramSocket.bind(
        addr.type == InternetAddressType.IPv6
            ? InternetAddress.anyIPv6
            : InternetAddress.anyIPv4,
        0,
      );
      socket = sock;
      final reply = Completer<int>();
      final sw = Stopwatch()..start();
      sock.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = sock.receive();
        if (d != null && d.data.isNotEmpty && !reply.isCompleted) {
          reply.complete(d.data[0]);
        }
      });
      sock.send(hardResetPacket(), addr, s.remotePort);
      final first = await reply.future.timeout(timeout, onTimeout: () => -1);
      sw.stop();
      return first >= 0 && isServerReset(first) ? sw.elapsedMilliseconds : -1;
    } catch (_) {
      return -1;
    } finally {
      socket?.close();
    }
  }

  /// İlk ölçümde hiçbir sunucu el sıkışmaya cevap vermediyse ama kapıları
  /// açıksa, yedek moda geçer: kapısı açık olanları çalışıyor sayar.
  /// Ağ VPN protokolünü kısıtlıyorsa uygulama yine de çalışsın diye.
  static void applyFallback(List<VpnServer> servers) {
    if (!handshakeCheck) return;
    if (servers.any((s) => s.reachable)) return;
    final weak = servers.where((s) => s.latency == -3).toList();
    if (weak.isEmpty) return;
    handshakeCheck = false;
    for (final s in weak) {
      s.latency = s.tcpLatency;
    }
  }

  /// Sunucuları paralel ölçer; [onProgress] her sonuçta çağrılır.
  /// [shouldStop] true dönerse kalan gruplar ölçülmez.
  static Future<void> measureAll(
    List<VpnServer> servers, {
    int parallel = 24,
    VoidCallback? onProgress,
    bool Function()? shouldStop,
    bool keepLatency = false,
  }) async {
    for (var i = 0; i < servers.length; i += parallel) {
      if (shouldStop?.call() ?? false) return;
      final batch = servers.skip(i).take(parallel);
      await Future.wait(batch.map((s) async {
        final r = await measure(s);
        s.checkedAt = DateTime.now();
        // Tünel içinden ölçerken süreler yanıltıcıdır: yalnızca çalışıp
        // çalışmadığını güncelle, eski süreyi koru.
        if (keepLatency && r >= 0 && s.reachable) {
          // değişiklik yok
        } else {
          s.latency = r == -2 ? null : r;
        }
        onProgress?.call();
      }));
    }
  }

  /// Tünel içinden kısa bir indirme yapıp hızı Mbps olarak ölçer.
  /// En fazla ~7 saniye sürer, en fazla 2 MB indirir. Ölçülemezse null.
  static Future<double?> measureThroughput() async {
    final client = http.Client();
    final sw = Stopwatch();
    var got = 0;
    try {
      final req = http.Request(
        'GET',
        Uri.parse('https://speed.cloudflare.com/__down?bytes=2000000'),
      );
      final res = await client.send(req).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      sw.start();
      try {
        await for (final chunk
            in res.stream.timeout(const Duration(seconds: 4))) {
          got += chunk.length;
          if (sw.elapsedMilliseconds > 7000) break;
        }
      } on TimeoutException {
        // takıldı: o ana kadar inenle hesapla
      }
      sw.stop();
      if (got < 64 * 1024 || sw.elapsedMicroseconds <= 0) {
        return got > 0 ? 0.1 : null;
      }
      return got * 8 / (sw.elapsedMicroseconds / 1e6) / 1e6;
    } catch (_) {
      return null;
    } finally {
      client.close();
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
      return perUser * 2 + mbps * 0.5 - s.latency! / 8;
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
