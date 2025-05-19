# Cilium Ingress L2-ARP network flow

### How L2 ARP works ?
```shell
You've allocated an IP (e.g., 10.0.1.240) via a CiliumLoadBalancerIPPool
You created a CiliumL2AnnouncementPolicy for interface ens5
You deployed an Ingress with loadbalancer-mode: shared
The LB IP 10.0.1.240 is now active and working


[ External Client ]
      |
      |  1. ARP: "Who has 10.0.1.240?"
      |--------------------------------------→
      |                                (L2 broadcast on subnet)
      |
      |  2. Response from Node-1:
      |<-------------------------------------- 
      |  "It's me! MAC = aa:bb:cc:11:22:33"
      |
      |  3. TCP SYN to http://10.0.1.240:80
      |====================================→
      |
      v
┌──────────────────────────────────────────────────────────────┐
│                          Node-1 (worker)                     │
│  ens5: 10.0.1.50     (claims 10.0.1.240 via L2 ARP announce) │
│                                                              │
│  ╭────────────────────────────────────────────────────────╮  │
│  │           Cilium + Envoy (cilium-envoy pod)            │  │
│  │  - Accepts traffic to 10.0.1.240                       │  │
│  │  - Applies Ingress routing via Envoy                   │  │
│  ╰──────────────┬──────────────────────────────┬──────────╯  │
│                 |                              |             ы│
│        ┌───────▼───────┐               ┌───────▼───────┐     │
│        │ ClusterIP SVC │               │ ClusterIP SVC │     │
│        │ test-nginx    │               │ hubble-ui     │     │
│        └───────┬───────┘               └───────────────┘     │
│                |                                             │
│         +------+--------+                                    │
│         |  Pod: nginx   |   ← Cilium overlay IP (10.244.x.x) │
│         +---------------+                                    │
└──────────────────────────────────────────────────────────────┘

```

```shell
CIDR	        What it is	                            Who uses it
10.0.1.x	    VPC network (host)	                    Nodes, hostNetwork pods (e.g., apiserver)
10.244.x.x	  Overlay network by Cilium	              Workload pods (e.g., CoreDNS, apps)
100.128.x.x	  Cluster service network (ClusterIP)	    Kubernetes services (DNS, API, UI, etc.) via kube-proxy or Cilium
```
