#ALBIngressControllerSetupScript

$CLUSTER_NAME="project-bedrock-cluster"
$AWS_ACCOUNT_ID="197104194412"
$REGION="us-east-1"
$VPC_ID="vpc-0a8f9d36574fed19d"

Write-Host"SettingupAWSLoadBalancerController..."-ForegroundColorGreen

#Step1:GetOIDCprovider
Write-Host"`n1.GettingOIDCprovider..."-ForegroundColorYellow
$OIDC_ID=(awseksdescribe-cluster--name$CLUSTER_NAME--region$REGION--query"cluster.identity.oidc.issuer"--outputtext).Split('/')[-1]
Write-Host"OIDCProviderID:$OIDC_ID"

#Step2:CreateIAMpolicy(ifnotexists)
Write-Host"`n2.Creating/VerifyingIAMPolicy..."-ForegroundColorYellow
try{
awsiamget-policy--policy-arn"arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"2>$null
Write-Host"Policyalreadyexists"
}catch{
Write-Host"Policynotfound,willbecreatedbyHelm"
}

#Step3:InstallALBControllerusingHelm
Write-Host"`n3.InstallingAWSLoadBalancerControllerviaHelm..."-ForegroundColorYellow

wslbash-c@"
helminstallaws-load-balancer-controllereks/aws-load-balancer-controller\
-nkube-system\
--setclusterName=$CLUSTER_NAME\
--setserviceAccount.create=true\
--setserviceAccount.name=aws-load-balancer-controller\
--setregion=$REGION\
--setvpcId=$VPC_ID\
--setserviceAccount.annotations.'eks\.amazonaws\.com/role-arn'=arn:aws:iam::${AWS_ACCOUNT_ID}:role/AmazonEKSLoadBalancerControllerRole\
--wait--timeout5m
"@

Write-Host"`n✅ALBControllerinstallationcomplete!"-ForegroundColorGreen