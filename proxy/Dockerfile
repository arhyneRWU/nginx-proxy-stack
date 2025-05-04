# syntax=docker/dockerfile:1

FROM python:3.11-alpine AS builder
RUN apk add --no-cache openssl bash \
 && pip install --no-cache-dir jinja2 pyyaml

WORKDIR /workspace
COPY scripts/ ./scripts/
COPY config/  ./config/
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/   /etc/nginx/conf.d/
COPY nginx/snippets/ /etc/nginx/snippets/

# (No build‐time generation — host’s deploy.sh does it)

FROM nginx:stable-alpine
LABEL maintainer="arhyne@rwu.edu"

COPY --from=builder /etc/nginx/nginx.conf    /etc/nginx/nginx.conf
COPY --from=builder /etc/nginx/conf.d/       /etc/nginx/conf.d/
COPY --from=builder /etc/nginx/snippets/     /etc/nginx/snippets/

# Dummy certs & vhosts will come from host mounts
EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
