<p align="center">
  <img src="assets/logo/icon.png" width="140" alt="ShadeX VPN logosu">
</p>

<h1 align="center">ShadeX VPN</h1>

<p align="center">Açık kaynaklı, ücretsiz, reklamsız Android VPN. Flutter ile yazıldı.</p>

<p align="center">
  <a href="../../releases/latest"><b>⬇️ Son APK'yı indir</b></a>
</p>

## Özellikler

- **Ücretsiz ve reklamsız:** dünyanın dört bir yanında sunucu, kayıt yok, hesap yok.
- **Hızlı bağlantı:** sunucuların gerçek hızını cihazından ölçer, en hızlısını otomatik seçer. Bağlantı kurulamazsa sıradaki en iyi sunucuyu kendisi dener.
- **Hız testi:** bağlanınca tünelin gerçek hızını ölçüp gösterir; otomatik seçilen sunucu çok yavaşsa daha hızlısına kendiliğinden geçer.
- **Canlı sunucu değiştirme:** bağlıyken başka ülke seç, bağlantıyı kesmeden geçsin.
- **Yalnızca çalışan sunucular:** her sunucuya gerçek VPN el sıkışması denenir; cevap vermeyenler listede hiç görünmez. Liste 2 dakikada bir arka planda yenilenir, bağlanmadan hemen önce seçilen sunucu yeniden doğrulanır.
- **Seçtiğin ülkede kalır:** elle seçilen ülkede bir sunucu çalışmazsa yalnızca o ülkenin diğer sunucuları denenir.
- **Tek dokunuş:** büyük bağlan düğmesi; bağlıyken nabız animasyonu, süre sayacı, indirme ve yükleme miktarı ile hızı.
- **Konum seçici:** ülke arama; *Önerilen / En hızlı / En düşük ping / Favoriler* sekmeleri; renkli ping rozetleri; favori ülkeler.
- **IP kontrolü:** bağlanmadan önce gerçek IP'ni, bağlandıktan sonra VPN IP'sini ve ülkesini gösterir.
- **Ayarlar:** açılışta otomatik bağlan, akıllı sunucu değiştirme, kapatınca bağlantıyı kes, bildirimde hız, titreşim, Kill Switch kısayolu.
- **Hızlı açılış:** sunucu listesi önbellekten anında gelir, arka planda güncellenir.
- **Hızlı DNS:** siteler daha hızlı açılır, DNS sızıntısı önlenir (ayarlardan kapatılabilir).
- **7 dil:** Türkçe, English, Français, Español, Português, Русский, العربية (sağdan sola destekli). Uygulama telefonun dilinde açılır; desteklenmeyen dillerde İngilizce.
- **Taşma yok:** ana ekran kaymaz, her ekran boyutuna kendini sığdırır; büyük yazı boyutunda düzen bozulmaz.

## APK

Her `main` gönderiminde GitHub Actions APK'yı derler ve **Releases** sayfasına koyar.

Elle derlemek istersen ([Flutter](https://docs.flutter.dev/get-started/install) ve Android SDK gerekir): Windows'ta `kur.bat`, Linux/macOS'ta `./kur.sh`.

```bash
flutter create --platforms=android --org com.shadex --project-name shadex_vpn .
flutter pub get
dart run flutter_launcher_icons
dart run tool/android_kur.dart
flutter build apk --release
```

`android/` klasörü bilerek repoda yok. `flutter create` onu üretiyor, `tool/android_kur.dart` de VPN için gerekenleri ekliyor: izinler, native kütüphane ayarı, sunucu listesi için HTTP izni, bildirim ikonu.

## Bilmen gerekenler

- Sunucular gönüllü operatörlerce işletilir; hızları değişebilir. Uygulama bağlanamadığı sunucuda beklemez, sıradakine geçer.
- Operatörler bağlantı kayıtlarını bir süre tutar. Uygulama engelli siteleri açmak ve genel kullanım için uygundur, **tam anonimlik için uygun değildir**.

## Lisans

Kod MIT lisanslıdır. APK içindeki OpenVPN ve ics-openvpn bileşenleri GPLv2 lisanslıdır.
