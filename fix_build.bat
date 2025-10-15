@echo off
echo ==========================================
echo  Permission Handler Build Fix
echo ==========================================

echo.
echo [1/6] Stopping all processes...
taskkill /F /IM java.exe 2>nul
taskkill /F /IM dart.exe 2>nul
taskkill /F /IM flutter.exe 2>nul
taskkill /F /IM adb.exe 2>nul
taskkill /F /IM qemu-system-x86_64.exe 2>nul
timeout /t 2 >nul

echo.
echo [2/6] Deleting build folder...
rd /s /q build 2>nul
rd /s /q android\app\build 2>nul
rd /s /q android\.gradle 2>nul

echo.
echo [3/6] Cleaning Gradle cache...
rd /s /q %USERPROFILE%\.gradle\caches\transforms-3 2>nul
rd /s /q %USERPROFILE%\.gradle\caches\transforms-4 2>nul

echo.
echo [4/6] Flutter clean...
call flutter clean

echo.
echo [5/6] Getting packages...
call flutter pub get

echo.
echo [6/6] Starting app...
call flutter run -d emulator-5554

pause