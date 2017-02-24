# gfwlist2dnsmasq
A shell script which convert gfwlist into dnsmasq rules.

__Note: This script now lacks testing. Use carefully. Please send issues to help me debug.__

### Usage
```
    Usage: sh gfwlist2dnsmasq.sh [options] -f FILE
    Valid options are:
        -d <dns_ip>        DNS IP address for the GfwList Domains (Default: 127.0.0.1)
        -p <dns_port>      DNS Port for the GfwList Domains (Default: 5300)
        -s <ipset_name>    ipset name for the GfwList domains (If not given, ipset rules will not be generated.)
        -f <FILE>          /path/to/output_filename
		-b                 Force bypass certificate validation (insecure)
        -h                 Usage
```

### OpenWRT / LEDE Usage

Before using this script, you should install curl first.

For security reason, this script won't bypass the certificate validation. You should install ca-certificates as well.

You can follow this to install them:

```
mkdir -p /etc/ssl/certs
export SSL_CERT_DIR=/etc/ssl/certs
source /etc/profile
opkg update
opkg install ca-certificates curl
```

If you have problem installing ca-certificates, or if you really want to bypass the certificate validation, use "-b" option. You should know this is insecure.