# 数据监控助手 - 打包指南

## 📋 快速开始

### 一键打包（推荐）

直接运行项目根目录下的脚本：

```powershell
# Windows 系统
.\Build-All.ps1
```

该脚本会自动完成以下步骤：
1. 清理旧构建
2. 获取依赖
3. 构建 Windows Release
4. 构建 Android Release
5. 自动整理到 `dist/` 目录

---

## 🔧 手动打包

### 前置条件

- Flutter SDK（已配置在 `C:\Users\31569\flutter-sdk\flutter\bin`）
- Visual Studio 2022（Windows 桌面开发）
- Android Studio（Android 开发）
- Git（可选）

---

### 1. 打包 Windows 桌面端

```powershell
# 进入项目目录
cd a:\shangweiji

# 清理旧构建
flutter clean

# 获取依赖
flutter pub get

# 构建 Release 版本
flutter build windows --release
```

**构建产物位置：**
```
build\windows\x64\runner\Release\
```

**分发说明：**
- 整个 `Release` 目录是可直接分发的
- 可以压缩为 zip 或者制作成安装包
- 不需要安装 Flutter 即可运行

---

### 2. 打包 Android 移动端

```powershell
# 构建 Release APK
flutter build apk --release
```

**构建产物位置：**
```
build\app\outputs\flutter-apk\app-release.apk
```

**安装说明：**
- 复制 APK 到 Android 设备
- 允许安装未知来源应用
- 点击 APK 即可安装

---

## 📦 项目打包脚本

项目提供了以下实用脚本：

| 脚本 | 说明 |
|------|------|
| `Build-All.ps1` | 一键打包 Windows + Android |
| `Start-App.ps1` | 启动 Windows 开发版 |

---

## 🚀 版本信息

当前版本：`1.0.0`

在 `pubspec.yaml` 中修改版本：

```yaml
name: data_monitor
version: 1.0.0+1  # 版本号+构建号
```

---

## 📂 目录结构

```
a:\shangweiji\
├── lib/                    # 源代码
├── windows/                # Windows 平台配置
├── android/                # Android 平台配置
├── build/                  # 构建输出（临时）
├── dist/                   # 发布包目录
│   ├── windows/           # Windows 发布包
│   └── android/           # Android 发布包
├── Build-All.ps1          # 打包脚本
└── Start-App.ps1          # 启动脚本
```

---

## ⚙️ 配置说明

### Android 签名配置（可选）

如果需要正式签名发布版 APK，需要在 `android/key.properties` 中配置：

```properties
storePassword=密码
keyPassword=密码
keyAlias=别名
storeFile=密钥文件路径
```

### Windows 发布选项

可以在 `windows/CMakeLists.txt` 中修改应用名称和图标。

---

## 📞 常见问题

### Q: 构建 Windows 失败？

A: 确保安装了 Visual Studio 2022，并且包含 "使用 C++ 的桌面开发" 工作负载。

### Q: Android 构建失败？

A: 确保安装了 Android Studio，并且配置了正确的 SDK 路径。

### Q: 如何修改应用名称？

A:
- Android: 修改 `android/app/src/main/AndroidManifest.xml`
- Windows: 修改 `windows/runner/Runner.rc`
- 通用: 修改 `pubspec.yaml` 中的 name 字段

---

## 📄 许可证

数据监控助手 - MIT License
