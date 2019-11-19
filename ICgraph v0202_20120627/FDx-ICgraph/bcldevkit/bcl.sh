#!/bin/bash
MAC=`uname | tr '[A-Z]' '[a-z]'| grep -o darwin`       # on MAC OS it is "darwin"
function translate {
cat $1 | $crlf_path
}


CPCRLF=../tools/cpcrlf
if [ "${MAC}" = "" ]; then
#linux
TFTP=atftp
BPKG=../tools/bpkg-static-linux-x86
TOKENIZER=../../tools/tokenizer-static-linux-x86
else
#mac
TFTP=tftp
BPKG=../tools/bpkg-mac-x86
TOKENIZER=../../tools/tokenizer-mac-x86
fi

DESTINATION_PAGE=WEB6

if [ $# -lt 1 ] ; then echo -e "BCL devkit tool, (c)2006 Barix AG\nUsage: $0 <project_name> [<ip_address>]\nRequires dosemu installed." ; exit 0 ; fi

${CPCRLF} -r $1 bla

IS_BCL=0
BAS_FILE="$1.bas"

# .BCL support
if [ -f $1/$1.bcl ] ; then
   mkdir bla/BCL
   # there could be multiple .bcl's
   for module in $(ls $1/*.bcl);
   do
      ${CPCRLF} ${module} bla/BCL
   done
   # no double code
   rm bla/*.bcl
   BAS_FILE="$1.bcl"
   IS_BCL=1
fi

cd bla
if ${TOKENIZER} audio ${BAS_FILE} ; then : ; else echo "ERROR - TOKENIZER REPORTS FAILURE" ; fi
cd ../

rm -f bla/*.bak bla/*.BAK

if [ "$IS_BCL" = "1" ] ; then
	rm -f bla/$1.bas bla/$1.BAS
fi


${BPKG} /o $1.cob /d bla
rm -rf bla
echo
if [ $# -gt 1 ] ; then
if  [ "${MAC}" = "" ] ; then
	#linux
	${TFTP} -l $1.cob -r ${DESTINATION_PAGE} -p $2
else
	#mac
    echo "tftp: uploading file $1.cob to page ${DESTINATION_PAGE}"
    TMP=${RANDOM}.sh
    echo "connect $2" > ${TMP}
    echo "bin" >> ${TMP}
    echo "put $1.cob ${DESTINATION_PAGE}" >> ${TMP}
    cat  ${TMP}
    ${TFTP} < ${TMP}
    rm -rf ${TMP}
fi
fi


