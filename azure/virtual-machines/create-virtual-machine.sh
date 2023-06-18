#!/bin/bash

# Check if Azure CLI is logged in
az account show >/dev/null 2>&1
if [ $? != 0 ]; then
    echo "Azure CLI is not logged in. Please run 'az login' to authenticate."
    exit 1
fi

NODE_NAME=$1
RESOURCE_GROUP_NAME=$2
SSH_ALIAS=$3
IS_CONTROL_PLANE=${4:-false}
LOCATION="westeurope"
VM_SIZE="Standard_D2s_v3"
VM_IMAGE="Ubuntu2204"
SUBSCRIPTION="Azure for Students"
ADMIN_USERNAME="rishith-poloju"

# Function to delete the virtual machine
delete_virtual_machine() {
    echo "Deleting virtual machine $NODE_NAME..."
    az vm delete --resource-group $RESOURCE_GROUP_NAME --name $NODE_NAME --yes
}

# Function to delete the resource group
delete_resource_group() {
    echo "Deleting resource group $RESOURCE_GROUP_NAME..."
    az group delete --name $RESOURCE_GROUP_NAME --yes
}

# Function to create the resource group
create_resource_group() {
    echo "Creating resource group $RESOURCE_GROUP_NAME..."
    az group create --name $RESOURCE_GROUP_NAME --location $LOCATION
}

# Function to create the virtual machine
create_virtual_machine() {
    echo "Creating virtual machine $NODE_NAME..."

    if [ "$IS_CONTROL_PLANE" = true ]; then
        PORT_RANGES="6443,2379-2380,10250,10259,10257"
    else
        PORT_RANGES="10250,30000-32767"
    fi

    az vm create --resource-group $RESOURCE_GROUP_NAME --name $NODE_NAME \
        --size $VM_SIZE --image $VM_IMAGE --location $LOCATION \
        --subscription "$SUBSCRIPTION" --admin-username $ADMIN_USERNAME \
        --generate-ssh-keys --public-ip-sku Standard \
        --nsg-rule "PortRanges=$PORT_RANGES;Protocol=TCP"
}

# Function to get the VM IP address
get_virtual_machine_ip() {
    echo "Getting IP address for $NODE_NAME..."
    VIRTUAL_MACHINE_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP_NAME --name ${NODE_NAME}PublicIP --query ipAddress --output tsv)
}

# Function to add or replace SSH alias for the VM
add_ssh_alias() {
    echo "Adding or replacing SSH alias for $NODE_NAME..."
    sed -i "/alias $SSH_ALIAS/d" ~/.bash_aliases
    echo "alias $SSH_ALIAS='ssh $ADMIN_USERNAME@$VIRTUAL_MACHINE_IP'" >> ~/.bash_aliases
    source ~/.bashrc
}

# Check if the virtual machine exists
VIRTUAL_MACHINE_ID=$(az vm show --resource-group $RESOURCE_GROUP_NAME --name $NODE_NAME --query id --output tsv 2>/dev/null)

if [ -n "$VIRTUAL_MACHINE_ID" ]; then
    echo "Virtual Machine $NODE_NAME exists."
    delete_virtual_machine
fi

# Check if the resource group exists
RESOURCE_GROUP_ID=$(az group show --name $RESOURCE_GROUP_NAME --query id --output tsv 2>/dev/null)

if [ -n "$RESOURCE_GROUP_ID" ]; then
    echo "Resource Group $RESOURCE_GROUP_NAME exists."
    delete_resource_group
fi

create_resource_group
create_virtual_machine
get_virtual_machine_ip
add_ssh_alias

echo "SSH alias '$SSH_ALIAS' added for VM $NODE_NAME."
