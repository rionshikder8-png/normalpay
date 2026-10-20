@echo off
setlocal
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter SDK not found. Install Flutter stable and run flutter doctor first.
  exit /b 1
)
call flutter pub get
if errorlevel 1 exit /b 1
if not exist android\gradle\wrapper\gradle-wrapper.jar (
  set SEED=%TEMP%\normal_pay_wrapper_seed
  call flutter create --platforms=android --project-name normal_pay_sms_reader "%TEMP%\normal_pay_wrapper_seed"
  if errorlevel 1 exit /b 1
  copy /Y "%TEMP%\normal_pay_wrapper_seed\android\gradlew" android\gradlew >nul
  copy /Y "%TEMP%\normal_pay_wrapper_seed\android\gradlew.bat" android\gradlew.bat >nul
  copy /Y "%TEMP%\normal_pay_wrapper_seed\android\gradle\wrapper\gradle-wrapper.jar" android\gradle\wrapper\gradle-wrapper.jar >nul
)
call flutter analyze
if errorlevel 1 exit /b 1
call flutter build apk --release
if errorlevel 1 exit /b 1
echo APK: build\app\outputs\flutter-apk\app-release.apk
