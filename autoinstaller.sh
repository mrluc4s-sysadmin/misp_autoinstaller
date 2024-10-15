doas pkg_add curl
eval "$(curl -fsSL https://raw.githubusercontent.com/MISP/MISP/2.4/docs/generic/globalVariables.md | awk '/^# <snippet-begin/,0' | grep -v \`\`\`)"

echo "exportando automake"
export AUTOMAKE_VERSION=1.16
export AUTOCONF_VERSION=2.71

echo "verificando portas"
cd /tmp
ftp https://cdn.openbsd.org/pub/OpenBSD/$(uname -r)/{ports.tar.gz,SHA256.sig}
signify -Cp /etc/signify/openbsd-$(uname -r | cut -c 1,3)-base.pub -x SHA256.sig ports.tar.gz
doas tar -x -z -f /tmp/ports.tar.gz -C /usr

echo "php-gd redimensionador de imagens"
cd /tmp
ftp https://cdn.openbsd.org/pub/OpenBSD/$(uname -r)/$(uname -m)/{xbase$(uname -r| tr -d \.).tgz,SHA256.sig}
signify -Cp /etc/signify/openbsd-$(uname -r | cut -c 1,3)-base.pub -x SHA256.sig xbase$(uname -r |tr -d \.).tgz
doas tar -xzphf /tmp/xbase$(uname -r| tr -d \.).tgz -C /
ftp https://cdn.openbsd.org/pub/OpenBSD/$(uname -r)/$(uname -m)/{xshare$(uname -r| tr -d \.).tgz,SHA256.sig}
signify -Cp /etc/signify/openbsd-$(uname -r | cut -c 1,3)-base.pub -x SHA256.sig xshare$(uname -r |tr -d \.).tgz
doas tar -xzphf /tmp/xshare$(uname -r| tr -d \.).tgz -C /

echo "autalizando sistema"
doas syspatch

echo "instalando bash e ntp"
doas pkg_add -v bash ntp

echo "instalando mariadb-server"
doas pkg_add -v mariadb-server

doas pkg_add -v curl git sqlite3 python--%3.9 redis libmagic autoconf--%2.71 automake--%1.16 libtool unzip--iconv rust nano

doas pkg_add -v gnupg--%gnupg2
doas ln -s /usr/local/bin/gpg /usr/local/bin/gpg2

doas pkg_add -v postfix--%stable
doas /usr/local/sbin/postfix-enable

echo "echo -n ' ntpdate'" |doas tee -a /etc/rc.local
echo "/usr/local/sbin/ntpdate -b pool.ntp.org >/dev/null" |doas tee -a /etc/rc.local

doas rcctl enable xntpd
doas rcctl set xntpd flags "-p /var/run/ntpd.pid"
doas /usr/local/sbin/ntpd -p /var/run/ntpd.pid

if [[ -z $(id misp 2>/dev/null) ]]; then
  doas useradd -m -s /usr/local/bin/bash -G wheel,www misp
else
  doas usermod -G www misp
fi

cd /root/misp_autoinstaller

doas cp httpd.conf /etc # adjust by hand, or copy/paste the config example below

OPENSSL_C='BR'
OPENSSL_ST='State'
OPENSSL_L='Location'
OPENSSL_O='Organization'
OPENSSL_OU='Organizational Unit'
OPENSSL_CN='Common Name'
OPENSSL_EMAILADDRESS='teste@teste.com'

doas openssl req -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=$OPENSSL_C/ST=$OPENSSL_ST/L=$OPENSSL_L/O=<$OPENSSL_O/OU=$OPENSSL_OU/CN=$OPENSSL_CN/emailAddress=$OPENSSL_EMAILADDRESS" -keyout /etc/ssl/private/server.key -out /etc/ssl/server.crt

doas rcctl restart httpd

doas httpd -n

doas /etc/rc.d/httpd -f start

