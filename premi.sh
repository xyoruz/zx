#!/bin/bash
# =====================================================
#  Autoscript Xray (VMess/VLESS/Trojan WS) + SSH WS
#  OS   : Ubuntu 20.04+ / Debian 10-11
#  Port : WS 80 | TLS 443 | Enhanced WS 80 & 8080
#  Alur : HAProxy (80/8080/443) -> Nginx (127.0.0.1:8880) -> Xray / SSH-WS
# =====================================================
REPO="https://raw.githubusercontent.com/xyoruz/zx/main"

[[ $EUID -ne 0 ]] && { echo "Jalankan sebagai root!"; exit 1; }
source /etc/os-release
case "$ID" in ubuntu|debian) ;; *) echo "OS tidak didukung"; exit 1;; esac

BASE=/etc/xray-script
mkdir -p $BASE && touch $BASE/users.db

read -rp "Masukkan domain (sudah pointing ke IP VPS): " DOMAIN
[[ -z "$DOMAIN" ]] && { echo "Domain wajib diisi"; exit 1; }
echo "$DOMAIN" > $BASE/domain
echo "$REPO" > $BASE/repo
echo 0 > $BASE/limit

export DEBIAN_FRONTEND=noninteractive
apt update -y && apt install -y nginx haproxy fail2ban logrotate curl wget jq openssl socat cron python3 unzip uuid-runtime openssh-server

# ---------- Cek domain sudah pointing ke VPS ini ----------
MYIP=$(curl -s4 --max-time 10 ifconfig.me || curl -s4 --max-time 10 icanhazip.com)
DOMIP=$(getent ahostsv4 "$DOMAIN" | awk 'NR==1{print $1}')
if [[ -z "$DOMIP" || "$DOMIP" != "$MYIP" ]]; then
    echo "-----------------------------------------------"
    echo " Domain   : $DOMAIN -> ${DOMIP:-tidak ditemukan}"
    echo " IP VPS   : $MYIP"
    echo " DNS belum mengarah ke VPS ini, sertifikat SSL bisa gagal."
    echo " Buat A record ke $MYIP (Cloudflare: DNS only / awan abu-abu),"
    echo " tunggu beberapa menit, lalu jalankan ulang script."
    echo "-----------------------------------------------"
    read -rp "Tetap lanjut? (y/n): " y
    [[ "$y" != "y" ]] && exit 1
else
    echo "Domain OK ($DOMIP)"
fi

# Kosongkan port 80/8080/443 (webserver lain di-nonaktifkan)
systemctl disable --now apache2 2>/dev/null
systemctl stop nginx haproxy

# ---------- Xray ----------
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# ---------- Sertifikat ----------
curl -s https://get.acme.sh | sh -s email=admin@"$DOMAIN"
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
if ~/.acme.sh/acme.sh --issue --standalone -d "$DOMAIN" --keylength ec-256 --force && \
   ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc \
        --fullchain-file $BASE/xray.crt --key-file $BASE/xray.key \
        --reloadcmd "cat $BASE/xray.crt $BASE/xray.key > $BASE/xray.pem; systemctl restart haproxy 2>/dev/null || true"; then
    SSL_TYPE="Let's Encrypt (valid)"
    echo ">>> SSL BERHASIL: sertifikat Let's Encrypt terpasang"
else
    SSL_TYPE="Self-signed (client perlu allow insecure)"
    echo ">>> SSL GAGAL: Let's Encrypt tidak terbit, pakai self-signed."
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 -subj "/CN=$DOMAIN" \
        -keyout $BASE/xray.key -out $BASE/xray.crt
fi
chmod 644 $BASE/xray.crt $BASE/xray.key
# HAProxy butuh cert + key dalam satu file PEM
cat $BASE/xray.crt $BASE/xray.key > $BASE/xray.pem
chmod 600 $BASE/xray.pem

# ---------- Unduh config & file ----------
wget -q -O /usr/local/etc/xray/config.json "$REPO/config/config.json"
wget -q -O /etc/nginx/conf.d/xray.conf     "$REPO/config/xray.conf"
wget -q -O /etc/haproxy/haproxy.cfg        "$REPO/config/haproxy.cfg"
wget -q -O $BASE/ws.conf                   "$REPO/config/ws.conf"
wget -q -O /etc/logrotate.d/xray-script    "$REPO/config/logrotate-xray"
wget -q -O /etc/cron.d/xray-script         "$REPO/config/cron-xray"
wget -q -O /etc/systemd/system/ssh-ws.service "$REPO/config/ssh-ws.service"
wget -q -O /usr/local/bin/ssh-ws.py        "$REPO/files/ssh-ws.py"
chmod +x /usr/local/bin/ssh-ws.py
rm -f /etc/nginx/sites-enabled/default /etc/nginx/conf.d/default.conf

# ---------- Menu (zip) ----------
wget -q -O /tmp/menu.zip "$REPO/menu.zip"
unzip -o /tmp/menu.zip -d /usr/local/sbin/ >/dev/null
chmod +x /usr/local/sbin/*
rm -f /tmp/menu.zip

# ---------- Log Xray (untuk cek user online) ----------
mkdir -p /var/log/xray && touch /var/log/xray/access.log /var/log/xray/error.log
chown -R nobody:$(id -gn nobody) /var/log/xray

# ---------- BBR ----------
grep -q "tcp_congestion_control=bbr" /etc/sysctl.conf || {
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
}
sysctl -p >/dev/null 2>&1

# ---------- Shell ----------
grep -q '^/bin/false' /etc/shells || echo /bin/false >> /etc/shells

systemctl daemon-reload
systemctl enable --now ssh-ws xray nginx haproxy fail2ban cron
nginx -t && systemctl restart nginx
systemctl restart xray haproxy

echo
echo "================================================"
echo " Instalasi selesai!"
echo " Domain : $DOMAIN"
echo " SSL    : $SSL_TYPE"
echo " Berlaku: $(openssl x509 -in $BASE/xray.crt -noout -enddate | cut -d= -f2)"
echo " WS 80 | TLS 443 | Enhanced WS 80 & 8080"
echo " Ketik: menu"
echo "================================================"
