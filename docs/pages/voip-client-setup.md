---
layout: default
title: VOIP Client Setup Guide - AgencyStack Documentation
---

# VOIP Client Setup Guide

This guide helps you connect to your AgencyStack VOIP system using free, open-source tools on your preferred device.

## Account Information

Before connecting, make sure you have received the following information from your administrator:

- **SIP Username**: Usually your extension number (e.g., 101)
- **SIP Password**: Your secure password
- **SIP Domain**: The VOIP server address (e.g., voip.yourdomain.com)
- **STUN Server**: stun.yourdomain.com (or stun.l.google.com:19302 as fallback)
- **TURN Server**: Optional, for difficult network situations

## Desktop Setup

### Windows

#### Using MicroSIP (Recommended)
1. Download [MicroSIP](https://www.microsip.org/downloads) (free & open-source)
2. Install and open MicroSIP
3. Click "Add Account"
4. Enter your details:
   - **SIP Username**: Your extension (e.g., 101)
   - **SIP Domain**: Your server (e.g., voip.yourdomain.com)
   - **SIP Password**: Your password
   - **Display Name**: Your name
5. In the "Network" tab, enable "Use STUN" and enter the STUN server address
6. Click "OK" to save and connect

#### Using Linphone
1. Download [Linphone](https://www.linphone.org/releases/windows/app) (open-source)
2. Follow the installation wizard
3. Launch Linphone and go to Settings
4. Create a new SIP account with your credentials
5. Enable STUN server in network settings

### macOS

#### Using Telephone
1. Download [Telephone](https://telephoneapp.com/) (free & open-source)
2. Install and open the application
3. Go to Preferences > Accounts > Add (+)
4. Enter your account details:
   - **Username**: Your extension
   - **Domain**: Your SIP server domain
   - **Password**: Your SIP password
5. Click "OK" to save and connect

#### Using Linphone
1. Download [Linphone](https://www.linphone.org/releases/macos/app)
2. Follow the same configuration steps as the Windows version

### Linux

#### Using Linphone
1. Install Linphone using your package manager:
   ```bash
   # Ubuntu/Debian
   sudo apt install linphone
   
   # Fedora
   sudo dnf install linphone
   ```
2. Launch Linphone and configure your SIP account

#### Using Jami
1. Install [Jami](https://jami.net/download-jami-linux/) using your distribution's package manager
2. Launch Jami and go to Settings > Account
3. Select "Add SIP Account"
4. Enter your credentials and server information

## Mobile Setup

### Android

#### Using Linphone
1. Download [Linphone](https://play.google.com/store/apps/details?id=org.linphone) from Google Play Store
2. Open the app and tap "Use SIP account"
3. Enter your credentials:
   - **Username**: Your extension
   - **SIP Domain**: Your server address
   - **Password**: Your SIP password
4. Tap "Connect" to save and register

#### Using Zoiper
1. Download [Zoiper](https://play.google.com/store/apps/details?id=com.zoiper.android.app) from Google Play Store
2. Open the app and tap "Configure manually"
3. Select "SIP" as the account type
4. Enter your account details and tap "Save"

### iOS

#### Using Linphone
1. Download [Linphone](https://apps.apple.com/us/app/linphone/id360065638) from the App Store
2. Open the app and create a new SIP account
3. Enter your SIP credentials and server information
4. Tap "Connect" to register

#### Using Zoiper
1. Download [Zoiper](https://apps.apple.com/us/app/zoiper-lite-voip-soft-phone/id438949960) from the App Store
2. Follow the same configuration steps as the Android version

## Web Browser Access

Your AgencyStack VOIP system also provides a web interface for making and receiving calls directly from your browser:

1. Open your web browser (Chrome or Firefox recommended)
2. Navigate to https://voip.yourdomain.com/webphone (replace with your actual server address)
3. Log in with your SIP extension and password
4. Allow microphone and speaker access when prompted
5. The web interface will connect to the VOIP server

## Troubleshooting

### Cannot Connect
- Verify your username, password, and server address
- Ensure you're not behind a restrictive firewall
- Try enabling the STUN server in your client settings

### Poor Call Quality
- Test your internet connection speed
- Try using a wired connection instead of Wi-Fi
- Disable other bandwidth-intensive applications
- Enable echo cancellation in your client settings

### No Audio
- Check microphone/speaker permissions
- Verify audio device selection in your VOIP client
- Try a different headset or microphone

## Getting Help

If you continue to experience issues, contact your system administrator with:
- The exact error message you're receiving
- Your device and VOIP client details
- Any troubleshooting steps you've already tried

---

For more advanced configuration options, refer to the documentation for your specific VOIP client or contact your AgencyStack administrator.
