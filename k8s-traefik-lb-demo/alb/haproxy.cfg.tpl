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
    default_backend traefik_nodes_http

frontend https_front
    bind *:443
    mode tcp
    option tcplog
    default_backend traefik_nodes_https

backend traefik_nodes_http
    mode http
    balance roundrobin
    option httpchk
    http-check send meth GET uri / ver HTTP/1.1 hdr Host ${ALB_DOMAIN}
${HAPROXY_HTTP_BACKEND_SERVERS}

backend traefik_nodes_https
    mode tcp
    balance roundrobin
    option tcp-check
${HAPROXY_HTTPS_BACKEND_SERVERS}
