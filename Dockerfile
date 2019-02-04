FROM nginx:alpine

LABEL maintainer="samuel.gratzl@datavisyn.io"

# customization

RUN apk add --update bash \
  certbot \
  openssl openssl-dev ca-certificates \
  && rm -rf /var/cache/apk/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

ENV EMAIL=bot@caleydo.org

EXPOSE 80
EXPOSE 443

#copy static page
COPY landing_page /usr/share/nginx/html

# enable gzip
COPY *.conf /etc/nginx/conf.d/

# custom entry
COPY entry_point /phovea/

# change security
RUN chmod +x /phovea/entry_point.sh

ENTRYPOINT ["/phovea/entry_point.sh"]
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
