# HAProxy Edge Load Balancer

This folder runs the public HAProxy load balancer in front of the Kubernetes cluster.

HAProxy receives public traffic for `benhvien.teamdevops.shop`, terminates HTTPS, then forwards HTTP traffic to Traefik NodePort `30080` on worker nodes.

## Flow

```text
Route 53
  -> HAProxy EC2 public IP
  -> port 80 redirects to 443
  -> port 443 terminates TLS
  -> worker nodes on NodePort 30080
  -> Traefik Gateway API
  -> frontend or backend service
```

## Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | Runs HAProxy container. |
| `discover-traefik-nodes.sh` | Discovers worker nodes with Traefik pods and renders `haproxy.cfg`. |
| `reload-haproxy.sh` | Regenerates config and gracefully reloads HAProxy. |
| `haproxy.cfg.tpl` | HAProxy template. |
| `.env.example` | Example runtime config. |
| `certs/` | Local certificate PEM files. Do not commit real private keys. |

## DNS and Security Group

Route 53:

```text
benhvien.teamdevops.shop -> <HAProxy_EC2_PUBLIC_IP>
```

The HAProxy EC2 security group must allow:

```text
TCP 80  from 0.0.0.0/0
TCP 443 from 0.0.0.0/0
```

Worker nodes must allow HAProxy to reach NodePort `30080`.

## Create TLS Certificate

Stop HAProxy before using Certbot standalone:

```bash
cd ~/cicd-ecr-kube-ec2-gitaction/k8s-traefik-lb-demo/alb
sudo docker-compose stop haproxy
```

Install and run Certbot:

```bash
sudo apt update
sudo apt install -y certbot
sudo certbot certonly --standalone -d benhvien.teamdevops.shop
```

Create the PEM file HAProxy expects:

```bash
sudo mkdir -p certs
sudo cat /etc/letsencrypt/live/benhvien.teamdevops.shop/fullchain.pem \
         /etc/letsencrypt/live/benhvien.teamdevops.shop/privkey.pem \
  | sudo tee ./certs/benhvien.teamdevops.shop.pem > /dev/null
sudo chmod 644 ./certs/benhvien.teamdevops.shop.pem
```

## Configure

```bash
cp .env.example .env
```

Important values:

```env
ALB_DOMAIN="benhvien.teamdevops.shop"
KUBE_NODE_ADDRESS_TYPE="InternalIP"
TRAEFIK_HTTP_NODEPORT=30080
```

The discovery scripts need working `kubectl` access.

## Start or Reload

Generate config and start:

```bash
bash discover-traefik-nodes.sh
sudo docker-compose up -d --force-recreate
```

Reload after worker nodes change:

```bash
bash reload-haproxy.sh
```

## Verify

```bash
curl -I http://benhvien.teamdevops.shop
curl -IL --max-redirs 5 https://benhvien.teamdevops.shop
curl -i https://benhvien.teamdevops.shop/api/User/test
sudo docker-compose logs -f haproxy
```

Only HAProxy should redirect HTTP to HTTPS. Traefik should stay HTTP-only behind HAProxy.
