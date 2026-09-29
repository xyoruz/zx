# AUTOSCRIPT XRAY + SSH WEBSOCKET

Support OS: Ubuntu 20.04+ / Debian 10-11

## Install
```
apt update -y && apt upgrade -y && wget -q https://raw.githubusercontent.com/xyoruz/zx/main/premi.sh && chmod +x premi.sh && ./premi.sh
```

## Update
```
wget -q https://raw.githubusercontent.com/xyoruz/zx/main/update.sh && chmod +x update.sh && ./update.sh
```

## Info Port
```
- PORT WEBSOCKET » 80
- PORT TLS / SSL » 443
- PORT HANCED WS » 80 » 8080
```

## Alur Port (tidak bentrok)
```
80 / 8080 / 443  -> HAProxy (publik, mode tcp, TLS di 443)
127.0.0.1:8880   -> Nginx (lokal saja)
127.0.0.1:10001  -> Xray VLESS   (/vless)
127.0.0.1:10002  -> Xray VMess   (/vmess)
127.0.0.1:10003  -> Xray Trojan  (/trojan)
127.0.0.1:10015  -> SSH WS       (/ssh-ws atau /)
22               -> OpenSSH
```

## Fitur Menu
```
Menu utama : SSH / VMess / VLESS / Trojan (tambah, trial, perpanjang,
             hapus, daftar), cek user online, status, cek port, pengaturan
Pengaturan : ganti domain, perpanjang sertifikat, backup/restore akun,
             limit login SSH, firewall (ufw), BBR, auto reboot,
             hapus akun expired, restart service, update, uninstall
Otomatis   : hapus akun expired (tiap 10 menit), limit login SSH (tiap menit),
             fail2ban, BBR, rotasi log Xray
```

## Setting Cloudflare (jika pakai)
```
- SSL/TLS : FULL
- WEBSOCKET : ON
- Always Use HTTPS : OFF
```

## Struktur
```
bot/      -> (opsional) bot Telegram
config/   -> config.json, xray.conf (nginx), haproxy.cfg, ws.conf,
             ssh-ws.service, cron-xray, logrotate-xray
files/    -> ssh-ws.py
menu/     -> sumber menu (di-zip jadi menu.zip)
menu.zip  -> hasil zip folder menu/
premi.sh  -> installer
update.sh -> updater menu
```
Setelah mengubah isi `menu/`, buat ulang zip: `cd menu && zip -r ../menu.zip . && cd ..`
