#!/bin/bash

output_file="/users/ewilson/zmc_files/logs/connected_endpoints.csv"
: > "$output_file"
curl --insecure -s -c logs/cookies.txt -X POST https://localhost:7443/api/v2/users/logIn -d 'username=superuser&password=Image4Jup!' 1> /dev/null
sleep 0.5
echo -e "Check performed on: $(date)\nStatus,Hostname,ipAddress,lastCheckin,groups,OS\n" | tee -a "$output_file" > /dev/null
curl --insecure -s -b logs/cookies.txt https://localhost:7443/api/v2/endpoints/summary \
    | ./jq -r '.content.rows[] | select(.connectionStatus=="connected") |  "\(.connectionStatus),\(.hostname),\(.ipAddress),\(.lastCheckIn),\(.groups),\(.os)"' \
    | grep -E -iv 'sma|vmwcon|vmwbta' | sort >> "$output_file"
curl --insecure -s -b logs/cookies.txt -X POST https://localhost:7443/api/v2/users/logOut 1> /dev/null
