#!/bin/bash
#shellcheck disable=SC2086
{
  : ${AUTH_CREDENTIALS:?"Error: environment variable AUTH_CREDENTIALS should be populated with a comma-separated list of user:password pairs. Example: \"admin:pa55w0rD\"."}
  : ${DATABASE_URL:?"Error: environment variable DATABASE_URL should be set to the Aptible DATABASE_URL of the Elasticsearch instance you wish to use."}
  : ${ELASTALERT_URL:?"Error: environment variable ELASTALERT_URL should be set to the Aptible ELASTALERT_URL of the Elastalert instance you wish to use. See the Enclave dashboard and create an endpoint for this app if it does not already exist. This URL should be of the form 'https://<host_name>:<port>'"}
}

# Parse auth credentials, add to a htpasswd file.
AUTH_PARSER="
create_opt = 'c'
ENV['AUTH_CREDENTIALS'].split(',').map do |creds|
  user, password = creds.split(':')
  %x(htpasswd -b#{create_opt} /etc/nginx/conf.d/kibana.htpasswd #{user} #{password})
  create_opt = ''
end"

ruby -e "$AUTH_PARSER" || {
  echo "Error creating htpasswd file from credentials '$AUTH_CREDENTIALS'"
  exit 1
}

# -r is to load a libary, -T 2 is the interpolation trim mode see `man erb` for details
erb -T 2 -r uri -r base64 ./kibana.erb > /etc/nginx/sites-enabled/kibana || {
  echo "Error creating nginx configuration from Elasticsearch url '$DATABASE_URL'"
  exit 1
}

# Run config
erb -T 2 -r uri -r base64 "/opt/kibana/config/kibana.yml.erb" > "/opt/kibana/config/kibana.yml" || {
  echo "Error creating kibana config file"
  exit 1
}

# Append Elastalert config to kibana config if lines required not already present
if ! grep -q "elastalert-kibana-plugin.serverHost:\|elastalert-kibana-plugin.serverPort:" /opt/kibana/config/kibana.yml;
then
  erb -T 2 -r uri "/opt/kibana/config/elastalert.yml.erb" >> "/opt/kibana/config/kibana.yml" || {
    echo "Error appending elastalert config to the kibana config file"
    exit 1
  }
fi

service nginx start

# Default node options to limit Kibana memory usage as per https://github.com/elastic/kibana/issues/5170
# If this is not set, Node tries to use about 1.5GB of memory before it starts actively garbage collect.
# shellcheck disable=SC2086
: ${NODE_OPTIONS:="--max-old-space-size=256"}

export NODE_OPTIONS
exec "/opt/kibana/bin/kibana"
