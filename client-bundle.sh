#!/bin/bash

read -p "Password: " -s pass
read -p "Username: " user
read -p "MKE URL: " url
AUTHTOKEN=$(curl -sk -d '{"username":"'$user'","password":"'$pass'"}' \
https://$url/auth/login | jq -r .auth_token)
curl -k -H "Authorization: Bearer $AUTHTOKEN" \
https://$url/api/clientbundle -o bundle.zip
unzip bundle.zip -d bundle
cd bundle && eval "$(<env.sh)"
# test
docker version --format '{{.Server.Version}}'
kubectl config current-context
