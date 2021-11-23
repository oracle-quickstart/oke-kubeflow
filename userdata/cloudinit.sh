#!/bin/bash
LOG_FILE="/var/log/OKE-kubeflow-initialize.log"
log() { 
	echo "$(date) [${EXECNAME}]: $*" >> "${LOG_FILE}" 
}
region=`curl -s -L http://169.254.169.254/opc/v1/instance/regionInfo/regionIdentifier`
oke_cluster_id=`curl -s -L http://169.254.169.254/opc/v1/instance/metadata/oke_cluster_id`
EXECNAME="Kubectl & Git"
log "->Install"
# Get the latest kubectl
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
yum install kubectl git screen -y >> $LOG_FILE
log "->Configure"
mkdir -p /home/opc/.kube
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "alias k='kubectl'" >> ~/.bashrc
echo "source <(kubectl completion bash)" >> /home/opc/.bashrc
echo "alias k='kubectl'" >> /home/opc/.bashrc
source ~/.bashrc
EXECNAME="OCI CLI"
log "->Download"
curl -L -O https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh >> $LOG_FILE
chmod a+x install.sh 
log "->Install"
./install.sh --accept-all-defaults >> $LOG_FILE
echo "export OCI_CLI_AUTH=instance_principal" >> ~/.bash_profile
echo "export OCI_CLI_AUTH=instance_principal" >> ~/.bashrc
echo "export OCI_CLI_AUTH=instance_principal" >> /home/opc/.bash_profile
echo "export OCI_CLI_AUTH=instance_principal" >> /home/opc/.bashrc
EXECNAME="Kubeconfig"
log "->Generate"
RET_CODE=1
INDEX_NR=1
SLEEP_TIME="10s"
while [ ! -f /root/.kube/config ]
do
	sleep 5
	source ~/.bashrc
	fetch_metadata
	log "-->Attempting to generate kubeconfig"
	oci ce cluster create-kubeconfig --cluster-id ${oke_cluster_id} --file /root/.kube/config  --region ${region} --token-version 2.0.0 >> $LOG_FILE
	log "-->Finished attempt"
done
mkdir -p /home/opc/.kube/
cp /root/.kube/config /home/opc/.kube/config
chown -R opc:opc /home/opc/.kube/
EXECNAME="Kustomize"
log "->Fetch & deploy to /bin/"
wget https://github.com/kubernetes-sigs/kustomize/releases/download/v3.2.0/kustomize_3.2.0_linux_amd64
mv kustomize_3.2.0_linux_amd64 /bin/kustomize
chmod +x /bin/kustomize
EXECNAME="Kubeflow"
log "->Clone Repo"
mkdir -p /opt/kubeflow
cd /opt/kubeflow
git clone https://github.com/kubeflow/manifests.git >> $LOG_FILE
cd manifests
#log "->Set UID/Password"
#kubeflow_login_ocid=`curl -s -L http://169.254.169.254/opc/v1/instance/metadata/kubeflow_login_ocid`
#kubeflow_password_ocid=`curl -s -L http://169.254.169.254/opc/v1/instance/metadata/kubeflow_password_ocid`
#pip3 install passlib
#pip3 install bcrypt
#kubeflow_login=`oci secrets secret-bundle get --secret-id ${kubeflow_login_ocid} --stage CURRENT | jq  ."data.\"secret-bundle-content\".content" |  tr -d '"' | base64 -d`
#kubeflow_ct_password=`oci secrets secret-bundle get --secret-id ${kubeflow_password_ocid} --stage CURRENT | jq  ."data.\"secret-bundle-content\".content" |  tr -d '"' | base64 -d`
#sed -ie "s/user@example.com/${kubeflow_login}/g" common/dex/base/config-map.yaml
#kubeflow_password=`python3 -c 'from passlib.hash import bcrypt; import getpass; print(bcrypt.using(rounds=12, ident="2y").hash("$kubeflow_ct_password"))'`
#escaped_password=$(printf '%s\n' "$kubeflow_password" | sed -e 's/[\/&]/\\&/g')
#sed -ie "s/\$2y\$12\$4K\/VkmDd1q1Orb3xAt82zu8gk7Ad6ReFR4LCP9UeYE90NLiN9Df72/${escaped_password}/g" common/dex/base/config-map.yaml
log "->Install via Kustomize"
source <(kubectl completion bash)
log "-->Build & Deploy Kubeflow"
#kustomize build example >> /opt/kubeflow/kubeflow.yaml 
#log "-->Deploy"
screen -dmLS Kubeflow
log "----> Inserting build commands into screen session.  Attach to this as root using 'screen -r' command to see build and deploy log"
screen -XS Kubeflow stuff "while ! kustomize build example | kubectl apply --kubeconfig /root/.kube/config -f -; do echo 'Retrying to apply resources'; sleep 10; done \\n"
log "->Done" 
EXECNAME="INFO"
log "-> Use following commands to check pod status"
log "---->
kubectl get pods -n cert-manager
kubectl get pods -n istio-system
kubectl get pods -n auth
kubectl get pods -n knative-eventing
kubectl get pods -n knative-serving
kubectl get pods -n kubeflow
kubectl get pods -n kubeflow-user-example-com
<----"
