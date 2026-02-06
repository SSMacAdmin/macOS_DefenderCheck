#!/bin/bash

################################################################################
# macOS Defender Check - Tamper Protection
# 
# Description: Tests Microsoft Defender for Endpoint Tamper Protection on macOS
#
# Prerequisites:
# - Microsoft Defender for Endpoint installed and onboarded
# - Tamper Protection enabled
# - Run with sudo privileges
#
# Usage: sudo ./defendercheck-tp.sh
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log directory
LOG_DIR="/tmp/DefenderCheck"
LOG_FILE="${LOG_DIR}/mde_tp_test_$(date +%Y%m%d_%H%M%S).log"

# Microsoft Defender paths
MDE_APP="/Applications/Microsoft Defender.app"
MDATP_CLI="/usr/local/bin/mdatp"
WDAVDAEMON_PATH="/Library/Application Support/Microsoft/Defender/wdavdaemon"

################################################################################
# Functions
################################################################################

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║       macOS Defender Check - Tamper Protection                ║"
    echo "║                                                               ║"
    echo "║         Microsoft Defender for Endpoint Testing Tool          ║"
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

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: This script must be run with sudo privileges${NC}"
        echo "Usage: sudo $0"
        exit 1
    fi
}

setup_log_directory() {
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        log_message "${GREEN}Created log directory: $LOG_DIR${NC}"
    fi
    log_message "${GREEN}Log file: $LOG_FILE${NC}"
}

check_mde_installation() {
    print_section "Checking Microsoft Defender for Endpoint Installation"
    
    if [ -d "$MDE_APP" ]; then
        log_message "${GREEN}✓ Microsoft Defender for Endpoint is installed${NC}"
        
        if [ -f "$MDATP_CLI" ]; then
            log_message "${GREEN}✓ mdatp command-line tool is available${NC}"
            
            # Get version information
            local version=$("$MDATP_CLI" version 2>/dev/null | grep "App version" | awk '{print $3}')
            if [ -n "$version" ]; then
                log_message "${CYAN}  Version: $version${NC}"
            fi
        else
            log_message "${YELLOW}⚠ mdatp command-line tool not found at $MDATP_CLI${NC}"
        fi
    else
        log_message "${RED}✗ Microsoft Defender for Endpoint is NOT installed${NC}"
        log_message "${YELLOW}Please install Microsoft Defender for Endpoint before running this test${NC}"
        exit 1
    fi
}

check_mde_health() {
    print_section "Checking Microsoft Defender for Endpoint Health Status"
    
    if [ -f "$MDATP_CLI" ]; then
        # Check health status
        log_message "${CYAN}Health Status:${NC}"
        "$MDATP_CLI" health --field healthy 2>/dev/null | while read -r line; do
            log_message "  $line"
        done
        
        # Check organization ID (onboarding status)
        log_message ""
        log_message "${CYAN}Onboarding Status:${NC}"
        local org_id=$("$MDATP_CLI" health --field org_id 2>/dev/null)
        if [ -n "$org_id" ] && [ "$org_id" != "unknown" ]; then
            log_message "${GREEN}✓ Device is onboarded (Org ID: $org_id)${NC}"
        else
            log_message "${RED}✗ Device is NOT onboarded to Microsoft Defender for Endpoint${NC}"
            log_message "${YELLOW}Please onboard the device before running tamper protection tests${NC}"
        fi
    fi
}

check_realtime_protection() {
    print_section "Checking Real-Time Protection Status"
    
    if [ -f "$MDATP_CLI" ]; then
        local rtp_status=$("$MDATP_CLI" health --field real_time_protection_enabled 2>/dev/null)
        
        if [ "$rtp_status" = "true" ]; then
            log_message "${GREEN}✓ Real-Time Protection is ENABLED${NC}"
        else
            log_message "${RED}✗ Real-Time Protection is DISABLED${NC}"
            log_message "${YELLOW}Recommendation: Enable Real-Time Protection for full protection${NC}"
        fi
        
        # Check if RTP is available
        local rtp_available=$("$MDATP_CLI" health --field real_time_protection_available 2>/dev/null)
        if [ "$rtp_available" = "true" ]; then
            log_message "${GREEN}✓ Real-Time Protection is available${NC}"
        fi
    fi
}

check_tamper_protection() {
    print_section "Checking Tamper Protection Status"
    
    if [ -f "$MDATP_CLI" ]; then
        # Check if tamper protection is enabled
        local tp_status=$("$MDATP_CLI" health --field tamper_protection 2>/dev/null)
        
        if [ "$tp_status" = "block" ] || [ "$tp_status" = "audit" ]; then
            log_message "${GREEN}✓ Tamper Protection is ENABLED (Mode: $tp_status)${NC}"
            log_message "${CYAN}  Tamper Protection will prevent unauthorized changes to security settings${NC}"
        elif [ "$tp_status" = "disabled" ]; then
            log_message "${YELLOW}⚠ Tamper Protection is DISABLED${NC}"
            log_message "${YELLOW}Recommendation: Enable Tamper Protection from Microsoft Defender portal${NC}"
        else
            log_message "${YELLOW}⚠ Tamper Protection status: $tp_status${NC}"
        fi
    fi
}

