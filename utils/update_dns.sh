#!/bin/bash

# Update the cloudflare DNS entry to match the public IP address
# Requires curl, jq, dig(dnsutils)

source config.sh

DOMAIN="isitfoggy.today"
HOST_TO_PROBE="zero.$DOMAIN"
EMAIL="albertmornington@gmail.com"
API_KEY="4cd6196710d0c45281e668e388dc714ac2bd1"


echo -n "Checking local IP Address: "
my_ip=$(curl -s ifconfig.me)
echo $my_ip

echo -n "Checking current DNS entry: "
my_current_dns=$(dig +short $HOST_TO_PROBE)
echo $my_current_dns

if [[ "$my_ip" == "$my_current_dns" ]] ; then
	echo "DNS entry is already correct"
	exit 0
fi

echo -n "Getting zone id for $DOMAIN: "
result=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN&status=active&page=1&per_page=20&order=status&direction=desc&match=all" \
     -H "X-Auth-Email: $EMAIL" \
     -H "X-Auth-Key: $API_KEY" \
     -H "Content-Type: application/json")
zoneid=$(echo "$result" | jq -r '.result | map(select(.name == "isitfoggy.today"))[].id')
echo $zoneid

for a_record in $DOMAIN $HOST_TO_PROBE ; do
	echo -n "Getting A record ID for $a_record: "
	dns_records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$a_record&page=1&per_page=20&order=type&direction=desc&match=all" \
     -H "X-Auth-Email: $EMAIL" \
     -H "X-Auth-Key: $API_KEY" \
     -H "Content-Type: application/json")
	dns_id=$(echo "$dns_records" | jq -r '.result[0].id')
	echo $dns_id
	proxied=$(echo "$dns_records" | jq -r '.result[0].proxied')
	echo "Proxied: $proxied"

	echo "Updating A record $a_record to $my_ip: "
	result=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dns_id" \
     -H "X-Auth-Email: $EMAIL" \
     -H "X-Auth-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     --data "{\"type\":\"A\",\"name\":\"$a_record\",\"content\":\"$my_ip\",\"proxied\":$proxied}")
	echo "$result" |jq .
done

