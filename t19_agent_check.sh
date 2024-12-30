#!/bin/bash

main() {
    local i=$1

    # Check if the service is active
    status_check=$(sshpass -p 'Image4Jup!' timeout 25 ssh -q -o StrictHostKeyChecking=no root@$i "systemctl is-active zerolock.service; exit")

    if [[ $status_check == 'active' ]]; then
        # Collect counts and connection checks
        tyr_count=$(sshpass -p 'Image4Jup!' timeout 25 ssh -q -o StrictHostKeyChecking=no root@$i "ps aux | grep zerolock-tyr | grep -v grep | wc -l; exit")
        sleep 1
        kworker_count=$(sshpass -p 'Image4Jup!' timeout 25 ssh -q -o StrictHostKeyChecking=no root@$i "ps aux | grep '\\[kworker/3:4-events\\]' | wc -l; exit")
        sleep 1
        sus_count=$(sshpass -p 'Image4Jup!' timeout 25 ssh -q -o StrictHostKeyChecking=no root@$i "ps aux | grep 'ZlrebaCIkVrlnCoeyoIc' | grep -v grep | wc -l; exit")
        sleep 1
        conn_check_raw=$(sshpass -p 'Image4Jup!' timeout 25 ssh -q -o StrictHostKeyChecking=no root@$i "\
            awk -v d=\"\$(date --date='4 hours ago' '+%m-%d %H:%M:%S')\" '
            {
                timestamp = \$1 \" \" \$2
                if (timestamp > d && (\$0 ~ /Connection Closed/ || \$0 ~ /Connection Opened/))
                    print \$0
            }' /opt/zerolock/zerolock-tyr/tyr.log && exit")

        four_hr_tyr_conn_check_close=$(echo "$conn_check_raw" | grep "Connection Closed" | wc -l)
        four_hr_tyr_conn_check_open=$(echo "$conn_check_raw" | grep "Connection Opened" | wc -l)
        sleep 1
        socket_conn_check=$(sshpass -p 'Image4Jup!' timeout 25 ssh -q -o StrictHostKeyChecking=no root@$i "ss -tanp | grep 172.18.232.245 | awk '{print \$1; exit}'")
    else
        echo "$i: Service is not active."
        return
    fi

    # Determine hostname
    if [[ $i =~ \.184$ ]]; then
        walk_hn="T19JOAVMWSMA01"
    else
        walk_hn=$(snmpwalk -v 2c -c samnocrw "$i" .1.3.6.1.2.1.1.5.0 | cut -d " " -f4)
    fi

    # Final output
    if [[ $status_check != "active" ]]; then
        echo "Inactive,$walk_hn,$i"
    elif [[ -z $socket_conn_check ]]; then
        echo "Active,cmd timeout,$walk_hn,$i,$four_hr_tyr_conn_check_open,$four_hr_tyr_conn_check_close"
    else
        echo "Active,$socket_conn_check,$walk_hn,$i,$four_hr_tyr_conn_check_open,$four_hr_tyr_conn_check_close"
    fi
}

export -f main

# Extract IP list
ip_list=$(cut -d "=" -f1,2 /root/ValiCyber/inventory.ini | grep -vE '#|.184' | grep 172 | awk '{print $2}' | cut -d '=' -f2)
# Parallel execution
max_jobs=5
current_jobs=0

for i in $ip_list; do
    main "$i" &  # Run in the background
    current_jobs=$((current_jobs + 1))

    if [ "$current_jobs" -ge "$max_jobs" ]; then
        wait -n 2>/dev/null # Wait for at least one background job to finish
        current_jobs=$((current_jobs - 1))
    fi
done
wait  # Wait for all background jobs to finish
