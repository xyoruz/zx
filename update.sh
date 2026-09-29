#!/bin/bash
REPO="https://raw.githubusercontent.com/xyoruz/zx/main"
BASE=/etc/xray-script; XCONF=/usr/local/etc/xray/config.json
[[ $EUID -ne 0 ]] && { echo "Jalankan sebagai root!"; exit 1; }
[[ ! -d $BASE ]] && { echo "Script belum terpasang. Jalankan premi.sh dulu."; exit 1; }
echo "$REPO" > $BASE/repo

wget -q -O /tmp/menu.zip "$REPO/menu.zip" || { echo "Gagal unduh menu.zip"; exit 1; }
unzip -o /tmp/menu.zip -d /usr/local/sbin/ >/dev/null
chmod +x /usr/local/sbin/*
rm -f /tmp/menu.zip

wget -q -O /usr/local/bin/ssh-ws.py "$REPO/files/ssh-ws.py" && chmod +x /usr/local/bin/ssh-ws.py
wget -q -O /etc/logrotate.d/xray-script "$REPO/config/logrotate-xray"
wget -q -O /etc/cron.d/xray-script "$REPO/config/cron-xray"
rm -f /etc/cron.d/xray-expired
[[ -f $BASE/limit ]] || echo 0 > $BASE/limit

# Aktifkan access log Xray (untuk cek user online)
mkdir -p /var/log/xray && touch /var/log/xray/access.log /var/log/xray/error.log
chown -R nobody:$(id -gn nobody) /var/log/xray
jq '.log = {"access":"/var/log/xray/access.log","error":"/var/log/xray/error.log","loglevel":"warning"}' $XCONF > /tmp/x.json && mv /tmp/x.json $XCONF

# Perbarui config nginx (halaman palsu), lalu muat ulang
wget -q -O /tmp/xray.conf "$REPO/config/xray.conf" && mv /tmp/xray.conf /etc/nginx/conf.d/xray.conf
nginx -t 2>/dev/null && systemctl reload nginx

systemctl restart ssh-ws xray
echo "Update selesai. Ketik: menu"
