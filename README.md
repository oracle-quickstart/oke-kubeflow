# Kubeflow on OCI OKE
This quickstart template deploys [Kubeflow](https://www.kubeflow.org/#overview) on [Oracle Kubernetes Engine (OKE)](https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengoverview.htm).

# Pre-Requisites
Please read the following prerequisites sections thoroughly prior to deployment.

## Instance Principals & IAM Policy
Deployment depends on use of [Instance Principals](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm) via OCI CLI to generate kube config for use with kubectl.  You should create a [dynamic group](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingdynamicgroups.htm) for the compartment where you are deploying Kubeflow.   In this example, I am using a [Default Tag](https://docs.oracle.com/en-us/iaas/Content/Tagging/Tasks/managingtagdefaults.htm) for all resources in the target compartment to define the Dynamic Group:

	tag.Kubeflow.InstancePrincipal.value='Enabled'

After creating the group, you should set specific [IAM policies](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/policyreference.htm) for OCI service interaction:

	Allow dynamic-group Kubeflow to manage cluster-family in compartment Kubeflow
	Allow dynamic-group Kubeflow to manage object-family in compartment Kubeflow
	

This will allow interaction with the OKE cluster using instance principals, as well as Kubeflow to interact with Object Storage and OCI Vaults.

<!-- ## Kubeflow Security
You will also need an [OCI Vault](https://docs.oracle.com/en-us/iaas/Content/KeyManagement/Concepts/keyoverview.htm), and two [Vault Secrets](https://docs.oracle.com/en-us/iaas/Content/KeyManagement/Tasks/managingsecrets.htm) - one for Kubeflow Login and one for Kubeflow Password.  Create the vault and secrets prior to deployment, and capture the OCIDs of each secret to insert into the deployment template.  These will be retrieved during the deployment process so that they do not persist in any terraform metadata.

*Note that the Vault should be in the same region you plan to deploy this template* - This is because the template uses OCI CLI to retrieve the vault secrets, and the OCI CLI configuration is localized to the deployment region.
-->
# Deployment
This deployment uses [Oracle Resource Manager](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/resourcemanager.htm) and consists of a VCN, OKE Cluster with Node Pool, and an Edge node.   The Edge node installs OCI CLI, Kubectl, and Kustomize.  Kustomize is used to build [Kubeflow manifests](https://github.com/kubeflow/manifests) and deploy them to OKE using kubectl.   This is done using [cloudinit](userdata/cloudinit.sh) - the build process is logged in ``/var/log/OKE-kubeflow-initialize.log``.

*Note that you should select shapes and scale your node pool as appropriate for your workload.*

This template deploys the following by default:

* Virtual Cloud Network
  * Public (Edge) Subnet
  * Private Subnet
  * Internet Gateway
  * NAT Gateway
  * Service Gateway
  * Route tables
  * Security Lists
    * TCP 22 for Edge SSH on public subnet
    * Ingress to both subnets from VCN CIDR
    * Egress to Internet for both subnets
* OCI Virtual Machine Edge Node
* OKE Cluster and Node Pool

Simply click the Deploy to OCI button to create an ORM stack, then walk through the menu driven deployment.  Once the stack is created, use the menu to Plan and Apply the template.

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://console.us-ashburn-1.oraclecloud.com/resourcemanager/stacks/create?region=home&zipUrl=https://github.com/oracle-quickstart/oke-kubeflow/archive/v3.1.1.zip)

## OKE post-deployment
You can check status of the OKE cluster using the following kubectl commands:

	kubectl get pods -n cert-manager
	kubectl get pods -n istio-system
	kubectl get pods -n auth
	kubectl get pods -n knative-eventing
	kubectl get pods -n knative-serving
	kubectl get pods -n kubeflow
	kubectl get pods -n kubeflow-user-example-com

### Kubeflow Access


	ssh -i ~/.ssh/PRIVATE_KEY opc@EDGE_NODE_IP
	cat /var/log/OKE-kubeflow-initialize.log|egrep -i "Load Balancer IP"

Then load up your browser to https://<load balancer ip> 
	Note: The certificate created above is a self signed certificate and hence the browser will issue warning. It needs to be accepted. 

Login with the default user's credential. The default email address is ``user@example.com`` and the password is what was provided with ORM (default is Kubeflow54321)

### Destroying the Stack
Note that with the inclusion of SSL Load Balancer, you will need to remove the `` istio-ingressgateway `` service before you destroy the stack, or you will get an error. 

	kubectl delete svc istio-ingressgateway -n istio-system

This will remove the service, then you can destroy the build without errors.
