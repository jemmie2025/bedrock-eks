#!/bin/bash

#DeployRetailApplicationtoEKSCluster
#ThisscriptdeploystheretailstoresampleappusingHelm

set-e

echo"================================================"
echo"DeployingRetailStoreApplication"
echo"================================================"
echo""

#Configuration
CLUSTER_NAME="project-bedrock-cluster"
AWS_REGION="us-east-1"
NAMESPACE="retail-app"
HELM_RELEASE="retail-app"

#Updatekubeconfig
echo"🔧Configuringkubectl..."
awseksupdate-kubeconfig--name$CLUSTER_NAME--region$AWS_REGION

#Verifyclusteraccess
echo"✅Verifyingclusteraccess..."
kubectlcluster-info
kubectlgetnodes

#Createnamespaceifitdoesn'texist
echo"📦Ensuringnamespaceexists..."
kubectlcreatenamespace$NAMESPACE--dry-run=client-oyaml|kubectlapply-f-

#AddHelmrepository
echo"📚AddingHelmrepository..."
helmrepoaddretail-apphttps://aws.github.io/retail-store-sample-app
helmrepoupdate

#Deploytheapplication
echo"🚀Deployingretailapplication..."
helmupgrade--install$HELM_RELEASEretail-app/retail-app\
--namespace$NAMESPACE\
--values../k8s/retail-app-values.yaml\
--wait\
--timeout10m

echo""
echo"✅Deploymentcomplete!"
echo""

#Getdeploymentstatus
echo"📊DeploymentStatus:"
kubectlgetpods-n$NAMESPACE
echo""
kubectlgetservices-n$NAMESPACE
echo""

#GetIngressURL
echo"🌐GettingapplicationURL..."
sleep30
ALB_URL=$(kubectlgetingress-n$NAMESPACE-ojsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'2>/dev/null||echo"Notavailableyet")

if["$ALB_URL"!="Notavailableyet"];then
echo""
echo"🎉Applicationisaccessibleat:http://$ALB_URL"
echo""
else
echo""
echo"⏳ALBisbeingprovisioned.Checkbackinafewminuteswith:"
echo"kubectlgetingress-n$NAMESPACE"
echo""
fi

echo"Tomonitorthedeployment:"
echo"kubectlgetpods-n$NAMESPACE-w"
echo""