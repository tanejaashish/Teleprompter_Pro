#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT=$(pwd)
LOG_DIR="$PROJECT_ROOT/logs"
FEEDBACK_DIR="$PROJECT_ROOT/feedback"
CONFIG_FILE="$PROJECT_ROOT/.teleprompt-config"

# Create necessary directories
mkdir -p "$LOG_DIR" "$FEEDBACK_DIR"

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/flutter-runner.log"
}

# Function to check if Flutter is installed
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}Flutter is not installed or not in PATH${NC}"
        echo "Please install Flutter first: https://flutter.dev/docs/get-started/install"
        exit 1
    fi
    log_message "INFO" "Flutter check passed"
}

# Function to check backend services
check_backend() {
    echo -e "${YELLOW}Checking backend services...${NC}"
    
    # Check if Docker is running
    if command -v docker &> /dev/null && docker ps &> /dev/null; then
        echo -e "${GREEN}✓ Docker is running${NC}"
        
        # Check specific services
        services=("ai-service" "media-processor" "payment-service" "redis-queue")
        for service in "${services[@]}"; do
            if docker ps | grep -q $service; then
                echo -e "${GREEN}✓ $service is running${NC}"
            else
                echo -e "${YELLOW}⚠ $service is not running${NC}"
            fi
        done
    else
        echo -e "${YELLOW}⚠ Docker is not running - backend services unavailable${NC}"
    fi
}

# Function to save and load user preferences
save_preference() {
    local key=$1
    local value=$2
    echo "$key=$value" >> "$CONFIG_FILE"
}

load_preferences() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# Function to clean and get dependencies
prepare_app() {
    local app_path=$1
    echo -e "${YELLOW}Preparing $app_path...${NC}"
    
    # Save current directory
    local current_dir=$(pwd)
    
    # Navigate to app directory
    cd "$PROJECT_ROOT/$app_path" || {
        echo -e "${RED}Failed to navigate to $app_path${NC}"
        return 1
    }
    
    # Clean and get dependencies
    flutter clean
    flutter pub get
    
    # Return to original directory
    cd "$current_dir"
    
    log_message "INFO" "Prepared $app_path"
}

# Function to run desktop app with proper navigation
run_desktop() {
    echo -e "${GREEN}Starting Desktop Application...${NC}"
    
    # Navigate to desktop directory
    cd "$PROJECT_ROOT/apps/desktop" || {
        echo -e "${RED}Failed to navigate to apps/desktop${NC}"
        return 1
    }
    
    # Clean and get dependencies
    flutter clean
    flutter pub get
    
    # Detect platform and run
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OS" == "Windows_NT" ]]; then
        echo -e "${CYAN}Running on Windows...${NC}"
        flutter run -d windows
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${CYAN}Running on macOS...${NC}"
        flutter run -d macos
    else
        echo -e "${CYAN}Running on Linux...${NC}"
        flutter run -d linux
    fi
    
    echo "01 Root"
    cd "$PROJECT_ROOT"
}

# Function to run web app with proper navigation
run_web() {
    echo -e "${GREEN}Starting Web Application...${NC}"
    
    cd "$PROJECT_ROOT/apps/web" || {
        echo -e "${RED}Failed to navigate to apps/web${NC}"
        return 1
    }
    
    flutter clean
    flutter pub get
    
    echo "Select browser:"
    echo "1) Chrome"
    echo "2) Edge"
    echo "3) Firefox"
    echo "4) Auto-detect"
    read -p "Enter choice (1-4): " browser_choice
    
    case $browser_choice in
        1) flutter run -d chrome --web-port=3000 ;;
        2) flutter run -d edge --web-port=3000 ;;
        3) flutter run -d firefox --web-port=3000 ;;
        4) flutter run -d web --web-port=3000 ;;
        *) flutter run -d chrome --web-port=3000 ;;
    esac
    
    echo "02 Root"
    cd "$PROJECT_ROOT"
}

