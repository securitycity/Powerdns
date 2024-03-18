#!/bin/bash

# Update package lists
sudo apt update

# Install required packages
sudo apt install -y software-properties-common curl git unzip python3-pip apache2 libapache2-mod-wsgi-py3

# Configure Apache2 server
echo "
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName ns20.bob.com
    DocumentRoot /var/www/html/frontend

    <Directory /var/www/html/frontend>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>

    RewriteEngine On
    RewriteRule ^index\.html$ - [L]
    RewriteCond %{DOCUMENT_ROOT}%{REQUEST_FILENAME} !-f
    RewriteCond %{DOCUMENT_ROOT}%{REQUEST_FILENAME} !-d
    RewriteRule !^/api/.* /index.html [L]

    Alias /api /var/www/html/backend/public

    <Directory /var/www/html/backend/public>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>

    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^ index.php [QSA,L]
</VirtualHost>
" | sudo tee /etc/apache2/sites-available/pdns-admin.conf

# Add PowerDNS repository
sudo add-apt-repository -y universe
sudo add-apt-repository -y ppa:powerdns/stable
sudo apt update

# Install PowerDNS
sudo apt install -y pdns-server pdns-backend-sqlite3

# Start PowerDNS service
sudo systemctl start pdns

# Install MariaDB server
sudo apt install -y mariadb-server

# Secure MariaDB installation
sudo mysql_secure_installation

# Create database and user for PowerDNS
sudo mysql -u root -p <<MYSQL_SCRIPT
CREATE DATABASE pdns;
GRANT ALL ON pdns.* TO 'pdns'@'localhost' IDENTIFIED BY 'your_password_here';
FLUSH PRIVILEGES;
EXIT;
MYSQL_SCRIPT

# Install pdns-admin
sudo pip3 install pdns-admin

# Clone pdns-admin repository
git clone https://github.com/ngoduykhanh/PowerDNS-Admin.git

# Enter pdns-admin directory
cd PowerDNS-Admin

# Install required Python packages
sudo pip3 install -r requirements.txt

# Copy configuration file
cp config_template.py config.py

# Edit configuration file with your preferred editor (e.g., nano)
nano config.py
# Update database settings with the database name, user, password, and host

# Initialize pdns-admin database
sudo python3 manage.py db upgrade

# Configure Apache2 for pdns-admin
sudo cp apache2_pdns_admin.conf /etc/apache2/sites-available/pdns-admin.conf
sudo a2ensite pdns-admin.conf

# Start pdns-admin service
sudo python3 manage.py runserver
