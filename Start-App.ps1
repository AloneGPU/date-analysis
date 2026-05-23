# 启动数据监控助手
$FlutterBin = "C:\Users\31569\flutter-sdk\flutter\bin"
$env:Path = "$FlutterBin;$env:Path"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "      数据监控助手 1.0.0" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "检查系统..." -ForegroundColor Yellow
& "$FlutterBin\flutter.bat" --version

Write-Host ""
Write-Host "常用命令:" -ForegroundColor Green
Write-Host "  flutter pub get"
Write-Host "  flutter run -d windows"
Write-Host "  flutter build windows --release"
Write-Host "  flutter build apk --release"
Write-Host ""

Push-Location $PSScriptRoot
try {
  & "$FlutterBin\flutter.bat" pub get
  & "$FlutterBin\flutter.bat" run -d windows
} finally {
  Pop-Location
}
