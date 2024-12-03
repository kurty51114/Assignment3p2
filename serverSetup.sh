#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Install required packages
echo "Installing required packages..."
pacman -Syu --noconfirm
pacman -Syu --noconfirm nginx
pacman -Syu --noconfirm ufw

# Create a system user for webgen
echo "Creating system user 'webgen'..."
if ! id "webgen" &>/dev/null; then
    sudo useradd -r -s /usr/sbin/nologin webgen
fi

# Create necessary directories
echo "Creating directory structure..."
sudo mkdir -p /var/lib/webgen/bin /var/lib/webgen/documents /var/lib/webgen/HTML
mkdir /etc/nginx/sites-available /etc/nginx/sites-enabled

# Create sample files in the documents directory
echo "Creating sample files..."
echo "Sample content for file-one" > "/var/lib/webgen/documents/file-one"
echo "Sample content for file-two" > "/var/lib/webgen/documents/file-two"

# Copy the generate_index script (assuming it's in the same directory as this script)
if [[ -f generate_index ]]; then
    echo "Copying generate_index script..."
    mv generate_index "/var/lib/webgen/bin"
else
    echo "generate_index script not found! Make sure it's in the same directory as this script."
    exit 1
fi

# Set ownership and permissions for webgen directories
echo "Setting ownership/permissions of webgen directories..."
sudo chmod +x /var/lib/webgen/bin/generate_index
sudo chown -R webgen:webgen /var/lib/webgen

# Configure Nginx
echo "Configuring Nginx..."
cat <<EOF >"/etc/nginx/nginx.conf"
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
cat <<EOF > "/etc/nginx/sites-available/webgen.conf"
server {
    listen 80;
    server_name webgen;

    root /var/lib/webgen/HTML;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /documents {
        root /var/lib/webgen;
        autoindex on;
    }
}
EOF

# Create symbolic link in sites-enabled to enable the server block
ln -s /etc/nginx/sites-available/webgen.conf /etc/nginx/sites-enabled/webgen.conf

# Restart Nginx to apply changes made to the configuration
echo "Restarting Nginx..."
systemctl enable nginx
systemctl restart nginx

# Move and enable the service and timer files (assuming they are in the same directory as this script)
echo "Setting up generate_index.service and generate_index.timer..."
if [[ -f ./generate_index.service && -f ./generate_index.timer ]]; then
    mv ./generate_index.service /etc/systemd/system/generate_index.service
    mv ./generate_index.timer /etc/systemd/system/generate_index.timer
    systemctl daemon-reload
    systemctl enable generate_index.timer
    systemctl start generate_index.timer
    systemctl start generate_index.service
else
    echo "Service or timer file not found in current directory! Ensure they are correctly uploaded."
    exit 1
fi

# UFW setup
sudo ufw allow ssh
sudo ufw allow http
sudo ufw limit ssh
sudo systemctl daemon-reload
sudo systemctl enable ufw.service
sudo ufw enable

# Verify firewall status
sudo ufw status verbose

echo "Server setup complete!" 