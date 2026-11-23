import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';
import 'theme.dart';

const appVersion = '1.4.0';
const shareLink =
    'https://github.com/XADAN-900/shadex-vpn/releases/latest/download/ShadeX-VPN.apk';

/// Kullanıcı ayarları (SharedPreferences'ta saklanır).
class AppSettings {
  AppSettings(this._p);

  final SharedPreferences? _p;

  bool _get(String k, bool d) => _p?.getBool(k) ?? d;
  Future<void> _set(String k, bool v) async => _p?.setBool(k, v);

  /// Uygulama açılınca en iyi sunucuya otomatik bağlan.
  bool get autoConnect => _get('auto_connect', false);
  set autoConnect(bool v) => _set('auto_connect', v);

  /// Bağlantı kurulamazsa sıradaki sunucuyu otomatik dene.
  bool get autoSwitch => _get('auto_switch', true);
  set autoSwitch(bool v) => _set('auto_switch', v);

  /// Sunucunun DNS'i yerine hızlı genel DNS kullan.
  bool get fastDns => _get('fast_dns', true);
  set fastDns(bool v) => _set('fast_dns', v);

  /// Bildirimde indirme/yükleme hızını göster.
  bool get trafficInNotification => _get('notif_traffic', true);
  set trafficInNotification(bool v) => _set('notif_traffic', v);

  /// Uygulama son kullanılanlardan kaldırılınca bağlantıyı kes.
  bool get disconnectOnClose => _get('kill_on_close', false);
  set disconnectOnClose(bool v) => _set('kill_on_close', v);

  /// Titreşimli geri bildirim.
  bool get haptics => _get('haptics', true);
  set haptics(bool v) => _set('haptics', v);

  /// Favori ülke kodları.
  Set<String> get favorites =>
      (_p?.getStringList('fav_countries') ?? const <String>[]).toSet();
  set favorites(Set<String> v) =>
      _p?.setStringList('fav_countries', v.toList());

  String? get lastHost => _p?.getString('last_host');
  set lastHost(String? v) {
    if (v == null) {
      _p?.remove('last_host');
    } else {
      _p?.setString('last_host', v);
    }
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.onOpenSystemVpn,
    required this.onRefreshServers,
  });

  final AppSettings settings;
  final Future<void> Function() onOpenSystemVpn;
  final VoidCallback onRefreshServers;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppSettings get s => widget.settings;

  Widget _section(String title) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 8),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: Colors.white.withAlpha(120),
          ),
        ),
      );

  Widget _card(List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: children),
          ),
        ),
      );

  Widget _switch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      value: value,
      onChanged: (v) => setState(() => onChanged(v)),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          tr('settings'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _section(tr('sec_connection')),
          _card([
            _switch(
              icon: Icons.flash_on_rounded,
              title: tr('auto_connect'),
              subtitle: tr('auto_connect_d'),
              value: s.autoConnect,
              onChanged: (v) => s.autoConnect = v,
            ),
            _switch(
              icon: Icons.alt_route_rounded,
              title: tr('auto_switch'),
              subtitle: tr('auto_switch_d'),
              value: s.autoSwitch,
              onChanged: (v) => s.autoSwitch = v,
            ),
            _switch(
              icon: Icons.dns_rounded,
              title: tr('fast_dns'),
              subtitle: tr('fast_dns_d'),
              value: s.fastDns,
              onChanged: (v) => s.fastDns = v,
            ),
            _switch(
              icon: Icons.close_fullscreen_rounded,
              title: tr('kill_on_close'),
              subtitle: tr('kill_on_close_d'),
              value: s.disconnectOnClose,
              onChanged: (v) => s.disconnectOnClose = v,
            ),
          ]),
          _section(tr('sec_security')),
          _card([
            _tile(
              icon: Icons.shield_moon_outlined,
              title: tr('kill_switch'),
              subtitle: tr('kill_switch_d'),
              onTap: () => widget.onOpenSystemVpn(),
            ),
          ]),
          _section(tr('sec_appearance')),
          _card([
            _switch(
              icon: Icons.speed_rounded,
              title: tr('notif_speed'),
              subtitle: tr('notif_speed_d'),
              value: s.trafficInNotification,
              onChanged: (v) => s.trafficInNotification = v,
            ),
            _switch(
              icon: Icons.vibration_rounded,
              title: tr('haptics'),
              subtitle: tr('haptics_d'),
              value: s.haptics,
              onChanged: (v) => s.haptics = v,
            ),
          ]),
          _section(tr('sec_servers')),
          _card([
            _tile(
              icon: Icons.refresh_rounded,
              title: tr('refresh_list'),
              subtitle: tr('refresh_list_d'),
              onTap: () {
                widget.onRefreshServers();
                Navigator.of(context).pop();
              },
            ),
            _tile(
              icon: Icons.star_outline_rounded,
              title: tr('clear_favs'),
              onTap: () {
                s.favorites = <String>{};
                _snack(tr('favs_cleared'));
              },
            ),
          ]),
          _section(tr('sec_about')),
          _card([
            _tile(
              icon: Icons.share_rounded,
              title: tr('share_app'),
              subtitle: tr('share_app_d'),
              trailing: const Icon(Icons.copy_rounded, size: 20),
              onTap: () async {
                await Clipboard.setData(const ClipboardData(text: shareLink));
                if (mounted) _snack(tr('link_copied'));
              },
            ),
            _tile(
              icon: Icons.privacy_tip_outlined,
              title: tr('privacy'),
              onTap: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: Text(tr('privacy')),
                  content: SingleChildScrollView(
                    child: Text(tr('privacy_text')),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(tr('ok')),
                    ),
                  ],
                ),
              ),
            ),
            _tile(
              icon: Icons.code_rounded,
              title: tr('licenses'),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'ShadeX VPN',
                applicationVersion: appVersion,
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/logo/logo.png',
                    width: 56,
                    height: 56,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(tr('version')),
              trailing: const Text(appVersion),
            ),
          ]),
        ],
      ),
    );
  }
}
