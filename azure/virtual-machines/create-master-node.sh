#!/bin/bash

MASTER_NODE_NAME="spend-production-master-node"
MASTER_NODE_RESOURCE_GROUP_NAME="spend-production-master-node-resource-group"
SSH_ALIAS="ssh_master"
IS_CONTROL_PLANE=true

./create-virtual-machine.sh $MASTER_NODE_NAME $MASTER_NODE_RESOURCE_GROUP_NAME $SSH_ALIAS $IS_CONTROL_PLANE
