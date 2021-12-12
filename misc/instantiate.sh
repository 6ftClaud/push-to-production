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
RESULT_XML=$(onevm show $CVMID -x)
#$(onevm show $CVMID > ${CVMID}.txt)
CSSH_CON=$(echo $RESULT_XML | xmllint --nocdata --xpath '//VM/USER_TEMPLATE/CONNECT_INFO1/text()' -)
CSSH_PRIP=$(echo $RESULT_XML | xmllint --nocdata --xpath '//VM/USER_TEMPLATE/PRIVATE_IP/text()' -)
echo "Connection string: $CSSH_CON"
echo "Local IP: $CSSH_PRIP"
echo $RESULT_XML > "${CVMID}.txt"