// packages/core/lib/platform/platform_detector.dart
class PlatformDetector {
  static PlatformType getCurrentPlatform() {
    if (kIsWeb) return PlatformType.web;
    if (Platform.isWindows) return PlatformType.windows;
    if (Platform.isMacOS) return PlatformType.macos;
    if (Platform.isLinux) return PlatformType.linux;
    if (Platform.isIOS) return PlatformType.ios;
    if (Platform.isAndroid) return PlatformType.android;
    return PlatformType.unknown;
  }
}