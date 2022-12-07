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

if [ "$1" == "scale-up" ];then

   # Scale up nodegroup to 1
   echo "Scale up eks nodegroup to 1"

   time eksctl scale nodegroup --cluster=p9-eks-cluster \
   --nodes=1 --name=node-group-1-2022111500171013530000001a \
   --nodes-min=1 --nodes-max=1 

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

   # Scale down nodegroup to zero
   echo "Scale down eks nodegroup to zero"

   time eksctl scale nodegroup --cluster=p9-eks-cluster \
   --nodes=0 --name=node-group-1-2022111500171013530000001a \
   --nodes-min=0 --nodes-max=1
fi