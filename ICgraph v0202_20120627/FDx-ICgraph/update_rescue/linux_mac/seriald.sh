#!/bin/bash
LOAD=load_mac
MAC=`echo ${OSTYPE} | tr '[A-Z]' '[a-z]'| grep -o darwin`  # on MAC OS it is "darwin"
if [ "${MAC}" = "" ]; then
# assume linux
LOAD=load_lin
LINUX=`echo ${OSTYPE} | tr '[A-Z]' '[a-z]'| grep -o linux`
if [ "${LINUX}" = "" ]; then
echo "${LOAD} not supported on this (${OSTYPE}) platform"
exit 1
fi
fi
chmod a+x ${LOAD}  # Needed if kit built on WIN OS
./${LOAD} -m 1000 -i -x ../UNIFULL.SPB -n -b ../blserial.bin -d ../compound.bin -c ../config.bin -s "$1"


