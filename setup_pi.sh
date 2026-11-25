#!/usr/bin/env bash
# TaruTek Observability View: Raspberry Pi setup
# Run from the folder that holds index.html (and sw.js, manifest.webmanifest, icons/ if you have them):
#   sudo bash setup_pi.sh
set -euo pipefail

PI_IP=$(hostname -I | awk '{print $1}')
PI_NAME=$(hostname)
echo "== TaruTek setup on ${PI_NAME} (${PI_IP})"

echo "== 1/5 Installing nginx and openssl"
apt-get update -y
apt-get install -y nginx openssl

echo "== 2/5 Copying the web files to /var/www/tarutek"
mkdir -p /var/www/tarutek
cp -f index.html /var/www/tarutek/
for f in sw.js manifest.webmanifest; do [ -f "$f" ] && cp -f "$f" /var/www/tarutek/ || true; done
[ -d icons ] && cp -rf icons /var/www/tarutek/ || true
chown -R www-data:www-data /var/www/tarutek
chmod -R a+rX /var/www/tarutek

echo "== 3/5 Making an https certificate for ${PI_IP} and ${PI_NAME}.local"
mkdir -p /etc/nginx/ssl
if [ ! -f /etc/nginx/ssl/tarutek.crt ]; then
  openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/tarutek.key -out /etc/nginx/ssl/tarutek.crt \
    -subj "/CN=${PI_NAME}.local" \
    -addext "subjectAltName=IP:${PI_IP},DNS:${PI_NAME}.local,DNS:${PI_NAME}"
  chmod 600 /etc/nginx/ssl/tarutek.key
fi

echo "== 4/5 Installing the nginx site"
cp -f tarutek-nginx.conf /etc/nginx/sites-available/tarutek
ln -sf /etc/nginx/sites-available/tarutek /etc/nginx/sites-enabled/tarutek
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl reload nginx

echo "== 5/5 Checking that the Pi can reach the TaruTek server"
if curl -sk -m 15 -X POST -H 'Content-Type: application/json-rpc' \
     -d '{"jsonrpc":"2.0","method":"apiinfo.version","params":{},"id":1}' \
     https://127.0.0.1/api_jsonrpc.php | grep -q '"result"'; then
  echo "   OK: the TaruTek server answers through the Pi."
else
  echo "   WARNING: no answer from ciq.tarutek.com through the Pi. Check the Pi's internet and DNS,"
  echo "   and whether the TaruTek server only accepts certain IP addresses."
fi

echo
echo "Done. Open:  https://${PI_IP}/   or   https://${PI_NAME}.local/"
echo "The browser will warn about the certificate the first time (it is made on this Pi): choose Advanced -> Proceed."
