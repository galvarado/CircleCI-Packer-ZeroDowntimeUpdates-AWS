#!/bin/bash

set -eu -o pipefail # Causes this script to terminate if any command returns an error

aws ec2 create-launch-template-version \
--launch-template-name $LAUNCH_TEMPLATE_NAME \
--source-version 1 \
--launch-template-data '{"ImageId":"$NEW_IMAGE_ID"}'