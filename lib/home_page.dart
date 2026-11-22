import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ip_info.dart';
import 'servers.dart';
import 'settings.dart';
import 'theme.dart';
import 'widgets.dart';

const Map<String, String> _stageTr = {
  'prepare': 'Hazırlanıyor',
  'vpn_generate_config': 'Hazırlanıyor',
  'resolve': 'Sunucu bulunuyor',
  'tcp_connect': 'Sunucuya bağlanılıyor',
  'udp_connect': 'Sunucuya bağlanılıyor',
  'wait_connection': 'Sunucu bekleniyor',
  'authenticating': 'Güvenli oturum açılıyor',
  'authentication': 'Güvenli oturum açılıyor',
  'get_config': 'Ayarlar alınıyor',
  'assign_ip': 'IP adresi alınıyor',
  'add_routes': 'Tünel hazırlanıyor',
  'connecting': 'Bağlanıyor',
  'connected': 'Korumalı • Bağlı',
  'reconnect': 'Yeniden bağlanıyor',
  'no_network': 'İnternet bekleniyor',
  'paused': 'Duraklatıldı',
  'auth_pending': 'Doğrulama bekleniyor',
  'disconnecting': 'Bağlantı kesiliyor',
  'exiting': 'Korumasız',
  'disconnected': 'Korumasız',
  'denied': 'VPN izni verilmedi',
  'auth_failed': 'Sunucu bağlantıyı reddetti',
  'error': 'Bağlantı hatası',
  'unknown': 'Korumasız',
};

const _idleStages = {
  'disconnected',
  'denied',
  'error',
  'auth_failed',
  'unknown',
  'exiting',
};

const _failureStages = {'error', 'auth_failed'};