test_av_tampering() {
    print_section "Testing Anti-Virus Tampering Protection"
    
    log_message "${CYAN}This test will attempt to disable Real-Time Protection...${NC}"
    log_message "${CYAN}If Tamper Protection is enabled, this should fail.${NC}"
    echo ""
    
    if [ -f "$MDATP_CLI" ]; then
        # Get current RTP status
        local rtp_before=$("$MDATP_CLI" health --field real_time_protection_enabled 2>/dev/null)
        log_message "${CYAN}Real-Time Protection status before test: $rtp_before${NC}"
        
        # Attempt to disable real-time protection
        log_message ""
        log_message "${YELLOW}Attempting to disable Real-Time Protection...${NC}"
        
        local result=$("$MDATP_CLI" config real-time-protection --value disabled 2>&1)
        local exit_code=$?
        
        if [ $exit_code -ne 0 ]; then
            log_message "${GREEN}✓ TAMPER PROTECTION WORKING: Failed to disable Real-Time Protection${NC}"
            log_message "${CYAN}  Error message: $result${NC}"
            
            # Verify RTP is still enabled
            local rtp_after=$("$MDATP_CLI" health --field real_time_protection_enabled 2>/dev/null)
            if [ "$rtp_after" = "$rtp_before" ]; then
                log_message "${GREEN}✓ Real-Time Protection status unchanged: $rtp_after${NC}"
                log_message "${GREEN}  Tamper Protection successfully prevented the change!${NC}"
            fi
        else
            log_message "${RED}✗ TAMPER PROTECTION NOT WORKING: Successfully disabled Real-Time Protection${NC}"
            log_message "${YELLOW}⚠ WARNING: This should not happen if Tamper Protection is properly enabled${NC}"
            
            # Try to re-enable it
            log_message ""
            log_message "${YELLOW}Attempting to re-enable Real-Time Protection...${NC}"
            "$MDATP_CLI" config real-time-protection --value enabled 2>&1
            
            local rtp_after=$("$MDATP_CLI" health --field real_time_protection_enabled 2>/dev/null)
            log_message "${CYAN}Real-Time Protection status after re-enable attempt: $rtp_after${NC}"
        fi
    fi
}

test_uninstall_protection() {
    print_section "Testing Uninstall Protection"
    
    log_message "${CYAN}Checking if the application is protected from uninstallation...${NC}"
    echo ""
    
    # Check if the app is present
    if [ -d "$MDE_APP" ]; then
        log_message "${GREEN}✓ Microsoft Defender application is present${NC}"
        
        # Check if there are tamper protection mechanisms in place
        # Note: On macOS, full uninstall protection requires MDM/System Extension approval
        log_message "${CYAN}Note: Full uninstall protection requires:${NC}"
        log_message "${CYAN}  - System Extension approval${NC}"
        log_message "${CYAN}  - MDM profile deployment${NC}"
        log_message "${CYAN}  - Tamper Protection enabled in MDE portal${NC}"
        
        # Check system extensions
        log_message ""
        log_message "${CYAN}Checking System Extensions...${NC}"
        if command -v systemextensionsctl &> /dev/null; then
            systemextensionsctl list 2>/dev/null | grep -i "microsoft\|defender" | while read -r line; do
                log_message "  $line"
            done
        fi
        
        # Check for MDM profiles
        log_message ""
        log_message "${CYAN}Checking Configuration Profiles...${NC}"
        if command -v profiles &> /dev/null; then
            profiles list 2>/dev/null | grep -i "microsoft\|defender" | while read -r line; do
                log_message "  $line"
            done
        fi
    fi
}

display_summary() {
    print_section "Test Summary"
    
    log_message "${CYAN}Microsoft Defender for Endpoint - Tamper Protection Test Complete${NC}"
    log_message ""
    log_message "${CYAN}Summary:${NC}"
    log_message "  - Installation Status: Checked"
    log_message "  - Health Status: Checked"
    log_message "  - Tamper Protection Status: Checked"
    log_message "  - AV Tampering Test: Completed"
    log_message "  - Uninstall Protection: Checked"
    log_message ""
    log_message "${GREEN}Full test results saved to: $LOG_FILE${NC}"
    echo ""
}

display_recommendations() {
    print_section "Recommendations"
    
    echo -e "${YELLOW}To ensure Tamper Protection is working correctly:${NC}"
    echo ""
    echo -e "1. ${CYAN}Enable Tamper Protection in Microsoft Defender portal:${NC}"
    echo "   - Navigate to Settings > Endpoints > Advanced features"
    echo "   - Enable 'Tamper Protection'"
    echo ""
    echo -e "2. ${CYAN}Verify device onboarding:${NC}"
    echo "   - Run: mdatp health --field org_id"
    echo "   - Should return your organization's tenant ID"
    echo ""
    echo -e "3. ${CYAN}Deploy MDM configuration profile:${NC}"
    echo "   - Use Intune or Jamf to deploy Microsoft Defender profile"
    echo "   - Include System Extension and TCC permissions"
    echo ""
    echo -e "4. ${CYAN}Monitor tamper attempts:${NC}"
    echo "   - Check logs: tail -f /Library/Logs/Microsoft/mdatp/microsoft_defender_core.log"
    echo "   - Review alerts in Microsoft Defender portal"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    print_banner
    check_root
    setup_log_directory
    
    log_message "${CYAN}Starting MDE Tamper Protection Test at $(date)${NC}"
    echo ""
    
    check_mde_installation
    check_mde_health
    check_realtime_protection
    check_tamper_protection
    test_av_tampering
    test_uninstall_protection
    
    display_summary
    display_recommendations
    
    log_message ""
    log_message "${CYAN}Test completed at $(date)${NC}"
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Test completed successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
}

# Run main function
main "$@"
