# 数据监控助手 - 打包脚本
$FlutterBin = "C:\Users\31569\flutter-sdk\flutter\bin"
$env:Path = "$FlutterBin;$env:Path"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "      数据监控助手 - 打包脚本" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

Push-Location $PSScriptRoot
try {
    # 清理
    Write-Host "[1/4] 清理旧构建..." -ForegroundColor Yellow
    & "$FlutterBin\flutter.bat" clean
    if ($LASTEXITCODE -ne 0) { Write-Host "Clean 完成" -ForegroundColor Green }

    # 获取依赖
    Write-Host "[2/4] 获取依赖..." -ForegroundColor Yellow
    & "$FlutterBin\flutter.bat" pub get
    if ($LASTEXITCODE -ne 0) { throw "依赖获取失败" }

    # 构建 Windows
    Write-Host "[3/4] 构建 Windows Release..." -ForegroundColor Yellow
    & "$FlutterBin\flutter.bat" build windows --release
    if ($LASTEXITCODE -ne 0) { throw "Windows 构建失败" }

    # 构建 Android
    Write-Host "[4/4] 构建 Android Release..." -ForegroundColor Yellow
    & "$FlutterBin\flutter.bat" build apk --release
    if ($LASTEXITCODE -ne 0) { throw "Android 构建失败" }

    # 整理文件
    Write-Host ""
    Write-Host "整理构建产物..." -ForegroundColor Yellow
    
    $distDir = Join-Path $PSScriptRoot "dist"
    Remove-Item $distDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
    
    # 复制 Windows
    $windowsDist = Join-Path $distDir "windows"
    $windowsBuild = Join-Path $PSScriptRoot "build\windows\x64\runner\Release"
    Copy-Item -Path $windowsBuild -Destination $windowsDist -Recurse -Force
    Write-Host "✓ Windows 已复制到: $windowsDist" -ForegroundColor Green

    # 复制 Android
    $androidDist = Join-Path $distDir "android"
    $androidApk = Get-ChildItem -Path "$PSScriptRoot\build\app\outputs\flutter-apk\*-release.apk" -File | Select-Object -First 1
    New-Item -ItemType Directory -Path $androidDist -Force | Out-Null
    Copy-Item -Path $androidApk.FullName -Destination (Join-Path $androidDist "data_monitor-release.apk") -Force
    Write-Host "✓ Android 已复制到: $androidDist" -ForegroundColor Green

    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "✓ 打包完成！" -ForegroundColor Green
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Windows 路径: $windowsDist" -ForegroundColor White
    Write-Host "Android 路径: $androidDist" -ForegroundColor White
    Write-Host ""
    Write-Host "按任意键退出..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

} catch {
    Write-Host ""
    Write-Host "构建失败: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "按任意键退出..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
} finally {
    Pop-Location
}
