@echo off
rem Windows: APK derler.
cd /d "%~dp0"
call flutter create --platforms=android --org com.shadex --project-name shadex_vpn . || goto :hata
call flutter pub get || goto :hata
call dart run flutter_launcher_icons || goto :hata
call dart run tool\android_kur.dart || goto :hata
call flutter build apk --release || goto :hata
echo.
echo APK hazir: build\app\outputs\flutter-apk\app-release.apk
pause
exit /b 0
:hata
echo HATA olustu, yukaridaki mesaja bak.
pause
exit /b 1
