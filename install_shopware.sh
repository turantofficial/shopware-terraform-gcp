#!/bin/bash
set -e

LOGFILE="/var/log/startup-script.log"
exec > >(tee -a ${LOGFILE} | logger -t startup-script) 2>&1
echo "=== Startup script started at $(date) ==="

# Get DB password securely from Secret Manager
DB_PASSWORD=$(gcloud secrets versions access latest --secret="shopware-db-password" --quiet)

echo "Installing Shopware environment..."
sleep 5
apt update && apt upgrade -y
apt install -y nginx mariadb-server mariadb-client php8.2 php8.2-fpm php8.2-cli \
php8.2-mysql php8.2-zip php8.2-intl php8.2-gd php8.2-curl php8.2-xml \
php8.2-mbstring php8.2-bcmath composer unzip ssl-cert google-cloud-cli

systemctl enable mariadb
systemctl start mariadb

mysql -e "CREATE DATABASE IF NOT EXISTS shopware6;"
mysql -e "CREATE USER IF NOT EXISTS 'sw_user'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
mysql -e "GRANT ALL PRIVILEGES ON shopware6.* TO 'sw_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

mkdir -p /var/www/shopware6
cd /var/www/shopware6
export COMPOSER_ALLOW_SUPERUSER=1
export COMPOSER_HOME=/root/.composer

composer create-project shopware/production . --no-interaction --prefer-dist

EXTERNAL_IP=$(curl -s ifconfig.me)
sed -i "s|APP_URL=.*|APP_URL=http://${EXTERNAL_IP}|" .env
sed -i "s|DATABASE_URL=.*|DATABASE_URL=\"mysql://sw_user:${DB_PASSWORD}@127.0.0.1:3306/shopware6\"|" .env

chown -R www-data:www-data /var/www/shopware6

sudo -u www-data php bin/console system:install --create-database --basic-setup
sudo -u www-data php bin/console secrets:generate-keys
sudo -u www-data php bin/console system:configure-shop --no-interaction


cat >/etc/nginx/sites-available/shopware <<'NGINX'
server {
    listen 80;
    server_name _;
    root /var/www/shopware6/public;
    index index.php;

    location / {
        try_files $uri /index.php$is_args$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/shopware /etc/nginx/sites-enabled/shopware
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx
systemctl enable nginx php8.2-fpm mariadb

echo "=== Shopware installation complete at $(date) ==="