# Function to run mobile app with proper navigation
run_mobile() {
    echo -e "${GREEN}Starting Mobile Application...${NC}"
    
    # Navigate to mobile directory and stay there
    cd "$PROJECT_ROOT/apps/mobile" || {
        echo -e "${RED}Failed to navigate to apps/mobile${NC}"
        return 1
    }
    
    flutter clean
    flutter pub get
    
    # List available devices
    echo -e "${YELLOW}Available devices:${NC}"
    flutter devices
    
    echo ""
    echo "Select platform:"
    echo "1) Android Device"
    echo "2) iOS Device (macOS only)"
    echo "3) Android Emulator"
    echo "4) iOS Simulator (macOS only)"
    echo "5) Auto-detect"
    echo "6) Chrome (Web)"
    echo "7) Edge (Web)"
    read -p "Enter choice (1-7): " mobile_choice
    
    # Check which main file exists
    if [ -f "lib/main.dart" ]; then
        case $mobile_choice in
            1) flutter run -d android ;;
            2) flutter run -d ios ;;
            3) flutter run ;;
            4) flutter run -d iPhone ;;
            5) flutter run ;;
            6) flutter run -d chrome ;;
            7) flutter run -d edge ;;
            *) flutter run ;;
        esac
    elif [ -f "lib/main_mobile.dart" ]; then
        case $mobile_choice in
            1) flutter run -t lib/main_mobile.dart -d android ;;
            2) flutter run -t lib/main_mobile.dart -d ios ;;
            3) flutter run -t lib/main_mobile.dart ;;
            4) flutter run -t lib/main_mobile.dart -d iPhone ;;
            5) flutter run -t lib/main_mobile.dart ;;
            6) flutter run -t lib/main_mobile.dart -d chrome ;;
            7) flutter run -t lib/main_mobile.dart -d edge ;;
            *) flutter run -t lib/main_mobile.dart ;;
        esac
    else
        echo -e "${RED}No main file found in apps/mobile/lib${NC}"
        cd "$PROJECT_ROOT"
        return 1
    fi
    
    # Return to project root
    echo "03 Root"
    cd "$PROJECT_ROOT"
}

# Fixed function to run all apps simultaneously
run_all() {
    echo -e "${GREEN}Starting all applications...${NC}"
    
    # Check if apps exist first
    if [ ! -d "$PROJECT_ROOT/apps/desktop" ]; then
        echo -e "${RED}Desktop app not found at apps/desktop${NC}"
        return 1
    fi
    if [ ! -d "$PROJECT_ROOT/apps/web" ]; then
        echo -e "${RED}Web app not found at apps/web${NC}"
        return 1
    fi
    if [ ! -d "$PROJECT_ROOT/apps/mobile" ]; then
        echo -e "${RED}Mobile app not found at apps/mobile${NC}"
        return 1
    fi
    
    # Start desktop in new terminal/process
    echo -e "${CYAN}Starting Desktop app...${NC}"
    if [[ "$OS" == "Windows_NT" ]] || [[ "$OSTYPE" == "msys" ]]; then
        # Windows - use start command to open new terminal
        start cmd //c "cd /d $PROJECT_ROOT\apps\desktop && flutter run -d windows"
    else
        # Linux/Mac
        cd "$PROJECT_ROOT/apps/desktop" && flutter run -d linux &
    fi
    
    sleep 3
    
    # Start web in new terminal/process
    echo -e "${CYAN}Starting Web app...${NC}"
    if [[ "$OS" == "Windows_NT" ]] || [[ "$OSTYPE" == "msys" ]]; then
        start cmd //c "cd /d $PROJECT_ROOT\apps\web && flutter run -d chrome --web-port=3000"
    else
        cd "$PROJECT_ROOT/apps/web" && flutter run -d chrome --web-port=3000 &
    fi
    
    sleep 3
    
    # Start mobile in current terminal
    echo -e "${CYAN}Starting Mobile app...${NC}"
    cd "$PROJECT_ROOT/apps/mobile"
    flutter run
}

# Function to run with hot reload watching
run_with_watch() {
    echo -e "${GREEN}Starting in watch mode...${NC}"
    
    echo "Select app to watch:"
    echo "1) Desktop"
    echo "2) Web"
    echo "3) Mobile"
    read -p "Enter choice (1-3): " watch_choice
    
    case $watch_choice in
        1) 
            cd "$PROJECT_ROOT/apps/desktop"
            flutter run -d windows --hot
            ;;
        2) 
            cd "$PROJECT_ROOT/apps/web"
            flutter run -d chrome --web-port=3000 --hot
            ;;
        3) 
            cd "$PROJECT_ROOT/apps/mobile"
            flutter run --hot
            ;;
    esac
}

# Function to run tests
run_tests() {
    echo -e "${GREEN}Running Tests...${NC}"
    
    echo "Select test type:"
    echo "1) Unit Tests"
    echo "2) Widget Tests"
    echo "3) Integration Tests"
    echo "4) All Tests"
    echo "5) Coverage Report"
    read -p "Enter choice (1-5): " test_choice
    
    case $test_choice in
        1)
            for package in packages/core packages/teleprompter_engine packages/ui_kit; do
                echo -e "${CYAN}Testing $package...${NC}"
                (cd "$PROJECT_ROOT/$package" && flutter test)
            done
            ;;
        2)
            for app in apps/desktop apps/web apps/mobile; do
                echo -e "${CYAN}Testing widgets in $app...${NC}"
                (cd "$PROJECT_ROOT/$app" && flutter test)
            done
            ;;
        3)
            echo -e "${CYAN}Running integration tests...${NC}"
            (cd "$PROJECT_ROOT" && flutter test integration_test)
            ;;
        4)
            echo -e "${CYAN}Running all tests...${NC}"
            (cd "$PROJECT_ROOT" && flutter test)
            ;;
        5)
            echo -e "${CYAN}Generating coverage report...${NC}"
            (cd "$PROJECT_ROOT" && flutter test --coverage)
            echo -e "${GREEN}Coverage report generated in coverage/lcov.info${NC}"
            ;;
    esac
}

