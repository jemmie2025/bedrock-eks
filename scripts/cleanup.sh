#!/bin/bash

#CleanupScript-Destroysallinfrastructure
#WARNING:ThiswilldeleteallresourcescreatedbyTerraform

set-e

echo"================================================"
echo"⚠️WARNING:InfrastructureCleanup"
echo"================================================"
echo""
echo"ThisscriptwilldestroyALLinfrastructureresources."
echo"ThisactionCANNOTbeundone!"
echo""
read-p"Areyousureyouwanttocontinue?(type'yes'toconfirm):"confirm

if["$confirm"!="yes"];then
echo"Cleanupcancelled."
exit0
fi

echo""
echo"🗑️Startingcleanupprocess..."
echo""

#Configuration
CLUSTER_NAME="project-bedrock-cluster"
AWS_REGION="us-east-1"
NAMESPACE="retail-app"
BACKEND_BUCKET="bedrock-terraform-state-alt-soe-025-0275"
DYNAMODB_TABLE="bedrock-terraform-locks"

#DeleteKubernetesresourcesfirst
echo"🧹CleaningupKubernetesresources..."
kubectldeletenamespace$NAMESPACE--ignore-not-found=true--wait=true

#WaitforLoadBalancerstobedeleted
echo"⏳WaitingforLoadBalancerstobecleanedup..."
sleep60

#RunTerraformdestroy
echo"🔥DestroyingTerraforminfrastructure..."
cd../terraform
terraformdestroy-auto-approve

echo""
echo"🧹Cleaningupbackendresources..."
echo""

#EmptyanddeleteS3bucket
echo"📦EmptyingS3bucket..."
awss3rms3://$BACKEND_BUCKET--recursive2>/dev/null||true

echo"🗑️DeletingS3bucket..."
awss3apidelete-bucket--bucket$BACKEND_BUCKET--region$AWS_REGION2>/dev/null||true

#DeleteDynamoDBtable
echo"🗄️DeletingDynamoDBtable..."
awsdynamodbdelete-table--table-name$DYNAMODB_TABLE--region$AWS_REGION2>/dev/null||true

echo""
echo"✅Cleanupcomplete!"
echo""