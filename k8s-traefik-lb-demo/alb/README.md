# HAProxy Edge Load Balancer

This folder contains a small HAProxy setup that acts like an external load balancer in front of the Kubernetes worker nodes.

## Architecture

```text
Client
  -> DNS / HAProxy VPS public IP
  -> HAProxy container
  -> Kubernetes worker NodePort
  -> Traefik Gateway
  -> Frontend / Backend services
```

Example lab values:

```text
HAProxy VPS public IP: <haproxy-public-ip>
HAProxy VPS private IP: <haproxy-private-ip>

Worker 1 private IP: <worker-1-private-ip>
Worker 2 private IP: <worker-2-private-ip>

Traefik HTTP NodePort: 30080
Traefik HTTPS NodePort: 30443
```

The domain should point to the HAProxy VPS public IP:

```text
benhvien.teamdevops.shop -> <haproxy-public-ip>
```

## Files

- `docker-compose.yml`: runs the HAProxy container and publishes ports `80` and `443`.
- `.env.example`: environment variables for real domain, NodePort, and Kubernetes discovery.
- `haproxy.cfg.tpl`: HAProxy template.
- `discover-traefik-nodes.sh`: discovers Kubernetes nodes running Traefik and writes `haproxy.cfg`.
- `reload-haproxy.sh`: discovers nodes, rewrites `haproxy.cfg`, and restarts the HAProxy container if it is running.
- `haproxy.cfg`: generated HAProxy config mounted by Docker Compose.

## HAProxy Configuration

Copy the env file and set the real values:

```bash
cd ~/k8s-traefik-lb-demo/alb
cp .env.example .env
nano .env
```

Generate `haproxy.cfg` from Kubernetes discovery:

```bash
bash ./discover-traefik-nodes.sh
```

The script discovers Running Traefik pods, maps them to Kubernetes node InternalIP values, and writes backend lines like this:

```cfg
backend traefik_nodes_http
    mode http
    balance roundrobin
    option httpchk
    http-check send meth GET uri / ver HTTP/1.1 hdr Host benhvien.teamdevops.shop
    server worker1 10.0.1.11:30080 check
    server worker2 10.0.1.12:30080 check
```

Use `KUBE_NODE_ADDRESS_TYPE=InternalIP` when the HAProxy VPS is in the same private network as the cluster. Use `ExternalIP` only when HAProxy reaches workers through public addresses.

If the worker IPs change, rerun discovery and reload HAProxy:

```bash
bash ./discover-traefik-nodes.sh
docker restart haproxy-alb
```

Or run both steps with:

```bash
bash ./reload-haproxy.sh
```

## Traefik Requirement

The Traefik Service is exposed as a NodePort:

```bash
kubectl get svc -A | grep -i traefik
```

Expected output should include:

```text
80:30080/TCP,443:30443/TCP
```

If you want to run `kubectl` from the HAProxy VPS, copy the Kubernetes admin kubeconfig from the control-plane node.

On the control-plane node:

```bash
sudo cat /etc/kubernetes/admin.conf
```

Copy the full output.

On the HAProxy VPS:

```bash
mkdir -p ~/.kube
nano ~/.kube/config
chmod 600 ~/.kube/config
```

Paste the copied `admin.conf` content into `~/.kube/config`, then verify access:

```bash
kubectl get nodes -o wide
```

This step is only needed when the HAProxy VPS is used to run `kubectl`. If you run `kubectl` directly on the control-plane node, skip it.

This setup uses `externalTrafficPolicy: Local` for Traefik. With this mode, every worker used by HAProxy should run a local Traefik pod.

The Traefik controller runs as a DaemonSet, so each schedulable worker gets a local Traefik pod. When a new EC2 worker joins the cluster, Kubernetes schedules Traefik there automatically and `reload-haproxy.sh` can add that node to HAProxy.

Apply the Traefik DaemonSet:

```bash
kubectl apply -f ~/k8s-traefik-lb-demo/k8s/03-traefik-deployment.yaml
kubectl rollout restart daemonset/traefik -n traefik
kubectl rollout status daemonset/traefik -n traefik
```

Check that Traefik pods are running across workers:

```bash
kubectl get pods -n traefik -o wide
```

Expected placement:

```text
traefik-xxxxx   1/1   Running   ...   <worker-1-node-name>
traefik-yyyyy   1/1   Running   ...   <worker-2-node-name>
traefik-zzzzz   1/1   Running   ...   <worker-3-node-name>
```

## Run HAProxy

Start HAProxy:

```bash
cd ~/k8s-traefik-lb-demo/alb
bash ./discover-traefik-nodes.sh
docker-compose up -d
```

Or with Docker Compose v2:

```bash
docker compose up -d
```

Reload HAProxy after changing `haproxy.cfg`:

```bash
docker restart haproxy-alb
docker logs --tail 50 haproxy-alb
```

## Test

Test each worker NodePort from the HAProxy VPS:

```bash
curl -I http://<worker-1-private-ip>:30080
curl -I http://<worker-2-private-ip>:30080
```

Both should return:

```text
HTTP/1.1 200 OK
```

Test through HAProxy:

```bash
curl -I http://<haproxy-public-ip>
```

Or through the domain:

```bash
curl -I http://benhvien.teamdevops.shop
```

## Verify Load Balancing

Watch HAProxy logs:

```bash
docker logs -f haproxy-alb
```

Send multiple requests from another terminal:

```bash
for i in {1..20}; do curl -s -o /dev/null -w "%{http_code}\n" http://<haproxy-public-ip>; done
```

The logs should show both workers:

```text
http_front traefik_nodes_http/worker1 ... "GET / HTTP/1.1"
http_front traefik_nodes_http/worker2 ... "GET / HTTP/1.1"
```

Count requests per worker:

```bash
docker logs haproxy-alb | grep -o "traefik_nodes_http/worker[12]" | sort | uniq -c
```

Expected result should be close to balanced:

```text
10 traefik_nodes_http/worker1
10 traefik_nodes_http/worker2
```
