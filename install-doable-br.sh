#!/usr/bin/env bash
set -Eeuo pipefail

die() {
  echo "ERRO: $*" >&2
  exit 1
}

[[ $EUID -eq 0 ]] || die "Execute como root."

[[ ! -e /root/doable ]] || die \
  "Este instalador é para uma VPS nova, sem /root/doable."

read -r -p "Dominio principal (ex.: tandi.tech): " DOMAIN </dev/tty
read -r -p "E-mail para o SSL: " EMAIL </dev/tty

DOMAIN="${DOMAIN,,}"

[[ "$DOMAIN" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$ ]] \
  || die "Dominio invalido."

[[ "$EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] \
  || die "E-mail invalido."

apt-get update
apt-get install -y git curl ca-certificates

SERVER_IP="$(curl -4fsS --max-time 10 https://api.ipify.org)" \
  || die "Nao foi possivel identificar o IPv4 desta VPS."

DNS_IPS="$(getent ahostsv4 "$DOMAIN" | awk '{print $1}' | sort -u)"

printf '%s\n' "$DNS_IPS" | grep -Fxq "$SERVER_IP" || die \
  "O DNS de $DOMAIN precisa apontar para o IPv4 $SERVER_IP."

echo "Baixando Doable BR do GitHub..."

git clone --depth 1 --single-branch --branch doable-br \
  https://github.com/emersonalex2026-svg/DoableBR.git \
  /root/doable

cd /root/doable

grep -q 'LETSENCRYPT=' deployment/server-setup.sh || die \
  "O instalador deste código nao possui suporte confirmado ao modo Let's Encrypt."

echo "Instalando Doable BR com HTTPS, sem Cloudflare..."

NO_TUNNEL=1 \
LETSENCRYPT=1 \
HOST="$DOMAIN" \
DOMAIN="$DOMAIN" \
EMAIL="$EMAIL" \
REPO=emersonalex2026-svg/DoableBR \
INSTALL_DIR=/root/doable \
NON_INTERACTIVE=1 \
DOABLE_NO_TMUX=1 \
bash deployment/server-setup.sh

echo
echo "Instalacao concluida. Verifique:"
systemctl status doable --no-pager
curl -fsS "https://${DOMAIN}/api/health"
echo
