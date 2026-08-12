@echo off
:: TEMA Market - Flutter Build Script
:: Bu script Masaüstü yolundaki Unicode sorununun kalıcı workaround'u.
:: impellerc.exe (Flutter shader compiler) Türkçe karakter içeren path'lerde crash yapıyor.
:: C:\temasan junction'ı kullanarak ASCII path üzerinden build alınır.

echo.
echo  ████████╗███████╗███╗   ███╗ █████╗ 
echo     ██╔══╝██╔════╝████╗ ████║██╔══██╗
echo     ██║   █████╗  ██╔████╔██║███████║
echo     ██║   ██╔══╝  ██║╚██╔╝██║██╔══██║
echo     ██║   ███████╗██║ ╚═╝ ██║██║  ██║
echo     ╚═╝   ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝
echo.
echo  TEMA Market Flutter Build Tool
echo  ================================
echo.

:: JAVA_HOME ayarla
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr

:: Junction kontrol et, yoksa oluştur
if not exist "C:\temasan" (
    echo [*] Junction oluşturuluyor: C:\temasan ...
    mklink /J "C:\temasan" "%~dp0"
    echo [OK] Junction oluşturuldu.
) else (
    echo [OK] Junction mevcut: C:\temasan
)
echo.

:: Argüman yoksa menü göster
if "%1"=="" (
    echo Seçenek:
    echo   1  -  APK Debug Build
    echo   2  -  APK Release Build
    echo   3  -  APK Debug + Telefona Kur
    echo   4  -  Windows'ta Çalıştır
    echo   5  -  Chrome'da Çalıştır
    echo   6  -  Flutter Clean
    echo.
    set /p CHOICE="Seçim (1-6): "
) else (
    set CHOICE=%1
)

echo.
if "%CHOICE%"=="1" goto build_debug
if "%CHOICE%"=="2" goto build_release
if "%CHOICE%"=="3" goto install_debug
if "%CHOICE%"=="4" goto run_windows
if "%CHOICE%"=="5" goto run_chrome
if "%CHOICE%"=="6" goto clean
goto build_debug

:build_debug
echo [*] Debug APK build ediliyor...
cd /d "C:\temasan"
flutter build apk --debug
echo.
echo [OK] APK: build\app\outputs\flutter-apk\app-debug.apk
goto end

:build_release
echo [*] Release APK build ediliyor...
cd /d "C:\temasan"
flutter build apk --release
echo.
echo [OK] APK: build\app\outputs\flutter-apk\app-release.apk
goto end

:install_debug
echo [*] Debug APK build edilip telefona kuruluyor...
cd /d "C:\temasan"
flutter run --release
goto end

:run_windows
echo [*] Windows uygulaması başlatılıyor...
cd /d "C:\temasan"
flutter run -d windows
goto end

:run_chrome
echo [*] Chrome'da başlatılıyor...
cd /d "C:\temasan"
flutter run -d chrome
goto end

:clean
echo [*] Build cache temizleniyor...
cd /d "C:\temasan"
flutter clean
flutter pub get
echo [OK] Temizlendi.
goto end

:end
echo.
pause
