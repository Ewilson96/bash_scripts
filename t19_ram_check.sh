
#!/bin/bash

output_file="/root/ValiCyber/lists/ram_check.csv"
: > $output_file  # Empty the output file

main() {
    local i=$1
   
    walk_kB=$(snmpwalk -v 2c -c samnocrw $i .1.3.6.1.4.1.2021.4.6 | cut -d " " -f4)
    walk_mB=$((walk_kB / 1024))
    walk_hn=$(snmpwalk -v 2c -c samnocrw $i 1.3.6.1.2.1.1.5.0 | awk {'print $4'})
    sleep 1
    hn=$(sshpass -p 'xxxx' timeout 25 ssh -q -o StrictHostKeyChecking=no root@$i 'hostname; exit')

    gw_name="${walk_hn:3:3}"
    sat_name="${walk_hn:0:3}"
    status_check=$(sshpass -p 'xxxx' timeout 25 ssh -q -o StrictHostKeyChecking=no root@$i 'systemctl is-active zerolock; exit')

    if [[ "$walk_kB" -lt 100000 ]] && [[ $status_check == "active" ]]; then
        raw_PID=$(sshpass -p 'xxxx' timeout 25 ssh -q -o StrictHostKeyChecking=no root@$i 'pstree -p | grep -E "zerolock-tyr|kworker/3:4"; exit')

        if [ -n "$raw_PID" ]; then
            check_PIDs=$(echo $raw_PID | grep -oP '\(\d+\)' | grep -oP '\d+')
            tmp_file=$(mktemp)

            total_cpu=0
            total_mem=0

            # Iterate over each PID and perform checks in parallel
            for pid in $check_PIDs; do
                (
                    ps_output=$(sshpass -p 'xxxx' timeout 25 ssh -q -o StrictHostKeyChecking=no root@$i "ps -p $pid -o %cpu,%mem --no-headers; exit")
                    if [ -n "$ps_output" ]; then
                        cpu=$(echo $ps_output | awk '{print $1}')
                        mem=$(echo $ps_output | awk '{print $2}')
                        total_cpu=$(echo "$total_cpu + $cpu" | bc)
                        total_mem=$(echo "$total_mem + $mem" | bc)
                        echo "$total_cpu $total_mem" >> "$tmp_file"
                    fi
                ) &
            done
        fi

        echo "$sat_name,$gw_name,$hn,$walk_mB,$total_cpu%,$total_mem%" >> "$output_file"
    elif [ -z "$hn" ]; then
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "$timestamp,$i,Unreachable! Check sshd and systemd-logind services on the machine." >> "$output_file"
    fi
}

export -f main

#07/19 filtering out the SMA. snmpd has been disabled for the time being.
ip_list=$(cut -d "=" -f1,2 /root/ValiCyber/inventory.ini | grep -vE '#|.184'| grep 172 | awk '{print $2}' | cut -d '=' -f2)

max_jobs=3
current_jobs=0

for i in $ip_list; do
    main "$i" >> $output_file &
    current_jobs=$((current_jobs + 1))

    if [ "$current_jobs" -ge "$max_jobs" ]; then
        wait -n 2>/dev/null # Wait for at least one background job to finish
        current_jobs=$((current_jobs - 1))
    fi

done
wait

sort -t, -k5 $output_file
rm -f $tmp_file

