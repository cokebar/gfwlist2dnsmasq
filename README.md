# gfwlist2dnsmasq
A shell script which covert gfwlist into dnsmasq rules.
```
    Usage: gfwlist2dnsmasq.sh [options] -f FILE
    Valid options are:
        -d <dns_ip>        DNS IP address for the GfwList Domains (Default: 127.0.0.1)
        -p <dns_port>      DNS Port for the GfwList Domains (Default: 5300)
        -s <ipset_name>    ipset name for the GfwList domains (If not given, ipset rules will not be generated.)
        -f <FILE>          /path/to/output_filename
        -h                 Usage
```