# Self-Hosted Kubernetes in AWS EC2

The project was intended to make Selfhosted Kubernetes Medium Well way on IaaS AWS with no any managed services.
1 master node + 3 worker nodes + 1 HAProxy LB node
!!! Not fully production ready !!!

## Cluster Boostrap

### Apply Terraform resources
```shell
terraform init
terraform apply
```

### Bootstrap 1st master node (on master)
```shell
ssh ubuntu@<master-0-ip> -i ~/.ssh/<your_key>
sudo -i
tail -100f /var/log/cloud-init-output.log

/root/bootstrap-master.sh

save kubeadm command somehwere, if lost see appendix to regenerate token !!!

cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
k cluster-info
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

### Check master node (on master)
```shell
crictl ps
CONTAINER           IMAGE               CREATED             STATE               NAME                      ATTEMPT             POD ID              POD                                     NAMESPACE
838ea4e35781a       a8d049396f6b8       45 seconds ago      Running             kube-controller-manager   0                   ce2b947bcbaf1       kube-controller-manager-ip-10-0-1-175   kube-system
99c8e606e46cd       c3ff26fb59f37       45 seconds ago      Running             kube-scheduler            0                   a43859917d7e7       kube-scheduler-ip-10-0-1-175            kube-system
39c05f0a8ebe1       2b5bd0f16085a       45 seconds ago      Running             kube-apiserver            0                   b90dc18780890       kube-apiserver-ip-10-0-1-175            kube-system
0727ad1981701       7fc9d4aa817aa       45 seconds ago      Running             etcd                      0                   49f68cfdbf151       etcd-ip-10-0-1-175                      kube-system


k get nodes
NAME            STATUS     ROLES           AGE   VERSION
ip-10-0-1-140   NotReady   control-plane   85s   v1.32.0
```

### Bootstrap single worker nodes (on each worker)

Then you can join any number of worker nodes by running the following on each as root:
```shell
kubeadm join 10.0.1.46:6443 --token a4dkp2.4t4uj3bkddccuffj \
	--discovery-token-ca-cert-hash sha256:9d641c0985a34a9236504703363b4143375d7e0ed142a2209539e3f11e205506
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
  --set k8sServiceHost="10.0.1.21" \
  -f kubernetes/cilium-values.yaml

k -n kube-system exec -it $(k -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}') -- cilium status --verbose
```

### Check PODs status
```shell
k get pods -A
```

### In case of single master - remove taint from single node (on Master node)
```shell
k taint node <nodename> node-role.kubernetes.io/control-plane:NoSchedule
```

## OPTION 1 - Cilium Ingress Controller setup

### Create Cilium IP Pool and L2 policy
```shell
k apply -f kubernetes/cilium-ippool.yaml
k get ippools

k apply -f kubernetes/cilium-l2-policy.yaml
k get CiliumL2AnnouncementPolicy

k logs -n kube-system -l k8s-app=cilium | grep -i "l2"
```

### Check Cilium L2 announcements and its state
```shell
k -n kube-system get lease | grep cilium-l2announce

k -n kube-system get lease cilium-l2announce-kube-system-cilium-ingress -o jsonpath='{.spec.holderIdentity}'

POD=$(k -n kube-system get pods -l k8s-app=cilium -o wide | grep worker-1 | awk '{print $1}')

k -n kube-system exec $POD -- cilium-dbg shell -- db/show l2-announce
```

### Deploy Haproxy ingress for Cilium Ingress Public access ( L2-ARP is NOT WORKING on AWS EC2 )

```shell
cat > /etc/haproxy/haproxy.cfg <<EOF
global
    maxconn 20000
    daemon

defaults
    log     global
    mode    tcp
    option  dontlognull
    timeout connect 10s
    timeout client 86400s
    timeout server 86400s
    timeout tunnel 86400s
    timeout http-request 10s
    timeout queue        1m

# --- Web UI for stats ---
listen stats
    bind :9000
    mode http
    stats enable
    stats uri /
    stats refresh 10s
    stats auth admin:password

# --- HTTP frontend ---
frontend cilium-http
    bind *:80
    mode tcp
    default_backend cilium-backend-http

backend cilium-backend-http
    mode tcp
    option tcp-check
    balance roundrobin
    server ingress1 10.0.1.200:80 check fall 3 rise 2

# --- HTTPS frontend ---
frontend cilium-https
    bind *:443
    mode tcp
    default_backend cilium-backend-https

