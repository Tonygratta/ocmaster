# Настройка сервера с OpenConnect

Cделано на основе [Habr-статьи](https://habr.com/ru/articles/776256/) с учётом личного опыта, запросов и уровня знаний.

Непрерывно дополняется.

Назначение данного руководства - гайд по быстрой настройке VPN для корпоративных нужд, способного надёжно функционировать в текущих непростых условиях.

В перспективе - автоматизация создания и управления сервером при помощи простого десктоп-приложения на python.

Используемый набор ПО:

- HAproxy - демультиплексор сервисов для возможности задействовать один IP для нескольких служб
- UFW - фаерволл и контроль над iptables
- ocserv - сервер VPN с поддержкой клиентов AnyConnect
- dnsmasq - сервис DNS
- letsencrypt - сертификат безопасности сайта
- dynv6.com - бесплатный сервис доменных имён
- python3 - служебное ПО

Ключевые конфигурационные файлы:

- /etc/ufw/sysctl.conf
- /etc/ufw/before.rules
- /etc/ufw/before6.rules
- /etc/ocserv/ocserv.conf
- /etc/ocserv/passwd
- /etc/dnsmasq.conf

Общий порядок установки:

- [Получаем доступ к VPS.](#vps)
- [Меняем порт SSH для доступа к серверу](#ssh-set)
- [Настраиваем доступ к серверу по ключу](#key-access)
- [Настраиваем доменное имя для публичных адресов сервера](#dns)
- [Получаем сертификат letsencrypt](#letsencrypt)
- [Устанавливаем и настраиваем UFW:](#ufw)
	- [Открываем порты 80, 443, порт SSH](#set-ports)
	- [Включаем роутинг](#set-route)
	- [Активируем NAT правкой конфиг-файлов](#set-nat)
- [Устанавливаем и настраиваем ocserv](#set-ocserv)
- [Создаём пользователей сервера](#users)
- [Настраиваем dnsmasq в качестве сервера DNS](#dnsmasq)
- [Устанавливаем и настраиваем HAproxy при необходимости](#haproxy)

<a id="vps"></a>
## Получаем доступ к VPS

Рекомендуемые ОС:
- Debian 13
- Ubuntu 24

Другие версии могут содержать несовместимую версию ocserv

Не все провайдеры предоставляют IPv6.

Недорогие зарубежные серверы с оплатой из России с высокой вероятностью попадут со временем под ковровые блокировки РКН. Поэтому для корпоративных нужд при отсутствии необходимости доступа за рубеж разумнее всего выбирать российские площадки и избегать таких хостеров как hostvds.

<a id="ssh-set"></a>
## Меняем порт SSH для доступа к серверу

Файл конфигурации `/etc/ssh/sshd_config`
- Открываем файл `sudo vim /etc/ssh/sshd_config`
- Ищем параметр `Port`
- Раскомментируем, меняем на кастомный, например `40257`
- Сохраняем `<Esc> :wq <Enter>`
- Перегружаем службу SSH сервера 
	- для версий ОС со службой sshd `sudo systemctl reload sshd`
	- для версий ОС с сокетами `systemctl daemon-reload && systemctl restart ssh.socket`

Код:
```
sed -i -E "s/^#?Port.*$/Port $SSHPORT/" /etc/ssh/sshd_config
#
systemctl is-active ssh.socket | grep -qw 'active' && systemctl daemon-reload && systemctl restart ssh.socket
#
systemctl is-active sshd.service | grep -qw 'active' && systemctl reload sshd.service
```

<a id="key-access"></a>
## Настраиваем доступ к серверу по ключу

Under construction.

<a id="dns"></a>
## Настраиваем доменное имя для публичных адресов сервера

Некоторые провайдеры предоставляют доменное имя в комплекте с публичным адресом.Другие имеют опцию в личном кабинете.
В остальных случаях можно воспользоваться одним из многих бесплатных вариантов, таких как:

- <http://hldns.ru/>
- <https://freedns.afraid.org/>
- <https://dynv6.com>

Можно также вообще не получать доменное имя и получить сертификат на IP-адрес. 
Всё же это не рекомендуется, так как накладывает ряд ограничений при эксплуатации - нельзя использовать IPv6, нельзя демультиплексировать клиентов по SNI.
<a id="letsencrypt"></a>
## Получаем сертификат letsencrypt 

Сделать это можно при помощи [certbot](https://certbot.eff.org/) или [acmesh](https://github.com/acmesh-official/acme.sh)

<a id="ufw"></a>
## Устанавливаем и настраиваем UFW

`sudo apt install ufw`

<a id="set-ports"></a>
### Открываем порты 80, 443, порт SSH

```
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp
sudo ufw allow 22/tcp
sudo ufw allow in on vpns0 to any proto udp port 53
```

<a id="set-route"></a>
### Включаем роутинг

В файле `/etc/ufw/sysctl.conf` раскомментируем строки 
```
net/ipv4/ip_forward=1
net/ipv6/conf/default/forwarding=1
net/ipv6/conf/all/forwarding=1
```

Разрешаем маршрутизацию правилом
`ufw route allow in on vpns0`

<a id="set-nat"></a>
### Активируем NAT правкой конфиг-файлов

Определимся с диапазоном IP клиентов. Например:
- IPv4 192.168.99.0/24
- IPv6 fda9:4e0a:7e3b::/48

Выясним интерфейс публичного IP, например eth0.

В конец файла `/etc/ufw/before.rules` добавим строки 
```
# OCMASTER-START
*nat
-A POSTROUTING -s 192.168.99.0/24 -o eth0 -j MASQUERADE
COMMIT
# OCMASTER-END
```

В конец файла `/etc/ufw/before6.rules` добавим строки 
```
# OCMASTER-START
*nat
-A POSTROUTING -s fda9:4e0a:7e3b::/48 -o eth0 -j MASQUERADE
COMMIT
# OCMASTER-END
```

<a id="set-ocserv"></a>
## Устанавливаем и настраиваем ocserv

`sudo apt install ocserv`

Файл конфигурации `/etc/ocserv/ocserv.conf`

Ключевые параметры:
```
auth = "plain[passwd=/etc/ocserv/passwd]"
tcp-port = 443
#udp-port = 443
run-as-user = ocserv
run-as-group = ocserv
socket-file = run/ocserv-socket
chroot-dir = /var/lib/ocserv
server-cert = /etc/letsencrypt/live/host.na.me/fullchain.pem
server-key = /etc/letsencrypt/live/host.na.me/privkey.pem
ca-cert = /etc/ssl/certs/ssl-cert-snakeoil.pem
isolate-workers = true
max-clients = 16
max-same-clients = 2
rate-limit-ms = 100
server-stats-reset-time = 604800
keepalive = 32400
dpd = 90
mobile-dpd = 1800
switch-to-tcp-timeout = 25
try-mtu-discovery = false
cert-user-oid = 0.9.2342.19200300.100.1.1
tls-priorities = "NORMAL:%SERVER_PRECEDENCE:%COMPAT:-VERS-SSL3.0:-VERS-TLS1.0:-VERS-TLS1.1:-VERS-TLS1.3"
auth-timeout = 240
min-reauth-time = 300
max-ban-score = 80
ban-reset-time = 1200
cookie-timeout = 300
deny-roaming = false
rekey-time = 172800
rekey-method = ssl
use-occtl = true
pid-file = /run/ocserv.pid
log-level = 2
device = vpns
predictable-ips = true
default-domain = example.com
ipv4-network = 192.168.99.0/24
ipv6-network = fda9:4e0a:7e3b:03ea::/48
ipv6-subnet-prefix = 128
tunnel-all-dns = true
dns = 192.168.99.1
ping-leases = false
route = default
cisco-client-compat = true
dtls-legacy = true
cisco-svc-client-compat = false
client-bypass-protocol = false
compression = false
camouflage = true
camouflage_secret = "random_sequence"
camouflage_realm = "Administrator login"
```

<a id="users"></a>
## Создаём пользователей сервера

`ocpasswd -c /etc/ocserv/passwd user99`

<a id="dnsmasq"></a>
## Настраиваем dnsmasq в качестве сервера DNS

Файл конфигурации `/etc/dnsmasq.conf`

Ключевые параметры:

```
interface=lo
interface=vpns0
```

<a id="haproxy"></a>
## Устанавливаем и настраиваем HAproxy при необходимости

`sudo apt install haproxy`

Файл конфигурации `/etc/haproxy/haproxy.cfg`

Ключевые параметры:

```
frontend main_ssl
        bind :443
        mode tcp
        tcp-request inspect-delay 5s
        tcp-request content accept if { req_ssl_hello_type 1 }

        use_backend b1 if { req.ssl_sni -m end host1.na.me/abc }
        use_backend b2 if { req.ssl_sni -m end  host2.na.me }
        use_backend b3 if { req.ssl_sni -m end host3.na.me }

        default_backend b3

backend b1
        mode tcp
        balance roundrobin
        server b1 127.0.0.1:444

backend b2
        mode tcp
        balance roundrobin
        server b2 127.0.0.1:445

backend b3
        mode tcp
        balance roundrobin
        server b3 127.0.0.1:446
```

