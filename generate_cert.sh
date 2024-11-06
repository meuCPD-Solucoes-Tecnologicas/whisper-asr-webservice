#!/bin/bash
echo "Generating SSL certificate for IP: ${SSL_IP}"

openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout /app/server.key -out /app/server.crt \
    -days 365 -subj "/CN=${SSL_IP}"

echo "SSL certificate generated at /app/server.crt and /app/server.key"