#! /bin/bash

a2enmod rewrite
cat > /etc/apache2/sites-available/plinth <<END
<VirtualHost *:8001>
        ServerAdmin webmaster@localhost

        <Location />
                ProxyPass http://127.0.0.1:8000/
        </Location>

        ErrorLog ${APACHE_LOG_DIR}/error.log

        # Possible values include: debug, info, notice, warn, error, crit,
        # alert, emerg.
        LogLevel warn

        CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
END
ln -s /etc/apache2/sites-available/plinth /etc/apache2/sites-enabled/plinth
cat > /etc/apache2/freedombox-ports.conf <<END
Listen 0.0.0.0:8001
END
if [ -z "`grep 'freedombox-ports.conf' /etc/apache2/ports.conf`" ];then
    cat >> /etc/apache2/ports.conf <<END
Include freedombox-ports.conf
END
fi
service apache2 restart

apt-get update
cd /home/fbx/plinth
make
./start.sh
cd /home/fbx