backend cilium-backend-https
    mode tcp
    option tcp-check
    balance roundrobin
    server ingress1 10.0.1.200:443 check fall 3 rise 2
EOF

systemctl restart haproxy
systemctl status haproxy
```

Check HAproxy stat:
http://<haproxy_node_public_ip>:9000

### Create Test Ingress LB to check
```shell
k apply -f nginx-ingress-test.yaml
curl http://<haproxy_node_public_ip>:80
```

## OPTION 2 - Nginx Ingress Controller setup

### Deploy Nginx Ingress Controller (on Master node)

```shell
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install \
 ingress-nginx ingress-nginx/ingress-nginx \
 --namespace ingress-nginx \
 --create-namespace \
 --set controller.replicaCount=2 \
 --set controller.service.type=NodePort \
 --set controller.service.nodePorts.http=30080 \
 --set controller.service.nodePorts.https=30443


~# kubectl get pods -n ingress-nginx
NAME                                       READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-cd9d6bbd7-9584c   1/1     Running   0          9m59s

~# kubectl get svc -n ingress-nginx
NAME                                 TYPE        CLUSTER-IP        EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             NodePort    100.128.195.118   <none>        80:30080/TCP,443:30443/TCP   9m38s
ingress-nginx-controller-admission   ClusterIP   100.128.146.0     <none>        443/TCP                      9m38s
```

### Deploy Haproxy ingress

- Frontend should be HTTP
- Backend should be worker nodes private ip with node port 30080 (!!! Replace Workers Internal IPs !!!)

```shell
cat > /etc/haproxy/haproxy.cfg <<EOF
defaults
    maxconn 20000
    mode    tcp
    option  dontlognull
    timeout http-request 10s
    timeout queue        1m
    timeout connect      10s
    timeout client       86400s
    timeout server       86400s
    timeout tunnel       86400s
listen stats
    bind :9000
    mode http
    stats enable
    stats uri /
    stats refresh 10s
    stats auth admin:password
frontend k8s-lb-ingress
    bind :80
    mode tcp
    default_backend k8s-nginx-ingress
backend k8s-nginx-ingress
    option tcp-check
    mode tcp
    balance roundrobin
    server worker0 10.0.1.108:30080 check fall 3 rise 2
    server worker1 10.0.1.82:30080 check fall 3 rise 2
    server worker2 10.0.1.44:30080 check fall 3 rise 2
EOF

systemctl restart haproxy
systemctl status haproxy
```

Check HAproxy stat:
http://<haproxy_node_public_ip>:9000

### Deploy Podinfo test pods and check DNS and network (on Master node)

```shell
k apply -f podinfo.yaml

route -n
kubectl run curl --rm -it --restart=Never --image=curlimages/curl -- sh
nslookup podinfo-service
curl -Is podinfo-service
```

### Update DNS for podinfo

- Update local DNS record in /etc/hosts:
```shell
<haproxy_node_public_ip>    podinfo.example.com
```

- Check website
http://podinfo.example.com

## Appendix A: Optional and legacy installation parts

### Regenerate kubeadm token command for worker nodes join (lifetime 24 hours)
```shell
kubeadm token create --print-join-command
```

### Regenerate kubeadm token commands for master nodes join
```shell
kubeadm init phase upload-certs --upload-certs

Copy key:
[upload-certs] Using certificate key:
1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef

kubeadm token create --print-join-command --control-plane

kubeadm join 10.0.1.183:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:51f73ac421b7... \
    --control-plane --certificate-key <PASTE_ME_HERE_KEY>


kubeadm token list
```

### Deploy CoreDNS (now it is included in kubeadm init)
```shell
k apply -f coredns.yaml
k logs -n kube-system -l k8s-app=kube-dns
```

### Direct Cilium installation from binary
```shell
cilium install --set ipam.mode=kubernetes
cilium status
```

### Remove broken Cilium installation (?)
```shell
helm uninstall cilium -n kube-system

kubectl delete daemonset cilium -n kube-system --ignore-not-found
kubectl delete deployment cilium-operator -n kube-system --ignore-not-found
kubectl delete svc hubble-ui -n kube-system --ignore-not-found
kubectl delete svc hubble-relay -n kube-system --ignore-not-found

on each node:
ip link delete cilium_host || true
ip link delete cilium_net || true

ip route | grep cilium
iptables -L -n -v | grep CILIUM

Then install it again
```
