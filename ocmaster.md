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
- /etc/ocserv/ocpasswd
- /etc/dnsmasq.conf

Общий порядок установки:

- [Получаем доступ к VPS.](#vps)
- [Меняем порт SSH для доступа к серверу](#ssh-set)
- [Настраиваем доступ к серверу по ключу](#key-access)
- [Настраиваем доменное имя для публичных адресов сервера](#dns)
- [Получаем сертификат letsencrypt при помощи certbot](#letsencrypt)
- [Устанавливаем и настраиваем UFW:](#ufw)
	- [Открываем порты 80, 443, порт SSH](#set-ports)
	- [Включаем роутинг](#set-route)
	- [Активируем NAT правкой конфиг-файлов](#set-nat)
- [Устанавливаем и настраиваем ocserv](#set-ocserv)
- [Создаём пользователей сервера](#users)
- [Настраиваем dnsmasq в качестве сервера DNS](#dnsmasq)
- [Устанавливаем и настраиваем HAproxy при необходимости](#haproxy)

## Получаем доступ к VPS
<a id="vps"></a>

Рекомендуемые ОС:
- Debian 12
- Debian 13
- Ubuntu 22
- Ubuntu 24

Не все провайдеры предоставляют IPv6.

Недорогие зарубежные серверы с оплатой из России с высокой вероятностью попадут со временем под ковровые блокировки РКН. Поэтому для корпоративных нужд при отсутствии необходимости доступа за рубеж разумнее всего выбирать российские площадки и избегать таких хостеров как hostvds.

## Меняем порт SSH для доступа к серверу
<a id="ssh-set"></a>

Файл конфигурации `/etc/ssh/sshd_config`
- Открываем файл `sudo vim /etc/ssh/sshd_config`
- Ищем параметр `Port`
- Раскомментируем, меняем на кастомный, например `40257`
- Сохраняем `<Esc> :wq <Enter>`
- Перегружаем службу SSH сервера `sudo systemctl reload sshd`

## Настраиваем доступ к серверу по ключу
<a id="key-access"></a>

Under construction.

## Настраиваем доменное имя для публичных адресов сервера
<a id="dns"></a>

Некоторые провайдеры предоставляют доменное имя в комплекте с публичным адресом. Другие имеют опцию в личном кабинете. В остальных случаях можно воспользоваться одним из многих бесплатных вариантов, таких как:

- <http://hldns.ru/>
- <https://freedns.afraid.org/>
- <https://dynv6.com>

## Получаем сертификат letsencrypt при помощи certbot
<a id="letsencrypt"></a>

Under construction.

## Устанавливаем и настраиваем UFW
<a id="ufw"></a>

`sudo apt install ufw`

### Открываем порты 80, 443, порт SSH
<a id="set-ports"></a>
```
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp
sudo ufw allow 40257/tcp
sudo ufw allow in on vpns0 to any proto udp port 53
```

### Включаем роутинг
<a id="set-route"></a>

В файле `/etc/ufw/sysctl.conf` раскомментируем строки 
```
net/ipv4/ip_forward=1
net/ipv6/conf/default/forwarding=1
net/ipv6/conf/all/forwarding=1
```

Разрешаем маршрутизацию правилом
`ufw route allow in on vpns0`

### Активируем NAT правкой конфиг-файлов
<a id="set-nat"></a>

Определимся с диапазоном IP клиентов. Например:
- IPv4 192.168.99.0/24
- IPv6 fda9:4e0a:7e3b::/48

Выясним интерфейс публичного IP, например eth0.

В конец файла `/etc/ufw/before.rules` добавим строки 
```
# Added with OC_Master <START>
*nat
-A POSTROUTING -s 192.168.99.0/24 -o eth0 -j MASQUERADE
COMMIT
# Added with OC_Master <END>
```

В конец файла `/etc/ufw/before6.rules` добавим строки 
```
# Added with OC_Master <START>
*nat
-A POSTROUTING -s fda9:4e0a:7e3b::/48 -o eth0 -j MASQUERADE
COMMIT
# Added with OC_Master <END>
```

## Устанавливаем и настраиваем ocserv
<a id="set-ocserv"></a>

`sudo apt install ocserv`

Файл конфигурации `/etc/ocserv/ocserv.conf`

Ключевые параметры:
```
auth = "plain[passwd=/etc/ocserv/ocpasswd]"
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
ipv4-network = 192.168.99.0
ipv4-netmask = 255.255.255.0
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
camouflage = true
camouflage_secret = "vsdo84"
camouflage_realm = "Administrator login"
```

## Создаём пользователей сервера
<a id="users"></a>

`ocpasswd -c /etc/ocserv/ocpasswd user99`

## Настраиваем dnsmasq в качестве сервера DNS
<a id="dnsmasq"></a>

Файл конфигурации `/etc/dnsmasq.conf`

Ключевые параметры:

```
interface=lo
interface=vpns0
```

## Устанавливаем и настраиваем HAproxy при необходимости
<a id="haproxy"></a>

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
