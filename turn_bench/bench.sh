#!/bin/bash

USAGE="
Usage: $(basename "$0") [options] turn-server-ip <username>=<password>

where:
    -h show this help text
    -s UDP datagram size in bytes
    -d session duration in seconds
    -n number of sessions
    -b bitrate in kbps

Example: $(basename "$0") -b 100 -n 10 127.0.0.1 john=password
"

PACKET_SIZE=100
DURATION=60
SESSIONS=1
BITRATE=50

while getopts ":hc:s:d:n:b:" opt; do
    case $opt in
    h)
        echo "$USAGE"
        exit
        ;;
    s)
        PACKET_SIZE="$OPTARG"
        ;;
    d)
        DURATION="$OPTARG"
        ;;
    n)
        SESSIONS="$OPTARG"
        ;;
    b)
        BITRATE="$OPTARG"
        ;;
    :) 
        echo "missing argument for -$OPTARG"
        exit
    esac
done

shift $((OPTIND -1))

if [ $# -ne 2 ]
then
    echo "Bad number of positional arguments. Expected: 2, got: $# $*. Were TURN IP and credentials passed?"
    echo "$USAGE"
    exit 1
fi

TURN_IP=$1
CREDENTIALS=$2

echo "
Runing TURN benchmark with the following configuration
TURN_IP=$TURN_IP
CREDENTIALS=$CREDENTIALS
SESSIONS=$SESSIONS
BITRATE=$BITRATE kbps
DURATION=$DURATION s
PACKET_SIZE=$PACKET_SIZE bytes
"

for ((i=0; i < $SESSIONS; i++)); do
    echo "Starting session $i"
    ./turn_bench -host $TURN_IP \
    -user $CREDENTIALS \
    -packetSize $PACKET_SIZE \
    -bitrate $BITRATE \
    -duration $DURATION &
    sleep 0.05
done

wait $(jobs -p)
