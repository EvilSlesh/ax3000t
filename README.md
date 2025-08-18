# OpenWrt + Passwall2 Auto Configuration [Xiaomi AX3000T]
Automated configuration script for setting up Passwall2 on the Xiaomi AX3000T running OpenWrt.
Also compatible with similar OpenWrt-supported hardware.

## Installation
### Run from ssh
```bash
rm -f /tmp/set.sh && wget -O /tmp/set.sh https://raw.githubusercontent.com/sadraimam/ax3000t/refs/heads/main/set.sh && chmod +x /tmp/set.sh && sh /tmp/set.sh
```

## Features
- Advanced custom package installer using RAM with retry download logic and custom ipk URL option
- Installs and configures Passwall2 with recommended defaults.
- Sets up optimized DNS and network settings
- Configures WiFi with secure defaults
- Adds custom routing rules for Iranian networks

## Prerequisites
- OpenWrt installed (non-SNAPSHOT version)
- Root access to the router
- Working internet connection

## Default Settings
- Default root password: 123456789 (Change after installation!)
- Timezone: Asia/Tehran
- DNS: Google DNS (8.8.4.4, 2001:4860:4860::8844)
