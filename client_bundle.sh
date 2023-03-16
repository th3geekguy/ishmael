#!/bin/bash
# client_bundle--Given a username, password, and MKE url, pulls and activates a client bundle via the API

USER=""
URL=""

while test $# -gt 0
do
	case "$1" in
		-u|--username) USER="$2"; shift; shift
			;;
		-w|--url) URL="$2"; shift; shift
			;;
		-h|--help) 
			echo "script usage: $(basename \$0) [-h|--help] [-u|--username username] [-w|--url web.URL]" >&2
			shift
			;;
		*)
			echo "script usage: $(basename \$0) [-h|--help] [-u|--username username] [-w|--url web.URL]" >&2
			exit 1
			;;
	esac
done

if [ -z $USER ]; then
	read -p "Username: " USER
fi
read -p "Password (characters typed here will not appear): " -s PASS
echo
if [ -z $URL ]; then
	read -p "MKE root domain URL (e.g. mke.example.com): " URL
fi

AUTHTOKEN=$(curl -sk -d '{"username":"'$USER'","password":"'$PASS'"}' https://$URL/auth/login | cut -f4 -d\")

curl -k -H "Authorization: Bearer $AUTHTOKEN" https://$URL/api/clientbundle -o bundle.zip

# check unzip is installed
unzip bundle.zip -d client_bundle
cd client_bundle && eval "$(<env.sh)"

#test
docker version
kubectl config current-context

echo 'Run `eval "$(<env.sh)"` to activate client bundle.'

#echo
#echo "--- Entering DEBUG ---"
#echo "User: $USER"
#echo "URL: $URL"

