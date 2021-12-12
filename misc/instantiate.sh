#!/bin/bash

Print_status() {
    echo "$(date +"%T") PTP-$1 $2"
}

Create_VM() {
    VM_ID=$(onetemplate instantiate $1 --name "PTP-WEB" --disk $2:size=4096 --ssh master_key.pub --context NETWORK=YES --raw TCP_PORT_FORWARDING=$4 | cut -d ' ' -f 3)

    # Notify
    Print_status $3 "Deployment started, ID: $VM_ID"

    # Get Status XML and Loop until ready
    RESULT_XML=$(onevm show $VM_ID -x)
    while [ "3" -ne $(echo $RESULT_XML | xmllint --xpath '//VM/STATE/text()' -) ]; do
        Print_status $3 "State not ACTIVE, waiting 5 sec"
        sleep 5
        RESULT_XML=$(onevm show $VM_ID -x)
    done
    Print_status $3 "Initialized"
    while [ "3" -ne $(echo $RESULT_XML | xmllint --xpath '//VM/LCM_STATE/text()' -) ]; do
        Print_status $3 "LCM State not RUNNING, waiting 5 sec"
        sleep 5
        RESULT_XML=$(onevm show $VM_ID -x)
    done
    Print_status $3 "is Running, Proceeding!"
    while [ "false" = $(echo $RESULT_XML | xmllint --xpath 'boolean(//VM/USER_TEMPLATE/PRIVATE_IP)' -) ]; do
        Print_status $3 "IP address not issued yet, waiting 5 sec"
        sleep 5
        RESULT_XML=$(onevm show $VM_ID -x)
    done
    Print_status $3 "IP retrieved, Proceeding!"

    # Get Network information
    VM_PUB_IP=$(echo $RESULT_XML | xmllint --nocdata --xpath '//VM/USER_TEMPLATE/PUBLIC_IP/text()' -)
    Print_status $3 "Public IP: $VM_PUB_IP"
    VM_PRIV_IP=$(echo $RESULT_XML | xmllint --nocdata --xpath '//VM/USER_TEMPLATE/PRIVATE_IP/text()' -)
    Print_status $3 "Private IP: $VM_PRIV_IP"
    VM_FRWRD=$(echo $RESULT_XML | xmllint --nocdata --xpath '//VM/USER_TEMPLATE/TCP_PORT_FORWARDING/text()' -)
    Print_status $3 "Port Forwarding (public:private): $VM_FRWRD"

    if ssh-keygen -F "$VM_PRIV_IP"
    then
        Print_status $3 "OLD SSH key found, deleting"
        ssh-keygen -R $VM_PRIV_IP
    fi

    while ! ssh -o "StrictHostKeyChecking no" -i master_key root@$VM_PRIV_IP "echo \"\$(date +\"%T\") PTP-$3 SSH Verified, Proceeding!\"" 2>/dev/null
    do
        Print_status $3 "SSH not up yet, waiting 5 sec"
        sleep 5
    done

    # Save VM Status for debbuging
    echo $RESULT_XML | xmllint --format - >"${VM_ID}.txt"

    echo "PTP-$3 ansible_host=$VM_PRIV_IP ansible_ssh_private_key_file=master_key" >>ansible/hosts

    Print_status $3 "VM CREATED! (I hope)"
}


# Generate SSH key
ssh-keygen -f master_key -q -N ""

# Connect to VU
export ONE_XMLRPC="https://grid5.mif.vu.lt/cloud3/RPC2"

echo "[servers]" >ansible/hosts

###############################################
############## WEB server VM ##################
###############################################
# Use Auth File of Darius
export ONE_AUTH="$HOME/.one/Darius_auth"

# Create Debian 11 VM with 4 GB disk; Get VM id
VM_Image_ID=1570 #Debian 11
VM_Disk_ID=3107 #Debian 11 Disk
VM_Name="WEB"
VM_Port=80

Create_VM $VM_Image_ID $VM_Disk_ID $VM_Name $VM_Port


#export ONE_AUTH="$HOME/.one/Julius_auth"
#export ONE_AUTH="$HOME/.one/Klaudijus_auth"
