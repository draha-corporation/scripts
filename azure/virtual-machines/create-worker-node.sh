#!/bin/bash

WORKER_NODE_NAME="spend-production-worker-node-1"
WORKER_NODE_RESOURCE_GROUP_NAME="spend-production-worker-node-1-resource-group"
SSH_ALIAS="ssh_worker1"

./create-virtual-machine.sh $WORKER_NODE_NAME $WORKER_NODE_RESOURCE_GROUP_NAME $SSH_ALIAS