/// Bağlantı kurulamazsa en fazla kaç sunucu denensin.
const _maxAttempts = 4;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final OpenVPN _engine;
  AppSettings _settings = AppSettings(null);

  // Bağlantı durumu
  String _stageName = 'disconnected';
  VpnStatus? _status;
  bool _starting = false;
  bool _userCancelled = false;
  Timer? _watchdog;
  int _attempt = 0;
  final Set<String> _tried = {};
  String? _note;
  bool _autoConnectDone = false;

  // Sunucular
  List<VpnServer> _servers = [];
  VpnServer? _selected;
  bool _userPicked = false;
  bool _loading = true;
  bool _measuring = false;
  String? _error;
  Set<String> _favorites = {};

  // IP
  IpInfo? _ip;
  bool _ipLoading = false;
  Timer? _ipTimer;

  bool get _connected => _stageName == 'connected';
  bool get _idle => _idleStages.contains(_stageName);
  bool get _busy => _starting || (!_idle && !_connected);
  bool get _locked => _connected || _busy;

  // ------------------------------------------------------------ yaşam döngüsü

  @override
  void initState() {
    super.initState();
    _engine = OpenVPN(
      onVpnStatusChanged: (status) {
        if (!mounted) return;
        setState(() => _status = status);
      },
      onVpnStageChanged: (stage, raw) => _onStage(stage.name),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _settings = AppSettings(prefs);
      _favorites = _settings.favorites;
      _userPicked = _settings.lastHost != null;
    });

    await _initEngine(withLast: true);
    unawaited(_refreshIp());

    // Önce önbellekteki liste: uygulama anında açılsın.
    final cached = await ServerApi.loadCached();
    if (mounted && cached.isNotEmpty) {
      _applyServers(cached);
      setState(() => _loading = false);
    }
    await _loadServers();
  }

  Future<void> _initEngine({bool withLast = false}) async {
    try {
      await _engine.initialize(
        groupIdentifier: 'group.com.shadex.vpn',
        providerBundleIdentifier: 'com.shadex.shadex_vpn.VPNExtension',
        localizedDescription: 'ShadeX VPN',
        lastStage: withLast ? (VPNStage stage) => _onStage(stage.name) : null,
        lastStatus: withLast
            ? (VpnStatus status) {
                if (mounted) setState(() => _status = status);
              }
            : null,
        showTrafficInNotification: _settings.trafficInNotification,
        disconnectOnTaskRemoved: _settings.disconnectOnClose,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _ipTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------ sunucular

  void _applyServers(List<VpnServer> list) {
    final wanted = _selected?.hostName ?? _settings.lastHost;
    VpnServer? pick;
    for (final s in list) {
      if (s.hostName == wanted) {
        pick = s;
        break;
      }
    }
    setState(() {
      _servers = list;
      _selected = pick ?? (list.isEmpty ? null : list.first);
    });
  }

  Future<void> _loadServers() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ServerApi.fetch();
      if (mounted) _applyServers(list);
    } catch (e) {
      if (mounted && _servers.isEmpty) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    await _measure();
    _maybeAutoConnect();
  }

  /// Sunuculara bu cihazdan gerçek bağlantı süresini ölçer ve
  /// kullanıcı elle seçmediyse en hızlısını seçer.
  Future<void> _measure() async {
    // Tünel açıkken ölçüm VPN'in içinden yapılır ve yanıltır.
    if (!mounted || _servers.isEmpty || !_idle || _starting || _measuring) {
      return;
    }
    final list = _servers;
    setState(() => _measuring = true);
    await ServerApi.measureAll(list, onProgress: () {
      if (mounted) setState(() {});
    });
    if (!mounted) return;
    setState(() {
      _measuring = false;
      if (identical(list, _servers) && !_userPicked && !_locked) {
        _selected = ServerApi.ranked(list).first;
      }
    });
  }

  void _maybeAutoConnect() {
    if (_autoConnectDone || !_settings.autoConnect) return;
    _autoConnectDone = true;
    if (_idle && !_starting && _selected != null) _startConnection();
  }

  Future<void> _refreshIp() async {
    if (_ipLoading || !mounted) return;
    setState(() => _ipLoading = true);
    final info = await IpInfo.fetch();
    if (!mounted) return;
    setState(() {
      _ip = info;
      _ipLoading = false;
    });
  }

  void _pickServer(VpnServer s) {
    setState(() {
      _selected = s;
      _userPicked = true;
    });
    _settings.lastHost = s.hostName;
  }

  void _pickAuto() {
    setState(() {
      _userPicked = false;
      if (_servers.isNotEmpty) _selected = ServerApi.ranked(_servers).first;
    });
    _settings.lastHost = null;
  }

  void _toggleFavorite(String country) {
    setState(() {
      final f = {..._favorites};
      if (!f.remove(country)) f.add(country);
      _favorites = f;
    });
    _settings.favorites = _favorites;
  }

  // ------------------------------------------------------------------ bağlantı

  void _onStage(String name) {
    if (!mounted) return;
    final changed = name != _stageName;
    setState(() {
      _stageName = name;
      _starting = false;
      if (name == 'connected') _note = null;
    });
    if (!changed) return;

    if (name == 'connected') {
      _watchdog?.cancel();
      if (_settings.haptics) HapticFeedback.lightImpact();
    }
    if (name == 'no_network') _watchdog?.cancel();
    if (name == 'denied') {
      _watchdog?.cancel();
      setState(() => _note = null);
    }
    if (name == 'connected' || name == 'disconnected') {
      _ipTimer?.cancel();
      _ipTimer = Timer(const Duration(milliseconds: 1200), _refreshIp);
    }
    if (_failureStages.contains(name)) _handleFailure();
  }

  Future<void> _onPowerTap() async {
    if (_settings.haptics) HapticFeedback.mediumImpact();
    if (_locked) {
      await _disconnect(byUser: true);
      return;
    }
    await _startConnection();
  }

  Future<void> _startConnection() async {
    final target = _selected;
    if (target == null) {
      _snack(_loading
          ? 'Sunucular yükleniyor, bir saniye…'
          : 'Sunucu bulunamadı. Ayarlar\'dan listeyi yenile.');
      return;
    }
    _attempt = 0;
    _tried.clear();
    _userCancelled = false;
    setState(() => _note = null);
    await _connectTo(target);
  }

  Future<void> _connectTo(VpnServer s) async {
    if (!mounted) return;
    _attempt++;
    _tried.add(s.hostName);
    setState(() {
      _selected = s;
      _starting = true;
    });
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 16), _handleFailure);

    try {
      final started = await _engine.connect(
        ServerApi.prepareConfig(s.config),
        'ShadeX • ${s.countryLong}',
        username: ServerApi.username,
        password: ServerApi.password,
      );
      if (started == false) {
        _watchdog?.cancel();
        if (!mounted) return;
        setState(() {
          _starting = false;
          _note = null;
        });
        _snack('VPN izni verilmedi.');
      }
    } catch (_) {
      _handleFailure();
    }
  }

  /// Bağlantı kurulamadı: ayara göre sıradaki en iyi sunucuyu dener.
  Future<void> _handleFailure() async {
    _watchdog?.cancel();
    if (!mounted || _userCancelled || _connected) return;

    VpnServer? next;
    if (_settings.autoSwitch && _attempt < _maxAttempts) {
      final current = _selected;
      final candidates = ServerApi.ranked(_servers)
          .where((s) => !_tried.contains(s.hostName) && !s.unreachable)
          .toList();
      if (_userPicked && current != null) {
        // Elle seçilen ülke varsa önce o ülkede kal.
        for (final s in candidates) {
          if (s.countryShort == current.countryShort) {
            next = s;
            break;
          }
        }
      }
      next ??= candidates.isEmpty ? null : candidates.first;
    }

    if (next == null) {
      try {
        await _engine.disconnect();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _starting = false;
        _note = null;
      });
      _snack('Bağlanılamadı. Başka bir ülke seçip tekrar dene.');
      return;
    }

    setState(() {
      _note = 'Daha hızlı sunucu deneniyor (${_attempt + 1}/$_maxAttempts)';
      _starting = true;
    });
    try {
      await _engine.disconnect();
    } catch (_) {}
    if (!mounted || _userCancelled) return;
    await _connectTo(next);
  }

  Future<void> _disconnect({bool byUser = false}) async {
    if (byUser) _userCancelled = true;
    _watchdog?.cancel();
    setState(() {
      _starting = false;
      _note = null;
    });
    try {
      await _engine.disconnect();
    } catch (_) {}
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          settings: _settings,
          onOpenSystemVpn: _openSystemVpn,
          onRefreshServers: _loadServers,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _favorites = _settings.favorites);
    await _initEngine(); // bildirim ve kapanış ayarlarını uygula
  }

  Future<void> _openSystemVpn() async {
    try {
      final ok = await _engine.openVpnSettings();
      if (ok == false) _snack('Android VPN ayarları açılamadı.');
    } catch (_) {
      _snack('Android VPN ayarları açılamadı.');
    }
  }

  // --------------------------------------------------------------- yardımcılar

  static String _fmtBytes(num? n, {bool perSecond = false}) {
    var v = (n ?? 0).toDouble();
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    final text = '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
    return perSecond ? '$text/s' : text;
  }

  String get _stageLabel {
    if (_note != null) return _note!;
    if (_starting && _idle) return 'Bağlanıyor';
    return _stageTr[_stageName] ?? 'Bağlanıyor';
  }

  Color get _accent {
    if (_connected) return AppColors.green;
    if (_busy) return AppColors.amber;
    if (_failureStages.contains(_stageName) || _stageName == 'denied') {
      return AppColors.red;
    }
    return AppColors.violet;
  }

  // ------------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final buttonSize = math
        .min(size.width * 0.5, size.height * 0.27)
        .clamp(140.0, 220.0)
        .toDouble();
    final accent = _accent;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.bg,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.35),
                    radius: 0.95,
                    colors: [accent.withAlpha(60), AppColors.bg],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                      child: Column(
                        children: [
                          _header(),
                          const SizedBox(height: 14),
                          StatusPill(text: _stageLabel, color: accent),
                          const Spacer(),
                          const SizedBox(height: 16),
                          PowerButton(
                            size: buttonSize,
                            color: accent,
                            connected: _connected,
                            busy: _busy,
                            onTap: _onPowerTap,
                          ),
                          const SizedBox(height: 8),
                          _timerArea(),
                          const Spacer(),
                          const SizedBox(height: 16),
                          _ipCard(),
                          const SizedBox(height: 12),
                          _statsRow(),
                          const SizedBox(height: 12),
                          _serverCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Image.asset('assets/logo/logo.png', width: 40, height: 40),
        const SizedBox(width: 10),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const GradientText(
                  'ShadeX',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'VPN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Colors.white.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Ayarlar',
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_rounded),
        ),
      ],
    );
  }

  Widget _timerArea() {
    final s = _selected;
    final where = s == null ? '' : '${s.flag} ${s.countryLong}';

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _connected
            ? Column(
                key: const ValueKey('timer'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _status?.duration ?? '00:00:00',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    where,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withAlpha(150),
                    ),
                  ),
                ],
              )
            : Padding(
                key: const ValueKey('hint'),
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _busy
                      ? 'Güvenli tünel kuruluyor…'
                      : 'Korunmak için düğmeye dokun',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(140),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _ipCard() {
    final ip = _ip;
    final String value;
    if (ip == null) {
      value = _ipLoading ? 'Kontrol ediliyor…' : 'Bilinmiyor';
    } else {
      value = [
        ip.flag,
        ip.ip,
        if (ip.country != null) '• ${ip.country}',
      ].join(' ');
    }

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Icon(
            _connected ? Icons.verified_user_rounded : Icons.public_rounded,
            color: _connected ? AppColors.green : Colors.white70,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _connected ? 'Görünen IP adresin' : 'Gerçek IP adresin',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withAlpha(140),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: _ipLoading
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: 'IP adresini yenile',
                    onPressed: _refreshIp,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    final st = _status;
    final on = _connected && st != null;
    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: Icons.arrow_downward_rounded,
            label: 'İndirme',
            value: _fmtBytes(on ? int.tryParse(st?.byteIn ?? '') : 0),
            sub: on ? _fmtBytes(st?.speedIn, perSecond: true) : null,
            color: AppColors.cyan,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            icon: Icons.arrow_upward_rounded,
            label: 'Yükleme',
            value: _fmtBytes(on ? int.tryParse(st?.byteOut ?? '') : 0),
            sub: on ? _fmtBytes(st?.speedOut, perSecond: true) : null,
            color: AppColors.pink,
          ),
        ),
      ],
    );
  }

  Widget _serverCard() {
    final s = _selected;
    Widget leading;
    String title;
    String subtitle;
    VoidCallback? onTap;
    Widget? trailing;

    if (s == null && _loading) {
      leading = const SizedBox(
        width: 44,
        height: 44,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
      title = 'Sunucular hazırlanıyor…';
      subtitle = 'Bir saniye';
    } else if (s == null) {
      leading = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.red.withAlpha(30),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.cloud_off_rounded, color: AppColors.red),
      );
      title = 'Sunuculara ulaşılamadı';
      subtitle = _error != null
          ? 'İnternetini kontrol et • tekrar denemek için dokun'
          : 'Tekrar denemek için dokun';
      onTap = _loadServers;
    } else {
      leading = FlagBadge(s.flag);
      title = _userPicked ? s.countryLong : 'En hızlı sunucu';
      if (_locked) {
        subtitle = _userPicked
            ? 'Değiştirmek için bağlantıyı kes'
            : '${s.countryLong} • değiştirmek için bağlantıyı kes';
      } else if (_measuring) {
        subtitle = 'Hızlar ölçülüyor…';
      } else {
        subtitle = _userPicked
            ? '${s.speedText} • dokun ve değiştir'
            : '${s.countryLong} • otomatik seçildi';
      }
      trailing = PingBadge(s.displayPing, offline: s.unreachable);
      onTap = _locked ? null : _openServerPicker;
    }

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withAlpha(140),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.chevron_right_rounded),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ sunucu seçici

  static int _pingKey(VpnServer s) {
    if (s.unreachable) return 1 << 30;
    final p = s.displayPing;
    return p > 0 ? p : (1 << 29);
  }

  void _openServerPicker() {
    if (_servers.isEmpty) {
      _loadServers();
      return;
    }
    var query = '';
    var tab = 0; // 0 önerilen, 1 en hızlı, 2 en düşük ping, 3 favoriler
    const tabs = ['Önerilen', 'En hızlı', 'En düşük ping', '★ Favoriler'];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final q = query.trim().toLowerCase();
            Iterable<VpnServer> src = _servers.where((s) =>
                q.isEmpty ||
                s.countryLong.toLowerCase().contains(q) ||
                s.countryShort.toLowerCase() == q);
            if (tab == 3) {
              src = src.where((s) => _favorites.contains(s.countryShort));
            }
            List<VpnServer> list;
            if (tab == 1) {
              list = src.toList()
                ..sort((a, b) {
                  if (a.unreachable != b.unreachable) {
                    return a.unreachable ? 1 : -1;
                  }
                  return b.speed.compareTo(a.speed);
                });
            } else if (tab == 2) {
              list = src.toList()
                ..sort((a, b) => _pingKey(a).compareTo(_pingKey(b)));
            } else {
              list = ServerApi.ranked(src);
            }

            void pick(VoidCallback action) {
              action();
              Navigator.of(sheetContext).pop();
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (ctx, controller) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Konum seç',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (_measuring)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          Text(
                            '${list.length} sunucu',
                            style: TextStyle(
                              color: Colors.white.withAlpha(130),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (v) => setSheet(() => query = v),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: 'Ülke ara: Japan, Korea, US…',
                          filled: true,
                          fillColor: Colors.white.withAlpha(14),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: tabs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ChoiceChip(
                          label: Text(tabs[i]),
                          selected: tab == i,
                          onSelected: (_) => setSheet(() => tab = i),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                        itemCount: list.length + 1,
                        itemBuilder: (ctx, i) {
                          if (i == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                highlight: _userPicked ? null : AppColors.amber,
                                padding: const EdgeInsets.all(12),
                                onTap: () => pick(_pickAuto),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.bolt_rounded,
                                      color: AppColors.amber,
                                      size: 30,
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'En hızlı sunucu',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            'Sana en yakın ve en hızlı olanı otomatik seçer',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_userPicked)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.green,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }
                          final s = list[i - 1];
                          final selected =
                              _userPicked && _selected?.hostName == s.hostName;
                          final fav = _favorites.contains(s.countryShort);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Opacity(
                              opacity: s.unreachable ? 0.5 : 1,
                              child: GlassCard(
                                highlight: selected ? AppColors.violet : null,
                                padding:
                                    const EdgeInsets.fromLTRB(10, 6, 2, 6),
                                onTap: () => pick(() => _pickServer(s)),
                                child: Row(
                                  children: [
                                    FlagBadge(s.flag, size: 42),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.countryLong,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            '${s.speedText} • ${s.sessions} kişi',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  Colors.white.withAlpha(130),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    PingBadge(
                                      s.displayPing,
                                      offline: s.unreachable,
                                    ),
                                    IconButton(
                                      tooltip: fav
                                          ? 'Favorilerden çıkar'
                                          : 'Favorilere ekle',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => setSheet(
                                        () => _toggleFavorite(s.countryShort),
                                      ),
                                      icon: Icon(
                                        fav
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        color: fav
                                            ? AppColors.amber
                                            : Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
