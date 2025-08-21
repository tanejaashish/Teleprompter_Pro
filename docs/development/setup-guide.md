# TelePrompt Pro - Development Setup Guide

## Quick Start

1. Install Prerequisites:
   - Flutter 3.22.0+: https://flutter.dev/docs/get-started/install
   - Node.js 20.0.0+: https://nodejs.org/
   - Docker Desktop: https://www.docker.com/products/docker-desktop
   - Git: https://git-scm.com/

2. Clone and Setup:
   ```bash
   git clone https://github.com/teleprompt-pro/teleprompt-pro.git
   cd teleprompt-pro
   ./scripts/setup/install-dependencies.sh
   ```

3. Configure Environment:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. Start Development:
   ```bash
   docker-compose up -d
   flutter run
   ```

For detailed instructions, see the complete setup guide.
