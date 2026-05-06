global
    log stdout format raw local0
    maxconn 4096

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
    default_backend traefik_nodes_http

backend traefik_nodes_http
    mode http
    balance roundrobin
    option httpchk
    http-check send meth GET uri / ver HTTP/1.1 hdr Host ${ALB_DOMAIN}
${HAPROXY_BACKEND_SERVERS}
