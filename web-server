#!/bin/bash

# Update sistem
apt update && apt upgrade -y

# Instal Apache dan PHP
apt install -y apache2 php libapache2-mod-php

# Aktifkan dan mulai layanan Apache
systemctl enable apache2
systemctl start apache2

# Buat file PHP untuk pengujian
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

# Konfirmasi instalasi
echo "Web server telah diinstal dan dapat diakses di http://localhost/info.php"
