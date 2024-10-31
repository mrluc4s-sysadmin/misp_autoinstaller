echo "permit nopass root" >> /etc/doas.conf

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
doas rm /usr/local/bin/gpg2
doas ln -s /usr/local/bin/gpg /usr/local/bin/gpg2

doas pkg_add -v postfix--%stable
doas /usr/local/sbin/postfix-enable

echo "echo -n ' ntpdate'" |doas tee -a /etc/rc.local
echo "/usr/local/sbin/ntpdate -b pool.ntp.org >/dev/null" |doas tee -a /etc/rc.local

doas rcctl enable xntpd
doas rcctl set xntpd flags "-p /var/run/ntpd.pid"
doas /usr/local/sbin/ntpd -p /var/run/ntpd.pid


  doas useradd -m -s /usr/local/bin/bash -G wheel,www misp

  doas usermod -G www misp


cd /root/misp_autoinstaller

doas pkg_add nginx

rm /etc/nginx/nginx.conf
cp nginx.conf /etc/nginx/

OPENSSL_C='BR'
OPENSSL_ST='State'
OPENSSL_L='Location'
OPENSSL_O='Organization'
OPENSSL_OU='Organizational Unit'
OPENSSL_CN='Common Name'
OPENSSL_EMAILADDRESS='teste@teste.com'

doas openssl req -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=$OPENSSL_C/ST=$OPENSSL_ST/L=$OPENSSL_L/O=<$OPENSSL_O/OU=$OPENSSL_OU/CN=$OPENSSL_CN/emailAddress=$OPENSSL_EMAILADDRESS" -keyout /etc/ssl/private/server.key -out /etc/ssl/server.crt


doas pkg_add -v py3-virtualenv py3-pip
doas ln -sf /usr/local/bin/pip3.9 /usr/local/bin/pip
doas ln -s /usr/local/bin/python3.9 /usr/local/bin/python
doas mkdir /usr/local/virtualenvs
doas /usr/local/bin/virtualenv /usr/local/virtualenvs/MISP

doas pkg_add -v ssdeep


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
git clone https://github.com/MISP/MISP.git /var/www/htdocs/MISP
git submodule update --progress --init --recursive

# Make git ignore filesystem permission differences for submodules
git submodule foreach --recursive git config core.filemode false

# Make git ignore filesystem permission differences
git config core.filemode false

doas pkg_add -v py3-pip libxml libxslt py3-jsonschema
doas /usr/local/virtualenvs/MISP/bin/pip install -U pip setuptools setuptools-rust

doas rm -rf python-cybox
git clone https://github.com/CybOXProject/python-cybox.git

doas rm -rf python-stix
git clone https://github.com/STIXProject/python-stix.git

doas rm -rf python-maec
git clone https://github.com/MAECProject/python-maec.git

doas rm -rf mixbox
git clone https://github.com/CybOXProject/mixbox.git

cd /var/www/htdocs/MISP/app/files/scripts/python-cybox
git config core.filemode false
doas /usr/local/virtualenvs/MISP/bin/python setup.py install

cd /var/www/htdocs/MISP/app/files/scripts/python-stix
git config core.filemode false
doas /usr/local/virtualenvs/MISP/bin/python setup.py install

cd /var/www/htdocs/MISP/app/files/scripts/python-maec
git config core.filemode false
doas /usr/local/virtualenvs/MISP/bin/python setup.py install

# Install mixbox to accommodate the new STIX dependencies:
cd /var/www/htdocs/MISP/app/files/scripts/mixbox
git config core.filemode false
doas /usr/local/virtualenvs/MISP/bin/python setup.py install

# Install PyMISP
#cd /var/www/htdocs/MISP/PyMISP
#git config --global --add safe.directory /var/www/htdocs/MISP/PyMISP
#git submodule update --init
#pip3 install poetry --break-system-packages
#poetry install -E fileobjects -E openioc -E virustotal -E docs -E pdfexport -E email

doas /usr/local/virtualenvs/MISP/bin/pip install pymisp

cd /var/www/htdocs/MISP/app/files/scripts/misp-stix
doas /usr/local/virtualenvs/MISP/bin/pip install stix2
doas /usr/local/virtualenvs/MISP/bin/python setup.py install

# Install python-magic and pydeep
doas /usr/local/virtualenvs/MISP/bin/pip install python-magic
doas /usr/local/virtualenvs/MISP/bin/pip install git+https://github.com/kbandla/pydeep.git


# CakePHP is included as a submodule of MISP and has been fetched earlier.
# Install CakeResque along with its dependencies if you intend to use the built in background jobs:
cd /var/www/htdocs/MISP/app
doas mkdir /var/www/.composer ; doas chown www:www /var/www/.composer
env HOME=/var/www php composer.phar install --no-dev

# To use the scheduler worker for scheduled tasks, do the following:
cp -f /var/www/htdocs/MISP/INSTALL/setup/config.php /var/www/htdocs/MISP/app/Plugin/CakeResque/Config/config.php

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

sh -c "mysql -u misp -p${DBPASSWORD_MISP} misp < /var/www/htdocs/MISP/INSTALL/MYSQL.sql"

# There are 4 sample configuration files in /var/www/htdocs/MISP/app/Config that need to be copied
cp /var/www/htdocs/MISP/app/Config/bootstrap.default.php /var/www/htdocs/MISP/app/Config/bootstrap.php
cp /var/www/htdocs/MISP/app/Config/database.default.php /var/www/htdocs/MISP/app/Config/database.php
cp /var/www/htdocs/MISP/app/Config/core.default.php /var/www/htdocs/MISP/app/Config/core.php
cp /var/www/htdocs/MISP/app/Config/config.default.php /var/www/htdocs/MISP/app/Config/config.php

# Configure the fields in the newly created files:
cd /root/misp_autoinstaller

cp database.php /var/www/htdocs/MISP/app/Config/

doas chown -R www:www /var/www/htdocs/MISP/app/Config
doas chmod -R 750 /var/www/htdocs/MISP/app/Config

export GPG_REAL_NAME='Autogenerated Key'
export GPG_COMMENT='WARNING: MISP AutoGenerated Key consider this Key VOID!'
export GPG_EMAIL_ADDRESS='admin@admin.test'
export GPG_KEY_LENGTH='2048'
export GPG_PASSPHRASE='Password1234'

echo "%echo Generating a default key
    Key-Type: RSA
    Key-Length: $GPG_KEY_LENGTH
    Subkey-Type: RSA
    Name-Real: $GPG_REAL_NAME
    Name-Comment: $GPG_COMMENT
    Name-Email: $GPG_EMAIL_ADDRESS
    Expire-Date: 0
    Passphrase: $GPG_PASSPHRASE
    # Do a commit here, so that we can later print "done"
    %commit
%echo done" > /tmp/gen-key-script

mkdir /var/www/htdocs/MISP/.gnupg
doas chmod 700 /var/www/htdocs/MISP/.gnupg
doas gpg2 --homedir /var/www/htdocs/MISP/.gnupg --batch --gen-key /tmp/gen-key-script
doas sh -c "gpg2 --homedir /var/www/htdocs/MISP/.gnupg --export --armor $GPG_EMAIL_ADDRESS > /var/www/htdocs/MISP/app/webroot/gpg.asc"































