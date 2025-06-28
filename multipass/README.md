#  Self-Hosted Kubernetes in Multipass Ubuntu nodes

https://medium.com/@shih.chieh.cheng/cilium-argo-cd-on-a-single-node-kubernetes-cluster-on-your-laptop-a-love-story-of-ebpf-and-44936ea38ff1

This folder contains configuration for setting up a Kubernetes cluster using Multipass.

## Create multipass nodes with cloud-init
```shell
# Launch master node with cloud-init
multipass launch --name k8s-master --cpus 4 --memory 8G --disk 24G noble --cloud-init=master-cloud-init.yaml

# Launch worker nodes with cloud-init
multipass launch --name k8s-worker-0 --cpus 4 --memory 8G --disk 24G noble --cloud-init=worker-cloud-init.yaml

multipass launch --name k8s-worker-1 --cpus 4 --memory 8G --disk 24G noble --cloud-init=worker-cloud-init.yaml
```

### Bootstrap master node
```shell
multipass list

multipass shell k8s-master

sudo -i
tail -100f /var/log/cloud-init-output.log

/root/bootstrap-master.sh

save kubeadm command somehwere, if lost see appendix to regenerate token !!!

cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
k cluster-info
```

### Merge cluster kubeconfig with your own kubeconfig on laptop
- Backup current config
```shell
cp ~/.kube/config ~/.kube/config-bkp
```

- Cleanup old cluster if any:
```shell
kubectl config delete-context kubernetes-admin@kubernetes
kubectl config delete-cluster kubernetes
kubectl config delete-user kubernetes-admin
```

- Put new cluster config at ~/.kube/config-sandbox, replace IP and cluster name

- Set kubeconfig env to merge several configs
```shell
export KUBECONFIG=~/.kube/config:~/.kube/config-sandbox
kubectl config view
```

- Merge kubeconfig files
```shell
kubectl config view --flatten > ~/.kube/config-new
mv ~/.kube/config-new ~/.kube/config
chmod 600 ~/.kube/config
unset KUBECONFIG
```

### Bootstrap worker nodes

Then you can join any number of worker nodes by running the following on each as root:
```shell
multipass shell k8s-worker

kubeadm join 192.168.64.11:6443 --token a4dkp2.4t4uj3bkddccuffj \
	--discovery-token-ca-cert-hash sha256:9d641c0985a34a9236504703363b4143375d7e0ed142a2209539e3f11e205506
```

### Install Cilium
```shell
!!! Replace API server Internal IP !!!

helm repo add cilium https://helm.cilium.io/
helm repo update

helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.17.3 \
  --reuse-values \
  --set k8sServiceHost="192.168.64.11" \
  -f kubernetes/cilium-values-multipass.yaml

k -n kube-system exec -it $(k -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}') -- cilium status --verbose
```

### Check PODs status
```shell
k get pods -A
```

## Cilium Ingress Controller setup

### Create Cilium IP Pool and L2 policy
```shell
k apply -f kubernetes/cilium-ippool.yaml
k get ippools

k apply -f kubernetes/cilium-l2-policy.yaml
k get CiliumL2AnnouncementPolicy

k logs -n kube-system -l k8s-app=cilium | grep -i "l2"
```

### Check Cilium L2 announcement node and its state
```shell
k -n kube-system get lease | grep cilium-l2announce

POD=$(k -n kube-system get pods -l k8s-app=cilium -o wide | grep $(k -n kube-system get lease cilium-l2announce-kube-system-cilium-ingress -o jsonpath='{.spec.holderIdentity}') | awk '{print $1}')

k -n kube-system exec $POD -- cilium-dbg shell -- db/show l2-announce
```

### Check Cilium LB and open Hubble UI
```shell
curl http://<VIP_SVC_IP>
```

### Check Cilium Hubble UI via Cilium LB
```shell
http://<VIP_CILIUM_SVC_IP>
```

## Install ArgoCD

### Add the Argo CD Helm repository
```shell
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### Install Argo CD with its default configuration and expose the UI as a LoadBalancer
```shell
k create namespace argocd
helm install argocd argo/argo-cd \
    --set server.service.type=LoadBalancer \
    --namespace argocd
```

### Verify Argo CD Server status and find the VIP assigned
```shell
k get all -n argocd
k get pods -n argocd
k describe svc argocd-server -n argocd
k get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

http://<VIP_ARGO_SVC_IP>
```

## Install OpenTelemetry Astronomy Shop from ArgoCD
```shell
k apply -f kubernetes/otel-shop-application.yaml
```

### Check demo apps 
```shell
Web store: http://<VIP>:8080/
Grafana: http:// <VIP>:8080/grafana/
Load Generator UI: http:// <VIP>:8080/loadgen/
Jaeger UI: http:// <VIP>:8080/jaeger/ui/
Flagd configurator UI: http:// <VIP>:8080/feature
```

### Tear down demo apps
```shell
k delete -f kubernetes/otel-shop-application.yaml
```
