$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutter = Join-Path $projectRoot 'flutter_sdk\flutter\bin\flutter.bat'

if (-not (Test-Path $flutter)) {
  Write-Error "Flutter SDK not found at $flutter"
}

Push-Location $projectRoot
try {
  & $flutter run -d chrome
} finally {
  Pop-Location
}
