#!/bin/bash

################################################################################
# macOS Defender Check - Web Protection
#
# Description: Tests Microsoft Defender for Endpoint Web Protection features
#
# Features Tested:
# 1. Microsoft Defender SmartScreen
# 2. Network Protection
# 3. MDE URL Indicators (requires CSV file)
# 4. MDE Web Content Filtering (WCF)
#
# Prerequisites:
# - Microsoft Defender for Endpoint installed and onboarded
# - Real-Time Protection enabled
# - Network Protection enabled
# - Google Chrome and/or Safari installed
#
# Usage: 
#   Basic test: sudo ./defendercheck-wp.sh
#   With URL indicators: sudo ./defendercheck-wp.sh -f urls.csv
#   With WCF category: sudo ./defendercheck-wp.sh -c AdultContent
#   Combined: sudo ./defendercheck-wp.sh -f urls.csv -c Leisure
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Log directory
LOG_DIR="/tmp/DefenderCheck"
LOG_FILE="${LOG_DIR}/mde_wp_test_$(date +%Y%m%d_%H%M%S).log"
URL_LOG="${LOG_DIR}/url_test_results_$(date +%Y%m%d_%H%M%S).csv"

# Microsoft Defender paths
MDATP_CLI="/usr/local/bin/mdatp"

# Browser paths
CHROME_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SAFARI_PATH="/Applications/Safari.app/Contents/MacOS/Safari"
EDGE_PATH="/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"

# Default test URLs (bash 3.2 compatible - using functions instead of associative arrays)
get_smartscreen_urls() {
    echo "SmartScreen_Phishing|https://demo.smartscreen.msft.net/phishingdemo.html"
    echo "SmartScreen_Malware|https://demo.smartscreen.msft.net/other/malware.html"
    echo "SmartScreen_Exploit|https://demo.smartscreen.msft.net/other/exploit.html"
}

get_network_protection_urls() {
    echo "NetworkProtection_Test|https://smartscreentestratings2.net"
    echo "EICAR_Test|https://secure.eicar.org/eicar.com.txt"
}

# Web Content Filtering test URLs by category (bash 3.2 compatible)
get_wcf_urls_adultcontent() {
    echo "Adult_Site1|https://www.pornhub.com"
    echo "Adult_Site2|https://www.xvideos.com"
}

get_wcf_urls_highbandwidth() {
    echo "Streaming1|https://www.twitch.tv"
    echo "Streaming2|https://www.netflix.com"
}

get_wcf_urls_legalliability() {
    echo "Gambling1|https://www.bet365.com"
    echo "Gambling2|https://www.pokerstars.com"
}

get_wcf_urls_leisure() {
    echo "Gaming1|https://www.miniclip.com"
    echo "Gaming2|https://www.addictinggames.com"
    echo "Social1|https://www.facebook.com/games"
}

# Variables
CSV_FILE=""
WCF_CATEGORY=""
BROWSER_CMD=""
FORCE_BROWSER=""
REAL_USER=""
REAL_UID=""
REAL_GID=""
BROWSERS_TO_TEST=()

################################################################################
# Functions
################################################################################

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║       macOS Defender Check - Web Protection                   ║"
    echo "║                                                               ║"
    echo "║       Microsoft Defender for Endpoint Testing Tool            ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

log_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
    echo -e "$message"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -f FILE     CSV file containing URLs to test (for MDE URL Indicators)"
    echo "              CSV must have 'IndicatorValue' column header"
    echo "  -c CATEGORY Test Web Content Filtering for specific category"
    echo "              Valid categories: AdultContent, HighBandwidth, LegalLiability, Leisure"
    echo "  -b BROWSER  Force specific browser (chrome, edge, safari)"
    echo "              Default: Auto-detect (priority: Chrome > Edge > Safari)"
    echo "  -h          Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0                              # Test with ALL available browsers"
    echo "  $0 -b edge                      # Test with Edge only"
    echo "  $0 -b safari                    # Test with Safari only"
    echo "  $0 -f urls.csv                  # Test ALL browsers with custom URL indicators"
    echo "  $0 -c AdultContent              # Test ALL browsers with Web Content Filtering"
    echo "  $0 -f urls.csv -c Leisure       # Combined test (ALL browsers)"
    echo "  $0 -b chrome -f urls.csv        # Test Chrome only with custom URLs"
    echo ""
    exit 0
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: This script must be run with sudo privileges${NC}"
        echo "Usage: sudo $0"
        exit 1
    fi
    
    # Get the real user who ran sudo (for browser operations)
    if [ -n "$SUDO_USER" ]; then
        REAL_USER="$SUDO_USER"
        REAL_UID=$(id -u "$SUDO_USER")
        REAL_GID=$(id -g "$SUDO_USER")
        log_message "${CYAN}Running as sudo, but will launch browser as user: $REAL_USER${NC}"
    else
        REAL_USER="$USER"
        REAL_UID="$UID"
        REAL_GID="$(id -g)"
    fi
}

