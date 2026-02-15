#!/bin/bash

#SetupScriptforProjectBedrockInfrastructure
#ThisscriptinitializestheTerraformbackendandsetsuptheremotestate

set-e

echo"================================================"
echo"ProjectBedrock-InfrastructureSetup"
echo"================================================"
echo""

#Configuration
AWS_REGION="us-east-1"
BACKEND_BUCKET="bedrock-terraform-state-alt-soe-025-0275"
DYNAMODB_TABLE="bedrock-terraform-locks"
STUDENT_ID="ALT-SOE-025-0275"

echo"📦CreatingS3bucketforTerraformstate..."
if["$AWS_REGION"="us-east-1"];then
awss3apicreate-bucket\
--bucket$BACKEND_BUCKET\
--region$AWS_REGION2>/dev/null||echo"Bucketalreadyexists"
else
awss3apicreate-bucket\
--bucket$BACKEND_BUCKET\
--region$AWS_REGION\
--create-bucket-configurationLocationConstraint=$AWS_REGION2>/dev/null||echo"Bucketalreadyexists"
fi

echo"🔒EnablingversioningonS3bucket..."
awss3apiput-bucket-versioning\
--bucket$BACKEND_BUCKET\
--versioning-configurationStatus=Enabled

echo"🔐EnablingencryptiononS3bucket..."
awss3apiput-bucket-encryption\
--bucket$BACKEND_BUCKET\
--server-side-encryption-configuration'{
"Rules":[{
"ApplyServerSideEncryptionByDefault":{
"SSEAlgorithm":"AES256"
}
}]
}'

echo"🚫BlockingpublicaccesstoS3bucket..."
awss3apiput-public-access-block\
--bucket$BACKEND_BUCKET\
--public-access-block-configuration\
BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo"🏷️TaggingS3bucket..."
awss3apiput-bucket-tagging\
--bucket$BACKEND_BUCKET\
--tagging"TagSet=[{Key=Project,Value=barakat-2025-capstone},{Key=ManagedBy,Value=Terraform},{Key=StudentID,Value=$STUDENT_ID}]"

echo"🗄️CreatingDynamoDBtableforstatelocking..."
awsdynamodbcreate-table\
--table-name$DYNAMODB_TABLE\
--attribute-definitionsAttributeName=LockID,AttributeType=S\
--key-schemaAttributeName=LockID,KeyType=HASH\
--provisioned-throughputReadCapacityUnits=5,WriteCapacityUnits=5\
--region$AWS_REGION\
--tagsKey=Project,Value=barakat-2025-capstoneKey=ManagedBy,Value=TerraformKey=StudentID,Value=$STUDENT_ID\
2>/dev/null||echo"DynamoDBtablealreadyexists"

echo""
echo"✅Backendsetupcomplete!"
echo""
echo"Nextsteps:"
echo"1.cdterraform"
echo"2.terraforminit"
echo"3.terraformplan"
echo"4.terraformapply"
echo""