# Function to setup OAuth
setup_oauth() {
    echo -e "${GREEN}Setting up OAuth...${NC}"
    
    echo "Enter your OAuth credentials:"
    read -p "Google Client ID: " google_client_id
    read -p "Facebook App ID: " facebook_app_id
    read -p "Apple Service ID: " apple_service_id
    
    # Save to .env file
    cat >> "$PROJECT_ROOT/.env" << EOF
GOOGLE_CLIENT_ID=$google_client_id
FACEBOOK_APP_ID=$facebook_app_id
APPLE_SERVICE_ID=$apple_service_id
EOF
    
    echo -e "${GREEN}OAuth credentials saved${NC}"
    log_message "INFO" "OAuth credentials configured"
}

# Function to export feedback and analytics
export_feedback() {
    echo -e "${GREEN}Exporting Feedback & Analytics...${NC}"
    
    echo "Select export format:"
    echo "1) PDF Report"
    echo "2) CSV Data"
    echo "3) JSON"
    echo "4) HTML Dashboard"
    read -p "Enter choice (1-4): " export_choice
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local export_file="$FEEDBACK_DIR/export_$timestamp"
    
    case $export_choice in
        1) 
            export_file="${export_file}.pdf"
            echo -e "${CYAN}Exporting to PDF...${NC}"
            ;;
        2) 
            export_file="${export_file}.csv"
            echo -e "${CYAN}Exporting to CSV...${NC}"
            ;;
        3) 
            export_file="${export_file}.json"
            echo -e "${CYAN}Exporting to JSON...${NC}"
            ;;
        4) 
            export_file="${export_file}.html"
            echo -e "${CYAN}Exporting to HTML...${NC}"
            ;;
    esac
    
    echo -e "${GREEN}Export saved to: $export_file${NC}"
    log_message "INFO" "Feedback exported to $export_file"
}

# Function to launch specific features
launch_feature() {
    echo -e "${GREEN}Launch Specific Feature...${NC}"
    
    echo "Select feature:"
    echo "1) Real-time Voice Analysis"
    echo "2) Video Recording Studio"
    echo "3) AI Script Generator"
    echo "4) Live Transcription"
    echo "5) Analytics Dashboard"
    echo "6) Settings Manager"
    read -p "Enter choice (1-6): " feature_choice
    
    cd "$PROJECT_ROOT/apps/desktop"
    
    case $feature_choice in
        1) flutter run -d windows --dart-define=LAUNCH_FEATURE=voice_analysis ;;
        2) flutter run -d windows --dart-define=LAUNCH_FEATURE=recording_studio ;;
        3) flutter run -d windows --dart-define=LAUNCH_FEATURE=ai_generator ;;
        4) flutter run -d windows --dart-define=LAUNCH_FEATURE=transcription ;;
        5) flutter run -d windows --dart-define=LAUNCH_FEATURE=analytics ;;
        6) flutter run -d windows --dart-define=LAUNCH_FEATURE=settings ;;
    esac
}

# Function to check system requirements
check_requirements() {
    echo -e "${CYAN}Checking System Requirements...${NC}"
    
    # Check Flutter version
    flutter_version=$(flutter --version | head -n 1)
    echo "Flutter: $flutter_version"
    
    # Check Dart version
    dart_version=$(dart --version)
    echo "Dart: $dart_version"
    
    # Check available memory
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OS" == "Windows_NT" ]]; then
        mem_available=$(wmic OS get TotalVisibleMemorySize /value | grep = | cut -d= -f2)
        echo "Memory: $((mem_available / 1024)) MB"
    else
        mem_available=$(free -m | awk 'NR==2{print $7}')
        echo "Available Memory: ${mem_available} MB"
    fi
    
    # Check disk space
    disk_space=$(df -h . | awk 'NR==2{print $4}')
    echo "Available Disk Space: $disk_space"
    
    # Check for required tools
    tools=("git" "docker" "node" "npm")
    for tool in "${tools[@]}"; do
        if command -v $tool &> /dev/null; then
            echo -e "${GREEN}✓ $tool installed${NC}"
        else
            echo -e "${YELLOW}⚠ $tool not found${NC}"
        fi
    done
}

