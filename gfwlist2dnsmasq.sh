#/bin/sh

# Name:        gfwlist2dnsmasq.sh
# Desription:  A shell script which convert gfwlist into dnsmasq rules.
# Version:     0.5 (2017.03.07)
# Author:      Cokebar Chi
# Website:     https://github.com/cokebar

usage() {
        cat <<-EOF

Usage: sh gfwlist2dnsmasq.sh [options] -o FILE
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
EOF
        exit $1
}

clean_and_exit(){
	# Clean up temp files
	printf 'Cleaning up...'
	rm -rf $TMP_DIR
	printf ' Done.\n\n'
	exit $1
}

DNS_IP=''
DNS_PORT=''
IPSET_NAME=''
FILE_FULLPATH=''
CURL_EXTARG=''

while [ ${#} -gt 0 ]; do
	case "${1}" in
		--help | -h)
			usage 0
			;;
		--insecure | -i)
			CURL_EXTARG='--insecure'
			;;
		--dns | -d)
			DNS_IP="$2"
			shift
			;;
		--port | -p)
			DNS_PORT="$2"
			shift
			;;
		--ipset | -s)
			IPSET_NAME="$2"
			shift
			;;
		--output | -o)
			OUT_FILE="$2"
			shift
			;;
		*)
			echo "Invalid argument: $1"
			usage 1
			;;
	esac
	shift 1
done

############################## Check Dependency #############################

which sed awk base64 curl >/dev/null
if [ $? != 0 ]; then
	printf '\033[31mError: Missing Dependency.\nPlease check whether you have the following binaries on you system:\n, sed, awk, base64, curl\033[m\n'
	exit 3
fi

SYS_KERNEL=`uname -s`
if [ $SYS_KERNEL == "Darwin"  -o $SYS_KERNEL == "FreeBSD" ]; then
	SED_ERES='sed -E'
else
	SED_ERES='sed -r'
fi

########################### Check input arguments ###########################

# Check path & file name
if [ -z $OUT_FILE ]; then
	echo 'Please enter full path to the file.(/path/to/output_filename)'
	exit 1
else
	if [ -z ${OUT_FILE##*/} ]; then
		echo 'Please enter full path to the file, include file name.'
		exit 1
	else
		if [ ${OUT_FILE}a != ${OUT_FILE%/*}a ] && [ ! -d ${OUT_FILE%/*} ]; then
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
RND=`awk 'BEGIN{srand();print int(rand()*10000)}'`
TMP_DIR="/tmp/gfwlist2dnsmasq.$RND"
BASE64_FILE="$TMP_DIR/base64.txt"
GFWLIST_FILE="$TMP_DIR/gfwlist.txt"
DOMAIN_FILE="$TMP_DIR/gfwlist2domain.tmp"
GOOGLE_DOMAIN_FILE="$TMP_DIR/google_domain.txt"
CONF_TMP_FILE="$TMP_DIR/gfwlist.conf.tmp"
OUT_TMP_FILE="$TMP_DIR/gfwlist.out.tmp"

# Fetch GfwList and decode it into plain text
printf 'Fetching GfwList...'
mkdir $TMP_DIR
curl -s -L $CURL_EXTARG -o$BASE64_FILE $BASE_URL
if [ $? != 0 ]; then
	printf '\033[31mFailed to fetch gfwlist.txt. Please check your Internet connection.\033[m\n'
	clean_and_exit 2
fi
base64 --decode $BASE64_FILE > $GFWLIST_FILE || ( printf '\033[31mFailed to decode gfwlist.txt. Quit.\033[m\n'; clean_and_exit 2 )
printf ' Done.\n\n'

# Convert
IGNORE_PATTERN='^\!|\[|^@@|(https?://){0,1}[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'
HEAD_FILTER_PATTERN='s#^(\|\|)?(https?://)?##g'
TAIL_FILTER_PATTERN='s#/.*$##g'
DOMAIN_PATTERN='([a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+)'
HANDLE_WILDCARD_PATTERN='s#^(([a-zA-Z0-9]*\*[-a-zA-Z0-9]*)?(\.))?([a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+)(\*)?#\4#g'

echo 'Converting GfwList to dnsmasq rules...'
printf '\033[33m\nWARNING:\nThe following lines in GfwList contain regex, and might be ignored:\033[m\n\n'
cat $GFWLIST_FILE | grep -n '^/.*$'
printf "\033[33m\nThis script will try to convert some of the regex rules. But you should know this may not be a equivalent conversion.\nIf there's regex rules which this script do not deal with, you should add the domain manually to the list.\033[m\n\n"
grep -vE $IGNORE_PATTERN $GFWLIST_FILE | $SED_ERES $HEAD_FILTER_PATTERN | $SED_ERES $TAIL_FILTER_PATTERN | grep -E $DOMAIN_PATTERN | $SED_ERES $HANDLE_WILDCARD_PATTERN > $DOMAIN_FILE

# Add Google search domains
printf 'Fetching Google search domain list...'
curl -s -L $CURL_EXTARG -o$GOOGLE_DOMAIN_FILE https://www.google.com/supported_domains
if [ $? != 0 ]; then
	printf '\n\033[31mFailed. Please check your Internet connection. You may need a proxy/VPN.\033[m\n'
	clean_and_exit 2
fi
printf ' Done\n\n'
sed 's#^\.##g' $GOOGLE_DOMAIN_FILE >> $DOMAIN_FILE
echo 'Google search domains... Added.'

# Add blogspot domains
printf 'blogspot.com\nblogspot.hk\nblogspot.jp\nblogspot.tw\nblogspot.kr\nblogspot.sg\nblogspot.fr\nblogspot.co.uk\nblogspot.cat' >> $DOMAIN_FILE
echo 'Blogspot domains... Added.'

# Add twimg.edgesuit.net
echo 'twimg.edgesuit.net' >> $DOMAIN_FILE
echo 'twimg.edgesuit.net... Added.'

# Convert domains into dnsmasq rules
if [ $WITH_IPSET == 1 ]; then
	echo 'Ipset rules included.'
	sort -u $DOMAIN_FILE | $SED_ERES 's#(.*)#server=/\1/'$DNS_IP'\#'$DNS_PORT'\
ipset=/\1/'$IPSET_NAME'#g' > $CONF_TMP_FILE
else
	echo 'Ipset rules not included.'
	sort -u $DOMAIN_FILE | $SED_ERES 's#(.*)#server=/\1/'$DNS_IP'\#'$DNS_PORT'#g' > $CONF_TMP_FILE
fi

# Generate output file
echo '# GfwList ipset rules for dnsmasq' > $OUT_TMP_FILE
LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
echo "# Last Updated on $LOGTIME" >> $OUT_TMP_FILE
echo '# ' >> $OUT_TMP_FILE
cat $CONF_TMP_FILE >> $OUT_TMP_FILE
cp $OUT_TMP_FILE $OUT_FILE
printf '\nConverting GfwList to dnsmasq rules... Done.\n\n'

# Clean up
clean_and_exit 0
echo 'Finished!'
