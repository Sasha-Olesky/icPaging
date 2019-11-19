#!/bin/bash

MAC=`uname | tr '[A-Z]' '[a-z]'| grep -o darwin`       # on MAC OS it is "darwin"


CPCRLF=../tools/cpcrlf
if [ "${MAC}" = "" ]; then
#linux
BPKG=../tools/bpkg-static-linux-x86
TOKENIZER=../../tools/tokenizer-static-linux-x86
else
#mac
BPKG=../tools/bpkg-mac-x86
TOKENIZER=../../tools/tokenizer-mac-x86
fi

APPLICATIONS="annunfdx"
for name in ${APPLICATIONS} ; do 

	IS_BCL=0
	BAS_FILE="$name.bas"

	if [ -f $name/$name.bcl ] ; then 
		mkdir $name/BCL
		cp $name/*.bcl $name/BCL
		BAS_FILE="$name.bcl"
		IS_BCL=1
	fi

	echo "--- Building application \"$name\""
	cd $name
	rm -f *.bak *.BAK
	if ${TOKENIZER} audio ${BAS_FILE} ; then : ; else echo "ERROR - TOKENIZER REPORTS FAILURE" ; fi
	cd ../

	if [ "$IS_BCL" = "1" ] ; then rm -f $name/$name.bas ; fi

	${CPCRLF} -r $name bla
	rm -rf $name/BCL
done
if [ "$1" == "-no_source" ]; then
	echo "Deleting source files ..."
	rm -f -v bla/{*.bcl,*.bas}
	echo ""
fi
cp appconfig.bin bla/
${BPKG} /o applications.cob /d bla
rm -rf bla