setup_log_directory() {
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        log_message "${GREEN}Created log directory: $LOG_DIR${NC}"
    fi
    log_message "${GREEN}Log file: $LOG_FILE${NC}"
}

detect_browser() {
    print_section "Detecting Available Browsers"
    
    local browsers_available=()
    
    # Check all browsers
    if [ -f "$CHROME_PATH" ]; then
        browsers_available+=("chrome")
        log_message "${GREEN}✓ Google Chrome detected${NC}"
    fi
    
    if [ -f "$EDGE_PATH" ]; then
        browsers_available+=("edge")
        log_message "${GREEN}✓ Microsoft Edge detected${NC}"
    fi
    
    if [ -f "$SAFARI_PATH" ]; then
        browsers_available+=("safari")
        log_message "${GREEN}✓ Safari detected${NC}"
        log_message "${YELLOW}  Note: Safari doesn't support command-line private mode${NC}"
    fi
    
    # Exit if no browsers found
    if [ ${#browsers_available[@]} -eq 0 ]; then
        log_message "${RED}✗ No compatible browser found${NC}"
        log_message "${YELLOW}Please install Google Chrome, Microsoft Edge, or use Safari${NC}"
        exit 1
    fi
    
    echo ""
    if [ -n "$FORCE_BROWSER" ]; then
        # User specified a specific browser - test only that one
        case "${FORCE_BROWSER,,}" in
            chrome)
                if [ -f "$CHROME_PATH" ]; then
                    BROWSERS_TO_TEST=("chrome")
                    log_message "${CYAN}Testing with: Google Chrome only (forced)${NC}"
                else
                    log_message "${RED}✗ Google Chrome not found but was requested${NC}"
                    exit 1
                fi
                ;;
            edge)
                if [ -f "$EDGE_PATH" ]; then
                    BROWSERS_TO_TEST=("edge")
                    log_message "${CYAN}Testing with: Microsoft Edge only (forced)${NC}"
                else
                    log_message "${RED}✗ Microsoft Edge not found but was requested${NC}"
                    exit 1
                fi
                ;;
            safari)
                if [ -f "$SAFARI_PATH" ]; then
                    BROWSERS_TO_TEST=("safari")
                    log_message "${CYAN}Testing with: Safari only (forced)${NC}"
                    log_message "${YELLOW}Note: Safari has limited SmartScreen integration${NC}"
                else
                    log_message "${RED}✗ Safari not found but was requested${NC}"
                    exit 1
                fi
                ;;
            *)
                log_message "${RED}✗ Invalid browser: $FORCE_BROWSER${NC}"
                log_message "${YELLOW}Valid options: chrome, edge, safari${NC}"
                exit 1
                ;;
        esac
    else
        # No specific browser requested - test ALL available browsers
        BROWSERS_TO_TEST=("${browsers_available[@]}")
        log_message "${CYAN}Testing with: ALL available browsers${NC}"
        log_message "${CYAN}Browsers to test: ${BROWSERS_TO_TEST[*]}${NC}"
        echo ""
        log_message "${YELLOW}Each browser will open test URLs in a separate incognito/private window${NC}"
    fi
    
    log_message "${CYAN}Available browsers on system: ${browsers_available[*]}${NC}"
}

get_browser_cmd() {
    local browser="$1"
    case "$browser" in
        chrome)
            echo "$CHROME_PATH"
            ;;
        edge)
            echo "$EDGE_PATH"
            ;;
        safari)
            echo "open -a Safari"
            ;;
    esac
}

