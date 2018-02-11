#!/bin/bash
#Program: configure-nginx-ssl.sh
#Script to Configure NginX SSL Server for TLS 
#Author: <Amal-J>	Amal Jith
#Nginx variables
upstream='$upstream'
host='$host'
remote_addr='$remote_addr'
proxy_add_x_forwarded_for='$proxy_add_x_forwarded_for'
request_uri='$request_uri'
scheme='$scheme'

#Creating the ssl directory for storing key and certificates
sudo rm -rf /etc/nginx/ssl
mkdir -p /etc/nginx/ssl

#Create directory for storing ssl Configuration Snippet
sudo rm -rf /etc/nginx/snippets
mkdir -p /etc/nginx/snippets
sudo chmod -R 662 /etc/nginx
#Creating ssl certificate/etc/ssl/private
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-subj "/C=UAE/ST=Dubai/L=Al Barsha/O=ABC/OU=www/CN=ABC Corp LLC" \
	-keyout /etc/nginx/ssl/nginx-selfsigned.key -out /etc/nginx/ssl/nginx-selfsigned.crt
#Configuration Snippet Pointing to the SSL Key and Certificate:
cat << SNIPPET_CONF | sudo tee /etc/nginx/snippets/self-signed.conf >& /dev/null
ssl_certificate /etc/nginx/ssl/nginx-selfsigned.crt;
ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;
SNIPPET_CONF


#Snippet with Strong Encryption Settings
cat << PARAM_CONF | sudo tee /etc/nginx/snippets/ssl-params.conf >& /dev/null
# from https://cipherli.st/
# and https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html

ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
ssl_ecdh_curve secp384r1;
ssl_session_cache shared:SSL:10m;
#ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
# Disable preloading HSTS for now.  You can use the commented out header line that includes
# the "preload" directive if you understand the implications.
#add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
client_max_body_size 300M;
#ssl_dhparam /etc/ssl/certs/dhparam.pem;
PARAM_CONF

#REMOVING THE EXISTING default from /etc/nginx/sites-enable
if [ -f /etc/nginx/sites-enabled/ABC_ssl ]; then
      echo "Removing /etc/nginx/sites-enabled/ABC_ssl"
      sudo rm /etc/nginx/sites-enabled/ABC_ssl
fi

#REMOVING THE EXISTING default from /etc/nginx/sites-available
if [ -f /etc/nginx/sites-available/ABC_ssl ]; then
      echo "Removing /etc/nginx/sites-available/ABC_ssl"
      sudo rm -f /etc/nginx/sites-available/ABC_ssl
fi
#The main conf file for sites-available:
cat << NGINX_CONF | sudo tee /etc/nginx/sites-available/ABC_ssl >& /dev/null
##HTTPS server

upstream backend_tomcat {
server 127.0.0.1:8080;		
}

upstream backend_node1 {
server 127.0.0.1:3000;
}


server {
listen    80;
return 301 https://$host$request_uri;
}

server {
	
    # SSL configuration
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    include snippets/self-signed.conf;
    include snippets/ssl-params.conf;
	
	proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
       
        
		location = / {
				#return 301 $scheme://$host/pulsar;
				proxy_pass http://backend_tomcat;
				#access_log /var/log/nginx/home_ac.log;
				error_log /var/log/nginx/home_er.log;
				proxy_read_timeout      90;
				proxy_redirect  http://$host:8080$request_uri https://$host;
				
		}

		location /MyApp-server {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
                #try_files  / =404;
                proxy_pass http://backend_tomcat;
				proxy_read_timeout      90;
				proxy_redirect  http://$host:8080$request_uri https://$host$request_uri;
				#access_log /var/log/nginx/MyApp_ac.log;
				error_log /var/log/nginx/MyApp_er.log;
                # Uncomment to enable naxsi on this location
                # include /etc/nginx/naxsi.rules
        }
}
NGINX_CONF

sudo ln -s /etc/nginx/sites-available/ABC_ssl /etc/nginx/sites-enabled/ABC_ssl

sudo chmod -R 511 /etc/nginx
#Test Ngix New Config file syntax:
sudo nginx -t

#Restart nginx
sudo systemctl restart nginx

echo "End of SSL Configuration"
