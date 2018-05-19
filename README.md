# Description

This Docker image helps you validate your domain with Let's Encrypt, so you can create FREE certificates for your domains.

You need to create domain categories under /domains/ directory. Each category is a file containing your domains and the name of the created certificate will be the same as the name of category.

Example:

**/domains/mydomain.tld**

```text
mydomain.tld
sub1.mydomain.tld
sub2.mydomain.tld
```

It will be converted to the following command:

```bash
certbot certonly \
      --expand \
      --email ${LE_EMAIL} \
      --non-interactive \
      --agree-tos \
      --standalone \
      --preferred-challenges http-01 \
      --http-01-port 9080 \
      --cert-name mydomain.tld \
      -d mydomain.tld -d sub1.mydomain.tld -d sub2.mydomain.tld
```

You always need to bind mount /etc/letsencrypt or define it as a volume

## Without running web server

To create categories, you can mount the directory from the host:

```bash
docker run --rm -it \
    -e LE_EMAIL=youremail@domain.tld \
    -v `pwd`/domains:/domains \
    -v /etc/letsencrypt:/etc/letsencrypt \
    -p 80:9080 \
    itsziget/letsencrypt-http 
```

If you want to create or renew only certain certificates, you can add the name of them at the end of the command:

```bash
docker run --rm -it \
    -e LE_EMAIL=youremail@domain.tld \
    -v `pwd`/domains:/domains \
    -v /etc/letsencrypt:/etc/letsencrypt \
    -p 80:9080 \
    itsziget/letsencrypt-http \
    "mydomain.tld myotherdomain.tld"
```

Make sure the name of the categories are enclosed in quotes!

## With running web server

Note that the commands above work only if you do not have running service on port 80.
Your web server probably listen on this port so you need to set a reverse proxy in front of the web server
and map all requests for "/.well-known/acme-challenge" to the Let's Encrypt container.

You can also reuse the loopback interface of the proxy container so the proxy can use 127.0.0.1 as target address.

In case of NGINX:

```
location /.well-known/acme-challenge {
    proxy_pass http://127.0.0.1:9080;
}
```

If the name of the NGINX container is "nginx-proxy", run Let's Encrypt:

```bash
docker run --rm -it \
    -e LE_EMAIL=youremail@domain.tld \
    -v `pwd`/domains:/domains \
    -v /etc/letsencrypt:/etc/letsencrypt \
    --network "container:nginx-proxy"
    itsziget/letsencrypt-http
```

## Environment variables

This image provides a very basic solution to make a little easier to define multiple certificates with multiple domains.
You can find more advanced solutions on Docker Hub.
However, if you find this image easier for your needs you can customize it by setting environment variables.

There are boolean variables that accept some certain case insensitive values:

* **FALSE**: 0, n, no, false
* **TRUE**: 1, y, yes, true

Variables:

* **LE_EMAIL:** It is the only required variable. Let's Encrypt will send notifications to this address.
* **LE_HTTP_PORT:** 9080 by default. Let's Encrypt client will listen on this port. The server will use port 80 so you need to forward it from your host to the container's port 9080. If you want to use host network, you can change the port to 80. 
* **LE_STAGING:** Boolean or string. "false" by default. If you set it to "true", option "--staging" will be added so you will get invalid test certificate. If you have multiple certificates and only some of them should be test, list the names of them here separated by space. Ex.: "test1 test2" 
* **LE_DRY_RUN:** Boolean. "false" by default. If you set it to "true", option "--dry-run" will be added so certificates will not actually saved.
* **LE_EXTRA_OPTIONS:** "" by default. You can set any additional option you need like "--break-my-certs".
* **LE_SHOW_COMMAND:** Boolean. "false" by default. You may want to see what is the actual command run inside the container instead of variables. If you set the variable to "true" the command will be shown before it runs.

## Automate the process

You can schedule the commands with CRON to automate the process of renewing certificates.
Before you do this, make sure Let's Encrypt container is reachable from outside on port 80 and each domain set to your server.
Even if certificates are generated successfully, you need to reload configurations of NGINX, Apache HTTPD or any server which uses the certificates.

In case of Docker containers the following command should work:

```bash
docker kill -s HUP containername
``` 
You can run it manually by cron:

Example:

```bash
docker run --rm -it \
    -e LE_EMAIL=youremail@domain.tld \
    -v `pwd`/domains:/domains \
    -v /etc/letsencrypt:/etc/letsencrypt \
    --network "container:nginx-proxy"
    itsziget/letsencrypt-http \
  && docker kill -s nginx-proxy
```

**Tip:** You can use [itsziget/docron](https://hub.docker.com/r/itsziget/docron/) to run Let's Encrypt periodically or [itsziget/ssmtp-mailer](https://hub.docker.com/r/itsziget/ssmtp-mailer/) to be notified after the success of renewing certificates. 

Here is a complete Docker Compose example using both of them:

```yaml
version: '2'

services:
  certbot:
    image: 'itsziget/letsencrypt-http'
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt
      - ./domains:/domains
    network_mode: container:nginx-proxy
    environment:
      LE_EMAIL: ${LE_EMAIL}
    labels:
      itsziget.docron-gen.start.schedule: "0 20 1 * *"
      itsziget.docron-gen.start.pipeline: |
        docker run -i \
          -e SMTP_HOST="smtp.host:587" \
          -e SMTP_USER="smtp@user" \
          -e SMTP_PASS="password" \
          -e TO="notify@me" \
          -e FROM_EMAIL="be@the.sender" \
          -e FROM_NAME="I am The Sender" \
          -e SUBJECT="Let's Encrypt" \
          --rm itsziget/ssmtp-mailer \
        && docker kill -s HUP nginx-proxy
```

Do not forget about the NGINX path mapping:

```
location /.well-known/acme-challenge {
    proxy_pass http://127.0.0.1:9080;
}
```

And run the following command:

```bash
docker-compose up
```

Of course it will stop after the command run, but because of the used labels the running cron container will start it again periodically until you remove the Let's Encrypt container.
