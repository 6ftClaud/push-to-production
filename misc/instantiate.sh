#!/bin/bash

# Generate SSH key
ssh-keygen -f master_key -q -N ""



# Connect to VU
export ONE_XMLRPC="https://grid5.mif.vu.lt/cloud3/RPC2"
#export ONE_AUTH="$HOME/.one/Matas_auth"
#export ONE_AUTH="$HOME/.one/Julius_auth"
#export ONE_AUTH="$HOME/.one/Klaudijus_auth"

###############################################
############## WEB server VM ##################
###############################################
# Use Auth File of Darius
export ONE_AUTH="$HOME/.one/Darius_auth"

# Create Debian 11 VM with 4 GB disk; Get VM id
WEB_VM_ID=$(onetemplate instantiate 1570 --name "PTP-WEB" --disk 3107:size=4096 --ssh master_key.pub | cut -d ' ' -f 3)

# Notify
echo "$(date +"%T") WEB VM deployment started, ID: $WEB_VM_ID"

# Get Status XML and Loop until ready
RESULT_XML=$(onevm show $WEB_VM_ID -x)
while [ "3" -ne $(echo $RESULT_XML | xmllint --xpath '//VM/STATE/text()' -) ]; do
    echo "$(date +"%T") VM State not ACTIVE, waiting 5 sec"
    sleep 5
    RESULT_XML=$(onevm show $WEB_VM_ID -x)
done
echo "$(date +"%T") WEB VM Initialized"
while [ "3" -ne $(echo $RESULT_XML | xmllint --xpath '//VM/LCM_STATE/text()' -) ]; do
    echo "$(date +"%T") VM LCM State not RUNNING, waiting 5 sec"
    sleep 5
    RESULT_XML=$(onevm show $WEB_VM_ID -x)
done
echo "$(date +"%T") WEB VM is Running, Proceeding!"
while [ "false" = $(echo $RESULT_XML | xmllint --xpath 'boolean(//VM/USER_TEMPLATE/PRIVATE_IP)' - ) ]; do
    echo "$(date +"%T") VM IP address not issued yet, waiting 5 sec"
    sleep 5
    RESULT_XML=$(onevm show $WEB_VM_ID -x)
done
echo "$(date +"%T") WEB VM IP retrieved, Proceeding!"

# Save VM Status for debbuging
echo $RESULT_XML | xmllint --format - >"${WEB_VM_ID}.txt"

# Get Network information
WEB_VM_PUB_IP=$(echo $RESULT_XML | xmllint --nocdata --xpath '//VM/USER_TEMPLATE/PUBLIC_IP/text()' -)
echo "$(date +"%T") WEB VM Public IP: $WEB_VM_PUB_IP"
WEB_VM_PRIV_IP=$(echo $RESULT_XML | xmllint --nocdata --xpath '//VM/USER_TEMPLATE/PRIVATE_IP/text()' -)
echo "$(date +"%T") WEB VM Private IP: $WEB_VM_PRIV_IP"
WEB_VM_FRWRD=$(echo $RESULT_XML | xmllint --nocdata --xpath '//VM/USER_TEMPLATE/TCP_PORT_FORWARDING/text()' -)
echo "$(date +"%T") WEB VM Port Forwarding (public:private): $WEB_VM_FRWRD"
