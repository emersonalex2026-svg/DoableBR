#!/usr/bin/env bash
set -Eeuo pipefail

die() {
  echo "ERRO: $*" >&2
  exit 1
}

[[ $EUID -eq 0 ]] || die "Execute como root."
[[ ! -e /root/doable ]] || die \
  "A pasta /root/doable já existe. Este instalador é para uma VPS limpa."

[[ -r /dev/tty ]] || die \
  "Execute em um terminal interativo."

read -r -p "Dominio principal (ex.: tandi.tech): " DOMAIN < /dev/tty
read -r -p "E-mail para o certificado SSL: " EMAIL < /dev/tty

DOMAIN="${DOMAIN,,}"

[[ "$DOMAIN" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$ ]] \
  || die "Dominio invalido."

[[ "$EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] \
  || die "E-mail invalido."

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git curl ca-certificates

DNS_IP="$(getent ahostsv4 "$DOMAIN" | awk 'NR==1 {print $1}' || true)"
SERVER_IP="$(curl -4fsS --max-time 8 https://api.ipify.org || true)"

[[ -n "$DNS_IP" ]] || die \
  "O dominio ainda nao resolve. Configure o registro DNS A primeiro."

if [[ -n "$SERVER_IP" && "$DNS_IP" != "$SERVER_IP" ]]; then
  die "O DNS de $DOMAIN aponta para $DNS_IP, mas esta VPS usa $SERVER_IP. Corrija o DNS antes de instalar."
fi

echo "Dominio: $DOMAIN"
echo "DNS IPv4: $DNS_IP"
echo
echo "Confirme que as portas TCP 80 e 443 estao liberadas."
echo "O dominio deve apontar para esta VPS para o SSL funcionar."

git clone --depth 1 --single-branch \
  --branch doable-br \
  https://github.com/1052326311/Doable.git \
  /root/doable

cd /root/doable

NO_TUNNEL=1 \
LETSENCRYPT=1 \
HOST="$DOMAIN" \
DOMAIN="$DOMAIN" \
EMAIL="$EMAIL" \
INSTALL_DIR=/root/doable \
REPO=1052326311/Doable \
NON_INTERACTIVE=1 \
DOABLE_NO_TMUX=1 \
bash deployment/server-setup.sh

echo
echo "Instalacao finalizada. Verifique o servico com:"
echo "systemctl status doable --no-pager"
