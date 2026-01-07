#!/bin/bash

# halt on any error for safety and proper pipe handling
set -euo pipefail ; # <- this semicolon and comment make options apply
# even when script is corrupt by CRLF line terminators
# empty line must follow this comment for immediate fail with CRLF newlines

if (( $EUID != 0 )); then
    echo "USER IS NOT ROOT" >&2 
	exit 1
fi


# Checking if the OS version is correct
grep -q -e 'PRETTY_NAME="Ubuntu 24' -e 'PRETTY_NAME=Debian 13' /etc/os-release || \
(echo "Error: Incompatible OS version" 1>&2 && exit 1)

SSHPORT='22'
VPNIP4='192.168.75.0/24'
VPNGW4='192.168.75.1'
VPNIP6='fda9:4efe:7e3b:03ea::/48'
DNS1='208.67.222.222'
USER1=user99
PASS1="$(tr -cd '[:alnum:]' < /dev/urandom | dd bs=1 count=10 2>/dev/null || true)"
SKEY="$(tr -cd '[:alnum:]' < /dev/urandom | dd bs=1 count=10 2>/dev/null || true)"
# Автоопределение PUBINT PUBIP PUBHOST
PUBINT=$(ip route | tr -d [:cntrl:] | sed -E "s/^default via (.*) dev (.*) proto (.*) src (.*) metric .*$/\2/")
PUBIP=$(ip route | tr -d [:cntrl:] | sed -E "s/^default via (.*) dev (.*) proto (.*) src (.*) metric .*$/\4/")
#PUBHOST='abcname.local'
PUBHOST=$PUBIP



echo 'START 0.1'

arch="$(uname -m)"

ensure_deps() {
  for dep in "$@"; do
    if ! command -v "$dep" >/dev/null 2>&1 ; then
      >&2 echo "Unable to locate dependency: \"$dep\". Please install it."
      exit 1
    fi
  done
}
ensure_deps curl openssl tr sed

# Installing software
# ufw ocserv curl
apt update
apt install ufw ocserv curl -y

##############################
# Replace  default SSH port ##
##############################
# Searches 'Port' parameter then uncomments it and sets to value SSHPORT
sed -i -E "s/^#?Port.*$/Port $SSHPORT/" /etc/ssh/sshd_config
# Will be reloaded after firewall start at the end of script

#########################
# Setup ufw #############
#########################
# Set rules
ufw disable
ufw allow 443/tcp
ufw allow 80/tcp
ufw allow $SSHPORT/tcp
ufw allow in from $VPNIP4 to $VPNGW4 proto udp port 53
ufw route allow in on vpns0
#Enable routing
sed -i -e "s@#net/ipv4/ip_forward=1@net/ipv4/ip_forward=1@" /etc/ufw/sysctl.conf
sed -i -e "s@#net/ipv6/conf/default/forwarding=1@net/ipv6/conf/default/forwarding=1@" /etc/ufw/sysctl.conf
sed -i -e "s@#net/ipv6/conf/all/forwarding=1@net/ipv6/conf/all/forwarding=1@" /etc/ufw/sysctl.conf
#Enable NAT
sed -i -e '/# OCMASTER-START/,/# OCMASTER-END/d' /etc/ufw/before.rules
sed -i -e '/# OCMASTER-START/,/# OCMASTER-END/d' /etc/ufw/before6.rules
cat >> /etc/ufw/before.rules <<EOF
# OCMASTER-START
*nat
-A POSTROUTING -s $VPNIP4 -o $PUBINT -j MASQUERADE
COMMIT
# OCMASTER-END
EOF
cat >> /etc/ufw/before6.rules <<EOF
# OCMASTER-START
*nat
-A POSTROUTING -s $VPNIP6 -o $PUBINT -j MASQUERADE
COMMIT
# OCMASTER-END
EOF

#########################
# Setup ocserv ##########
#########################
# Set users
echo -e "$PASS1\n$PASS1\n" | ocpasswd -c /etc/ocserv/passwd $USER1

