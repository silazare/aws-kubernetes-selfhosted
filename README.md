# Self-Hosted Kubernetes in AWS for development

The project was intended to make Selfhosted Kubernetes Medium way on IaaS AWS with no any managed services.
Not production ready!

### Apply Terraform resources
```shell
terraform init
terraform apply
```

### Bootstrap 1st master node
```shell
ssh ubuntu@<master-0-ip> -i ~/.ssh/<your_key>
sudo -i
tail -f /var/log/cloud-init-output.log

/root/bootstrap-master.sh

cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
k cluster-info
```

### Check master node
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

### Install Cilium
```shell
cilium install --set ipam.mode=kubernetes

cilium status
```

### Check PODs status
```shell
kubectl get pods -A
```

### Deploy CoreDNS
```shell
k apply -f /root/coredns.yaml
k logs -n kube-system -l k8s-app=kube-dns
```

### In case of single master - remove taint from single node (on Master node)
```shell
k taint node <nodename> node-role.kubernetes.io/control-plane:NoSchedule
```

### Bootstrap single worker nodes (on each Worker node)

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.0.1.46:6443 --token a4dkp2.4t4uj3bkddccuffj \
	--discovery-token-ca-cert-hash sha256:9d641c0985a34a9236504703363b4143375d7e0ed142a2209539e3f11e205506

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
- Backend should be worker nodes private ip with node port 30080

```shell
apt-get update
apt-get install -y haproxy

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
    server worker0 10.0.1.139:30080 check fall 3 rise 2
    server worker1 10.0.1.253:30080 check fall 3 rise 2
    server worker2 10.0.1.209:30080 check fall 3 rise 2
EOF

systemctl restart haproxy
systemctl status haproxy
```

Check HAproxy stat:
http://<haproxy_node_public_ip>:9000

### Deploy Podinfo test pods and check DNS and network (on Master node)

```shell
k apply -f /root/podinfo.yaml

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
