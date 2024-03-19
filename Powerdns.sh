#!/bin/bash

exho "installing Power DNS\n\n"
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
echo "deb [arch=amd64] http://repo.powerdns.com/ubuntu focal-auth-45 main" | sudo tee /etc/apt/sources.list.d/pdns.list
echo "Package: pdns-*
Pin: origin repo.powerdns.com
Pin-Priority: 600" | sudo tee /etc/apt/preferences.d/pdns
curl https://repo.powerdns.com/FD380FBB-pub.asc | sudo apt-key add -

# Install PowerDNS
sudo apt update
sudo apt install -y pdns-server pdns-backend-sqlite3

# Start and enable PowerDNS service
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

#Copy configuration files
cp config_template.py config.py
cp apache2_pdns_admin.conf /etc/apache2/sites-available/pdns-admin.conf
cp pdns_admin_config.json.example pdns_admin_config.json

# Edit configuration files
sudo sed -i "s/CHANGEMECHANGETHIS/your_password_here/g" config.py
sudo sed -i "s/PDNS_API_URL/https:\/\/your_pdns_server\/api/g" pdns_admin_config.json
sudo sed -i "s/PDNS_API_KEY/your_pdns_api_key/g" pdns_admin_config.json
sudo sed -i "s/SECRET_KEY/your_secret_key/g" pdns_admin_config.json
# Initialize pdns-admin database

# New configs
echo "[client]
user=root
password=password_here" | sudo tee /root/.my.cnf

#add permissions required
 chmod 400 /root/.my.cnf
 
#upgrade and install pdns
sudo update install pdns-server
sudo apt install pdns-server

# Edit pdns.conf
echo "allow-axfr-ips=127.0.0.1 
config-dir=/etc/powerdns
daemon=yes
disable-axfr=no
guardian=yes
local-address=0.0.0.0
local-port=53
master=yes
slave=yes
module-dir=/usr/lib/x86_64-linux-gnu/pdns
setgid=pdns
setuid=pdns
#socket-dir=/var/run
version-string=powerdns
include-dir=/etc/powerdns/pdns.d" | sudo tee /etc/powerdns/pdns.conf

# mysql bankend configuration
echo "launch=gmysql
gmysql-host=localhost
gmysql-port=3306
gmysql-dbname=pdns
gmysql-user=pdns
gmysql-password=pdns
gmysql-dnssec=no" | sudo tee /etc/powerdns/pdns.d/pdns.local.gmysql.conf

# remove the binds
cp -pvr /etc/pdns.d /etc/pdns.d-backup-21
rm -vf /etc/pdns.d/bind.conf

# restart pdns
systemctl enable pdns
systemctl restart pdns

# configure the master
echo"
launch=
allow-axfr-ips=127.0.0.1 135.181.95.52
config-dir=/etc/powerdns
daemon=yes
disable-axfr=no
guardian=yes
local-address=0.0.0.0
local-port=53
master=yes
slave=yes
module-dir=/usr/lib/x86_64-linux-gnu/pdns
setgid=pdns
setuid=pdns
#socket-dir=/var/run
version-string=powerdns
api=yes
api-key=key_here
log-dns-queries=yes
log-timestamp=yes
loglevel=5
master=yes
primary=yes
query-logging=yes
include-dir=/etc/powerdns/pdns.d

launch=
allow-axfr-ips=127.0.0.1
config-dir=/etc/powerdns
daemon=yes
disable-axfr=no
guardian=yes
local-address=0.0.0.0
local-port=53
module-dir=/usr/lib/x86_64-linux-gnu/pdns
setgid=pdns
setuid=pdns
#socket-dir=/var/run
version-string=powerdns
api=yes
api-key=key_here
log-dns-queries=yes
log-timestamp=yes
query-logging=yes
slave=yes
slave-cycle-interval=60
superslave=yes
include-dir=/etc/powerdns/pdns.d" | sudo tee /etc/powerdns/pdns.conf

#restart the server
systemctl restart pdns

# Configure Apache2 for pdns-admin
sudo cp apache2_pdns_admin.conf /etc/apache2/sites-available/pdns-admin.conf
sudo a2ensite pdns-admin.conf

# Start pdns-admin service
sudo python3 manage.py runserver