# Настройка ocserv
cat > ~/oc.conf.rules <<EOF
#
#------------Insert auth = "plain[passwd=/etc/ocserv/passwd]"
#
# Comments other auth parameters
s/^auth =/#auth =/
# Inserts the new 'auth =' parameter before the first commented '#auth ='
0,/^#auth =/ s@^#auth =@auth = \"plain\[passwd=/etc/ocserv/passwd\]\"\n#auth =@
# Deletes previous inserted string if any
/^#auth = \"plain\[passwd=\/etc\/ocserv\/passwd\]\"$/d
#
#------------Insert route = default
#
s/^route =/#route =/
0,/#route =/s/^#route =/route = default\n#route =/
/^#route = default/d
#
#------------Insert tcp-port = 443
#
s/^tcp-port =/#tcp-port =/
0,/#tcp-port =/s/^#tcp-port =/tcp-port = 443\n#tcp-port =/
/^#tcp-port = 443/d
#
#------------Disable udp-port
#
s/^udp-port =/#udp-port =/
#
#------------Insert server-cert = /etc/ocserv/server-fullchain.pem
#
s/^server-cert =/#server-cert =/
0,/#server-cert =/s@^#server-cert =@server-cert = /etc/ocserv/server-fullchain.pem\n#server-cert =@
/^#server-cert = \/etc\/ocserv\/server-fullchain.pem/d
#
#------------Insert server-key = /etc/ocserv/server-key.pem
#
s/^server-key =/#server-key =/
0,/#server-key =/s@^#server-key =@server-key = /etc/ocserv/server-key.pem\n#server-key =@
/^#server-key = \/etc\/ocserv\/server-key.pem/d
#
#------------Insert ipv4-network = ${VPNIP4}
#
s/^ipv4-network =/#ipv4-network =/
0,/#ipv4-network =/s@^#ipv4-network =@ipv4-network = ${VPNIP4}\n#ipv4-network =@
s@^#ipv4-network = ${VPNIP4}@@
#
#------------Disable ipv4-netmask
#
s/^ipv4-netmask =/#ipv4-netmask =/
#
#------------Insert ipv6-network = ${VPNIP6}
#
s/^ipv6-network =/#ipv6-network =/
0,/#ipv6-network =/s@^#ipv6-network =@ipv6-network = ${VPNIP6}\n#ipv6-network =@
s@^#ipv6-network = ${VPNIP6}@@
#
#------------Insert ipv6-subnet-prefix = 128
#
s/^ipv6-subnet-prefix =/#ipv6-subnet-prefix =/
0,/#ipv6-subnet-prefix =/s/^#ipv6-subnet-prefix =/ipv6-subnet-prefix = 128\n#ipv6-subnet-prefix =/
/^#ipv6-subnet-prefix = 128/d
#
#------------Insert tunnel-all-dns = true
#
s/^tunnel-all-dns =/#tunnel-all-dns =/
0,/#tunnel-all-dns =/s/^#tunnel-all-dns =/tunnel-all-dns = true\n#tunnel-all-dns =/
/^#tunnel-all-dns = true/d
#
#------------Insert dns = ${DNS1}
#
s/^dns =/#dns =/
0,/#dns =/s/^#dns =/dns = ${DNS1}\n#dns =/
/^#dns = ${DNS1}/d
#
#------------Insert compression = false
#
s/^compression =/#compression =/
0,/#compression =/s/^#compression =/compression = false\n#compression =/
/^#compression =.*$/d
#
#------------Insert cisco-client-compat = true
#
s/^cisco-client-compat =/#cisco-client-compat =/
0,/#cisco-client-compat =/s/^#cisco-client-compat =/cisco-client-compat = true\n#cisco-client-compat =/
/^#cisco-client-compat =.*$/d
#
#------------Insert camouflage = true
#
s/^camouflage =/#camouflage =/
#0,/#camouflage =/s/^#camouflage =/camouflage = true\n#camouflage =/
$ a\camouflage = true
/^#camouflage =.*$/d
#
#------------Insert camouflage_secret = "${SKEY}"
#
s/^camouflage_secret =/#camouflage_secret =/
#0,/#camouflage_secret =/s/^#camouflage_secret =/camouflage_secret = "${SKEY}"\n#camouflage_secret =/
$ a\camouflage_secret = "${SKEY}"
/^#camouflage_secret =.*$/d
#
#------------Insert camouflage_realm = "Administrator login"
#
s/^camouflage_realm =/#camouflage_realm =/
#0,/#camouflage_realm =/s/^#camouflage_realm =/camouflage_realm = "Please log in"\n#camouflage_realm =/
$ a\camouflage_realm = "Please log in"
/^#camouflage_realm =.*$/d
EOF
sed -i.ocmaster.bak -E -f ~/oc.conf.rules /etc/ocserv/ocserv.conf
rm -f ~/oc.conf.rules
#diff /etc/ocserv/ocserv.conf /etc/ocserv/ocserv.conf.ocmaster.bak
# Рестарт
systemctl restart ocserv

# !!! Сертификат
#########################
# Issue certificate #####
#########################

# Install acme.sh
# curl --no-progress-meter -Lo /usr/local/bin/acme.sh 'https://raw.githubusercontent.com/acmesh-official/acme.sh/refs/heads/master/acme.sh'
# chmod +x /usr/local/bin/acme.sh
# /usr/local/bin/acme.sh --install-cronjob || true


# # Issue certificate
# acme.sh --issue \
  # -d "$PUBHOST" \
  # --alpn \
  # --force \
  # --pre-hook "systemctl stop ocserv || true" \
  # --post-hook "[ -e /etc/ocserv/server-cert.pem -a -e /etc/ocserv/server-fullchain.pem ] && systemctl restart ocserv || true" \
  # --server letsencrypt \
  # --certificate-profile shortlived \
  # --days 3

# acme.sh --install-cert \
  # -d "$PUBHOST" \
  # --cert-file /etc/ocserv/server-cert.pem \
  # --key-file /etc/ocserv/server-key.pem \
  # --fullchain-file /etc/ocserv/server-fullchain.pem \
  # --reloadcmd "systemctl restart ocserv"

# Final message
cat <<EOF

=========================
Installation is finished!
=========================

Connect URL: https://${PUBHOST}:443/?${SKEY}

Protocol: OpenConnect
Port:     443
Host:     ${PUBHOST}
User:     ${USER1}
Proxy password: ${PASS1}

EOF

# Start ufw and then reload sshd 
# Ubuntu
systemctl is-active ssh.socket | grep -qw 'active' && \
ufw --force enable && systemctl daemon-reload && systemctl restart ssh.socket && exit 0
# Debian
systemctl is-active sshd.service | grep -qw 'active' && \
ufw --force enable && systemctl reload sshd.service && exit 0
# error
echo "SSH restart error" >&2
exit 1


# Несколько пользователей - потом
# Настройка dnsmasq - потом, а надо ли?
# Улучшить фаерволл, обработку портов на случай когда он уже стоит: исключить ситуацию когда ssh порт поменяли а в правиле нет