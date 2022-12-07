#!/bin/bash

set -eu -o pipefail # Causes this script to terminate if any command returns an error

checkContainerStatus() {
   # Query pods status and store the result as an array to iterate over individual status
   containers_status=( $(kubectl get pods -n kube-system  --output='jsonpath={.items[*].status.conditions[*].status}') )
   if [[ !" ${containers_status[*]} " =~ " False " ]]; then
      echo "Some pods are not ready"
      kubectl get pods -n kube-system
   else
      echo "All kube-system pods are ready."
      exit 0
   fi
}
export -f checkContainerStatus

### Main thread ###
EKS_CLUSTER_NAME="p9-eks-cluster"
NODE_GROUP_NAME=$(eksctl get nodegroup --cluster $EKS_CLUSTER_NAME -o json | jq '.[] .Name')

if [ "$1" == "scale-up" ];then
   DESIRED_NODES=1
   # Scale up nodegroup to 1
   echo "Scale up $EKS_CLUSTER_NAME to $DESIRED_NODES. Nodegroup to scale: $NODE_GROUP_NAME."
   
   time eksctl scale nodegroup --cluster=$EKS_CLUSTER_NAME \
   --nodes=$DESIRED_NODES --name=$NODE_GROUP_NAME \
   --nodes-min=$DESIRED_NODES --nodes-max=1 

   # Wait until the new node status is ready
   echo "Wait until node status is ready"
   while true ; do
      [ ! -z "$(kubectl wait node --all --for condition=ready --timeout=600s 2> /dev/null)" ] && echo && break
      sleep 2
      echo "Still waiting..."
      kubectl get nodes
   done

   # Once is ready, wait for kube-system pods:
   # aws-load-balancer-controller,  aws-node, coredns, csi-secrets-store-provider
   # kube-proxy, secrets-store-csi-driver
   while true ; do
      echo "Verifying that kube-system pods are ready"
      checkContainerStatus
      sleep 5
   done

elif [ "$1" == "tear-down" ];then

   DESIRED_NODES=0
   # Scale up nodegroup to 0
   echo "Scale down $EKS_CLUSTER_NAME to $DESIRED_NODES. Nodegroup to scale: $NODE_GROUP_NAME."

   time eksctl scale nodegroup --cluster=$EKS_CLUSTER_NAME \
   --nodes=$DESIRED_NODES --name=$NODE_GROUP_NAME \
   --nodes-min=$DESIRED_NODES --nodes-max=1
fi