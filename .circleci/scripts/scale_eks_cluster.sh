#!/bin/bash

# Script to scale up or tear down an eks cluster. 
#./scale_eks_cluster.sh --help for usage


set -eu -o pipefail # Causes this script to terminate if any command returns an error

################################## Functions ##################################

checkContainerStatus() {
   # Check if all pods are fully operational: the Pod is able to serve requests
   # and should be added to the load balancing pools of all matching Services.
   #
   # Note: A pod could be in a running state but still not ready. Therefore we
   # verify that all the conditions of a pod are True:
   #
   # kubectl describe -n kube-system pod POD_NAME | grep Conditions: -A5
   #   Conditions:
   #     Type              Status
   #     Initialized       True 
   #     Ready             True 
   #     ContainersReady   True 
   #     PodScheduled      True 
   #   
   # https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-conditions
   
   containers_status=( $(kubectl get pods -n kube-system  --output='jsonpath={.items[*].status.conditions[*].status}') )

   # Just print pods status
   kubectl get pods -n kube-system
   
   
   if [[ !" ${containers_status[*]} " =~ " False " ]]; then
      echo -e "\n***Some kube-system pods are not ready"
   else
      echo -e "\n***All kube-system pods are ready!"
      exit 0
   fi
}
export -f checkContainerStatus

scaleUp() {
   DESIRED_NODES=1
   EKS_CLUSTER_NAME="p9-eks-cluster"
   
   # Get the node group name to modify (p9-eks-clusters only have 1 nodegroup)
   NODE_GROUP_NAME=$(eksctl get nodegroup --cluster $EKS_CLUSTER_NAME -o json | jq '.[] .Name' | tr -d '"')
   
   # Scale up nodegroup to 1
   echo "Scale up $EKS_CLUSTER_NAME to $DESIRED_NODES. Nodegroup to scale: $NODE_GROUP_NAME."
   
   time eksctl scale nodegroup --cluster=$EKS_CLUSTER_NAME \
   --nodes=$DESIRED_NODES --name=$NODE_GROUP_NAME \
   --nodes-min=$DESIRED_NODES --nodes-max=1 

   # a while loop that will break until the node is ready
   echo "Wait until node status is ready"
   while true ; do
      # List nodes to see if it is already bootstrapped
      kubectl get nodes

      # Node is full operational when kubernetes reports it status in ready
      [ ! -z "$(kubectl wait node --all --for condition=ready --timeout=600s 2> /dev/null)" ] && echo && break

      # if not ready, will check again in 2 seconds
      echo -e "\nStill waiting..."
      sleep 2
   done

   # At this point the node is ready
   echo -e "\nNode is ready!"
   kubectl get nodes

   # A while loop that will exit until kube-system pods are ready:
   # - aws-load-balancer-controller
   # - aws-node
   # - coredns
   # - csi-secrets-store-provider
   # - kube-proxy
   # - secrets-store-csi-driver
   while true ; do
      echo -e "\nVerifying that kube-system pods are ready"
      checkContainerStatus
      # Check each 5 seconds
      sleep 5
   done
}
export -f scaleUp

tearDown() {
   DESIRED_NODES=0
   EKS_CLUSTER_NAME="p9-eks-cluster"
   
   # Get the node group name to modify (p9-eks-clusters only have 1 nodegroup)
   NODE_GROUP_NAME=$(eksctl get nodegroup --cluster $EKS_CLUSTER_NAME -o json | jq '.[] .Name' | tr -d '"')
   
   # Scale up nodegroup to 0
   echo "Tear down $EKS_CLUSTER_NAME to $DESIRED_NODES. Nodegroup to scale: $NODE_GROUP_NAME."

   time eksctl scale nodegroup --cluster=$EKS_CLUSTER_NAME \
   --nodes=$DESIRED_NODES --name=$NODE_GROUP_NAME \
   --nodes-min=$DESIRED_NODES --nodes-max=1
   
   exit 0
}
export -f tearDown

usage() {
   usage="$(basename "$0") [action] -- script to scale up or tear down an eks cluster. 
   where action:
      --scale-up:  scale up cluster to 1 node
      --tear-down: tear down cluster to zero nodes"
   echo "$usage"
   exit 0
}
export -f usage

##################################### Main #####################################

if [ $# -eq 0 ]; then
   echo "Error: No arguments supplied"
   usage
elif [ "$1" == "--scale-up" ];then
   scaleUp

elif [ "$1" == "--tear-down" ];then
   tearDown

elif [ "$1" == "--help" ];then
   usage
else
   echo "Error: Invalid option"
   usage
fi