#!/bin/bash
########################################################################
#Install  xl2tpd
########################################################################
#
#
clear
export LANG=zh_CN.GB18030
echo ""
echo "#################################################################"
echo "#             CentOS  xl2tpd Installer                #"
echo "#################################################################"
echo "visit bbs.guaidaoniao.net"
echo ""
sleep 2

if [ ! -e "/etc/redhat-release" ]; then
echo "You need to have CentOS system!"
exit 0
fi

IP=`ifconfig eth0 | grep "inet addr" | cut -f 2 -d ":" | cut -f 1 -d " "`

yum install -y ppp bison gmp-devel flex gcc make libpcap-devel perl openswan

cd /etc
mkdir xl2tpd
cd xl2tpd
wget  https://download.openswan.org/xl2tpd/xl2tpd-1.3.1.tar.gz --no-check-certificate
tar -zxvf xl2tpd-1.3.1.tar.gz
cd xl2tpd-1.3.1
make install
mkdir /var/run/xl2tpd
ln -s /usr/local/sbin/l2tp-control /var/run/xl2tpd/l2tp-control

cat >> /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
listen-addr = ${IP}
ipsec saref = yes
[lns default]
ip range = 192.168.100.2-192.168.100.200
local ip = 192.168.100.1
require chap = yes
refuse pap = yes
require authentication = yes
ppp debug = yes
pppoptfile = /etc/ppp/options
length bit = yes
EOF


mv /etc/ppp/options.xl2tpd /etc/ppp/options.xl2tpd.bankup
cat  >> /etc/ppp/options.xl2tpd << EOF
require-mschap-v2
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
ms-dns 8.8.4.4
asyncmap 0
auth
crtscts
nodefaultroute
hide-password
debug
modem
lock
proxyarp
name l2tpd
lcp-echo-interval 30
lcp-echo-failure 4
EOF


read -p "Enter a VPN name:"  user_name
read -p "Enter a VPN password:"  user_password
mv /etc/ppp/chap-secrets /etc/ppp/chap-secrets.bankup
echo  "${user_name} * ${user_password} *" > /etc/ppp/chap-secrets

read -p "Enter a Shared KEY :"  shared_key

mv /etc/ipsec.secrets /etc/ipsec.secrets.bankup
echo "${IP} %any: PSK '${shared_key}' " > /etc/ipsec.secrets

mv /etc/ipsec.conf /etc/ipsec.conf.bankup
cat >> /etc/ipsec.conf << EOF
config setup
    nat_traversal=yes
    #virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12
    oe=on
    interfaces=%defaultroute
    protostack=netkey
    #protostack=mast

conn L2TP-PSK-NAT
    rightsubnet=192.168.100.0/24
    ike=aes128-sha1-modp1024
    esp=3des-sha1-96
    leftnexthop=${IP}

conn L2TP-PSK-noNAT
    authby=secret
    pfs=no
    auto=add
    ike=3des-md5;modp1024,aes-sha1;modp1536
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=${IP}
    leftprotoport=17/%any
    right=%any
    rightid=%any
    rightprotoport=17/%any
    overlapip=yes
    #sareftrack=yes
    #dpddelay=5
    #dpdtimeout=5
    #dpdaction=clear
EOF

sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
sysctl -p

for each in /proc/sys/net/ipv4/conf/*
do
echo 0 > $each/accept_redirects
echo 0 > $each/send_redirects
done

iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -j SNAT --to-source ${IP }
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -A INPUT -p udp --dport 1701 -j ACCEPT
iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
iptables -A INPUT -p tcp --dport 1723 -j ACCEPT
iptables -A INPUT -p udp --dport 1723 -j ACCEPT
service iptables save
service iptables restart

service ipsec restart
xl2tpd
ipsec verify

sed -i '/^exit/d' /etc/rc.local

cat >> /etc/rc.local << EOF
for each in /proc/sys/net/ipv4/conf/*
do
echo 0 > $each/accept_redirects
echo 0 > $each/send_redirects
done
xl2tpd
exit 0
EOF

clear

echo "#############################"
echo "#      安装成功！        #"
echo "#############################"
echo "支持 Android、Windows、Linux、IOS(Supported Systems)"
echo "用户名：${user_name} 密码： ${user_password}; 共享密钥：${shared_key}"
echo "查看运行的错误信息 tail -f /var/log/secure;或者ipsec verify"
echo "tail -f /var/log/messages"
echo "service ipsec restart; ipsec 重新启动；xl2tpd -D 查看错误日志"
read -p "Press ENTER."

