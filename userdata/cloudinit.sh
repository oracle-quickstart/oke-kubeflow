#!/bin/bash
#adding comments to make code readable

set -o pipefail
LOG_FILE="/var/log/OKE-kubeflow-initialize.log"
log() { 
	echo "$(date) [${EXECNAME}]: $*" >> "${LOG_FILE}" 
}

region=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/regionInfo/regionIdentifier`
namespace=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/namespace`
oke_cluster_id=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v1/instance/metadata/oke_cluster_id`
kubeflow_password=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v1/instance/metadata/kubeflow_password`

country=`echo $region|awk -F'-' '{print $1}'`
city=`echo $region|awk -F'-' '{print $2}'`

EXECNAME="Kubectl & Git"

log "->Install"
# Get the latest kubectl and not use archaic ones that are in default repo
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

# Kubectl is installed and now, you need to configure kubectl
log "->Configure"
mkdir -p /home/opc/.kube
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "alias k='kubectl'" >> ~/.bashrc
echo "source <(kubectl completion bash)" >> /home/opc/.bashrc
echo "alias k='kubectl'" >> /home/opc/.bashrc
source ~/.bashrc

# Get the OCI CLI installed
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


# Now that we have kubectl configured, let us download kustomize
wget https://github.com/kubernetes-sigs/kustomize/releases/download/v3.2.0/kustomize_3.2.0_linux_amd64
mv kustomize_3.2.0_linux_amd64 /bin/kustomize
chmod +x /bin/kustomize
EXECNAME="Kubeflow"
log "->Clone Repo"
mkdir -p /opt/kubeflow
cd /opt/kubeflow
git clone https://github.com/kubeflow/manifests.git >> $LOG_FILE
cd manifests
cp common/dex/base/config-map.yaml common/dex/base/config-map.yaml.DEFAULT
cat common/dex/base/config-map.yaml.DEFAULT |sed "s|hash:.*|hash: $kubeflow_password|" >common/dex/base/config-map.yaml
log "->Install via Kustomize"
source <(kubectl completion bash)
log "-->Build & Deploy Kubeflow"
while ! kustomize build example | kubectl apply --kubeconfig /root/.kube/config -f - | tee -a $LOG_FILE; do echo 'Retrying to apply resources'; sleep 60; done 
cat <<EOF | sudo tee /tmp/patchservice_lb.yaml
spec:
  type: LoadBalancer
metadata:
  annotations:
    service.beta.kubernetes.io/oci-load-balancer-shape: "flexible"
    service.beta.kubernetes.io/oci-load-balancer-shape-flex-min: "10"
    service.beta.kubernetes.io/oci-load-balancer-shape-flex-max: "800"
    service.beta.kubernetes.io/oci-load-balancer-enable-proxy-protocol: "true"
EOF

for i in {1..3}; do
  if [ $(kubectl --kubeconfig /root/.kube/config get pods -n istio-system --no-headers=true |egrep -i ingressgateway | awk '{print $3}') = "Running" ]; then
      echo "Ingress Gateway has been created successfully"

      break
  fi
  sleep 60
done
kubectl --kubeconfig /root/.kube/config patch svc istio-ingressgateway -n istio-system -p "$(cat /tmp/patchservice_lb.yaml)" | tee -a $LOG_FILE
sleep 120
#LBIP=$(kubectl get svc istio-ingressgateway -n istio-system -o=jsonpath="{.spec.loadBalancerIP}")
LBIP=$(kubectl --kubeconfig /root/.kube/config get svc istio-ingressgateway -n istio-system -o=jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo "Load Balancer IP is ${LBIP}" |tee -a $LOG_FILE
mkdir -p kfsecure
cd kfsecure
cat <<EOF | sudo tee san.cnf
[req]
default_bits  = 2048
distinguished_name = req_distinguished_name
req_extensions = req_ext
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
countryName = ${country}
stateOrProvinceName = ${city}
localityName = N/A
organizationName = Self-signed certificate
commonName = ${LBIP}: Self-signed certificate
[req_ext]
subjectAltName = @alt_names
[v3_req]
subjectAltName = @alt_names
[alt_names]
IP.1 = ${LBIP}
EOF
# openSSL create keys
openssl req -x509 -nodes -days 730 -newkey rsa:2048 -keyout key.tls -out cert.tls -config san.cnf
kubectl --kubeconfig /root/.kube/config create -n istio-system secret tls kubeflow-tls-cert --key=key.tls --cert=cert.tls | tee -a $LOG_FILE
cat <<EOF | sudo tee sslenableingress.yaml 
apiVersion: v1
items:
- apiVersion: networking.istio.io/v1beta1
  kind: Gateway
  metadata:
    annotations:
    name: kubeflow-gateway
    namespace: kubeflow
  spec:
    selector:
      istio: ingressgateway
    servers:
    - hosts:
      - "*"
      port:
        name: https
        number: 443
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: kubeflow-tls-cert
    - hosts:
      - "*"
      port:
        name: http
        number: 80
        protocol: HTTP
      tls:
        httpsRedirect: true
kind: List
metadata:
  resourceVersion: ""
  selfLink: ""
EOF

kubectl --kubeconfig /root/.kube/config apply -f sslenableingress.yaml
