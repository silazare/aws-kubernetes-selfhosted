#  Self-Hosted Kubernetes in Multipass Ubuntu nodes

This folder contains configuration for setting up a Kubernetes cluster using Multipass.

## Create multipass nodes with cloud-init
```shell
# Launch master node with cloud-init
multipass launch --name k8s-master --cpus 4 --memory 8G --disk 20G noble --cloud-init=master-cloud-init.yaml

# Launch worker node with cloud-init
multipass launch --name k8s-worker --cpus 4 --memory 8G --disk 20G noble --cloud-init=worker-cloud-init.yaml
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

### Bootstrap worker node

Then you can join any number of worker nodes by running the following on each as root:
```shell
multipass shell k8s-worker

kubeadm join 192.168.64.6:6443 --token a4dkp2.4t4uj3bkddccuffj \
	--discovery-token-ca-cert-hash sha256:9d641c0985a34a9236504703363b4143375d7e0ed142a2209539e3f11e205506
```

### Merge cluster kubeconfig with your own kubeconfig on laptop (optional)
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

### Install Cilium
https://medium.com/@shih.chieh.cheng/cilium-argo-cd-on-a-single-node-kubernetes-cluster-on-your-laptop-a-love-story-of-ebpf-and-44936ea38ff1

```shell
!!! Replace API server Internal IP !!!

helm repo add cilium https://helm.cilium.io/
helm repo update

helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.17.3 \
  --reuse-values \
  --set k8sServiceHost="192.168.64.6" \
  -f kubernetes/cilium-values-multipass.yaml

k -n kube-system exec -it $(k -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}') -- cilium status --verbose
```

### Check PODs status
```shell
k get pods -A
```
