#!/bin/bash

################################################################################
# macOS Defender Check - Quick Install Script
################################################################################

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║          macOS Defender Check - Installation                  ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo ""
echo -e "${CYAN}This script will:${NC}"
echo "1. Verify system requirements"
echo "2. Check Microsoft Defender for Endpoint installation"
echo "3. Set up the testing scripts"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Warning: This setup script should NOT be run with sudo${NC}"
    echo -e "${YELLOW}The test scripts themselves will require sudo when executed${NC}"
    exit 1
fi

# Check macOS version
echo -e "${CYAN}Checking macOS version...${NC}"
macos_version=$(sw_vers -productVersion)
echo -e "${GREEN}✓ macOS version: $macos_version${NC}"

# Check if MDE is installed
echo ""
echo -e "${CYAN}Checking Microsoft Defender for Endpoint installation...${NC}"
if [ -d "/Applications/Microsoft Defender.app" ]; then
    echo -e "${GREEN}✓ Microsoft Defender for Endpoint is installed${NC}"
    
    if [ -f "/usr/local/bin/mdatp" ]; then
        echo -e "${GREEN}✓ mdatp command-line tool is available${NC}"
        
        version=$(mdatp version 2>/dev/null | grep "App version" | awk '{print $3}')
        if [ -n "$version" ]; then
            echo -e "${CYAN}  Version: $version${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ mdatp command-line tool not found${NC}"
        echo -e "${YELLOW}  This may affect some test functionality${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Microsoft Defender for Endpoint is NOT installed${NC}"
    echo -e "${YELLOW}  Please install MDE before running the tests${NC}"
    echo ""
    echo -e "${CYAN}Installation instructions:${NC}"
    echo "1. Download MDE from Microsoft Defender Security Center"
    echo "2. Or deploy via Intune/Jamf MDM"
    echo "3. Run onboarding package to connect to your tenant"
    exit 1
fi

# Check browser availability
echo ""
echo -e "${CYAN}Checking browser availability...${NC}"
browsers_found=0

if [ -f "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
    echo -e "${GREEN}✓ Google Chrome is installed${NC}"
    browsers_found=$((browsers_found + 1))
fi

if [ -f "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" ]; then
    echo -e "${GREEN}✓ Microsoft Edge is installed${NC}"
    browsers_found=$((browsers_found + 1))
fi

if [ -f "/Applications/Safari.app/Contents/MacOS/Safari" ]; then
    echo -e "${GREEN}✓ Safari is installed${NC}"
    browsers_found=$((browsers_found + 1))
fi

if [ $browsers_found -eq 0 ]; then
    echo -e "${YELLOW}⚠ No compatible browsers found${NC}"
    echo -e "${YELLOW}  Install Chrome or Edge for best web protection testing${NC}"
fi

# Make scripts executable
echo ""
echo -e "${CYAN}Setting up test scripts...${NC}"
chmod +x defendercheck-tp.sh 2>/dev/null
chmod +x defendercheck-wp.sh 2>/dev/null

if [ -x "defendercheck-tp.sh" ] && [ -x "defendercheck-wp.sh" ]; then
    echo -e "${GREEN}✓ Test scripts are now executable${NC}"
else
    echo -e "${YELLOW}⚠ Could not make scripts executable${NC}"
    echo -e "${YELLOW}  Run: chmod +x *.sh${NC}"
fi

# Create sample CSV if it doesn't exist
if [ ! -f "sample_urls.csv" ]; then
    echo ""
    echo -e "${CYAN}Creating sample URLs file...${NC}"
    cat > sample_urls.csv << 'EOF'
IndicatorValue
https://example-malicious-site.com
https://phishing-test.example.com
https://dangerous-domain.net
https://blocked-url.example.org
https://test-indicator.com
EOF
    echo -e "${GREEN}✓ Created sample_urls.csv${NC}"
fi

# Print usage instructions
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Quick Start:${NC}"
echo ""
echo -e "${YELLOW}Test Tamper Protection:${NC}"
echo "  sudo ./defendercheck-tp.sh"
echo ""
echo -e "${YELLOW}Test Web Protection (Basic):${NC}"
echo "  sudo ./defendercheck-wp.sh"
echo ""
echo -e "${YELLOW}Test Web Protection with URL Indicators:${NC}"
echo "  sudo ./defendercheck-wp.sh -f sample_urls.csv"
echo ""
echo -e "${YELLOW}Test Web Content Filtering:${NC}"
echo "  sudo ./defendercheck-wp.sh -c AdultContent"
echo ""
echo -e "${CYAN}For more information, see: README.md${NC}"
echo ""
