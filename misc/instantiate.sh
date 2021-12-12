#!/bin/bash
export ONE_XMLRPC="https://grid5.mif.vu.lt/cloud3/RPC2"
export ONE_AUTH="$HOME/.one/Matas_auth"
#export ONE_AUTH="$HOME/.one/Julius_auth"
#export ONE_AUTH="$HOME/.one/Klaudijus_auth"
#export ONE_AUTH="$HOME/.one/Darius_auth"
CVMREZ=$(onetemplate instantiate "debian11" --name "PTP-WEB" )
CVMID=$(echo $CVMREZ | cut -d ' ' -f 3)
echo $CVMID
echo "Waiting for VM to RUN 30 sec."
sleep 30
$(onevm show $CVMID --user $CUSER --password $CPASS --endpoint $CENDPOINT > ${CVMID}.txt)
CSSH_CON=$(cat $CVMID.txt | grep CONNECT\_INFO1| cut -d '=' -f 2 | tr -d '"')
CSSH_PRIP=$(cat $CVMID.txt | grep PRIVATE\_IP| cut -d '=' -f 2 | tr -d '"')
echo "Connection string: $CSSH_CON"
echo "Local IP: $CSSH_PRIP"