#!/bin/bash
set -e

#ipv6 비활성화
echo -e 'net.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1' | tee -a /etc/sysctl.conf
sysctl -p

timedatectl set-timezone Asia/Seoul

#초기 프로그램 설치
apt-get update
apt-get upgrade -y
apt-get install -y ca-certificates curl vim net-tools iputils-ping

#tailscale 설치
export TS_AUTHKEY="${tail_key}"
export HOSTNAME="${app_name}-vm-tower"

curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable --now tailscaled
tailscale up --authkey $TS_AUTHKEY --hostname $HOSTNAME --advertise-routes=${tail_subnet} --accept-routes --accept-dns=true

# Add Docker's official GPG key:
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo \"$${UBUNTU_CODENAME:-$${VERSION_CODENAME}}\") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update

apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

docker run --name rancher-server --privileged -d --restart=unless-stopped -p 80:80 -p 443:443 rancher/rancher

until docker logs rancher-server 2>&1 | grep -q "Bootstrap Password:"; do
  echo "Waiting for Rancher to start..."
  sleep 5
done

docker logs rancher-server 2>&1 \
  | grep "Bootstrap Password:" \
  | awk -F': ' '{print $2}' \
  | tee /home/ubuntu/rancher_init_pwd.txt > /dev/null && \

echo "${private_key}" | base64 -d > /home/ubuntu/private.key
chown ubuntu:ubuntu /home/ubuntu/private.key
chmod 600 /home/ubuntu/private.key

chown ubuntu:ubuntu /home/ubuntu/rancher_init_pwd.txt

install -o ubuntu -g ubuntu -m 644 /var/log/cloud-init-output.log /home/ubuntu/init_log.txt || true