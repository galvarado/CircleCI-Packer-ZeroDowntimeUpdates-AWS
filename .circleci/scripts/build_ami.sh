#!/bin/bash

set -eu -o pipefail # Causes this script to terminate if any command returns an error

packer build packer/ami.pkr.hcl
echo "export NEW_AMI_ID=$(jq -r '.builds[0].artifact_id|split(":")[1]' ./manifest.json)" >> $BASH_ENV