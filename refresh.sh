#!/bin/bash
PROXY="socks5h://127.0.0.1:40000"
URL="https://www.google.com/generate_204"

LATENCY_RAW=$(curl -x $PROXY -s -o /dev/null -w "%{time_total}" --connect-timeout 5 $URL)
RESULT=$?

if [ $RESULT -ne 0 ]; then
    LATENCY_INT=99
else
    LATENCY_INT=$(echo "$LATENCY_RAW" | sed 's/[^0-9.].*//' | cut -d. -f1)
fi

if [ $RESULT -ne 0 ] || [ "$LATENCY_INT" -ge 2 ]; then
    echo "$(date) - 触发重置: 延迟 $LATENCY_RAW s"
    warp-cli registration delete
    sleep 2
    warp-cli registration new
    warp-cli connect
else
    echo "$(date) - 状态正常: $LATENCY_RAW s"
fi
