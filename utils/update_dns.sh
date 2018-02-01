#!/bin/bash -x

# Update the cloudflare DNS entry to match the public IP address
# Requires curl, jq, dig(dnsutils)

dig -v 2>/dev/null ; [[ $? == 127 ]] && echo "Error: You need dnsutils to use this tool" && exit 1
curl -V 2>/dev/null ; [[ $? == 127 ]] && echo "Error: You need curl to use this tool" && exit 1
jq -V 2>/dev/null ; [[ $? == 127 ]] && echo "Error: You need jq to use this tool" && exit 1

CONFIG_FILE="/etc/isitfoggy.conf"
source $CONFIG_FILE

function get_zone_id() {
    echo -n "Getting zone id for $PUBLIC_FQDN: "
    result=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$PUBLIC_DOMAIN&status=active&page=1&per_page=20&order=status&direction=desc&match=all" \
         -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
         -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
         -H "Content-Type: application/json")
    jq_query=".result | map(select(.name == \"${PUBLIC_DOMAIN}\"))[].id"
    zone_id=$(echo "$result" | jq -r "$jq_query")
    echo $zone_id
}

function update_record() {
    record_type=$1
    ip=$2
    [[ -z $zone_id ]] && get_zone_id
    [[ -z $zone_id ]] && echo "Could not find zone id" && exit 1

    for record in $PUBLIC_FQDN $ORIGIN_FQDN ; do
        echo -n "Getting A record ID for $record: "
        dns_records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=${record_type}&name=$record&page=1&per_page=20&order=type&direction=desc&match=all" \
         -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
         -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
         -H "Content-Type: application/json")
        dns_id=$(echo "$dns_records" | jq -r '.result[0].id')
        echo $dns_id
        proxied=$(echo "$dns_records" | jq -r '.result[0].proxied')
        echo "Proxied: $proxied"

        echo "Updating $record_type record $record to $ip: "
        result=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$dns_id" \
         -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
         -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
         -H "Content-Type: application/json" \
         --data "{\"type\":\"${record_type}\",\"name\":\"$record\",\"content\":\"$ip\",\"proxied\":$proxied}")
        echo "$result" |jq .
    done
}

echo -n "Checking local IP Address: "
my_ip=$(curl -s ifconfig.me)
my_ipv6=$(ip addr show scope global |perl -n -e'/inet6\s(.*)\//&& print $1')
echo $my_ip
[[ -z $my_ipv6 ]] && echo "Found an global ipv6! : $my_ip" 

echo -n "Checking current DNS entry: "
my_current_a_record=$(dig +short $ORIGIN_FQDN A @${CLOUDFLARE_DNS_SERVER})
my_current_aaaa_record=$(dig +short $ORIGIN_FQDN AAAA @${CLOUDFLARE_DNS_SERVER})
echo $my_current_a_record
echo $my_current_aaaa_record

if ! [[ "$my_ip" == "$my_current_a_record" ]] ; then
	echo "A record is incorrect: Updating"
	update_record A $my_ip
else
    echo "A record is already correct"
fi

if ! [[ -z $IPV6_ENABLED ]] ; then
    if ! [[ "$my_ipv6" == "$my_current_aaaa_record" ]] ; then
    	echo "AAAA record is incorrect: Updating"
    	update_record AAAA $my_ipv6
    else
        echo "AAAA record is already correct"
    fi
fi
