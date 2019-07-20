#!/bin/bash
GOVER="1.12.7"
CFGDIR="/etc/wireguard"
INTERFACE="venet0"

echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list 
printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable 
apt update 
apt install wireguard-tools --no-install-recommends 

cd /tmp 
wget https://dl.google.com/go/go${GOVER}.linux-amd64.tar.gz 
tar zvxf go${GOVER}.linux-amd64.tar.gz 
mv go /opt/go${GOVER} 
ln -s /opt/go${GOVER}/bin/go /usr/local/bin/go 

cd /usr/local/src 
git clone https://git.zx2c4.com/wireguard-go 
cd wireguard-go 
make 
# "Install" it 
cp wireguard-go /usr/local/bin 
mkdir -p ${CFGDIR}
cd ${CFGDIR}
umask 077  # This makes sure credentials don't leak in a race condition.
wg genkey | tee privatekey | wg pubkey > publickey

echo "net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1" > /etc/sysctl.d/wg.conf

sysctl --system
cat <<EOF > ${CFGDIR}/wg0.conf
[Interface]
PrivateKey = $(cat ${CFGDIR}/privatekey)
ListenPort = 1194
Address = 10.66.66.1/24
PostUp = iptables -t nat -A POSTROUTING -o ${INTERFACE} -j MASQUERADE; ip6tables -t nat -A POSTROUTING -o ${INTERFACE} -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o ${INTERFACE} -j MASQUERADE; ip6tables -t nat -D POSTROUTING -o ${INTERFACE} -j MASQUERADE
EOF

