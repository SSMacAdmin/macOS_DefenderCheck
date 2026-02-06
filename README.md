# macOS Defender Check

**Microsoft Defender for Endpoint Testing Tool for macOS**

This is a macOS bash/shell script to check your Defender configuration. It provides comprehensive testing capabilities for Microsoft Defender for Endpoint (MDE) security features on macOS.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Scripts](#scripts)
- [Test Scenarios](#test-scenarios)
- [Logs and Output](#logs-and-output)
- [Troubleshooting](#troubleshooting)


## 🔍 Overview

macOS Defender Check helps security administrators and IT professionals validate that Microsoft Defender for Endpoint is properly configured and functioning on macOS devices. The toolkit includes two main scripts:

1. **defendercheck-tp.sh** - Tamper Protection testing
2. **defendercheck-wp.sh** - Web Protection testing

## ✨ Features

### Tamper Protection Testing (`defendercheck-tp.sh`)

- ✅ Verifies MDE installation and health status
- ✅ Checks Real-Time Protection status
- ✅ Validates Tamper Protection configuration
- ✅ Tests anti-virus tampering prevention
- ✅ Checks uninstall protection mechanisms
- ✅ Verifies System Extension approval
- ✅ Reviews MDM configuration profiles

### Web Protection Testing (`defendercheck-wp.sh`)

- ✅ Tests Microsoft Defender SmartScreen
- ✅ Validates Network Protection
- ✅ Tests custom URL Indicators (with CSV import)
- ✅ Validates Web Content Filtering (WCF) policies
- ✅ Supports multiple categories: AdultContent, HighBandwidth, LegalLiability, Leisure
- ✅ Multi-browser support (Chrome, Edge, Safari)
- ✅ Detailed logging and CSV export

## 📦 Prerequisites

### Required

- macOS 11.0 (Big Sur) or later
- Microsoft Defender for Endpoint installed
- Administrator/sudo privileges
- bash 3.2 or later (default macOS bash is compatible)
  - **Note**: Scripts are compatible with macOS default bash 3.2
  - No need to upgrade to bash 4.0+ (unlike some other scripts)

### Recommended

- Microsoft Defender for Endpoint onboarded to your organization
- Real-Time Protection enabled
- Network Protection enabled (for web protection tests)
- Tamper Protection enabled (for tamper protection tests)
- Google Chrome or Microsoft Edge installed (for web protection tests)

### MDE Configuration

Ensure the following are configured in Microsoft Defender Security Center:

1. **Device Onboarding**: Device must be onboarded to your tenant
2. **Real-Time Protection**: Enabled
3. **Network Protection**: Set to "Block" mode
4. **Tamper Protection**: Enabled (for tamper protection tests)
5. **System Extensions**: Approved in System Preferences
6. **MDM Profile**: Deployed via Intune or Jamf (recommended)

## 🚀 Installation

### Download the Scripts

```bash
# Clone or download the scripts
curl -O https://github.com/SSMacAdmin/macOS_DefenderCheck/scripts/defendercheck-tp.sh
curl -O https://github.com/SSMacAdmin/macOS_DefenderCheck/scripts/defendercheck-wp.sh
curl -O https://github.com/SSMacAdmin/macOS_DefenderCheck/sample_urls.csv

# Make scripts executable
chmod +x defendercheck-tp.sh
chmod +x defendercheck-wp.sh
```

### Verify MDE Installation

```bash
# Check if mdatp is installed
which mdatp

# Check MDE health
mdatp health
```

## 📖 Usage

### Tamper Protection Testing

**Basic Test:**

```bash
sudo ./defendercheck-tp.sh
```

**This will**:

1. Check MDE installation
2. Verify health status
3. Check Real-Time Protection
4. Validate Tamper Protection
5. Attempt to tamper with AV settings
6. Check uninstall protection


### Web Protection Testing

**Test 1: Test ALL Browsers (Default)**

```bash
sudo ./defendercheck-wp.sh
# Tests Chrome, Edge, and Safari (if installed)
```

**Test 2: Test Specific Browser**

```bash
sudo ./defendercheck-wp.sh -b edge     # Edge only
sudo ./defendercheck-wp.sh -b chrome   # Chrome only
sudo ./defendercheck-wp.sh -b safari   # Safari only
```

**Test 3: With Custom URL Indicators**

```bash
sudo ./defendercheck-wp.sh -f sample_urls.csv           # All browsers
sudo ./defendercheck-wp.sh -f sample_urls.csv -b edge   # Edge only
```

**Test 4: With Web Content Filtering Category**

```bash
sudo ./defendercheck-wp.sh -c AdultContent              # All browsers
sudo ./defendercheck-wp.sh -c AdultContent -b chrome    # Chrome only
```

**Test 5: Combined Test**

```bash
sudo ./defendercheck-wp.sh -f sample_urls.csv -c Leisure              # All browsers
sudo ./defendercheck-wp.sh -f sample_urls.csv -c Leisure -b edge      # Edge only
```

### Command-Line Options

#### defendercheck-wp.sh Options

| Option | Description | Example |
|--------|-------------|---------|
| `-f FILE` | CSV file with URLs to test | `-f urls.csv` |
| `-c CATEGORY` | WCF category to test | `-c AdultContent` |
| `-b BROWSER` | Force specific browser (chrome, edge, safari)<br>Default: Test ALL available browsers | `-b safari` |
| `-h` | Display help message | `-h` |

**Browser Testing:**

- **No `-b` flag**: Tests ALL available browsers (Chrome, Edge, Safari)
- **With `-b` flag**: Tests only the specified browser

#### Available WCF Categories

- `AdultContent` - Adult/pornographic content
- `HighBandwidth` - Streaming services (Netflix, Twitch)
- `LegalLiability` - Gambling and illegal content
- `Leisure` - Gaming and social media

## 📝 Scripts

### defendercheck-tp.sh

Tests Microsoft Defender for Endpoint Tamper Protection features.

**What it tests:**

- MDE installation verification
- Device health and onboarding status
- Real-Time Protection status
- Tamper Protection configuration
- Protection against AV tampering
- System Extension approval
- MDM profile deployment

**Expected Behavior:**

- If Tamper Protection is enabled, attempts to disable RTP should fail
- System Extensions should be approved and loaded
- MDM profiles should be present

### defendercheck-wp.sh

Tests Microsoft Defender for Endpoint Web Protection features across multiple browsers.

**What it tests:**

- Microsoft Defender SmartScreen (phishing, malware sites)
- Network Protection (malicious domain blocking)
- Custom URL Indicators (from CSV file)
- Web Content Filtering policies

**Browser Support:**

- Tests ALL available browsers by default (Chrome, Edge, Safari)
- Can test a specific browser with `-b` flag
- Chrome/Edge: Automatic incognito/private mode
- Safari: Manual private mode (see troubleshooting)

**Expected Behavior:**

- SmartScreen should warn/block malicious URLs
- Network Protection should block dangerous connections
- URL Indicators should be blocked/allowed per policy
- WCF should block sites in configured categories
- Each browser opens test URLs in a separate window

## 🧪 Test Scenarios

### Scenario 1: Verify Tamper Protection

```bash
sudo ./defendercheck-tp.sh
```

**Expected Results:**

- ✅ MDE is installed and healthy
- ✅ Tamper Protection is enabled
- ✅ Attempt to disable RTP fails
- ✅ Security settings remain protected

### Scenario 2: Test SmartScreen

```bash
sudo ./defendercheck-wp.sh
```

**Expected Results:**

- ✅ Browser opens Microsoft SmartScreen demo sites
- ✅ Warning pages appear for phishing/malware URLs
- ✅ Legitimate sites load normally

### Scenario 3: Test Custom URL Indicators

**Step 1:** Create your CSV file

```csv
IndicatorValue
https://malicious-site.com
https://blocked-domain.org
```

**Step 2:** Run the test

```bash
sudo ./defendercheck-wp.sh -f your_urls.csv
```

**Expected Results:**

- ✅ URLs matching block indicators are blocked
- ✅ URLs matching allow indicators are allowed
- ✅ Results are logged to CSV

### Scenario 4: Test Web Content Filtering

**Configure WCF in MDE Portal:**

1. Navigate to Settings > Endpoints > Web content filtering
2. Enable blocking for "Adult content"

**Run the test:**
```bash
sudo ./defendercheck-wp.sh -c AdultContent
```

**Expected Results:**

- ✅ Adult content sites are blocked
- ✅ Connection attempts fail/timeout
- ✅ Events are logged in MDE

## 📊 Logs and Output

### Log Location

All logs are stored in `/tmp/DefenderCheck/`:

```
/tmp/DefenderCheck/
├── mde_tp_test_20260114_143052.log          # Tamper Protection test log
├── mde_wp_test_20260114_143152.log          # Web Protection test log
└── url_test_results_20260114_143152.csv     # URL test results (CSV)
```

### Log Contents

**Tamper Protection Log:**

- Installation verification
- Health status checks
- Tamper Protection status
- Tampering test results
- System Extension status
- MDM profile information

**Web Protection Log:**

- SmartScreen test results
- Network Protection tests
- URL Indicator results
- WCF test results

**URL Test Results CSV:**

```csv
Timestamp,URL,Result,Details
2026-01-14 14:31:52,"https://malicious-site.com",Blocked,"Connection failed/blocked"
2026-01-14 14:31:54,"https://allowed-site.com",Allowed,"HTTP 200 - Connection succeeded"
```

### View Logs

```bash
# View latest Tamper Protection log
tail -f /tmp/DefenderCheck/mde_tp_test_*.log

# View latest Web Protection log
tail -f /tmp/DefenderCheck/mde_wp_test_*.log

# View URL test results
cat /tmp/DefenderCheck/url_test_results_*.csv
```

## 🔧 Troubleshooting

### Common Issues

#### Issue: "mdatp: command not found"

**Solution:**

```bash
# Verify MDE installation
ls -la /usr/local/bin/mdatp

# If not present, reinstall MDE
# Download from Microsoft Defender Security Center
```

#### Issue: "Device is NOT onboarded"

**Solution:**

```bash
# Check onboarding status
mdatp health --field org_id

# Re-onboard the device using the onboarding package from MDE portal
```

#### Issue: "Real-Time Protection is DISABLED"

**Solution:**

```bash
# Enable Real-Time Protection
sudo mdatp config real-time-protection --value enabled

# Verify
mdatp health --field real_time_protection_enabled
```

#### Issue: "Network Protection status: stopped"

**Solution:**

```bash
# Enable Network Protection
sudo mdatp config network-protection enforcement-level --value block

# Verify
mdatp health --field network_protection_status
```

#### Issue: Tamper Protection tests fail

**Solution:**

1. Enable Tamper Protection in Microsoft Defender Security Center
2. Navigate to: Settings > Endpoints > Advanced features
3. Toggle "Tamper Protection" to ON
4. Wait 15-30 minutes for policy sync
5. Re-run the test

#### Issue: Browser errors about cache/profile when running tests

**Common errors:**

```
ERROR:chrome/browser/process_singleton_posix.cc Failed to create SingletonLock
ERROR:chrome/browser/mac/dock.mm dock_plist is not an NSDictionary
ERROR:net/disk_cache/simple/simple_version_upgrade.cc Failed to write fake index
```

**Explanation:**

- These are harmless warnings from the browser when launched via sudo
- The script now launches browsers as your user account (not root) to minimize these
- Browsers still open correctly and tests still work

**Solution (if errors persist):**

```bash
# The warnings don't affect functionality, but if you want to suppress them:
sudo ./defendercheck-wp.sh 2>/dev/null  # Suppress stderr
```

#### Issue: Safari doesn't open in private mode or URLs don't load

**Explanation:**

Safari doesn't support reliable command-line private browsing mode like Chrome/Edge do.

**Solution:**

1. **Manual Private Mode:**

   ```bash
   # Open Safari in Private Browsing first
   # Press: Cmd+Shift+N
   # Then run the test
   sudo ./defendercheck-wp.sh -b safari
   ```

2. **Recommended: Use Chrome or Edge for automatic private mode:**

   ```bash
   sudo ./defendercheck-wp.sh -b edge    # Fully automatic InPrivate mode
   sudo ./defendercheck-wp.sh -b chrome  # Fully automatic Incognito mode
   ```

3. **Test all browsers except Safari:**

   ```bash
   # Safari will still be tested but in normal mode
   # Chrome and Edge will use private mode automatically
   sudo ./defendercheck-wp.sh
   ```

**Note:** Chrome and Edge provide better SmartScreen integration and automatic private mode support.

#### Issue: Browser doesn't show SmartScreen warnings

**Solution:**

1. Ensure you're using Chrome or Edge (Safari has limited support)
2. Check that MDE browser extension is installed
3. Verify Real-Time Protection is enabled
4. Check browser settings allow extensions

### MDE Health Check

```bash
# Comprehensive health check
mdatp health

# Check specific fields
mdatp health --field real_time_protection_enabled
mdatp health --field tamper_protection
mdatp health --field network_protection_status
mdatp health --field org_id
```

### View MDE Logs

```bash
# Core MDE logs
tail -f /Library/Logs/Microsoft/mdatp/microsoft_defender_core.log

# Network Protection logs
tail -f /Library/Logs/Microsoft/mdatp/microsoft_defender_network_protection.log

# Browser Protection logs
tail -f /Library/Logs/Microsoft/mdatp/microsoft_defender_browser_protection.log
```

## 🛡️ Security Considerations

1. **Run with sudo**: Both scripts require root privileges to interact with MDE
2. **Test in isolated environment**: Consider testing in a VM or isolated network first
3. **Review logs**: Always review logs for sensitive information before sharing
4. **CSV files**: Sanitize CSV files to remove any internal URLs before sharing
5. **Malicious URLs**: The scripts intentionally access known malicious URLs for testing


## 🙏 Acknowledgments

- Microsoft Defender for Endpoint team
- macOS security community

## 📚 Additional Resources

### Microsoft Documentation

- [Microsoft Defender for Endpoint on macOS](https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/microsoft-defender-endpoint-mac)
- [Deploy Microsoft Defender for Endpoint on macOS with Intune](https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/mac-install-with-intune)
- [Network Protection for macOS](https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/network-protection-macos)
- [Web Content Filtering](https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/web-content-filtering)

### Useful Commands

```bash
# MDE version
mdatp version

# Full health report
mdatp health

# List threats
mdatp threat list

# Scan a file
mdatp scan custom --path /path/to/file

# Update definitions
mdatp definitions update

# Enable diagnostic logging
mdatp log level set --level verbose
```

---

**Note**: This is an unofficial testing tool. Always test in a controlled environment before deploying to production systems.

**Disclaimer**: The scripts intentionally access known malicious URLs for testing purposes. Ensure you have proper authorization before running these tests on your network.