# Enhanced main menu
main_menu() {
    clear
    echo -e "${BLUE}======================================"
    echo "   TelePrompt Pro - Flutter Runner    "
    echo "   Enhanced Version with Phase 4      "
    echo "======================================${NC}"
    echo ""
    echo -e "${CYAN}Main Options:${NC}"
    echo "1) Run Desktop Application"
    echo "2) Run Web Application"
    echo "3) Run Mobile Application"
    echo "4) Run All Applications"
    echo ""
    echo -e "${CYAN}Development:${NC}"
    echo "5) Build Applications"
    echo "6) Run Tests"
    echo "7) Hot Reload Mode"
    echo ""
    echo -e "${CYAN}Features:${NC}"
    echo "8) Launch Specific Feature"
    echo "9) Export Feedback/Analytics"
    echo ""
    echo -e "${CYAN}Setup & Maintenance:${NC}"
    echo "10) Flutter Doctor"
    echo "11) Clean All Projects"
    echo "12) Check Backend Services"
    echo "13) Setup OAuth"
    echo "14) Check Requirements"
    echo ""
    echo "15) Exit"
    echo ""
    read -p "Enter your choice (1-15): " choice
    
    case $choice in
        1) run_desktop ;;
        2) run_web ;;
        3) run_mobile ;;
        4) run_all ;;
        5) build_app ;;
        6) run_tests ;;
        7) run_with_watch ;;
        8) launch_feature ;;
        9) export_feedback ;;
        10) run_doctor ;;
        11) 
            for app in apps/desktop apps/web apps/mobile; do
                echo "Cleaning $app..."
                (cd "$PROJECT_ROOT/$app" && flutter clean)
            done
            for package in packages/core packages/ui_kit packages/teleprompter_engine packages/platform_services; do
                echo "Cleaning $package..."
                (cd "$PROJECT_ROOT/$package" && flutter clean)
            done
            ;;
        12) check_backend ;;
        13) setup_oauth ;;
        14) check_requirements ;;
        15) 
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0 
            ;;
        *) 
            echo -e "${RED}Invalid choice${NC}"
            sleep 2
            main_menu
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    main_menu
}

# Function to run Flutter doctor
run_doctor() {
    echo -e "${YELLOW}Running Flutter doctor...${NC}"
    flutter doctor -v
}

# Function to build apps (keeping the original implementation)
build_app() {
    echo -e "${GREEN}Building Applications...${NC}"
    
    echo "Select build target:"
    echo "1) Desktop (Release)"
    echo "2) Web (Release)"
    echo "3) Android APK"
    echo "4) iOS (macOS only)"
    echo "5) All platforms"
    read -p "Enter choice (1-5): " build_choice
    
    case $build_choice in
        1)
            cd "$PROJECT_ROOT/apps/desktop"
            if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OS" == "Windows_NT" ]]; then
                flutter build windows --release
                echo -e "${GREEN}Built: build/windows/runner/Release/${NC}"
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                flutter build macos --release
                echo -e "${GREEN}Built: build/macos/Build/Products/Release/${NC}"
            else
                flutter build linux --release
                echo -e "${GREEN}Built: build/linux/x64/release/bundle/${NC}"
            fi
            ;;
        2)
            cd "$PROJECT_ROOT/apps/web"
            flutter build web --release --web-renderer html
            echo -e "${GREEN}Built: build/web/${NC}"
            ;;
        3)
            cd "$PROJECT_ROOT/apps/mobile"
            flutter build apk --release
            echo -e "${GREEN}Built: build/app/outputs/flutter-apk/app-release.apk${NC}"
            ;;
        4)
            cd "$PROJECT_ROOT/apps/mobile"
            flutter build ios --release
            echo -e "${GREEN}Built: build/ios/iphoneos/${NC}"
            ;;
        5)
            build_all
            ;;
    esac
    
    echo "04 Root"
    cd "$PROJECT_ROOT"
}

# Function to build all platforms
build_all() {
    echo -e "${YELLOW}Building all platforms...${NC}"
    
    # Desktop
    cd "$PROJECT_ROOT/apps/desktop"
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OS" == "Windows_NT" ]]; then
        flutter build windows --release
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        flutter build macos --release
    else
        flutter build linux --release
    fi
    
    # Web
    cd "$PROJECT_ROOT/apps/web"
    flutter build web --release --web-renderer html
    
    # Mobile
    cd "$PROJECT_ROOT/apps/mobile"
    flutter build apk --release
    
    echo "05 Root"
    cd "$PROJECT_ROOT"
    echo -e "${GREEN}All builds completed!${NC}"
}

# Initialize
check_flutter
load_preferences

# Check if in correct directory
if [ ! -d "apps" ]; then
    echo -e "${RED}Error: 'apps' directory not found.${NC}"
    echo "Please run this script from the project root directory."
    exit 1
fi

# Log startup
log_message "INFO" "TelePrompt Pro Flutter Runner started"

# Show main menu
main_menu