# gfwlist2dnsmasq
A shell script which convert gfwlist into dnsmasq rules.

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

Before using this script, you should install curl first.

For security reason, this script won't bypass the certificate validation. So you should install ca-certificates as well.

You can follow this to install them:

```
mkdir -p /etc/ssl/certs
export SSL_CERT_DIR=/etc/ssl/certs
source /etc/profile
opkg update
opkg install ca-certificates curl
```

If you have problem installing ca-certificates, or if you really want to bypass the certificate validation, use '-i' or '--insecure' option. You should know this is insecure.
