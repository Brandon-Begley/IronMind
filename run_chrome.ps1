$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutter = Join-Path $projectRoot 'flutter_sdk\flutter\bin\flutter.bat'

# Fall back to system flutter if local SDK not found
if (-not (Test-Path $flutter)) {
  $flutter = "flutter"
}

Push-Location $projectRoot
try {
  & $flutter run -d chrome
} finally {
  Pop-Location
}
