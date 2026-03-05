#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

dnf update -y
dnf install -y git docker jq

systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user || true
usermod -aG docker ssm-user || true

# Esperar docker ficar pronto
until docker info >/dev/null 2>&1; do
  echo "Aguardando docker..."
  sleep 2
done

mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.23.3/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Swap (evita OOM no build)
dd if=/dev/zero of=/swapfile bs=128M count=32
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
grep -q swapfile /etc/fstab || echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

# Deploy
cd /home/ec2-user

# Clone enxuto (sparse)
git clone --filter=blob:none --no-checkout https://github.com/RildoDias08/TestandoAws.git
cd TestandoAws

git sparse-checkout init --cone
git sparse-checkout set api docker-compose.yml db.env.example
git checkout main

# Arquivos de ambiente
cp -n api/.env.example api/.env
cp -n db.env.example db.env

