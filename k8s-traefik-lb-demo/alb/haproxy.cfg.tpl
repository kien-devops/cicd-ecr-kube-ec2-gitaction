global
    log stdout format raw local0
    maxconn 4096
    master-worker

defaults
    log global
    timeout connect 5s
    timeout client 50s
    timeout server 50s

frontend http_front
    bind *:80
    mode http
    option httplog
    option forwardfor
    # Redirect all HTTP traffic to HTTPS
    http-request redirect scheme https code 301 if !{ ssl_fc }
    default_backend traefik_nodes_http

frontend https_front
    bind *:443 ssl crt /usr/local/etc/haproxy/certs/benhvien.teamdevops.shop.pem
    mode http
    option httplog
    option forwardfor
    http-request set-header X-Forwarded-Proto https
    http-request set-header X-Forwarded-Port 443
    http-request set-header X-Forwarded-Host %[req.hdr(Host)]
    http-request set-header X-Real-IP %[src]
    default_backend traefik_nodes_http

backend traefik_nodes_http
    mode http
    balance roundrobin
    option tcp-check
${HAPROXY_HTTP_BACKEND_SERVERS}
