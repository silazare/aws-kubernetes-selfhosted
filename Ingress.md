# Bare Metal Default Ingress flow

```shell
Client
  |
  v
DNS (app.example.com -> VIP: 192.168.1.100:443)
  |
  v
Keepalived
  +--------------------------+
  | Active HAProxy  : 192.168.1.10 (VIP 192.168.1.100)
  | Passive HAProxy : 192.168.1.11 (standby)
  +--------------------------+
  |
  v
HAProxy
  +-----------------------------------+
  | frontend https-in                 |
  | bind 192.168.1.100:443            |
  |                                   |
  | backend k8s-nodes:                |
  | - k8s-node1: 192.168.2.10:30443  |
  | - k8s-node2: 192.168.2.11:30443  |
  | - k8s-node3: 192.168.2.12:30443  |
  +-----------------------------------+
  |
  v
Kubernetes Node (example: k8s-node1)
  +--------------------------------+
  | External IP: 192.168.2.10      |
  | NodePort: 30443                |
  |                                |
  | -> kube-proxy                  |
  |    routes traffic to:          |
  |    Pod IP: 10.244.1.10:443     |
  +--------------------------------+
  |
  v
Ingress Controller (Nginx)
  +--------------------------------+
  | Pod IP: 10.244.1.10:443        |
  |                                |
  | Host header & path rules:      |
  | - app.example.com ->           |
  |   Service: my-app-svc:8080     |
  +--------------------------------+
  |
  v
Kubernetes Service
  +--------------------------------+
  | ClusterIP: 10.100.100.100:8080 |
  |                                |
  | Routes to Target Pod:          |
  | Pod IP: 10.244.2.5:8080        |
  +--------------------------------+

```
