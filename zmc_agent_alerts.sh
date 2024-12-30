#!/bin/bash
log_file='/users/ewilson/zmc_files/logs/alerts_file.csv'
: > "$log_file" 

curl --insecure -s -c logs/cookies.txt -X POST https://localhost:7443/api/v2/users/logIn -d 'username=superuser&password=Image4Jup!' > /dev/null
sleep 0.5


echo -e "Check performed on: $(date)\nEvent_Id,ID : Endpoint,Alarm,Timestamp,Info,Status,Severity\n" | tee -a $log_file 1> /dev/null
fetch_alerts() {
    local alert_type="$1"
    curl --insecure -s -b logs/cookies.txt "https://localhost:7443/api/v2/alerts/summary?filters=%5B%7B%22columnField%22:%22time%22,%22operatorValue%22:%22time%22,%22value%22:%22last%20hour%22%7D,%7B%22columnField%22:%22type%22,%22operatorValue%22:%22equals%22,%22value%22:%22${alert_type}%22%7D%5D" | \
    ./jq -r '.content.rows[] | "\(.id),\(.endpoint),\(.type),\(.time),\(.info),\(.severity)"'
}

# Fetch alerts for each type
block_check=$(fetch_alerts "block")
cj_check=$(fetch_alerts "cryptojacking")
fa_check=$(fetch_alerts "fileaccess")
na_check=$(fetch_alerts "networkaccess")
pe_check=$(fetch_alerts "programexecution")
ransom_check=$(fetch_alerts "ransomware")
##sshmfa_check=$(fetch_alerts "ssh-mfa") too large to run!
tamper_check=$(fetch_alerts "tampering")


curl --insecure -s -b logs/cookies.txt -X POST https://localhost:7443/api/v2/users/logOut > /dev/null

# Append results to log file
{
    echo "$block_check"
    echo "$cj_check"
    echo "$fa_check"
    echo "$na_check"
    echo "$pe_check"
    echo "$ransom_check"
    echo "$tamper_check"
} >> "$log_file"

sed -i '/^$/d' "$log_file"
