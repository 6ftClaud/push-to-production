#!/bin/bash
export ONE_XMLRPC="https://grid5.mif.vu.lt/cloud3/RPC2"
#export ONE_AUTH="$HOME/.one/Matas_auth"
#export ONE_AUTH="$HOME/.one/Julius_auth"
#export ONE_AUTH="$HOME/.one/Klaudijus_auth"

# WEB server VM

# Auth to Darius
export ONE_AUTH="$HOME/.one/Darius_auth"
# Create Debian 11 VM 
CVMREZ=$(onetemplate instantiate 1570 --name "PTP-WEB" --disk 3107:size=4096)
CVMID=$(echo $CVMREZ | cut -d ' ' -f 3)
echo $CVMID

while [ "3" -ne $(onevm show $CVMID -x | xmllint --xpath '//VM/STATE/text()' -) ]
do
 echo "$(date +"%T") VM not ready, waiting 5 sec"
 sleep 5
done
echo "VM ready, continuing"
$(onevm show $CVMID > ${CVMID}.txt)
CSSH_CON=$(cat $CVMID.txt | grep CONNECT\_INFO1| cut -d '=' -f 2 | tr -d '"')
CSSH_PRIP=$(cat $CVMID.txt | grep PRIVATE\_IP| cut -d '=' -f 2 | tr -d '"')
echo "Connection string: $CSSH_CON"
echo "Local IP: $CSSH_PRIP"