#!/bin/bash

set -eu -o pipefail # Causes this script to terminate if any command returns an error

aws ec2 create-launch-template-version \
--launch-template-name ipcs-asg-launch-template \
--source-version 1 \
--launch-template-data '{"ImageId":"ami-08ebbb9b96a9af18a"}'