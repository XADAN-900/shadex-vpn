import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
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
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Ayarlar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _section('Bağlantı'),
          _card([
            _switch(
              icon: Icons.flash_on_rounded,
              title: 'Açılışta otomatik bağlan',
              subtitle: 'Uygulama açılınca en hızlı sunucuya bağlanır',
              value: s.autoConnect,
              onChanged: (v) => s.autoConnect = v,
            ),
            _switch(
              icon: Icons.alt_route_rounded,
              title: 'Akıllı sunucu değiştirme',
              subtitle: 'Bağlantı kurulamazsa sıradaki en iyi sunucuyu dener',
              value: s.autoSwitch,
              onChanged: (v) => s.autoSwitch = v,
            ),
            _switch(
              icon: Icons.close_fullscreen_rounded,
              title: 'Kapatınca bağlantıyı kes',
              subtitle: 'Uygulama son kullanılanlardan silinince VPN kapanır',
              value: s.disconnectOnClose,
              onChanged: (v) => s.disconnectOnClose = v,
            ),
          ]),
          _section('Güvenlik'),
          _card([
            _tile(
              icon: Icons.shield_moon_outlined,
              title: 'Kill Switch ve Her zaman açık VPN',
              subtitle:
                  'Android ayarlarında ShadeX için ikisini de aç: VPN koparsa internet kesilir',
              onTap: () => widget.onOpenSystemVpn(),
            ),
          ]),
          _section('Görünüm'),
          _card([
            _switch(
              icon: Icons.speed_rounded,
              title: 'Bildirimde hızı göster',
              subtitle: 'İndirme ve yükleme hızını bildirimde gösterir',
              value: s.trafficInNotification,
              onChanged: (v) => s.trafficInNotification = v,
            ),
            _switch(
              icon: Icons.vibration_rounded,
              title: 'Titreşim',
              subtitle: 'Düğmeye basınca hafif titreşir',
              value: s.haptics,
              onChanged: (v) => s.haptics = v,
            ),
          ]),
          _section('Sunucular'),
          _card([
            _tile(
              icon: Icons.refresh_rounded,
              title: 'Sunucu listesini yenile',
              subtitle: 'Listeyi indirir ve hızları yeniden ölçer',
              onTap: () {
                widget.onRefreshServers();
                Navigator.of(context).pop();
              },
            ),
            _tile(
              icon: Icons.star_outline_rounded,
              title: 'Favori ülkeleri temizle',
              onTap: () {
                s.favorites = <String>{};
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Favoriler temizlendi.')),
                );
              },
            ),
          ]),
          _section('Hakkında'),
          _card([
            _tile(
              icon: Icons.privacy_tip_outlined,
              title: 'Gizlilik',
              onTap: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text('Gizlilik'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'ShadeX hesap istemez, kişisel veri toplamaz ve '
                      'reklam göstermez.\n\n'
                      'Trafiğin, seçtiğin ülkedeki sunucuya şifreli tünelle '
                      'gider. Sunucular gönüllü operatörlerce işletilir ve '
                      'bağlantı kayıtları bir süre tutulabilir. Bu yüzden '
                      'ShadeX, engelleri aşmak ve halka açık Wi-Fi\'da '
                      'korunmak için uygundur; tam anonimlik gerektiren '
                      'işler için uygun değildir.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tamam'),
                    ),
                  ],
                ),
              ),
            ),
            _tile(
              icon: Icons.code_rounded,
              title: 'Açık kaynak lisansları',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'ShadeX VPN',
                applicationVersion: '1.1.0',
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
            const ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('Sürüm'),
              trailing: Text('1.1.0'),
            ),
          ]),
        ],
      ),
    );
  }
}
