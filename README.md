# gfwlist2dnsmasq
A shell script which convert gfwlist into dnsmasq rules.

Working on both Linux-based (Debian/Ubuntu/Cent OS/OpenWrt/LEDE/Cygwin/Bash on Windows/etc.) and BSD-based (FreeBSD/Mac OS X/etc.) system.

This script needs `sed`, `base64` and `curl`. You should have these binaries on you system.

__Note: This script now lacks testing. Use carefully. Please send issues to help me debug.__

### Usage
```
sh gfwlist2dnsmasq.sh [options] -o FILE
Valid options are:
    -d, --dns <dns_ip>
                DNS IP address for the GfwList Domains (Default: 127.0.0.1)
    -p, --port <dns_port>
                DNS Port for the GfwList Domains (Default: 5300)
    -s, --ipset <ipset_name>
                Ipset name for the GfwList domains
                (If not given, ipset rules will not be generated.)
    -o, --output <FILE>
                /path/to/output_filename
    -i, --insecure
                Force bypass certificate validation (insecure)
    -h, --help  Usage
```

### OpenWRT / LEDE Usage

For OpenWrt/LEDE system, `base64` and `curl` may not be included into the system by default. For security reason, this script won't bypass the certificate validation. So you should install ca-certificates as well. For LEDE users, you should install ca-bundle in addition:

```
# OpenWrt
opkg update
opkg install coreutils-base64 curl ca-certificates
# LEDE
opkg update
opkg install coreutils-base64 curl ca-certificates ca-bundle
```

If you really want to bypass the certificate validation, use '-i' or '--insecure' option. You should know this is insecure.
