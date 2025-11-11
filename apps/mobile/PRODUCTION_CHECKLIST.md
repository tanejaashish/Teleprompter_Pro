# Mobile App Production Checklist

Complete checklist for preparing TelePrompt Pro mobile app for App Store and Play Store release.

## App Configuration

### iOS (App Store)

- [ ] **Bundle Identifier**: Set in `ios/Runner/Info.plist`
  ```xml
  <key>CFBundleIdentifier</key>
  <string>com.teleprompter.pro</string>
  ```

- [ ] **App Name**: Update display name
  ```xml
  <key>CFBundleDisplayName</key>
  <string>TelePrompt Pro</string>
  ```

- [ ] **Version & Build**: Update in `pubspec.yaml`
  ```yaml
  version: 1.0.0+1
  ```

- [ ] **App Icon**: Add to `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
  - Sizes: 20pt, 29pt, 40pt, 60pt, 76pt, 83.5pt (@1x, @2x, @3x)
  - Use https://appicon.co/ to generate all sizes

- [ ] **Launch Screen**: Configure `ios/Runner/Base.lproj/LaunchScreen.storyboard`

- [ ] **Permissions**: Update `ios/Runner/Info.plist`
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>Record video presentations</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Record audio for presentations</string>
  <key>NSPhotoLibraryUsageDescription</key>
  <string>Access photos for presentation thumbnails</string>
  ```

- [ ] **Signing**: Configure in Xcode
  - Team: Your Apple Developer Team
  - Bundle ID: com.teleprompter.pro
  - Provisioning Profile: Production

- [ ] **Capabilities**: Enable in Xcode
  - Push Notifications
  - Background Modes (Audio)
  - In-App Purchase

### Android (Google Play)

- [ ] **Package Name**: Set in `android/app/build.gradle`
  ```gradle
  applicationId "com.teleprompter.pro"
  ```

- [ ] **App Name**: Update in `android/app/src/main/AndroidManifest.xml`
  ```xml
  android:label="TelePrompt Pro"
  ```

- [ ] **Version**: Update in `android/app/build.gradle`
  ```gradle
  versionCode 1
  versionName "1.0.0"
  ```

- [ ] **App Icon**: Add to `android/app/src/main/res/`
  - mipmap-mdpi (48x48)
  - mipmap-hdpi (72x72)
  - mipmap-xhdpi (96x96)
  - mipmap-xxhdpi (144x144)
  - mipmap-xxxhdpi (192x192)

- [ ] **Splash Screen**: Configure `android/app/src/main/res/values/styles.xml`

- [ ] **Permissions**: Update `AndroidManifest.xml`
  ```xml
  <uses-permission android:name="android.permission.CAMERA"/>
  <uses-permission android:name="android.permission.RECORD_AUDIO"/>
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
  ```

- [ ] **Signing**: Configure keystore
  ```bash
  keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```

  Create `android/key.properties`:
  ```
  storePassword=<password>
  keyPassword=<password>
  keyAlias=upload
  storeFile=<location of keystore>
  ```

## App Polish

### Branding

- [ ] **Color Scheme**: Consistent brand colors in `lib/theme/colors.dart`
- [ ] **Typography**: Custom fonts in `pubspec.yaml` and `lib/theme/typography.dart`
- [ ] **Logo**: High-resolution logo assets
- [ ] **Brand Guidelines**: Follow in all UI elements

### UI/UX

- [ ] **Onboarding Flow**: Welcome screens for new users
- [ ] **Tutorial**: First-time user guidance
- [ ] **Empty States**: Helpful messages when no data
- [ ] **Loading States**: Skeleton screens and progress indicators
- [ ] **Error States**: User-friendly error messages
- [ ] **Animations**: Smooth transitions and micro-interactions
- [ ] **Dark Mode**: Full dark theme support
- [ ] **Accessibility**: Screen reader support, sufficient contrast
- [ ] **Responsive Design**: Tablet and landscape layouts

### Features

- [ ] **Offline Mode**: Full offline functionality with sync
- [ ] **Push Notifications**: Set up Firebase Cloud Messaging
- [ ] **Deep Linking**: Handle app links and universal links
- [ ] **Share Extension**: Share scripts from other apps
- [ ] **Widgets**: Home screen widgets (iOS 14+, Android)
- [ ] **App Shortcuts**: Quick actions (3D Touch, long press)

## Performance

- [ ] **App Size**: < 50MB initial download
- [ ] **Launch Time**: < 2 seconds
- [ ] **Memory Usage**: < 100MB typical usage
- [ ] **Battery Impact**: Minimal battery drain
- [ ] **Network Usage**: Optimize API calls, implement caching
- [ ] **Image Optimization**: Compress and lazy-load images
- [ ] **Bundle Optimization**: Remove unused dependencies

## Testing

- [ ] **Unit Tests**: > 80% coverage
- [ ] **Widget Tests**: Key user flows
- [ ] **Integration Tests**: End-to-end scenarios
- [ ] **Manual Testing**: Test on real devices
  - iPhone 12/13/14 (iOS 15+)
  - Pixel 6/7 (Android 12+)
  - iPad Pro (tablet layout)
  - Various screen sizes

