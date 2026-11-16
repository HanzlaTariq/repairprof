$ErrorActionPreference='Stop'
Set-Location "$PSScriptRoot/.."
npm ci
if ($LASTEXITCODE -ne 0) { throw 'Root npm install failed.' }
npm --prefix functions ci
if ($LASTEXITCODE -ne 0) { throw 'Functions install failed.' }
npm --prefix customer_web ci
if ($LASTEXITCODE -ne 0) { throw 'Customer website install failed.' }
npm run build
if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
npx firebase emulators:start --project demo-repairproof
