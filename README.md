# LINUX SETUPS

## DEBIAN 12
### UNDUH PACKAGES DEBIAN 12
Untuk mengunduh packages dasar yang diperlukan pada debian 12, Anda hanya perlu mengetikkan ini:
#### Jika User root
```
wget -O- https://raw.githubusercontent.com/marhaendev/linux-setups/main/packages-debian-12.sh | bash
```
#### Jika User biasa (non root)
```
wget -O- https://raw.githubusercontent.com/marhaendev/linux-setups/main/packages-debian-12.sh | sudo bash
```
Untuk mengecek apakah sudah berhasil, Anda bisa mengetikkan perintah ini:
```
nano /etc/apt/sources.list
```
seharusnya, di dalamnya akan berisi packages ini:
```
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware

deb http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
```


### INSTALL WEB SERVER
Untuk instalasi web server menggunakan apache pada debian 12, Anda hanya perlu mengetikkan ini:
#### Jika User root
```
wget -O- https://github.com/marhaendev/linux-setups/blob/main/web-server.sh | bash
```
#### Jika User biasa (non root)
```
wget -O- https://github.com/marhaendev/linux-setups/blob/main/web-server.sh | sudo bash
```
Untuk mengecek apakah sudah berhasil, Anda bisa mengetikkan perintah ini:
```
systemctl status apache2
```

### INSTALL VIRTUALMIN
Untuk instalasi VIRTUALMIN menggunakan apache pada debian 12, Anda hanya perlu mengetikkan ini:
#### Jika User root
```
wget -O- https://raw.githubusercontent.com/marhaendev/linux-setups/main/webmin.sh | bash
```
#### Jika User biasa (non root)
```
wget -O- https://raw.githubusercontent.com/marhaendev/linux-setups/main/webmin.sh | sudo bash
```
Untuk mengecek apakah sudah berhasil, Anda bisa mengetikkan perintah ini:
```
systemctl status webmin
```

