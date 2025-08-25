# OpenWrt Passwall2 Auto Configuration
Automated configuration script for setting up Passwall2 on the Xiaomi AX3000T running OpenWrt.
Also compatible with similar OpenWrt-supported hardware. Minimum hardware profile:
- Flash 128MB
- RAM 256MB
- Note: On Xiaomi AX3000T, factory partitioning results in an overlay size of ~60 MB, compared to ~90 MB available on similar routers. The script is optimized to work with limited storage space. To regain more free space you will need to modify factory partitioning using UART or direct flash the ROM chip (not recommanded), and recovering original firmware is only possible by mentioned methods.
- Manual Upgrade Required: Sing-box must be manually upgraded via the Passwall2 App Update page due to router storage limits; all other packages install automatically at their latest versions.
  
## Installation
### Run from ssh
```bash
rm -f /tmp/set.sh && wget -O /tmp/set.sh https://raw.githubusercontent.com/sadraimam/ax3000t/refs/heads/main/set.sh && chmod +x /tmp/set.sh && sh /tmp/set.sh
```

## Features
- Advanced custom package installer using RAM with retry download logic and optional custom URL
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
