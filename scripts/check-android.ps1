$ErrorActionPreference = 'Stop'
Set-Location "$PSScriptRoot/../shopkeeper_app"
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Analyzer failed.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
flutter build apk --debug --dart-define-from-file=config/emulator.android.json
if ($LASTEXITCODE -ne 0) { throw 'Debug Android build failed.' }
Write-Host 'Debug APK: shopkeeper_app/build/app/outputs/flutter-apk/app-debug.apk'
