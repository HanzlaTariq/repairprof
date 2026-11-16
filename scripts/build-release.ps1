$ErrorActionPreference = 'Stop'
Set-Location "$PSScriptRoot/../shopkeeper_app"
if (!(Test-Path 'config/production.json')) { throw 'Create config/production.json using production.example.json.' }
if (!(Test-Path 'android/key.properties')) { throw 'Configure your own upload signing key first.' }
$config = Get-Content 'config/production.json' -Raw | ConvertFrom-Json
if ($config.USE_EMULATORS -ne 'false' -or $config.API_BASE -notlike 'https://*' -or $config.TRACKING_BASE -notlike 'https://*' -or $config.FIREBASE_PROJECT_ID -like '*YOUR*') { throw 'Production settings are incomplete.' }
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Analyzer failed.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
flutter build appbundle --release --dart-define-from-file=config/production.json
if ($LASTEXITCODE -ne 0) { throw 'Release build failed.' }
Write-Host 'AAB: shopkeeper_app/build/app/outputs/bundle/release/app-release.aab'
Write-Host 'This command does not upload or publish anything.'
