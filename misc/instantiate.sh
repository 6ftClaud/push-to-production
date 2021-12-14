#!/bin/bash
start_time=$SECONDS

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
    while ! ssh -o "StrictHostKeyChecking no" -i master_key root@$VM_PRIV_IP "echo \"\$(date +\"%T\") PTP-$3 SSH Verified, Proceeding!\""; do
        if ssh-keygen -F "$VM_PRIV_IP"; then
            Print_status $3 "OLD SSH key found, deleting"
            ssh-keygen -R $VM_PRIV_IP
        fi
        Print_status $3 "SSH not up yet, waiting 5 sec"
        sleep 5
    done

    # Save VM Status for debugging
    echo $RESULT_XML | xmllint --format - >"${VM_ID}.txt"

    if [ $3 = "Client" ]
    then
        echo $(echo $RESULT_XML | xmllint --nocdata --xpath '//VM/USER_TEMPLATE/CONNECT_INFO2/text()' -)>Client_conn.txt
    fi

    echo "PTP-$3 ansible_host=$VM_PRIV_IP ansible_ssh_private_key_file=master_key ansible_user=root" >>ansible/hosts

    echo "$VM_PRIV_IP   PTP-$3" >>created_VMs.csv

    Print_status $3 "VM CREATED! (I hope)"
}

# Generate SSH key
rm ~/.ssh/known_hosts*

Print_status "Main" "Generating SSH key"
ssh-keygen -f master_key -q -N ""
Print_status "Main" "SSH key generated!"


Print_status "Main" "Generating Password"
password=$(tr </dev/urandom -dc a-z0-9 | head -c8)
echo $password >master_password
Print_status "Main" "Done! Password is: $password"

# Connect to VU
export ONE_XMLRPC="https://grid5.mif.vu.lt/cloud3/RPC2"

echo "[servers]" >ansible/hosts
echo "" >created_VMs.csv

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
# Use Auth File of Julius
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
# Use Auth File of Klaudijus
export ONE_AUTH="/etc/opennebula/.one/Klaudijus_auth"

# Create Debian 11 VM with GUI; Get VM id
VM_Image_ID=1571 #Debian 11 lxde
VM_Disk_ID=3108  #Debian 11 Disk
VM_Name="Client"
VM_Port=3389

Create_VM $VM_Image_ID $VM_Disk_ID $VM_Name $VM_Port $password

Print_status "Main" "Infrastructure Created! Good luck Klaudijus!"

ansible all -i ansible/hosts -m ping

ansible-playbook ansible/update.yml -i ansible/hosts
ansible-playbook ansible/db.yml -i ansible/hosts
ansible-playbook ansible/client.yml -i ansible/hosts
ansible-playbook ansible/webserver.yml -i ansible/hosts

echo "#################################"
echo "########## Connection ###########"
echo "#################################"
cat Client_conn.txt
echo "#################################"
echo "########### Password ############"
echo "#################################"
cat master_password
echo "#################################"

elapsed=$(( SECONDS - start_time ))

eval "echo Elapsed time: $(date -ud "@$elapsed" +'$((%s/3600/24)) days %H hr %M min %S sec')"