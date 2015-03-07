#!/bin/bash

# Workaround

sed -i "s/nameserver 10.0.2.3/nameserver 8.8.8.8/g" /etc/resolv.conf

# Configuration

root_db_password=secure
db_username=stikked
db_password=stikked_admin
db_name=stikked

apt-get update && apt-get dist-upgrade

# Database

debconf-set-selections <<< "mysql-server mysql-server/root_password password $root_db_password"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $root_db_password"
apt-get install -y mysql-server

sed -i "s/127.0.0.1/0.0.0.0/g" /etc/mysql/my.cnf

service mysql restart

mysql -p$root_db_password -e "CREATE DATABASE $db_name;"
mysql -p$root_db_password -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$stikked'@'localhost' IDENTIFIED BY '$db_password';"
mysql -p$root_db_password -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$stikked'@'%' IDENTIFIED BY '$db_password';"

#echo -e "$root_db_password\nn\nY\nY\n\Y\n" | mysql_secure_installation

# Web Server

apt-get install -y git  apache2 php5 libapache2-mod-php5 php5-mysql php5-ldap

git config --global url.https://.insteadof git://
git clone https://github.com/claudehohl/Stikked.git /var/www/Stikked

pushd /var/www/Stikked
cp htdocs/application/config/stikked.php.dist htdocs/application/config/stikked.php
sed -i "s/\$config\['db_username'\] = 'stikked';/\$config\['db_username'\] = '$db_username';/g" htdocs/application/config/stikked.php
sed -i "s/\$config\['db_password'\] = 'stikked';/\$config\['db_password'\] = '$db_password';/g" htdocs/application/config/stikked.php
sed -i "s/\$config\['enable_captcha'\] = true;/\$config\['enable_captcha'\] = false;/g" htdocs/application/config/stikked.php

rm /etc/apache2/sites-available/*
rm /etc/apache2/sites-enabled/*

cat <<EOL > /etc/apache2/sites-enabled/stikked.conf
<VirtualHost *:80>
    ServerName stikked-server
    DocumentRoot /var/www/Stikked/htdocs
    ErrorLog /var/log/apache2/stikked-error_log
    CustomLog /var/log/apache2/stikked-access_log common
    <Directory "/var/www/Stikked/htdocs">
        Options +FollowSymLinks
        AllowOverride All
        Order allow,deny
        Allow from all
    </Directory>
</VirtualHost>
EOL

popd

a2enmod php5 rewrite
a2ensite stikked
service apache2 restart
