# TelePrompt Pro

<p align="center">
  <img src="docs/assets/logo.png" alt="TelePrompt Pro Logo" width="200">
</p>

<p align="center">
  <a href="https://github.com/teleprompt-pro/teleprompt-pro/actions/workflows/ci.yml">
    <img src="https://github.com/teleprompt-pro/teleprompt-pro/actions/workflows/ci.yml/badge.svg" alt="CI Status">
  </a>
  <a href="https://codecov.io/gh/teleprompt-pro/teleprompt-pro">
    <img src="https://codecov.io/gh/teleprompt-pro/teleprompt-pro/branch/main/graph/badge.svg" alt="Code Coverage">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License">
  </a>
</p>

## 🎯 Overview

TelePrompt Pro is a comprehensive, cross-platform teleprompter solution that sets the industry standard for performance, features, and user experience. Built with Flutter for consistent cross-platform experience, it offers professional-grade teleprompting across Windows desktop (with system tray), web browsers, and mobile devices.

## ✨ Features

### 🆓 Basic Tier (Free)
- Script editor with rich text formatting
- Adjustable scrolling speed
- Basic display customization
- 720p video recording (5-minute limit)
- Local storage for up to 10 scripts

### 💎 Advanced Tier ($19/month)
- Unlimited cloud-synced scripts
- Voice-activated scrolling
- 1080p HD recording (30-minute limit)
- Virtual backgrounds
- AI-powered script generation (1000 words/month)
- Cross-device synchronization

### 🚀 Pro Tier ($49/month)
- Real-time collaborative editing
- 4K video recording (unlimited)
- AI VoiceTrack™ technology
- Eye contact correction
- Multi-language support (25+ languages)
- Team workspace (5 users)
- Priority support

## 🛠️ Technology Stack

- **Frontend**: Flutter 3.22+ (Desktop, Web, Mobile)
- **Backend**: Node.js, Express, GraphQL
- **Database**: PostgreSQL, Redis
- **Storage**: AWS S3, CloudFront CDN
- **AI/ML**: OpenAI GPT-4, Google Cloud Speech-to-Text
- **Infrastructure**: Docker, Kubernetes, Terraform

## 🚀 Quick Start

### Prerequisites
- Flutter 3.22.0 or higher
- Node.js 20.0.0 or higher
- Docker Desktop
- Git

### Installation

1. Clone the repository:
```bash
git clone https://github.com/teleprompt-pro/teleprompt-pro.git
cd teleprompt-pro
```

2. Run the setup script:
```bash
./scripts/setup/install-dependencies.sh
```

3. Copy environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Start development servers:
```bash
# Backend services
docker-compose up -d

# Flutter app (choose platform)
flutter run -d windows  # Desktop
flutter run -d chrome   # Web
flutter run            # Mobile (with connected device)
```

## 📖 Documentation

- [Architecture Overview](docs/architecture/overview.md)
- [Development Guide](docs/development/setup-guide.md)
- [API Documentation](docs/api/rest-api.md)
- [Contributing Guidelines](CONTRIBUTING.md)

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/unit/script_test.dart

# Run integration tests
flutter test integration_test/
```

## 🚢 Deployment

### Production Build

```bash
# Desktop (Windows)
flutter build windows --release

# Web
flutter build web --release

# Mobile
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

### Docker Deployment

```bash
# Build all services
docker-compose -f docker-compose.prod.yml build

# Deploy to production
./scripts/deploy/deploy-production.sh
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details on how to get started.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing cross-platform framework
- Our beta testers for invaluable feedback
- Open source community for inspiration and support

## 📞 Support

- Documentation: [docs.teleprompt.pro](https://docs.teleprompt.pro)
- Email: support@teleprompt.pro
- Discord: [Join our community](https://discord.gg/teleprompt)

---

<p align="center">Made with ❤️ by the TelePrompt Pro Team</p>
