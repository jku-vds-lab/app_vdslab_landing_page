#!/usr/bin/env bash

set -euo pipefail

rm -rf /usr/share/nginx/html/apps.csv

landing_page_domain=""
app_domains="" # array[]
app_domain_counter=0

while IFS='=' read -r -d '' key value; do

  if [[ $key == PHOVEA_ENABLE_SSL_LANDING_PAGE ]] ; then
    echo "Enable SSL for landing page"
    landing_page_domain="caleydoapp.org"
  fi

  if [[ $key == PHOVEA_APPFORWARD_* ]] ; then # use APPFORWARD (without space) to avoid conflicts with the `PHOVEA_APP_*` variable
    IFS=';'; nameAndDomainAndForward=($value); unset IFS;
    echo "Adding application forward (landing page only): ${nameAndDomainAndForward[*]}"
    echo $value >> /usr/share/nginx/html/apps.csv
  fi

  if [[ $key == PHOVEA_APP_* ]] ; then
    IFS=';'; nameAndDomainAndForward=($value); unset IFS;
    echo "Adding application (landing page + SSL): ${nameAndDomainAndForward[*]}"
    echo $value >> /usr/share/nginx/html/apps.csv
    sed -e s#DOMAIN#"${nameAndDomainAndForward[1]}"#g -e s#FORWARD#"${nameAndDomainAndForward[2]}"#g /phovea/templates/caleydoapp.in.conf > /etc/nginx/conf.d/${nameAndDomainAndForward[1]}_app.conf
    cat /etc/nginx/conf.d/${nameAndDomainAndForward[1]}_app.conf
    app_domains[app_domain_counter]="${nameAndDomainAndForward[1]}.caleydoapp.org"
    app_domain_counter=`expr $app_domain_counter + 1`
  fi

  if [[ $key == PHOVEA_FORWARD_* ]] ; then
    IFS=';'; nameAndDomainAndForward=($value); unset IFS;
    echo "Adding forward: ${nameAndDomainAndForward[*]}"
    sed -e s#DOMAIN#"${nameAndDomainAndForward[1]}"#g -e s#FORWARD#"${nameAndDomainAndForward[2]}"#g /phovea/templates/forward.in.conf > /etc/nginx/conf.d/${nameAndDomainAndForward[1]}_forward.conf
    cat /etc/nginx/conf.d/${nameAndDomainAndForward[1]}_forward.conf
    # Add forwards to app_domains to get certificates:
    app_domains[app_domain_counter]="${nameAndDomainAndForward[1]}" # is a separate domain --> no caleydoapp suffix
    app_domain_counter=`expr $app_domain_counter + 1`
  fi

done < <(cat /proc/self/environ)


if [[ -z "$landing_page_domain" && -z "$app_domains" ]]; then
  echo "No domains found -> skip SSL setup"
else
  echo "Setup SSL certificates"

  # if no landing page is set use the first app_domain
  if [[ -z "$landing_page_domain" ]]; then
    landing_page_domain=${app_domains[0]}
    unset app_domains[0] # clear to avoid duplicates
  fi

  # activate the ssl_certificate for the landing page in ssl.conf
  sed -i "s/\DOMAIN/${landing_page_domain}/g" /etc/nginx/conf.d/ssl.conf

  # based on https://github.com/smashwilson/lets-nginx/blob/master/entrypoint.sh

  # Generate strong DH parameters for nginx, if they don't already exist.
  if [ ! -f /etc/ssl/dhparams.pem ]; then
    if [ -f /cache/dhparams.pem ]; then
      cp /cache/dhparams.pem /etc/ssl/dhparams.pem
    else
      openssl dhparam -out /etc/ssl/dhparams.pem 2048
      # Cache to a volume for next time?
      if [ -d /cache ]; then
        cp /etc/ssl/dhparams.pem /cache/dhparams.pem
      fi
    fi
  fi

  #create temp file storage
  mkdir -p /var/cache/nginx
  chown nginx:nginx /var/cache/nginx

  mkdir -p /var/tmp/nginx
  chown nginx:nginx /var/tmp/nginx

  echo "Landing page domain: ${landing_page_domain}"
  echo "Other domains:"
  printf '\t%s\n' "${app_domains[@]}"

  # Build the certbot command
  # domains
  command="${landing_page_domain/#/-d } ${app_domains[*]/#/-d }" # prefix with domain with `-d `
  # non-interactive: Run without ever asking for user input
  # force renewal: Renew certificate, even if there is one. Also implies --expand. Used instead of keep because I think the certificate is not always available in the container (e.g. when a new container is created).
  # standalone: certbot will run a webserver
  # email: contact info in certificate
  # agree-tos: dont ask on stdin if we agree TOS
  # Note: for testing add the --staging param
  # Also see: https://certbot.eff.org/docs/using.html#certbot-command-line-options
  echo "certbot certonly ${command} \
    --non-interactive \
    --force-renewal \
    --standalone --text \
    --email ${EMAIL} \
    --agree-tos " > /etc/nginx/lets

    echo "Running initial certificate request... "
    cat /etc/nginx/lets
  /bin/bash /etc/nginx/lets

  #Create the renewal directory (containing well-known challenges)
  mkdir -p /etc/letsencrypt/webrootauth/

  # Template a cronjob to renew certificate with the webroot authenticator
  echo "Creating a cron job to keep the certificate updated"
    cat <<EOF >/etc/periodic/weekly/renew
#!/bin/sh
# First renew certificate, then reload nginx config
certbot renew --webroot --webroot-path /etc/letsencrypt/webrootauth/ --post-hook "/usr/sbin/nginx -s reload"
EOF

  chmod +x /etc/periodic/weekly/renew

  # Kick off cron to reissue certificates as required
  # Background the process and log to stderr
  /usr/sbin/crond -f -d 8 &
fi

echo "Ready"
# Launch nginx in the foreground

cat /etc/nginx/conf.d/default.conf
set -x #echo on
exec "$@"
#nginx -g "daemon off;"
