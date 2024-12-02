#!/bin/bash

# Variables
WEBGEN_DIR="/var/lib/webgen"
NGINX_CONF="/etc/nginx/nginx.conf"
SERVICE_FILE="/etc/systemd/system/generate_index.service"
TIMER_FILE="/etc/systemd/system/generate_index.timer"
NGINX_CONF_AVAILABLE="/etc/nginx/sites-available/webgen"
NGINX_CONF_ENABLED="/etc/nginx/sites-enabled/webgen"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Install required packages
echo "Installing required packages..."
pacman -Syu --noconfirm nginx

# Create a system user for webgen
echo "Creating system user 'webgen'..."
if ! id "webgen" &>/dev/null; then
    sudo useradd -r -d /var/lib/webgen -s /usr/sbin/nologin webgen
fi

# Create necessary directories
echo "Creating directory structure..."
mkdir "$WEBGEN_DIR/bin"
mkdir "$WEBGEN_DIR/documents"
mkdir "$WEBGEN_DIR/HTML"

# Create sample files in the documents directory
echo "Creating sample files..."
echo "Sample content for file-one" > "$WEBGEN_DIR/documents/file-one"
echo "Sample content for file-two" > "$WEBGEN_DIR/documents/file-two"

# Copy the generate_index script (assuming it's in the same directory as this script)
if [[ -f generate_index ]]; then
    echo "Copying generate_index script..."
    cp generate_index "$WEBGEN_DIR/bin/generate_index"
    chmod +x "$WEBGEN_DIR/bin/generate_index"
else
    echo "generate_index script not found! Make sure it's in the same directory as this script."
    exit 1
fi

# Set ownership for webgen directories
echo "Setting ownership of webgen directories..."
chown -R webgen:webgen "$WEBGEN_DIR"

# Configure Nginx
echo "Configuring Nginx..."
cat <<EOF >"$NGINX_CONF"
user webgen;
worker_processes auto;
worker_cpu_affinity auto;

events {
    multi_accept on;
    worker_connections 1024;
}

http {
    charset utf-8;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    server_tokens off;
    log_not_found off;
    types_hash_max_size 4096;
    client_max_body_size 16M;

    # MIME
    include mime.types;
    default_type application/octet-stream;

    # logging to the two log files
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    # load configs for nginx (servers)
    include /etc/nginx/sites-available/*.conf;
    include /etc/nginx/sites-enabled/*;
    include sites-enabled/*;
}
EOF

# Create a server block for webgen
cat <<EOF > "$NGINX_CONF_AVAILABLE"
server {
    listen 80;
    server_name localhost;

    root $WEBGEN_DIR/HTML;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /documents {
        root $WEBGEN_DIR;
        autoindex on;
    }
}
EOF

# Create symbolic link in sites-enabled to enable the server block
ln -sf "$NGINX_CONF_AVAILABLE" "$NGINX_CONF_ENABLED"

# Restart Nginx to apply changes made to the configuration
echo "Restarting Nginx..."
systemctl enable nginx
systemctl restart nginx

# Copy and enable the service and timer files (assuming they are in the same directory as this script)
echo "Setting up generate_index.service and generate_index.timer..."
if [[ -f ./generate_index.service && -f ./generate_index.timer ]]; then
    cp ./generate_index.service "$SERVICE_FILE"
    cp ./generate_index.timer "$TIMER_FILE"
    systemctl daemon-reload
    systemctl enable generate_index.timer
    systemctl start generate_index.timer
else
    echo "Service or timer file not found in current directory! Ensure they are correctly uploaded."
    exit 1
fi

# UFW setup
sudo ufw allow ssh
sudo ufw allow http
sudo ufw limit ssh
sudo systemctl enable --now ufw.service

# Verify firewall status
sudo ufw status verbose

sudo systemctl disable --now httpd

echo "Server setup complete!"