- [ ] **Beta Testing**: TestFlight (iOS) and Internal Testing (Android)
  - 50+ testers
  - 2+ weeks of testing
  - Bug reports addressed

## Security

- [ ] **API Keys**: Stored securely (not in source code)
- [ ] **SSL Pinning**: Prevent man-in-the-middle attacks
- [ ] **Data Encryption**: Encrypt sensitive local data
- [ ] **Secure Storage**: Use Keychain (iOS) / Keystore (Android)
- [ ] **Code Obfuscation**: Enable in release build
- [ ] **Jailbreak/Root Detection**: Warn users about security risks

## Analytics & Monitoring

- [ ] **Crash Reporting**: Firebase Crashlytics or Sentry
- [ ] **Analytics**: Firebase Analytics or Mixpanel
- [ ] **Performance Monitoring**: Track app performance metrics
- [ ] **User Feedback**: In-app feedback mechanism

## Legal & Compliance

- [ ] **Privacy Policy**: Published and linked in app
- [ ] **Terms of Service**: Accepted during signup
- [ ] **GDPR Compliance**: Data deletion, export capabilities
- [ ] **COPPA**: Age verification if applicable
- [ ] **App Store Guidelines**: Compliance verified
- [ ] **Copyright**: Licenses for all assets and libraries

## Store Listing

### iOS App Store

- [ ] **App Name**: TelePrompt Pro
- [ ] **Subtitle**: Professional Teleprompter for Creators
- [ ] **Description**: Compelling app description
- [ ] **Keywords**: Optimized for SEO
- [ ] **Screenshots**: 5-10 screenshots per device size
  - 6.7" iPhone
  - 6.5" iPhone
  - 5.5" iPhone
  - 12.9" iPad Pro
- [ ] **Preview Video**: 30-second app preview
- [ ] **Category**: Productivity
- [ ] **Age Rating**: 4+
- [ ] **Content Rights**: All content owned or licensed

### Google Play Store

- [ ] **App Name**: TelePrompt Pro
- [ ] **Short Description**: < 80 characters
- [ ] **Full Description**: Detailed app description
- [ ] **Screenshots**: 2-8 screenshots
  - Phone (1080x1920)
  - 7" Tablet (1024x600)
  - 10" Tablet (1920x1080)
- [ ] **Feature Graphic**: 1024x500 banner
- [ ] **Promo Video**: YouTube link
- [ ] **Category**: Productivity
- [ ] **Content Rating**: Everyone
- [ ] **Privacy Policy**: URL provided

## Pre-Launch

- [ ] **Internal Testing**: Team testing complete
- [ ] **Beta Testing**: Public beta feedback addressed
- [ ] **App Review**: Pre-submission review complete
- [ ] **Support Infrastructure**: Help docs, FAQs, support email
- [ ] **Marketing Materials**: Website, social media assets
- [ ] **Press Kit**: Screenshots, logo, description
- [ ] **Backend Readiness**: Server capacity, monitoring, alerts

## Submission

### iOS

```bash
# Build release version
flutter build ios --release

# Archive in Xcode
# Upload to App Store Connect
# Submit for review
```

- [ ] **App Store Connect**: Configured
- [ ] **TestFlight**: Beta distributed
- [ ] **Review Submission**: Submitted
- [ ] **Review Response**: Ready for questions

### Android

```bash
# Build app bundle
flutter build appbundle --release

# Upload to Play Console
# Submit for review
```

- [ ] **Google Play Console**: Configured
- [ ] **Internal Testing**: Track configured
- [ ] **Production**: Submitted for review
- [ ] **Staged Rollout**: 5% → 10% → 50% → 100%

## Post-Launch

- [ ] **Monitor Crashes**: Review crash reports daily
- [ ] **User Reviews**: Respond to reviews
- [ ] **Analytics**: Track key metrics (DAU, retention, conversion)
- [ ] **Updates**: Plan regular updates (monthly)
- [ ] **Support**: Respond to support requests < 24h
- [ ] **Marketing**: Launch announcement, PR, social media

## Build Commands

### iOS Release

```bash
# Clean build
flutter clean
flutter pub get

# Build release
flutter build ios --release --no-codesign

# Or with Xcode
open ios/Runner.xcworkspace
# Archive and upload
```

### Android Release

```bash
# Clean build
flutter clean
flutter pub get

# Build app bundle
flutter build appbundle --release

# Or APK
flutter build apk --release --split-per-abi
```

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Clean build folder
   - Update dependencies
   - Check signing certificates

2. **App Rejection**
   - Review rejection reasons
   - Address issues
   - Resubmit with notes

3. **Crash on Launch**
   - Check crash logs
   - Test on real devices
   - Review recent changes

## Resources

- [Flutter Deployment Guide](https://docs.flutter.dev/deployment)
- [iOS App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Policy Center](https://play.google.com/about/developer-content-policy/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer/)
