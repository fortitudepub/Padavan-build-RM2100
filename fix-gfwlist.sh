#!/bin/sh


cmd=`sysctl -a | grep wmem | grep 8388`
if [[ $? != 0 ]]; then
    logger -t "fix-gfwlist" "optimize longfat network for office router."
    sysctl -w net.ipv4.tcp_wmem="8388608 16777216 33554432"
    sysctl -w net.ipv4.tcp_rmem="8388608 16777216 33554432"
    sysctl -w net.ipv4.tcp_window_scaling=7
    sysctl -w net.ipv4.tcp_adv_win_scale=1
fi


cmd=`iptables -t nat -L INPUT -n | grep 80`
if [[ $? != 0 ]]; then
	logger -t "fix-gfwlist" "fix ugly 80 port can't be accesed"
	iptables -t nat -A INPUT -p tcp --dport 80 -d 192.168.2.1/32 -s 192.168.2.0/24 -j ACCEPT
fi

cmd=`iptables -t nat -L INPUT -n | grep 22`
if [[ $? != 0 ]]; then
	logger -t "fix-gfwlist" "fix ugly 22 port can't be accesed"
	iptables -t nat -A INPUT -p tcp --dport 22 -d 192.168.2.1/32 -s 192.168.2.0/24 -j ACCEPT
fi



# check whitelist is ok by checking a random china prefix.
cmd=`ipset list whitelist | grep 171.40.0.0`
if [[ $? != 0 ]]; then
    logger -t "fix-gfwlist" "whitelist not contain china ip, need fix."
    # no need, ssr plus will do this.
    #echo "create whitelist hash:net family inet" >/tmp/chnroutefix.ipset
    if [[ ! -f /etc/storage/rawchnroute.data ]]; then
        curl -4sSkL 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest' -o /etc/storage/rawchnroute.data
    fi
    cat /etc/storage/rawchnroute.data | grep CN | grep ipv4 | awk -F'|' '{printf("add whitelist %s/%d\n", $4, 32-log($5)/log(2))}' >>/tmp/chnroutefix.ipset
    #ipset destroy whitelist
    # try create if not created.
    ipset create whitelist hash:net family inet
    ipset -R < /tmp/chnroutefix.ipset
    rm /tmp/chnroutefix.ipset
    logger -t "fix-gfwlist" "whitelist propogated."
fi

cmd=`iptables -t nat -L -nv | grep white | grep "\!"`
if [[ $? != 0 ]]; then
    logger -t "fix-gwflist" "can't find fix gfwlist rule, redo it."
    cmd=`iptables -t nat -L -nv | grep white`
    if [[ $? == 0 ]]; then
        logger -t "fix-gfwlist" "required tables exist, need add missing rule."
        iptables -t nat -A SS_SPEC_WAN_AC -m set ! --match-set whitelist dst -j SS_SPEC_WAN_FW
    fi
fi
