#/bin/sh

# Name:        gfwlist2dnsmasq.sh
# Desription:  A shell script which convert gfwlist into dnsmasq rules.
# Version:     0.3 (2017.02.22)
# Author:      Cokebar Chi
# Website:     https://github.com/cokebar

usage() {
        cat <<-EOF

    Usage: gfwlist2dnsmasq.sh [options] -f FILE
    Valid options are:
        -d <dns_ip>        DNS IP address for the GfwList Domains (Default: 127.0.0.1)
        -p <dns_port>      DNS Port for the GfwList Domains (Default: 5300)
        -s <ipset_name>    ipset name for the GfwList domains (If not given, ipset rules will not be generated.)
        -f <FILE>          /path/to/output_filename
        -h                 Usage
EOF
        exit $1
}

DNS_IP=''
DNS_PORT=''
IPSET_NAME=''
FILE_FULLPATH=''

while getopts "d:p:s:f:h" arg; do
	case "$arg" in
		d)
			DNS_IP=$OPTARG
			;;
		f)
			OUT_FILE=$OPTARG
			;;
		p)
			DNS_PORT=$OPTARG
			;;
		s)
			IPSET_NAME=$OPTARG
			;;
		h)
			usage 0
			;;
		*)
			echo "Invalid argument: -$OPTARG"
			exit 1
			;;
	esac
done

########################### Check input arguments ###########################

# Check path & file name
if [ -z $OUT_FILE ]; then
	echo 'Please enter full path to the file.( Use: -f /path/to/output_filename)'
	exit 1
else
	if [ -z ${OUT_FILE##*/} ]; then
		echo 'Please enter full path to the file, include file name.'
		exit 1
	else
		if [ ! -d ${OUT_FILE%/*} ]; then
			echo "Folder do not exist: ${OUT_FILE%/*}"
			exit 1
		fi
	fi
fi

# Check DNS IP
if [ -z $DNS_IP ]; then
	DNS_IP=127.0.0.1
else
	IP_TEST=$(echo $DNS_IP | grep -E '^((2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)\.){3}(2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)$')
	if [ "$IP_TEST" != "$DNS_IP" ]; then
		echo 'Please enter a valid DNS server IP address.'
		exit 1
	fi
fi

# Check DNS port
if [ -z $DNS_PORT ]; then
	DNS_PORT=5300
elif [ $DNS_PORT -lt 1 -o $DNS_PORT -gt 65535 ]; then
	echo 'Please enter a valid DNS server port.'
	exit 1
fi

# Check ipset name
if [ -z $IPSET_NAME ]; then
	WITH_IPSET=0
else
	IPSET_TEST=$(echo $IPSET_NAME | grep -E '^\w+$')
	if [ "$IPSET_TEST" != "$IPSET_NAME" ]; then
		echo 'Please enter a valid IP set name.'
		exit 1
	else
		WITH_IPSET=1
	fi
fi

########################### BEGIN THE MAIN ROUTINE ###########################

# Set Global Var
BASE_URL='https://github.com/gfwlist/gfwlist/raw/master/gfwlist.txt'
RND=`od -x /dev/urandom | head -n 1 | awk '{print $2}'`
TMP_DIR="/tmp/gfwlist2dnsmasq.$RND"
BASE64_FILE="$TMP_DIR/base64.txt"
GFWLIST_FILE="$TMP_DIR/gfwlist.txt"
DOMAIN_FILE="$TMP_DIR/gfwlist2domain.tmp"
GOOGLE_DOMAIN_FILE="$TMP_DIR/google_domain.txt"
UNIQ_DOMAIN_FILE="$TMP_DIR/gfwlist2uniq_domain.tmp"

# Fetch GfwList and decode it into plain text
echo -e 'Fetching GfwList...\c'
mkdir $TMP_DIR
wget -q -O$BASE64_FILE $BASE_URL
if [ $? != 0 ]; then
	echo -e '\033[31m Failed to fetch gfwlist.txt. Please check your Internet connection.\033[0m'
	exit 2
fi
base64 -d $BASE64_FILE > $GFWLIST_FILE
echo -e ' Done.\n'

# Convert
IGNORE_PATTERN='^\!|\[|^@@|(https?://){0,1}[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'
HEAD_FILTER_PATTERN='s#^(\|\|)?(https?://)?##g'
TAIL_FILTER_PATTERN='s#/.*$##g'
DOMAIN_PATTERN='([a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+)'
HANDLE_WILDCARD_PATTERN='s#^(([a-zA-Z0-9]*\*[-a-zA-Z0-9]*)?(\.))?([a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+)(\*)?#\4#g'

echo 'Converting GfwList to dnsmasq rules...'
echo -e '\033[33m\nWARNING:\nThe following lines in GfwList contain regex, and might be ignored.\n \033[0m'
cat $GFWLIST_FILE | grep -n '^/.*$'
echo -e "\033[33m\nThis script will try to convert some of the regex rules. But you should know this may not be a equivalent conversion.\nIf there's regex rules which this script do not deal with, you should add the domain manually to the list.\n\033[0m"
grep -vE $IGNORE_PATTERN $GFWLIST_FILE | sed -r $HEAD_FILTER_PATTERN | sed -r $TAIL_FILTER_PATTERN | grep -E $DOMAIN_PATTERN | sed -r $HANDLE_WILDCARD_PATTERN > $DOMAIN_FILE

# Add Google search domains
echo -e 'Fetching Google search domain list...\c'
wget -q -O$GOOGLE_DOMAIN_FILE https://www.google.com/supported_domains
if [ $? != 0 ]; then
	echo -e '\033[31mFailed. Please check your Internet connection.\033[0m'
	exit 2
fi
echo -e ' Done\n'
sed 's#^\.##g' $GOOGLE_DOMAIN_FILE >> $DOMAIN_FILE
echo 'Google search domains... Added.'

# Add blogspot domains
echo -e 'blogspot.com\nblogspot.hk\nblogspot.jp\nblogspot.tw\nblogspot.kr\nblogspot.sg\nblogspot.fr\nblogspot.co.uk\nblogspot.cat' >> $DOMAIN_FILE
echo 'Blogspot domains... Added.'

# Add twimg.edgesuit.net
echo 'twimg.edgesuit.net' >> $DOMAIN_FILE
echo 'twimg.edgesuit.net... Added.'

# Delete duplicated domains:
sort -u $DOMAIN_FILE > $UNIQ_DOMAIN_FILE

# Convert domains into dnsmasq rules
if [ $WITH_IPSET == 1 ]; then
	echo 'Ipset rules included.'
	sed -ir.bak 's#.*#server=/\0/'$DNS_IP'\#'$DNS_PORT'\nipset=/\0/'$IPSET_NAME'#g' $UNIQ_DOMAIN_FILE
else
	echo 'Ipset rules not included.'
	sed -ir.bak 's#.*#server=/\0/'$DNS_IP'\#'$DNS_PORT'#g' $UNIQ_DOMAIN_FILE
fi
echo -e '\nConverting GfwList to dnsmasq rules... Done.\n'

# Generate output file
echo -e 'Generating dnsmasq configuration file...\c'
echo '# GfwList ipset rules for dnsmasq' > $OUT_FILE
LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
echo "# Last Updated on $LOGTIME" >> $OUT_FILE
echo '# ' >> $OUT_FILE
cat $UNIQ_DOMAIN_FILE >> $OUT_FILE
echo -e ' Done.\n'

# Clean up temp files
echo -e 'Cleaning up...\c'
rm -rf $TMP_DIR
echo -e ' Done.\n'

echo 'Finished!'