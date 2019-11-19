cd ..
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
chmod a+x linux_mac/${LOAD} 
linux_mac/${LOAD} -g compound.bin abclw.rom 0xc000 fs.bin 0xc100 sg.bin 0xc200 abclapp.cob 0xc400 custom1.cob 0xc600 bclio.bin 0xc900 applications.cob 0xcA00
