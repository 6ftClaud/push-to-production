#!/bin/bash

Print_status() {
    echo -e "\e[94m\e[1m$(date +"%T")\e[0m \e[31mPTP-$1\e[0m $2"
}

Create_VM() {
    VM_ID=$(onetemplate instantiate $1 --name "PTP-$3" --disk $2:size=8192 --ssh master_key.pub --context NETWORK=YES,ROOT_PASSWORD=$5 --raw TCP_PORT_FORWARDING=$4 | cut -d ' ' -f 3)

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
    
    if ssh-keygen -F "$VM_PRIV_IP"; then
        Print_status $3 "OLD SSH key found, deleting"
        ssh-keygen -R $VM_PRIV_IP
    fi
    while ! ssh -o "StrictHostKeyChecking no" -i master_key root@$VM_PRIV_IP "echo \"\$(date +\"%T\") PTP-$3 SSH Verified, Proceeding!\"" 2>/dev/null; do
        if ssh-keygen -F "$VM_PRIV_IP"; then
            Print_status $3 "OLD SSH key found, deleting"
            ssh-keygen -R $VM_PRIV_IP
        fi
        Print_status $3 "SSH not up yet, waiting 5 sec"
        sleep 5
    done

    # Save VM Status for debbuging
    echo $RESULT_XML | xmllint --format - >"${VM_ID}.txt"

    echo "PTP-$3 ansible_host=$VM_PRIV_IP ansible_ssh_private_key_file=master_key ansible_user=root" >>ansible/hosts

    echo "PTP-$3,$VM_PRIV_IP,$VM_PUB_IP,$(echo $VM_FRWRD | cut -d ':' -f 1),$(echo $VM_FRWRD | cut -d ':' -f 2)" >>created_VMs.csv

    Print_status $3 "VM CREATED! (I hope)"
}

# set permissions
umask u=rwx,g=rwx,o=rx

# Generate SSH key

Print_status "Main" "Generating SSH key"
ssh-keygen -f master_key -q -N ""
Print_status "Main" "SSH key generated!"

chmod 660 master_key
chmod 660 master_key.pub

Print_status "Main" "Generating Password"
password=$(tr </dev/urandom -dc a-z0-9 | head -c8)
echo $password >master_password
Print_status "Main" "Done! Password is: $password"

# Connect to VU
export ONE_XMLRPC="https://grid5.mif.vu.lt/cloud3/RPC2"

echo "[servers]" >ansible/hosts
echo "Name,Private_IP,Public_IP,External_Port,Internal_Port" >created_VMs.csv

###############################################
############## WEB server VM ##################
###############################################
Print_status "Main" "Starting WEB VM creation"
# Use Auth File of Darius
export ONE_AUTH="/etc/opennebula/.one/Darius_auth"

# Create Debian 11 VM; Get VM id
VM_Image_ID=1570 #Debian 11
VM_Disk_ID=3107  #Debian 11 Disk
VM_Name="WEB"
VM_Port=80

Create_VM $VM_Image_ID $VM_Disk_ID $VM_Name $VM_Port $password

###############################################
############## SQL server VM ##################
###############################################
Print_status "Main" "Starting SQL VM creation"
# Use Auth File of Darius
export ONE_AUTH="/etc/opennebula/.one/Julius_auth"

# Create Debian 11 VM; Get VM id
VM_Image_ID=1570 #Debian 11
VM_Disk_ID=3107  #Debian 11 Disk
VM_Name="SQL"
VM_Port=22

Create_VM $VM_Image_ID $VM_Disk_ID $VM_Name $VM_Port $password

###############################################
############## RDP client VM ##################
###############################################
Print_status "Main" "Starting Client VM creation"
# Use Auth File of Darius
export ONE_AUTH="/etc/opennebula/.one/Klaudijus_auth"

# Create Debian 11 VM with GUI; Get VM id
VM_Image_ID=1571 #Debian 11 lxde
VM_Disk_ID=3108  #Debian 11 Disk
VM_Name="Client"
VM_Port=3389

Create_VM $VM_Image_ID $VM_Disk_ID $VM_Name $VM_Port $password

Print_status "Main" "Infrastructure Created! Gool luck Klaudijus!"

ansible all -i ansible/hosts -m ping