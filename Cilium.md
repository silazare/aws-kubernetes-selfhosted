# Cilium network flows

```shell
CIDR	    What it is	                            Who uses it
10.0.1.x	VPC network (host)	                    Nodes, hostNetwork pods (e.g., apiserver)
10.244.x.x	Overlay network by Cilium	            Workload pods (e.g., CoreDNS, apps)
100.128.x.x	Cluster service network (ClusterIP)	    Kubernetes services (DNS, API, UI, etc.) via kube-proxy or Cilium
```

```shell
+------------------- AWS VPC (10.0.1.0/24) ---------------------+
|                                                             |
|               +------------------------------+              |
|               |    master-0 (10.0.1.194)      |              |
|               |   [hostNetwork pods]:        |              |
|               |   - kube-apiserver           |              |
|               |   - etcd                     |              |
|               |   - cilium-agent             |              |
|               |   - cilium-envoy             |              |
|               +------------------------------+              |
|                                                             |
|               +------------------------------+              |
|               |    worker-2 (10.0.1.177)      |              |
|               |                              |              |
|               |   +----------------------+   |              |
|               |   |  hubble-ui pod       |   |   Pod IP:    |
|               |   |  IP: 10.244.0.5       |<-----------------------------+
|               |   +----------------------+   |              |           |
|               |                              |              |           |
|               |   +----------------------+   |              |           |
|               |   |  coredns pod         |   |              |           |
|               |   |  IP: 10.244.0.178     |<----------------+           |
|               |   +----------------------+   |                          |
|               +------------------------------+                          |
|                                                                       |
+-----------------------------------------------------------------------+

====

+-----------------+
|  External User  |  <-- e.g., browser, curl
+-----------------+
         |
         v
+---------------------------------------------+
| LoadBalancer Service (cilium-ingress)       |
| Type: LoadBalancer                          |
| IP: 100.128.66.129                          |
| Ports: 80→30146, 443→31054                  |
+---------------------------------------------+
         |
         v
+---------------------------------------------+
| cilium-envoy (hostNetwork pod)              |
| Runs on Node: 10.0.1.x                      |
| Acts as Ingress Gateway (L7 proxy)          |
+---------------------------------------------+
         |
         v
+---------------------------------------------+
| Target Pod (e.g., hubble-ui)                |
| Pod IP: 10.244.0.5                          |
| Overlay Network via Cilium                  |
+---------------------------------------------+


                   +---------------------------+
                   | Pod: hubble-ui            |
                   | IP: 10.244.0.5            |
                   +---------------------------+
                             |
                             v
               Receives traffic from ingress

                   SERVICE NETWORK
              ClusterIP: 100.128.250.11
              (for internal access to UI)

```
