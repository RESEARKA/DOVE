#!/bin/bash
# Load environment variables
source ./server_env.sh

# Create TEMP_FILE_CHECK directory if it doesn't exist
ssh $SERVER_USER@$SERVER_IP "sudo mkdir -p /var/www/html/TEMP_FILE_CHECK"
ssh $SERVER_USER@$SERVER_IP "sudo chmod 755 /var/www/html/TEMP_FILE_CHECK"
ssh $SERVER_USER@$SERVER_IP "sudo chown $SERVER_USER:$SERVER_USER /var/www/html/TEMP_FILE_CHECK"

# Upload key Solidity files
echo "Uploading Solidity files to temporary folder..."
scp ./contracts/token/DOVE.sol $SERVER_USER@$SERVER_IP:/var/www/html/TEMP_FILE_CHECK/
scp ./contracts/utils/FeeLibrary.sol $SERVER_USER@$SERVER_IP:/var/www/html/TEMP_FILE_CHECK/
scp ./contracts/interfaces/IDOVE.sol $SERVER_USER@$SERVER_IP:/var/www/html/TEMP_FILE_CHECK/
scp ./contracts/admin/DOVEAdmin.sol $SERVER_USER@$SERVER_IP:/var/www/html/TEMP_FILE_CHECK/

# Set up basic nginx configuration for the temp folder (if nginx is installed)
ssh $SERVER_USER@$SERVER_IP "if command -v nginx > /dev/null; then
    echo 'Setting up nginx configuration...'
    sudo bash -c 'cat > /etc/nginx/conf.d/temp_files.conf << EOF
server {
    listen 80;
    server_name \$SERVER_IP;
    
    location /TEMP_FILE_CHECK/ {
        alias /var/www/html/TEMP_FILE_CHECK/;
        autoindex on;
    }
}
EOF'
    sudo nginx -t && sudo systemctl reload nginx
    echo 'Nginx configuration applied'
fi"

echo "==================================================="
echo "Setup complete! Files available at:"
echo "http://$SERVER_IP/TEMP_FILE_CHECK/"
echo "==================================================="
