#!/bin/bash
INDEX="${node_index}"
K3S_TOKEN="${k3s_token}"
MASTER_IP="${master_ip}"
NODE_NAME="${node_name}"
EXEC="--disable traefik --token $K3S_TOKEN --node-name $NODE_NAME"

#ipv6 비활성화
echo -e 'net.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1' | tee -a /etc/sysctl.conf
sysctl -p

timedatectl set-timezone Asia/Seoul

#초기 프로그램 설치
apt-get update
apt-get upgrade -y
apt-get install -y ca-certificates curl vim net-tools iputils-ping iptables-persistent
if [ "$INDEX" -eq "0" ]; then
  echo "[*] Initializing K3s cluster on $NODE_NAME"
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--cluster-init $EXEC" sh -
else
  echo "[*] Waiting for cluster to be ready..."
  until curl -sk https://$MASTER_IP:6443/healthz >/dev/null 2>&1; do
    echo "Waiting for master API server at $MASTER_IP..."
    sleep 10
  done

  echo "[*] Joining K3s cluster from $NODE_NAME"
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--server https://$MASTER_IP:6443 $EXEC" sh -
fi

iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F
iptables-save > /etc/iptables/rules.v4

install -o ubuntu -g ubuntu -m 644 /var/log/cloud-init-output.log /home/ubuntu/init_log.txt || true