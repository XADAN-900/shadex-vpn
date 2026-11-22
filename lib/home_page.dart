import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ip_info.dart';
import 'theme.dart';
import 'vpngate.dart';
import 'widgets.dart';

const Map<String, String> _stageTr = {
  'prepare': 'Hazırlanıyor',
  'vpn_generate_config': 'Yapılandırma hazırlanıyor',
  'resolve': 'Adres çözülüyor',
  'tcp_connect': 'Sunucuya bağlanılıyor',
  'udp_connect': 'Sunucuya bağlanılıyor',
  'wait_connection': 'Sunucu bekleniyor',
  'authenticating': 'Kimlik doğrulanıyor',
  'authentication': 'Kimlik doğrulanıyor',
  'get_config': 'Ayarlar alınıyor',
  'assign_ip': 'IP adresi alınıyor',
  'add_routes': 'Yönlendirme ekleniyor',
  'connecting': 'Bağlanıyor',
  'connected': 'Korumalı • Bağlı',
  'reconnect': 'Yeniden bağlanıyor',
  'no_network': 'İnternet bağlantısı yok',
  'paused': 'Duraklatıldı',
  'auth_pending': 'Doğrulama bekleniyor',
  'disconnecting': 'Bağlantı kesiliyor',
  'exiting': 'Korumasız',
  'disconnected': 'Korumasız',
  'denied': 'VPN izni verilmedi',
  'auth_failed': 'Kimlik doğrulama başarısız',
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

const _errorStages = {'denied', 'error', 'auth_failed'};

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final OpenVPN _engine;
  SharedPreferences? _prefs;

  String _stageName = 'disconnected';
  Object? _status; // VpnStatus
  bool _starting = false;
  Timer? _startTimeout;

  List<VpnServer> _servers = [];
  VpnServer? _selected;
  bool _loading = true;
  String? _error;

  String? _customConfig;
  String _customUser = '';
  String _customPass = '';
  bool _useCustom = false;

  IpInfo? _ip;
  bool _ipLoading = false;
  Timer? _ipTimer;

  bool get _connected => _stageName == 'connected';
  bool get _idle => _idleStages.contains(_stageName);
  bool get _busy => _starting || (!_idle && !_connected);
  bool get _locked => _connected || _busy;

  // ------------------------------------------------------------- yaşam döngüsü

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
    _engine.initialize(
      groupIdentifier: 'group.com.shadex.vpn',
      providerBundleIdentifier: 'com.shadex.shadex_vpn.VPNExtension',
      localizedDescription: 'ShadeX VPN',
      lastStage: (stage) => _onStage(stage.name),
      lastStatus: (status) {
        if (mounted) setState(() => _status = status);
      },
      showTrafficInNotification: true,
      disconnectOnTaskRemoved: false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      if (mounted) {
        setState(() {
          _customConfig = p.getString('custom_config');
          _customUser = p.getString('custom_user') ?? '';
          _customPass = p.getString('custom_pass') ?? '';
          _useCustom = _customConfig != null && (p.getBool('use_custom') ?? false);
        });
      }
    } catch (_) {}
    _refreshIp();
    await _loadServers();
  }

  @override
  void dispose() {
    _startTimeout?.cancel();
    _ipTimer?.cancel();
    super.dispose();
  }

  void _onStage(String name) {
    if (!mounted) return;
    final changed = name != _stageName;
    setState(() {
      _stageName = name;
      _starting = false;
    });
    if (changed && (name == 'connected' || name == 'disconnected')) {
      _ipTimer?.cancel();
      _ipTimer = Timer(const Duration(milliseconds: 1500), _refreshIp);
    }
    if (changed && _errorStages.contains(name)) {
      _snack('${_stageTr[name] ?? name}. Başka bir sunucu dene.');
    }
  }

  // --------------------------------------------------------------------- veri

  Future<void> _loadServers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await VpnGateApi.fetchServers();
      if (!mounted) return;
      final wanted = _selected?.hostName ?? _prefs?.getString('last_host');
      setState(() {
        _servers = list;
        _selected = list.isEmpty
            ? null
            : list.firstWhere(
                (s) => s.hostName == wanted,
                orElse: () => list.first,
              );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshIp() async {
    if (_ipLoading) return;
    setState(() => _ipLoading = true);
    final info = await IpInfo.fetch();
    if (!mounted) return;
    setState(() {
      _ip = info;
      _ipLoading = false;
    });
  }

  void _selectServer(VpnServer s) {
    setState(() {
      _selected = s;
      _useCustom = false;
    });
    _prefs?.setString('last_host', s.hostName);
    _prefs?.setBool('use_custom', false);
  }

  // ----------------------------------------------------------------- bağlantı

  Future<void> _toggle() async {
    HapticFeedback.mediumImpact();
    if (_locked) {
      _startTimeout?.cancel();
      setState(() => _starting = false);
      try {
        await _engine.disconnect();
      } catch (_) {}
      return;
    }

    final config = _useCustom ? _customConfig : _selected?.config;
    if (config == null) {
      _snack(_loading ? 'Sunucular yükleniyor, biraz bekle.' : 'Önce bir sunucu seç.');
      return;
    }

    final name = _useCustom
        ? 'ShadeX • Özel sunucu'
        : 'ShadeX • ${_selected!.countryLong}';

    setState(() => _starting = true);
    _startTimeout?.cancel();
    _startTimeout = Timer(const Duration(seconds: 30), () {
      if (mounted && _starting) setState(() => _starting = false);
    });

    try {
      final started = await _engine.connect(
        VpnGateApi.prepareConfig(config),
        name,
        username: _useCustom && _customUser.isNotEmpty ? _customUser : null,
        password: _useCustom && _customPass.isNotEmpty ? _customPass : null,
      );
      if (started == false) {
        _snack('VPN izni verilmedi.');
        if (mounted) setState(() => _starting = false);
      }
    } on PlatformException catch (e) {
      _snack('Yapılandırma hatalı: ${e.message ?? e.code}');
      if (mounted) setState(() => _starting = false);
    } catch (e) {
      _snack('Bağlanılamadı: $e');
      if (mounted) setState(() => _starting = false);
    }
  }

  void _quickConnect() {
    if (_servers.isEmpty) return;
    _selectServer(_servers.first);
    _toggle();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // --------------------------------------------------------------- yardımcılar

  /// VpnStatus alanlarını sürümden bağımsız okur (alan yoksa null).
  String? _statusValue(Object? Function(dynamic s) read) {
    final s = _status;
    if (s == null) return null;
    try {
      return read(s)?.toString();
    } catch (_) {
      return null;
    }
  }

  static String _fmtBytes(String? v, {bool perSecond = false}) {
    var n = double.tryParse(v ?? '') ?? 0;
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    while (n >= 1024 && i < units.length - 1) {
      n /= 1024;
      i++;
    }
    final text = '${n.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
    return perSecond ? '$text/s' : text;
  }

  String get _stageLabel {
    if (_starting && _idle) return 'Bağlanıyor';
    return _stageTr[_stageName] ?? _stageName;
  }

  Color get _accent {
    if (_connected) return AppColors.green;
    if (_busy) return AppColors.amber;
    if (_errorStages.contains(_stageName)) return AppColors.red;
    return AppColors.violet;
  }

  // ----------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final buttonSize =
        math.min(size.width * 0.5, size.height * 0.27)
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
                            onTap: _toggle,
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
          tooltip: 'Sunucuları yenile',
          onPressed: _loading ? null : _loadServers,
          icon: const Icon(Icons.refresh_rounded),
        ),
        PopupMenuButton<String>(
          tooltip: 'Menü',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (v) {
            if (v == 'custom') _openCustomDialog();
            if (v == 'about') _showAbout();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'custom',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.description_outlined),
                title: Text('Kendi .ovpn dosyan'),
              ),
            ),
            PopupMenuItem(
              value: 'about',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Hakkında'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _timerArea() {
    final duration = _statusValue((s) => s.duration);
    final where = _useCustom
        ? 'Özel sunucu'
        : (_selected != null ? '${_selected!.flag} ${_selected!.countryLong}' : '');

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
                    duration ?? '00:00:00',
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
                  _connected ? 'Görünen IP (VPN)' : 'Gerçek IP adresin',
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
    final byteIn = _statusValue((s) => s.byteIn);
    final byteOut = _statusValue((s) => s.byteOut);
    final speedIn = _statusValue((s) => s.speedIn);
    final speedOut = _statusValue((s) => s.speedOut);
    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: Icons.arrow_downward_rounded,
            label: 'İndirme',
            value: _connected ? _fmtBytes(byteIn) : '0 B',
            sub: _connected && speedIn != null
                ? _fmtBytes(speedIn, perSecond: true)
                : null,
            color: AppColors.cyan,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            icon: Icons.arrow_upward_rounded,
            label: 'Yükleme',
            value: _connected ? _fmtBytes(byteOut) : '0 B',
            sub: _connected && speedOut != null
                ? _fmtBytes(speedOut, perSecond: true)
                : null,
            color: AppColors.pink,
          ),
        ),
      ],
    );
  }

  Widget _serverCard() {
    Widget leading;
    String title;
    String subtitle;
    VoidCallback? onTap;
    Widget? trailing;

    if (_useCustom) {
      leading = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(16),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.description_outlined),
      );
      title = 'Özel sunucu';
      subtitle = _locked ? 'Değiştirmek için bağlantıyı kes' : 'Kendi .ovpn dosyan';
      onTap = _locked ? null : _openServerPicker;
    } else if (_loading && _servers.isEmpty) {
      leading = const SizedBox(
        width: 44,
        height: 44,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
      title = 'Sunucular yükleniyor…';
      subtitle = 'Ücretsiz VPN Gate sunucuları';
    } else if (_servers.isEmpty || _selected == null) {
      leading = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.red.withAlpha(30),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.cloud_off_rounded, color: AppColors.red),
      );
      title = 'Sunucu listesi alınamadı';
      subtitle = 'Tekrar denemek için dokun';
      onTap = _loadServers;
    } else {
      final s = _selected!;
      leading = FlagBadge(s.flag);
      title = s.countryLong;
      subtitle = _locked
          ? 'Değiştirmek için bağlantıyı kes'
          : '${s.speedText} • ${_servers.length} sunucu';
      trailing = PingBadge(s.ping);
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

  // ----------------------------------------------------------- sunucu seçici

  static int _pingKey(VpnServer s) => s.ping > 0 ? s.ping : 1 << 30;

  void _openServerPicker() {
    if (_servers.isEmpty) {
      _loadServers();
      return;
    }
    var query = '';
    var sort = 0; // 0: önerilen, 1: en hızlı, 2: en düşük ping
    const sortLabels = ['Önerilen', 'En hızlı', 'En düşük ping'];

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
            final list = _servers
                .where((s) =>
                    q.isEmpty ||
                    s.countryLong.toLowerCase().contains(q) ||
                    s.countryShort.toLowerCase() == q ||
                    s.hostName.toLowerCase().contains(q))
                .toList();
            if (sort == 1) {
              list.sort((a, b) => b.speed.compareTo(a.speed));
            } else if (sort == 2) {
              list.sort((a, b) => _pingKey(a).compareTo(_pingKey(b)));
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.85,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                builder: (ctx, controller) => Column(
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
                              'Sunucu seç',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
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
                        itemCount: sortLabels.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ChoiceChip(
                          label: Text(sortLabels[i]),
                          selected: sort == i,
                          onSelected: (_) => setSheet(() => sort = i),
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
                                highlight: AppColors.amber,
                                padding: const EdgeInsets.all(12),
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  _quickConnect();
                                },
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      color: AppColors.amber,
                                      size: 30,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Hızlı bağlan',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            'En iyi sunucuyu seçip hemen bağlanır',
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
                                  ],
                                ),
                              ),
                            );
                          }
                          final s = list[i - 1];
                          final selected =
                              !_useCustom && _selected?.hostName == s.hostName;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassCard(
                              highlight: selected ? AppColors.violet : null,
                              padding: const EdgeInsets.all(10),
                              onTap: () {
                                _selectServer(s);
                                Navigator.of(sheetContext).pop();
                              },
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
                                          '${s.speedText} • ${s.sessions} bağlantı',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withAlpha(130),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PingBadge(s.ping),
                                  if (selected)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.green,
                                        size: 20,
                                      ),
                                    ),
                                ],
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

  // ------------------------------------------------------------ özel .ovpn

  Future<void> _openCustomDialog() async {
    if (_locked) {
      _snack('Önce bağlantıyı kes.');
      return;
    }
    final configCtrl = TextEditingController(text: _customConfig ?? '');
    final userCtrl = TextEditingController(text: _customUser);
    final passCtrl = TextEditingController(text: _customPass);

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: AppColors.surface,
        title: const Text('Kendi .ovpn dosyan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '.ovpn dosyasını bir metin düzenleyiciyle aç, içeriğin tamamını '
              'kopyalayıp aşağıya yapıştır.',
              style: TextStyle(color: Colors.white.withAlpha(170), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: configCtrl,
              minLines: 6,
              maxLines: 10,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'client\ndev tun\nremote ...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(
                labelText: 'Kullanıcı adı (gerekiyorsa)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre (gerekiyorsa)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          if (_customConfig != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'clear'),
              child: const Text('Sil'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Kullan'),
          ),
        ],
      ),
    );

    if (!mounted || action == null) return;
    final p = _prefs;

    if (action == 'clear' || configCtrl.text.trim().isEmpty) {
      setState(() {
        _customConfig = null;
        _useCustom = false;
      });
      await p?.remove('custom_config');
      await p?.remove('custom_user');
      await p?.remove('custom_pass');
      await p?.setBool('use_custom', false);
      return;
    }

    final text = configCtrl.text.trim();
    if (!text.contains('remote ')) {
      _snack('Bu geçerli bir OpenVPN dosyası gibi durmuyor ("remote" satırı yok).');
      return;
    }
    setState(() {
      _customConfig = text;
      _customUser = userCtrl.text.trim();
      _customPass = passCtrl.text;
      _useCustom = true;
    });
    await p?.setString('custom_config', text);
    await p?.setString('custom_user', _customUser);
    await p?.setString('custom_pass', _customPass);
    await p?.setBool('use_custom', true);
    _snack('Özel sunucu seçildi.');
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'ShadeX VPN',
      applicationVersion: '1.0.0',
      applicationIcon: Image.asset('assets/logo/logo.png', width: 52, height: 52),
      children: const [
        Text(
          'Açık kaynaklı, ücretsiz VPN.\n\n'
          'Sunucular, Tsukuba Üniversitesi\'nin VPN Gate projesindeki gönüllü '
          'sunuculardır. Operatörler bağlantı kayıtlarını bir süre tuttuğu için '
          'tam anonimlik için uygun değildir.\n\n'
          'Bağlantı motoru: OpenVPN (ics-openvpn).',
        ),
      ],
    );
  }
}