doas pkg_add -v py3-virtualenv py3-pip
doas ln -sf /usr/local/bin/pip3.9 /usr/local/bin/pip
doas ln -s /usr/local/bin/python3.9 /usr/local/bin/python
doas mkdir /usr/local/virtualenvs
doas /usr/local/bin/virtualenv /usr/local/virtualenvs/MISP

doas pkg_add -v ssdeep

doas pkg_add -v apache-httpd
doas pkg_add -v fcgi-cgi fcgi

doas pkg_add -v php-mysqli--%8.3 php-pcntl--%8.3 php-pdo_mysql--%8.3 php-apache--%8.3 pecl83-redis php-gd--%8.3 php-zip--%8.3 php-bcmath--%8.3 php-intl--%8.3
#Can't find php-bcmath--%7.4

doas sed -i "s/^allow_url_fopen = Off/allow_url_fopen = On/g" /etc/php-8.3.ini

cd /etc/php-8.3
doas cp ../php-8.3.sample/* .

doas ln -s /usr/local/bin/php-8.3 /usr/local/bin/php
doas ln -s /usr/local/bin/phpize-8.3 /usr/local/bin/phpize
doas ln -s /usr/local/bin/php-config-8.3 /usr/local/bin/php-config

doas rcctl enable php83_fpm

doas sed -i "s/^;pid = run\/php-fpm.pid/pid = \/var\/www\/run\/php-fpm.pid/g" /etc/php-fpm.conf
doas sed -i "s/^;error_log = log\/php-fpm.log/error_log = \/var\/www\/logs\/php-fpm.log/g" /etc/php-fpm.conf
doas mkdir -p /etc/php-fpm.d

echo ";;;;;;;;;;;;;;;;;;;;
; Pool Definitions ;
;;;;;;;;;;;;;;;;;;;;

[www]
user = www
group = www
listen = /var/www/run/php-fpm.sock
listen.owner = www
listen.group = www
listen.mode = 0660
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
chroot = /var/www" | doas tee /etc/php-fpm.d/default.conf

doas /etc/rc.d/php83_fpm start 

doas rcctl enable redis
doas /etc/rc.d/redis start

doas /usr/local/bin/mysql_install_db
doas rcctl set mysqld status on
doas rcctl set mysqld flags --bind-address=127.0.0.1
doas /etc/rc.d/mysqld start
echo "Admin (${DBUSER_ADMIN}) DB Password: ${DBPASSWORD_ADMIN}"
doas mysql_secure_installation

# Download MISP using git in the /usr/local/www/ directory.
doas mkdir /var/www/htdocs/MISP
doas chown www:www /var/www/htdocs/MISP
cd /var/www/htdocs/MISP
false; while [[ $? -ne 0 ]]; do ${SUDO_WWW} git clone https://github.com/MISP/MISP.git /var/www/htdocs/MISP; done
false; while [[ $? -ne 0 ]]; do ${SUDO_WWW} git submodule update --progress --init --recursive; done

# Make git ignore filesystem permission differences for submodules
${SUDO_WWW} git submodule foreach --recursive git config core.filemode false

# Make git ignore filesystem permission differences
${SUDO_WWW} git config core.filemode false

doas pkg_add -v py3-pip libxml libxslt py3-jsonschema
doas /usr/local/virtualenvs/MISP/bin/pip install -U pip setuptools setuptools-rust

doas rm -rf python-cybox
false; while [[ $? -ne 0 ]]; do ${SUDO_WWW} git clone https://github.com/CybOXProject/python-cybox.git; done

doas rm -rf python-stix
false; while [[ $? -ne 0 ]]; do ${SUDO_WWW} git clone https://github.com/STIXProject/python-stix.git; done

doas rm -rf python-maec
false; while [[ $? -ne 0 ]]; do ${SUDO_WWW} git clone https://github.com/MAECProject/python-maec.git; done

doas rm -rf mixbox
false; while [[ $? -ne 0 ]]; do ${SUDO_WWW} git clone https://github.com/CybOXProject/mixbox.git; done

cd /var/www/htdocs/MISP/app/files/scripts/python-cybox
$SUDO_WWW git config core.filemode false
doas /usr/local/virtualenvs/MISP/bin/python setup.py install

cd /var/www/htdocs/MISP/app/files/scripts/python-stix
$SUDO_WWW git config core.filemode false
doas /usr/local/virtualenvs/MISP/bin/python setup.py install

cd /var/www/htdocs/MISP/app/files/scripts/python-maec
$SUDO_WWW git config core.filemode false
doas /usr/local/virtualenvs/MISP/bin/python setup.py install

# Install mixbox to accommodate the new STIX dependencies:
cd /var/www/htdocs/MISP/app/files/scripts/mixbox
$SUDO_WWW git config core.filemode false
doas /usr/local/virtualenvs/MISP/bin/python setup.py install

# Install PyMISP
#cd /var/www/htdocs/MISP/PyMISP
#git config --global --add safe.directory /var/www/htdocs/MISP/PyMISP
#git submodule update --init
#pip3 install poetry --break-system-packages
#poetry install -E fileobjects -E openioc -E virustotal -E docs -E pdfexport -E email

doas pip3 install pymisp --break-system-packages

cd /var/www/htdocs/MISP/app/files/scripts/misp-stix
pip3 install -r requirements.txt  --break-system-packages
pip3 install setuptools --break-system-packages
python3 setup.py install 

# Install python-magic and pydeep
doas /usr/local/virtualenvs/MISP/bin/pip install python-magic
doas /usr/local/virtualenvs/MISP/bin/pip install git+https://github.com/kbandla/pydeep.git

${SUDO_WWW} env HOME=/var/www php composer.phar install --no-dev --ignore-platform-req=ext-curl

# To use the scheduler worker for scheduled tasks, do the following:
${SUDO_WWW} cp -f /var/www/htdocs/MISP/INSTALL/setup/config.php /var/www/htdocs/MISP/app/Plugin/CakeResque/Config/config.php

# Check if the permissions are set correctly using the following commands:
doas chown -R www:www /var/www/htdocs/MISP
doas chmod -R 750 /var/www/htdocs/MISP
doas chmod -R g+ws /var/www/htdocs/MISP/app/tmp
doas chmod -R g+ws /var/www/htdocs/MISP/app/files
doas chmod -R g+ws /var/www/htdocs/MISP/app/files/scripts/tmp

mysql -u root -p <<EOF
CREATE DATABASE misp;
GRANT USAGE ON *.* TO 'misp'@'localhost' IDENTIFIED BY '${DBPASSWORD_MISP}';
GRANT ALL PRIVILEGES ON misp.* TO 'misp'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

echo "Banco de dados 'misp' criado e permissões concedidas ao usuário 'misp'."


# There are 4 sample configuration files in /var/www/htdocs/MISP/app/Config that need to be copied
${SUDO_WWW} cp /var/www/htdocs/MISP/app/Config/bootstrap.default.php /var/www/htdocs/MISP/app/Config/bootstrap.php
${SUDO_WWW} cp /var/www/htdocs/MISP/app/Config/database.default.php /var/www/htdocs/MISP/app/Config/database.php
${SUDO_WWW} cp /var/www/htdocs/MISP/app/Config/core.default.php /var/www/htdocs/MISP/app/Config/core.php
${SUDO_WWW} cp /var/www/htdocs/MISP/app/Config/config.default.php /var/www/htdocs/MISP/app/Config/config.php

# Configure the fields in the newly created files:
cd /root/misp_autoinstaller

cp database.php /var/www/htdocs/MISP/app/Config/

doas chown -R www:www /var/www/htdocs/MISP/app/Config
doas chmod -R 750 /var/www/htdocs/MISP/app/Config





































