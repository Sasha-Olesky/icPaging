#!/bin/bash

CPCRLF=../tools/cpcrlf
APPNAME=abclapp
DEST=${APPNAME}.cob

MAC=`uname | tr '[A-Z]' '[a-z]'| grep -o darwin`       # on MAC OS it is "darwin"
if [ "${MAC}" = "" ]; then		# Linux
	BPKG=../tools/bpkg-static-linux-x86
else					# MAC
	BPKG=../tools/bpkg-mac-x86
fi

${CPCRLF} -r ${APPNAME} bla

${BPKG} /o ${APPNAME}.cob /d bla
rm -rf bla
echo
