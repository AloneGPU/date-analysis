# 数据监控助手 - 跨平台配置指南

## Android 配置

### AndroidManifest.xml 权限配置

在 `android/app/src/main/AndroidManifest.xml` 中添加以下权限：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.data_monitor">
    
    <!-- 网络权限 -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
    
    <!-- 蓝牙权限 -->
    <uses-permission android:name="android.permission.BLUETOOTH"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
    
    <!-- 位置权限（蓝牙扫描需要） -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    
    <!-- 存储权限 -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    
    <application
        android:label="数据监控助手"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme"/>
            
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2"/>
    </application>
</manifest>
```

### Android 蓝牙配置

对于 Android 12+，需要在应用设置页面添加蓝牙权限说明。

在 `android/app/src/main/res/values/styles.xml` 中配置主题：

```xml
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
```

## Windows 配置

### Windows 蓝牙支持

Windows 平台需要安装 WinRT API 来支持蓝牙功能。在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  flutter:
    sdk: flutter
  win32: ^5.0.0
```

### Windows 防火墙配置

如果使用 WiFi 连接，确保防火墙允许应用访问网络：

1. 打开 Windows 防火墙高级设置
2. 创建入站规则，允许 `data_monitor.exe` 访问端口 8080
3. 创建出站规则，允许应用访问外部网络

## 应用图标配置

### Android

将应用图标放置在以下目录：

- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

### Windows

将 `app_icon.ico` 放置在 `windows/runner/` 目录。

## 构建配置

### Android Debug 构建

```bash
flutter build apk --debug
```

### Android Release 构建

```bash
flutter build apk --release
```

### Windows 构建

```bash
flutter build windows --release
```

### macOS 构建

```bash
flutter build macos --release
```

## 运行时权限说明

### Android

- 首次使用蓝牙时，系统会提示授权
- 数据存储需要存储权限
- 网络权限通常默认授予

### Windows

- 首次使用蓝牙时，系统会提示授权
- 防火墙可能阻止网络连接，需要手动配置

## 性能优化配置

### Android

在 `android/app/build.gradle` 中启用 R8 优化：

```gradle
android {
    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

### Windows

在 `windows/CMakeLists.txt` 中配置发布模式：

```cmake
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    add_compile_definitions(FLUTTER_RELEASE)
endif()
```

## 常见问题

### Android 蓝牙不工作

1. 检查是否添加了所有蓝牙权限
2. 确认设备支持蓝牙
3. 检查位置权限是否授予

### Windows WiFi 连接失败

1. 检查防火墙设置
2. 确认设备IP和端口正确
3. 检查网络连接

### 数据不显示

1. 确认数据格式为有效的 JSON
2. 检查 Topic 名称是否正确
3. 查看应用日志获取更多信息
