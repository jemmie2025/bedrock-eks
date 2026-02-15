#DeployRetailApplicationtoEKSCluster(PowerShellVersion)
#ThisscriptdeploystheretailstoresampleappusingHelm

$ErrorActionPreference="Stop"

Write-Host"================================================"-ForegroundColorCyan
Write-Host"DeployingRetailStoreApplication"-ForegroundColorCyan
Write-Host"================================================"-ForegroundColorCyan
Write-Host""

#Configuration
$CLUSTER_NAME="project-bedrock-cluster"
$AWS_REGION="us-east-1"
$NAMESPACE="retail-app"
$HELM_RELEASE="retail-app"

#Updatekubeconfig
Write-Host"🔧Configuringkubectl..."-ForegroundColorYellow
awseksupdate-kubeconfig--name$CLUSTER_NAME--region$AWS_REGION

#Verifyclusteraccess
Write-Host"✅Verifyingclusteraccess..."-ForegroundColorYellow
kubectlcluster-info
kubectlgetnodes

#Createnamespaceifitdoesn'texist
Write-Host"📦Ensuringnamespaceexists..."-ForegroundColorYellow
kubectlcreatenamespace$NAMESPACE--dry-run=client-oyaml|kubectlapply-f-

#AddHelmrepository
Write-Host"📚AddingHelmrepository..."-ForegroundColorYellow
helmrepoaddretail-apphttps://aws.github.io/retail-store-sample-app
helmrepoupdate

#Deploytheapplication
Write-Host"🚀Deployingretailapplication..."-ForegroundColorYellow
helmupgrade--install$HELM_RELEASEretail-app/retail-app`
--namespace$NAMESPACE`
--values..\k8s\retail-app-values.yaml`
--wait`
--timeout10m

Write-Host""
Write-Host"✅Deploymentcomplete!"-ForegroundColorGreen
Write-Host""

#Getdeploymentstatus
Write-Host"📊DeploymentStatus:"-ForegroundColorCyan
kubectlgetpods-n$NAMESPACE
Write-Host""
kubectlgetservices-n$NAMESPACE
Write-Host""

#GetIngressURL
Write-Host"🌐GettingapplicationURL..."-ForegroundColorYellow
Start-Sleep-Seconds30
try{
$ALB_URL=kubectlgetingress-n$NAMESPACE-ojsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'2>$null

if($ALB_URL){
Write-Host""
Write-Host"🎉Applicationisaccessibleat:http://$ALB_URL"-ForegroundColorGreen
Write-Host""
}else{
throw"URLnotavailableyet"
}
}catch{
Write-Host""
Write-Host"⏳ALBisbeingprovisioned.Checkbackinafewminuteswith:"-ForegroundColorYellow
Write-Host"kubectlgetingress-n$NAMESPACE"-ForegroundColorWhite
Write-Host""
}

Write-Host"Tomonitorthedeployment:"-ForegroundColorCyan
Write-Host"kubectlgetpods-n$NAMESPACE-w"-ForegroundColorWhite
Write-Host""