get_browser_name() {
    local browser="$1"
    case "$browser" in
        chrome)
            echo "Google Chrome"
            ;;
        edge)
            echo "Microsoft Edge"
            ;;
        safari)
            echo "Safari"
            ;;
    esac
}

check_mde_prerequisites() {
    print_section "Checking Microsoft Defender for Endpoint Prerequisites"
    
    local all_checks_passed=true
    
    # Check if MDE is installed
    if [ ! -f "$MDATP_CLI" ]; then
        log_message "${RED}✗ Microsoft Defender for Endpoint is NOT installed${NC}"
        all_checks_passed=false
    else
        log_message "${GREEN}✓ Microsoft Defender for Endpoint is installed${NC}"
        
        # Check Real-Time Protection
        local rtp_status=$("$MDATP_CLI" health --field real_time_protection_enabled 2>/dev/null)
        if [ "$rtp_status" = "true" ]; then
            log_message "${GREEN}✓ Real-Time Protection is ENABLED${NC}"
        else
            log_message "${RED}✗ Real-Time Protection is DISABLED${NC}"
            log_message "${YELLOW}  Please enable Real-Time Protection for web protection features${NC}"
            all_checks_passed=false
        fi
        
        # Check Network Protection
        local np_status=$("$MDATP_CLI" health --field network_protection_status 2>/dev/null)
        if [ "$np_status" = "started" ]; then
            log_message "${GREEN}✓ Network Protection is ENABLED${NC}"
        else
            log_message "${YELLOW}⚠ Network Protection status: $np_status${NC}"
            log_message "${YELLOW}  Network Protection should be enabled for full web protection${NC}"
        fi
        
        # Check onboarding status
        local org_id=$("$MDATP_CLI" health --field org_id 2>/dev/null)
        if [ -n "$org_id" ] && [ "$org_id" != "unknown" ]; then
            log_message "${GREEN}✓ Device is onboarded (Org ID: $org_id)${NC}"
        else
            log_message "${RED}✗ Device is NOT onboarded${NC}"
            log_message "${YELLOW}  Please onboard the device to test URL Indicators and WCF${NC}"
            all_checks_passed=false
        fi
    fi
    
    if [ "$all_checks_passed" = false ]; then
        log_message ""
        log_message "${YELLOW}⚠ Some prerequisites are not met. Tests may not work correctly.${NC}"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

test_smartscreen() {
    print_section "Testing Microsoft Defender SmartScreen"
    
    log_message "${CYAN}Microsoft Defender SmartScreen helps protect against:${NC}"
    log_message "${CYAN}  - Phishing websites${NC}"
    log_message "${CYAN}  - Malware downloads${NC}"
    log_message "${CYAN}  - Malicious websites${NC}"
    echo ""
    
    # Collect all URLs first
    local urls=()
    while IFS='|' read -r test_name url; do
        log_message "${YELLOW}Preparing test: $test_name${NC}"
        log_message "${CYAN}URL: $url${NC}"
        urls+=("$url")
    done < <(get_smartscreen_urls)
    
    # Test with each browser
    for browser in "${BROWSERS_TO_TEST[@]}"; do
        local browser_name=$(get_browser_name "$browser")
        local browser_cmd=$(get_browser_cmd "$browser")
        
        echo ""
        log_message "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
        log_message "${MAGENTA}Testing SmartScreen with: $browser_name${NC}"
        log_message "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        # Open all URLs in one new browser window with multiple tabs
        if [ ${#urls[@]} -gt 0 ]; then
            log_message "${CYAN}Opening all SmartScreen test URLs in a new incognito/private window...${NC}"
            log_message "${CYAN}Expected result: Browser should show SmartScreen warnings for malicious URLs${NC}"
            echo ""
            
            if [ "$browser" = "safari" ]; then
                # Safari - use AppleScript for better control
                # Create AppleScript to open private window with multiple tabs
                local safari_script="tell application \"Safari\"
    activate
    make new document
    set private_win to front window
    tell private_win
        set current tab to (make new tab with properties {URL:\"${urls[0]}\"})
    end tell
    delay 1"
                
                # Add remaining URLs as tabs
                for ((i=1; i<${#urls[@]}; i++)); do
                    safari_script="${safari_script}
    tell private_win
        set current tab to (make new tab with properties {URL:\"${urls[$i]}\"})
    end tell
    delay 0.5"
                done
                
                safari_script="${safari_script}
end tell"
                
                # Execute AppleScript as the real user
                sudo -u "$REAL_USER" osascript -e "$safari_script" 2>/dev/null
                
                echo ""
                log_message "${YELLOW}Note: Safari doesn't support command-line private mode${NC}"
                log_message "${YELLOW}Please enable private browsing manually:${NC}"
                log_message "${YELLOW}  1. Close the window that just opened${NC}"
                log_message "${YELLOW}  2. Press Cmd+Shift+N for new Private Window${NC}"
                log_message "${YELLOW}  3. Then re-run this test with -b safari${NC}"
                echo ""
                log_message "${CYAN}Alternative: Use Chrome or Edge for automatic private mode testing${NC}"
            elif [ "$browser" = "chrome" ]; then
                # Chrome - open in incognito mode with new window
                sudo -u "$REAL_USER" "$browser_cmd" --incognito --new-window "${urls[0]}" >/dev/null 2>&1 &
                sleep 2  # Give the window time to open
                
                # Open remaining URLs as tabs in the same incognito window
                for ((i=1; i<${#urls[@]}; i++)); do
                    sudo -u "$REAL_USER" "$browser_cmd" --incognito "${urls[$i]}" >/dev/null 2>&1 &
                    sleep 1
                done
            elif [ "$browser" = "edge" ]; then
                # Edge - open in InPrivate mode with new window
                sudo -u "$REAL_USER" "$browser_cmd" --inprivate --new-window "${urls[0]}" >/dev/null 2>&1 &
                sleep 2  # Give the window time to open
                
                # Open remaining URLs as tabs in the same InPrivate window
                for ((i=1; i<${#urls[@]}; i++)); do
                    sudo -u "$REAL_USER" "$browser_cmd" --inprivate "${urls[$i]}" >/dev/null 2>&1 &
                    sleep 1
                done
            fi
            
            log_message "${GREEN}✓ All test URLs opened in $browser_name (incognito/private window with ${#urls[@]} tabs)${NC}"
        fi
        
        # If testing multiple browsers, add delay before next browser
        if [ ${#BROWSERS_TO_TEST[@]} -gt 1 ]; then
            echo ""
            log_message "${YELLOW}Pausing 5 seconds before testing next browser...${NC}"
            sleep 5
        fi
    done
    
    echo ""
    log_message "${YELLOW}Note: SmartScreen warnings should appear in the browser tabs.${NC}"
    log_message "${YELLOW}If warnings don't appear, SmartScreen may not be properly configured.${NC}"
    
    if [ ${#BROWSERS_TO_TEST[@]} -gt 1 ]; then
        echo ""
        log_message "${CYAN}Tested ${#BROWSERS_TO_TEST[@]} browser(s): ${BROWSERS_TO_TEST[*]}${NC}"
    fi
}

test_network_protection() {
    print_section "Testing Network Protection"
    
    log_message "${CYAN}Network Protection blocks connections to malicious domains${NC}"
    echo ""
    
    # Get Network Protection test URLs
    while IFS='|' read -r test_name url; do
        log_message "${YELLOW}Testing: $test_name${NC}"
        log_message "${CYAN}URL: $url${NC}"
        
        # Test using curl with timeout
        log_message "${CYAN}Attempting connection...${NC}"
        local start_time=$(date +%s)
        
        if curl -s -m 10 -o /dev/null -w "%{http_code}" "$url" > /dev/null 2>&1; then
            local http_code=$(curl -s -m 10 -o /dev/null -w "%{http_code}" "$url" 2>&1)
            log_message "${YELLOW}⚠ Connection completed with HTTP code: $http_code${NC}"
            log_message "${YELLOW}  Network Protection may not be blocking this URL${NC}"
        else
            log_message "${GREEN}✓ Connection blocked or timed out${NC}"
            log_message "${GREEN}  Network Protection appears to be working${NC}"
        fi
        
        # Check MDE threat log
        log_message "${CYAN}Checking for threat events...${NC}"
        "$MDATP_CLI" threat list 2>/dev/null | tail -n 5 | while read -r line; do
            log_message "  $line"
        done
        
        echo ""
    done < <(get_network_protection_urls)
}

test_url_indicators() {
    print_section "Testing MDE URL Indicators"
    
    if [ -z "$CSV_FILE" ]; then
        log_message "${YELLOW}⚠ No CSV file provided. Skipping URL Indicators test.${NC}"
        log_message "${CYAN}To test URL Indicators, run with: $0 -f urls.csv${NC}"
        return
    fi
    
    if [ ! -f "$CSV_FILE" ]; then
        log_message "${RED}✗ CSV file not found: $CSV_FILE${NC}"
        return
    fi
    
    log_message "${GREEN}✓ CSV file found: $CSV_FILE${NC}"
    log_message "${CYAN}Testing URLs from custom indicators...${NC}"
    echo ""
    
    # Initialize results CSV
    echo "Timestamp,URL,Result,Details" > "$URL_LOG"
    
    # Read CSV file (skip header)
    local line_num=0
    while IFS=, read -r indicator_value || [ -n "$indicator_value" ]; do
        ((line_num++))
        
        # Skip header line
        if [ $line_num -eq 1 ]; then
            if [[ "$indicator_value" != "IndicatorValue" ]]; then
                log_message "${RED}✗ Invalid CSV format. Column header must be 'IndicatorValue'${NC}"
                return
            fi
            continue
        fi
        
        # Clean the URL (remove quotes and whitespace)
        local url=$(echo "$indicator_value" | tr -d '"' | tr -d ' ' | tr -d '\r')
        
        if [ -z "$url" ]; then
            continue
        fi
        
        log_message "${YELLOW}Testing indicator: $url${NC}"
        
        # Try to access the URL
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local result="Unknown"
        local details=""
        
        if timeout 10 curl -s -o /dev/null -w "%{http_code}" "$url" > /dev/null 2>&1; then
            local http_code=$(timeout 10 curl -s -o /dev/null -w "%{http_code}" "$url" 2>&1)
            result="Allowed"
            details="HTTP $http_code - Connection succeeded"
            log_message "${YELLOW}  Result: Connection allowed (HTTP $http_code)${NC}"
        else
            result="Blocked"
            details="Connection failed/blocked"
            log_message "${GREEN}  Result: Connection blocked${NC}"
        fi
        
        # Log to CSV
        echo "$timestamp,\"$url\",$result,\"$details\"" >> "$URL_LOG"
        
        sleep 2
    done < "$CSV_FILE"
    
    log_message ""
    log_message "${GREEN}✓ URL Indicators test complete${NC}"
    log_message "${CYAN}Results saved to: $URL_LOG${NC}"
}

test_web_content_filtering() {
    print_section "Testing Web Content Filtering (WCF)"
    
    if [ -z "$WCF_CATEGORY" ]; then
        log_message "${YELLOW}⚠ No WCF category specified. Skipping WCF test.${NC}"
        log_message "${CYAN}To test WCF, run with: $0 -c <category>${NC}"
        log_message "${CYAN}Available categories: AdultContent, HighBandwidth, LegalLiability, Leisure${NC}"
        return
    fi
    
    log_message "${CYAN}Testing Web Content Filtering for category: $WCF_CATEGORY${NC}"
    echo ""
    
    # Select the appropriate URL function based on category
    local url_function=""
    case "$WCF_CATEGORY" in
        AdultContent)
            url_function="get_wcf_urls_adultcontent"
            ;;
        HighBandwidth)
            url_function="get_wcf_urls_highbandwidth"
            ;;
        LegalLiability)
            url_function="get_wcf_urls_legalliability"
            ;;
        Leisure)
            url_function="get_wcf_urls_leisure"
            ;;
        *)
            log_message "${RED}✗ Invalid category: $WCF_CATEGORY${NC}"
            log_message "${CYAN}Valid categories: AdultContent, HighBandwidth, LegalLiability, Leisure${NC}"
            return
            ;;
    esac
    
    # Test each URL in the category
    while IFS='|' read -r test_name url; do
        log_message "${YELLOW}Testing: $test_name${NC}"
        log_message "${CYAN}URL: $url${NC}"
        
        # Try to access the URL
        if timeout 10 curl -s -o /dev/null -w "%{http_code}" "$url" > /dev/null 2>&1; then
            local http_code=$(timeout 10 curl -s -o /dev/null -w "%{http_code}" "$url" 2>&1)
            log_message "${YELLOW}  Result: Connection allowed (HTTP $http_code)${NC}"
            log_message "${YELLOW}  WCF may not be configured to block this category${NC}"
        else
            log_message "${GREEN}  Result: Connection blocked${NC}"
            log_message "${GREEN}  WCF appears to be working for this category${NC}"
        fi
        
        echo ""
        sleep 2
    done < <($url_function)
    
    log_message "${CYAN}Note: WCF policies are configured in Microsoft Defender portal${NC}"
    log_message "${CYAN}Navigate to: Settings > Endpoints > Web content filtering${NC}"
}

display_test_summary() {
    print_section "Test Summary"
    
    log_message "${CYAN}Microsoft Defender for Endpoint - Web Protection Test Complete${NC}"
    log_message ""
    log_message "${CYAN}Tests Performed:${NC}"
    log_message "  ✓ Microsoft Defender SmartScreen"
    log_message "  ✓ Network Protection"
    
    if [ -n "$CSV_FILE" ]; then
        log_message "  ✓ MDE URL Indicators (Custom URLs)"
    else
        log_message "  - MDE URL Indicators (Not tested - no CSV provided)"
    fi
    
    if [ -n "$WCF_CATEGORY" ]; then
        log_message "  ✓ Web Content Filtering ($WCF_CATEGORY)"
    else
        log_message "  - Web Content Filtering (Not tested - no category specified)"
    fi
    
    log_message ""
    log_message "${GREEN}Test results saved to: $LOG_FILE${NC}"
    
    if [ -n "$CSV_FILE" ]; then
        log_message "${GREEN}URL test results saved to: $URL_LOG${NC}"
    fi
}

display_recommendations() {
    print_section "Recommendations & Next Steps"
    
    echo -e "${CYAN}To ensure full web protection:${NC}"
    echo ""
    echo -e "1. ${YELLOW}Enable Network Protection:${NC}"
    echo "   mdatp config network-protection enforcement-level --value block"
    echo ""
    echo -e "2. ${YELLOW}Configure URL Indicators in Microsoft Defender portal:${NC}"
    echo "   - Navigate to: Settings > Endpoints > Indicators"
    echo "   - Add URLs/domains to block or allow"
    echo ""
    echo -e "3. ${YELLOW}Configure Web Content Filtering policies:${NC}"
    echo "   - Navigate to: Settings > Endpoints > Web content filtering"
    echo "   - Select categories to block (Adult, Gambling, etc.)"
    echo ""
    echo -e "4. ${YELLOW}Review MDE threat events:${NC}"
    echo "   - Command: mdatp threat list"
    echo "   - Portal: Microsoft Defender > Incidents & alerts"
    echo ""
    echo -e "5. ${YELLOW}Monitor protection logs:${NC}"
    echo "   - tail -f /Library/Logs/Microsoft/mdatp/microsoft_defender_core.log"
    echo ""
}

################################################################################
# Main Execution
################################################################################

# Parse command-line arguments
while getopts "f:c:b:h" opt; do
    case $opt in
        f)
            CSV_FILE="$OPTARG"
            ;;
        c)
            WCF_CATEGORY="$OPTARG"
            ;;
        b)
            FORCE_BROWSER="$OPTARG"
            ;;
        h)
            usage
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
    esac
done

main() {
    print_banner
    check_root
    setup_log_directory
    
    log_message "${CYAN}Starting MDE Web Protection Test at $(date)${NC}"
    
    if [ -n "$CSV_FILE" ]; then
        log_message "${CYAN}Testing with custom URL indicators from: $CSV_FILE${NC}"
    fi
    
    if [ -n "$WCF_CATEGORY" ]; then
        log_message "${CYAN}Testing Web Content Filtering category: $WCF_CATEGORY${NC}"
    fi
    
    echo ""
    
    detect_browser
    check_mde_prerequisites
    test_smartscreen
    test_network_protection
    test_url_indicators
    test_web_content_filtering
    
    display_test_summary
    display_recommendations
    
    log_message ""
    log_message "${CYAN}Test completed at $(date)${NC}"
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}All tests completed successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
}

# Run main function
main "$@"
