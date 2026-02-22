#SetupScriptforProjectBedrockInfrastructure(PowerShellVersion)
#ThisscriptinitializestheTerraformbackendandsetsuptheremotestate

$ErrorActionPreference="Stop"

Write-Host"================================================"-ForegroundColorCyan
Write-Host"ProjectBedrock-InfrastructureSetup"-ForegroundColorCyan
Write-Host"================================================"-ForegroundColorCyan
Write-Host""

#Configuration
$AWS_REGION="us-east-1"
$BACKEND_BUCKET="bedrock-terraform-state-alt-soe-025-1483"
$DYNAMODB_TABLE="bedrock-terraform-locks"
$STUDENT_ID="ALT/SOE/025/1483"

Write-Host"📦CreatingS3bucketforTerraformstate..."-ForegroundColorYellow
try{
if($AWS_REGION-eq"us-east-1"){
awss3apicreate-bucket--bucket$BACKEND_BUCKET--region$AWS_REGION2>$null
}else{
awss3apicreate-bucket--bucket$BACKEND_BUCKET--region$AWS_REGION--create-bucket-configurationLocationConstraint=$AWS_REGION2>$null
}
Write-Host"✅Bucketcreatedsuccessfully"-ForegroundColorGreen
}catch{
Write-Host"ℹ️Bucketalreadyexists"-ForegroundColorGray
}

Write-Host"🔒EnablingversioningonS3bucket..."-ForegroundColorYellow
awss3apiput-bucket-versioning--bucket$BACKEND_BUCKET--versioning-configurationStatus=Enabled

Write-Host"🔐EnablingencryptiononS3bucket..."-ForegroundColorYellow
awss3apiput-bucket-encryption--bucket$BACKEND_BUCKET--server-side-encryption-configuration'{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}'

Write-Host"🚫BlockingpublicaccesstoS3bucket..."-ForegroundColorYellow
awss3apiput-public-access-block`
--bucket$BACKEND_BUCKET`
--public-access-block-configuration"BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

Write-Host"🏷️TaggingS3bucket..."-ForegroundColorYellow
awss3apiput-bucket-tagging`
--bucket$BACKEND_BUCKET`
--tagging"TagSet=[{Key=Project,Value=Bedrock},{Key=ManagedBy,Value=Terraform},{Key=StudentID,Value=$STUDENT_ID}]"

Write-Host"🗄️CreatingDynamoDBtableforstatelocking..."-ForegroundColorYellow
try{
awsdynamodbcreate-table`
--table-name$DYNAMODB_TABLE`
--attribute-definitionsAttributeName=LockID,AttributeType=S`
--key-schemaAttributeName=LockID,KeyType=HASH`
--provisioned-throughputReadCapacityUnits=5,WriteCapacityUnits=5`
--region$AWS_REGION`
--tags"Key=Project,Value=Bedrock""Key=ManagedBy,Value=Terraform""Key=StudentID,Value=$STUDENT_ID"2>$null
Write-Host"✅DynamoDBtablecreatedsuccessfully"-ForegroundColorGreen
}catch{
Write-Host"ℹ️DynamoDBtablealreadyexists"-ForegroundColorGray
}

Write-Host""
Write-Host"✅Backendsetupcomplete!"-ForegroundColorGreen
Write-Host""
Write-Host"Nextsteps:"-ForegroundColorCyan
Write-Host"1.cdterraform"-ForegroundColorWhite
Write-Host"2.terraforminit"-ForegroundColorWhite
Write-Host"3.terraformplan"-ForegroundColorWhite
Write-Host"4.terraformapply"-ForegroundColorWhite
Write-Host""