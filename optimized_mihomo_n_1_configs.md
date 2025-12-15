### 单臂路由器教程：Armbian 上部署 Mihomo 和 AdGuardHome 服务

本教程指导您在 Armbian 系统（例如基于 ARM 的设备，如 Raspberry Pi 或 Orange Pi）上设置单臂路由器，部署 Mihomo（Clash 的一个分支，用于代理）和 AdGuardHome（用于基于 DNS 的广告屏蔽和过滤）。在单臂设置中，您的设备使用单个以太网接口（例如 `eth0`）来处理传入和传出流量，作为透明代理。这意味着它可以拦截和路由流量，而无需多个网卡，使用 Mihomo 的 TProxy（透明代理）技术和 AdGuardHome 的 DNS 劫持。

设置假设：
- 您以 root 或 sudo 权限运行 Armbian（基于 Debian）。
- 您的网络配置路由器 IP 为 `10.0.0.2`，LAN 子网为 `10.0.0.0/24`（根据需要调整）。
- 设备连接在主路由器/网关和客户端设备之间（例如通过交换机或直接连接）。
- 具备基本的网络知识（IP 规则、nftables、systemd 服务）。

我们将使用提供的配置文件作为基础，安装和配置 Mihomo 用于基于 TProxy 的路由，以及 AdGuardHome 用于 DNS 解析。这将创建一个设置，其中：
- 通过 Mihomo 代理流量进行选择性路由（例如绕过地理限制或使用 VPN）。
- DNS 查询被重定向到 AdGuardHome 以进行广告屏蔽。
- nftables 处理防火墙规则、NAT 伪装和 TProxy 的 mangle。

**警告：** 此设置会修改内核参数、路由和防火墙规则。请在非生产环境中测试。继续前备份您的系统。确保您的设备至少有 1GB RAM 和稳定的以太网连接。

#### 步骤 1：更新系统并安装依赖项
更新 Armbian 系统并安装网络、防火墙和服务所需的软件包。

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y nftables iproute2 wget curl unzip git systemd sysctl
```

在启动时启用 nftables：
```bash
sudo systemctl enable nftables
```

#### 步骤 2：创建 Mihomo 用户和目录
Mihomo 以非 root 用户运行以提高安全性。创建用户和组，然后设置目录。

```bash
sudo groupadd mihomo
sudo useradd -r -g mihomo -s /bin/false mihomo
sudo mkdir -p /etc/mihomo
sudo chown -R mihomo:mihomo /etc/mihomo
```

#### 步骤 3：安装 Mihomo（Clash）
从官方 GitHub 下载 Mihomo 的最新 ARM 二进制文件（假设使用 64 位 ARMv8 架构，在 Armbian 上常见）。请检查 https://github.com/MetaCubeX/mihomo 以获取更新。

```bash
cd /tmp
wget https://github.com/MetaCubeX/mihomo/releases/download/v1.19.17/mihomo-linux-arm64-v1.19.17.gz  # 用最新版本替换
gunzip mihomo-linux-arm64-v1.19.17.gz
chmod +x mihomo-linux-arm64-v1.19.17
sudo mv mihomo-linux-arm64-v1.19.17 /usr/local/bin/mihomo
```

配置 Mihomo。在 `/etc/mihomo/config.yaml` 创建配置文件。以下是您提供的优化配置（适用于 N1 单臂路由器），已包含嗅探器、自定义 DNS 处理、地理数据库和代理提供者。请替换 `proxy-providers` 中的占位符 URL 为您的实际订阅令牌。

```yaml
# =========================
# /etc/mihomo/config.yaml
# N1 Single-Arm Router Optimized
# =========================

port: 7890
socks-port: 7891
mixed-port: 7893
allow-lan: true
log-level: info
ipv6: true
external-controller: 0.0.0.0:9090
external-ui: /etc/mihomo/ui

# Good for browser privacy
global-client-fingerprint: chrome
keep-alive-interval: 15

# Strict is okay, but 'always' is sometimes more stable on N1 Linux builds
find-process-mode: strict

profile:
  store-selected: true
  store-fake-ip: true

# TProxy port for transparent proxying (manual setup via nftables/ip rules)
tproxy-port: 7895

# Sniffer: Helps identify traffic correctly (e.g. Netflix apps)
sniffer:
  enable: true
  parse-pure-ip: true
  sniff:
    HTTP:
      ports: [80, 8080-8880]
      override-destination: true
    TLS:
      ports: [443, 8443]
      override-destination: true
    QUIC:
      ports: [443, 8443]
      override-destination: true

dns:
  enable: true
  listen: 0.0.0.0:7853
  ipv6: true
  prefer-h3: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-range-ipv6: fd00:100::/64
  respect-rules: true

  proxy-server-nameserver:
    - 223.5.5.5
    - https://dns11.quad9.net/dns-query

  # Mapping specific domains to specific DNS servers to prevent loops
  nameserver-policy:
    "dns.google": "223.5.5.5"
    "dns11.quad9.net": "223.5.5.5"
    "geosite:cn": [223.5.5.5, 119.29.29.29]

  # Default nameservers (for bootstrapping)
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
    - 2400:3200::1

  # Upstream DNS (Encrypted) - Used for non-CN domains
  nameserver:
    - https://dns.google/dns-query
    - https://dns11.quad9.net/dns-query

  # Domestic DNS - Used for CN domains (via nameserver-policy/rules)
  direct-nameserver:
    - 223.5.5.5
    - 119.29.29.29
    - 2400:3200::1

  fake-ip-filter:
    - "+.adguardteam.github.io"
    - "+.github.io"
    - "+.github.com"
    - "+.githubusercontent.com"
    - "+.raw.githubusercontent.com"
    - "+.raw.githubusercontent.com.cn"
    - "+.gitee.com"
    - "+.gitea.com"
    - "+.gitlab.com"
    - "+.gitlabusercontent.com"
    - "+.fastly.jsdelivr.net"
    - "+.jsdelivr.net"
    - "+.cloudflare.com"
    - "+.cloudflare-dns.com"
    - "+.dns.adguard.com"
    - "+.adtidy.org"
    - "+.oisd.nl"
    - "+.abpvn.com"
    - "*"
    - "+.lan"
    - "+.local"
    - "+.home"
    - "+.internal"
    - "router.asus.com"
    - "routerlogin.net"
    - "myrouter.local"
    - "+.miwifi.com"
    - "+.mijia.com"
    - "time.apple.com"
    - "captive.apple.com"
    - "rule-set:private"
    - "rule-set:cn"

geox:
  geoip:
    path: /etc/mihomo/Country.mmdb
    url: https://github.com/Loyalsoldier/geoip/releases/latest/download/Country.mmdb
    asn-path: /etc/mihomo/GeoLite2-ASN.mmdb
    asn-url: https://github.com/DustinWin/geoip_asn/releases/latest/download/GeoLite2-ASN.mmdb
  geosite:
    path: /etc/mihomo/geosite.dat
    url: https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
  update-interval: 172800

proxy-providers:
  Airport1:
    type: http
    # REDACTED - PUT YOUR TOKEN BACK HERE
    url: "https://999.ts1110.top/weibo/ipx/client/dy?token=286deb68eb0f7714af083c7192349b12"
    path: /etc/mihomo/proxies/airport1.yaml
    interval: 43200
    update-on-start: true
    skip-cert-verify: false
    filter: "(?i)(hk|港|tw|台|jp|日|sg|新|us|美)"
    exclude-filter: "(?i)(倍|test|备用|Expire|到期)"
    health-check:
      enable: true
      url: https://cp.cloudflare.com/generate_204
      interval: 300
      timeout: 5
      lazy: true 
    override:
      additional-suffix: " - A1"

  Airport2:
    type: http
    # REDACTED - PUT YOUR TOKEN BACK HERE
    url: "https://fcsblka.fcsubcn.cc:2096/api/v1/client/subscribe?token=6a0563b8a30ac5e2d6310cf55cca705e"
    path: /etc/mihomo/proxies/airport2.yaml
    interval: 43200
    update-on-start: true
    skip-cert-verify: false
    filter: "(?i)(hk|港|tw|台|jp|日|sg|新|us|美)"
    exclude-filter: "(?i)(倍|test|备用|Expire|到期)"
    health-check:
      enable: true
      url: https://cp.cloudflare.com/generate_204
      interval: 300
      timeout: 5
      lazy: true
    override:
      additional-suffix: " - A2"

proxy-groups:
  - {name: Proxy, type: select, proxies: [Auto, AI, HK, TW, JP, SG, US, DIRECT, REJECT]}
  - {name: Auto, type: fallback, url: "https://cp.cloudflare.com/generate_204", interval: 300, use: [Airport1, Airport2]}
  - {name: AI, type: select, proxies: [TW, JP, SG, US]}
  - {name: HK, type: select, use: [Airport1, Airport2], filter: "(?i)(hk|港)"}
  - {name: TW, type: select, use: [Airport1, Airport2], filter: "(?i)(tw|台)"}
  - {name: JP, type: select, use: [Airport1, Airport2], filter: "(?i)(jp|日)"}
  - {name: SG, type: select, use: [Airport1, Airport2], filter: "(?i)(sg|新)"}
  - {name: US, type: select, use: [Airport1, Airport2], filter: "(?i)(us|美)"}

rule-providers:
  fakeip-filter:
    type: http
    behavior: domain
    format: mrs
    path: /etc/mihomo/rules/fakeip-filter.mrs
    url: "https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/fakeip-filter.mrs"
    interval: 86400
  private:
    type: http
    behavior: domain
    format: mrs
    path: /etc/mihomo/rules/private.mrs
    url: "https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/private.mrs"
    interval: 86400
  ai:
    type: http
    behavior: domain
    format: mrs
    path: /etc/mihomo/rules/ai.mrs
    url: "https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/ai.mrs"
    interval: 86400
  proxy:
    type: http
    behavior: domain
    format: mrs
    path: /etc/mihomo/rules/proxy.mrs
    url: "https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/proxy.mrs"
    interval: 86400
  cn:
    type: http
    behavior: domain
    format: mrs
    path: /etc/mihomo/rules/cn.mrs
    url: "https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/cn.mrs"
    interval: 86400
  cnip:
    type: http
    behavior: ipcidr
    format: mrs
    path: /etc/mihomo/rules/cnip.mrs
    url: "https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/cnip.mrs"
    interval: 86400

rules:
  # Special User Requirements
  - DOMAIN-SUFFIX,ncbi.nlm.nih.gov,DIRECT
  - DOMAIN-SUFFIX,pubmed.ncbi.nlm.nih.gov,DIRECT
  # Local / Private
  - RULE-SET,private,DIRECT
  - RULE-SET,fakeip-filter,DIRECT
  - DOMAIN-SUFFIX,local,DIRECT
  - DOMAIN-SUFFIX,home,DIRECT
  - DOMAIN-SUFFIX,lan,DIRECT
  # Apple local services
  - DOMAIN-KEYWORD,airdrop,DIRECT
  - DOMAIN-KEYWORD,airplay,DIRECT
  - DOMAIN-KEYWORD,bonjour,DIRECT
  # AI
  - RULE-SET,ai,AI
  # China traffic
  - RULE-SET,cn,DIRECT
  - RULE-SET,cnip,DIRECT,no-resolve
  - GEOIP,CN,DIRECT,no-resolve
  # Proxy
  - RULE-SET,proxy,Proxy
  - MATCH,Proxy
```

下载地理和规则文件（Mihomo 会在启动时自动更新，但初始手动下载以避免错误）：

```bash
sudo mkdir -p /etc/mihomo/rules
sudo chown -R mihomo:mihomo /etc/mihomo/rules

# GeoIP 文件
sudo wget -O /etc/mihomo/Country.mmdb https://github.com/Loyalsoldier/geoip/releases/latest/download/Country.mmdb
sudo wget -O /etc/mihomo/GeoLite2-ASN.mmdb https://github.com/DustinWin/geoip_asn/releases/latest/download/GeoLite2-ASN.mmdb
sudo wget -O /etc/mihomo/geosite.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat

# 规则提供者 (.mrs 文件)
sudo wget -O /etc/mihomo/rules/fakeip-filter.mrs https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/fakeip-filter.mrs
sudo wget -O /etc/mihomo/rules/private.mrs https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/private.mrs
sudo wget -O /etc/mihomo/rules/ai.mrs https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/ai.mrs
sudo wget -O /etc/mihomo/rules/proxy.mrs https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/proxy.mrs
sudo wget -O /etc/mihomo/rules/cn.mrs https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/cn.mrs
sudo wget -O /etc/mihomo/rules/cnip.mrs https://github.com/DustinWin/ruleset_geodata/releases/download/mihomo-ruleset/cnip.mrs

sudo chown -R mihomo:mihomo /etc/mihomo
```

下载仪表板（可选，用于 UI 管理）：

```bash
cd /etc/mihomo
sudo wget https://github.com/MetaCubeX/Yacd-meta/archive/gh-pages.zip
sudo unzip gh-pages.zip -d ui_temp
sudo mv ui_temp/Yacd-meta-gh-pages/* ui/
sudo rm -rf ui_temp gh-pages.zip
sudo chown -R mihomo:mihomo /etc/mihomo/ui
```

#### 步骤 4：安装 AdGuardHome
下载并安装 AdGuardHome 的 ARM 版本。

```bash
cd /tmp
wget https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.71/AdGuardHome_linux_arm64.tar.gz  # 用最新版本替换
tar -xzf AdGuardHome_linux_arm64.tar.gz
sudo mv AdGuardHome/AdGuardHome /usr/local/bin/
sudo mkdir -p /etc/adguardhome /var/lib/adguardhome
```

配置 AdGuardHome。运行初始设置：

```bash
sudo /usr/local/bin/AdGuardHome -s install
```

这将创建 `/etc/adguardhome/AdGuardHome.yaml`。编辑它以在端口 5353 上监听（与您的 nftables DNS_AGH_PORT 匹配）：

```yaml
# /etc/adguardhome/AdGuardHome.yaml 的摘录
bind_hosts:
  - 0.0.0.0
dns:
  bind_hosts:
    - 0.0.0.0
  port: 5353  # 与 DNS_AGH_PORT 匹配
```

通过 Web UI 添加屏蔽列表（例如广告）。初始访问 http://10.0.0.2:3000，然后配置。

启用并启动服务：

```bash
sudo systemctl enable AdGuardHome
sudo systemctl start AdGuardHome
```

#### 步骤 5：为 Mihomo 配置 Systemd 服务
使用提供的配置创建服务。

创建 `/etc/systemd/system/mihomo-net.service`（与您提供的文件匹配）：

```
[Unit]
Description=Mihomo TProxy Routing Setup
After=network-online.target nftables.service
Wants=network-online.target nftables.service
Before=mihomo-tproxy.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=root
Group=root
# ---- Kernel sysctl for TProxy ----
ExecStartPre=/sbin/sysctl -w net.ipv4.ip_forward=1
ExecStartPre=/sbin/sysctl -w net.ipv4.conf.all.route_localnet=1
ExecStartPre=/sbin/sysctl -w net.ipv4.conf.default.route_localnet=1
ExecStartPre=/sbin/sysctl -w net.ipv4.conf.eth0.route_localnet=1
ExecStartPre=/sbin/sysctl -w net.ipv4.conf.eth0.rp_filter=0
ExecStartPre=/sbin/sysctl -w net.ipv4.conf.lo.rp_filter=0
ExecStartPre=/sbin/sysctl -w net.ipv4.conf.all.accept_redirects=0
ExecStartPre=/sbin/sysctl -w net.ipv4.conf.all.send_redirects=0
# ---- Clean old rules (systemd-safe) ----
ExecStartPre=/bin/sh -c "/usr/sbin/ip rule del fwmark 0x1 lookup 100 2>/dev/null || true"
ExecStartPre=/bin/sh -c "/usr/sbin/ip rule del from 127.0.0.1/32 lookup main 2>/dev/null || true"
ExecStartPre=/bin/sh -c "/usr/sbin/ip rule del iif lo lookup main 2>/dev/null || true"
ExecStartPre=/bin/sh -c "/usr/sbin/ip route flush table 100 2>/dev/null || true"
# ---- Create TProxy routing table ----
ExecStartPre=/usr/sbin/ip route add local 0.0.0.0/0 dev lo table 100
# ---- Install new rules ----
ExecStart=/usr/sbin/ip rule add fwmark 0x1 lookup 100 priority 100
ExecStart=/usr/sbin/ip rule add from 127.0.0.1/32 lookup main priority 10
ExecStart=/usr/sbin/ip rule add iif lo lookup main priority 11
# ---- Cleanup on stop ----
ExecStop=/bin/sh -c "/usr/sbin/ip rule del fwmark 0x1 lookup 100 2>/dev/null || true"
ExecStop=/bin/sh -c "/usr/sbin/ip rule del from 127.0.0.1/32 lookup main 2>/dev/null || true"
ExecStop=/bin/sh -c "/usr/sbin/ip rule del iif lo lookup main 2>/dev/null || true"
ExecStopPost=/bin/sh -c "/usr/sbin/ip route flush table 100 2>/dev/null || true"

[Install]
WantedBy=multi-user.target
```

创建 `/etc/systemd/system/mihomo-tproxy.service`（与您提供的文件匹配）：

```
[Unit]
Description=Mihomo TProxy Process
After=mihomo-net.service network-online.target
Wants=mihomo-net.service

[Service]
Type=simple
User=mihomo
Group=mihomo
WorkingDirectory=/etc/mihomo
# Required caps for transparent proxy
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_RESOURCE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_RESOURCE
LimitNOFILE=1048576
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
```

重新加载 systemd 并启用服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable mihomo-net mihomo-tproxy
```

#### 步骤 6：配置 nftables
nftables 处理过滤、NAT（用于 DNS 劫持和伪装）以及 TProxy 标记的 mangle。

创建 `/etc/nftables.conf` 并使用您提供的配置：

```
#!/usr/sbin/nft -f
flush ruleset
# ==================== 变量定义 ====================
define LAN_NET      = 10.0.0.0/24
define ROUTER_IP    = 10.0.0.2
define TPROXY_PORT  = 7895
define DNS_AGH_PORT = 5353
define MIHOMO_USER  = mihomo
# ==================== 1. FILTER 表 ====================
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif lo accept
        ct state established,related accept
        ip protocol icmp accept
        ip6 nexthdr ipv6-icmp accept
        # LAN 可以访问路由器所有服务
        ip saddr $LAN_NET accept
    }
    chain forward {
        type filter hook forward priority 0; policy drop;
        ct state established,related accept
        # 单臂路由：eth0 → eth0 的转发流量
        iifname "eth0" oifname "eth0" accept
    }
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
# ==================== 2. NAT 表 ====================
table ip nat {
    chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        # DNS 劫持 -> AdGuardHome
        ip saddr != $ROUTER_IP udp dport 53 redirect to $DNS_AGH_PORT
        ip saddr != $ROUTER_IP tcp dport 53 redirect to $DNS_AGH_PORT
    }
    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        # 单臂伪装
        ip saddr $LAN_NET oif "eth0" masquerade
    }
}
# ==================== 3. MANGLE 表 (TProxy) ====================
table ip mangle {
    chain prerouting {
        type filter hook prerouting priority mangle; policy accept;
        # 1) 全部内网 / 本机保留
        ip daddr {
            127.0.0.0/8,
            10.0.0.0/8,
            172.16.0.0/12,
            192.168.0.0/16,
            224.0.0.0/4,
            255.255.255.255
        } return
        # 3) 剩下的流量转发给 Mihomo TProxy
        meta l4proto { tcp, udp } tproxy to :$TPROXY_PORT meta mark set 0x1 accept
    }
    chain output {
        type route hook output priority -150; policy accept;
        # Mihomo 代理本机流量自身不处理
        meta mark 0x1 return
        # 跳过 mihomo 进程自身的流量 (避免循环)
        meta skuid $MIHOMO_USER return
        # 过滤内网
        ip daddr {
            127.0.0.0/8,
            10.0.0.0/8,
            172.16.0.0/12,
            192.168.0.0/16,
            224.0.0.0/4,
            255.255.255.255
        } return
        # 本机访问公网 -> 走 TProxy 代理
        meta l4proto { tcp, udp } meta mark set 0x1 accept
    }
}
```

使其可执行并加载：

```bash
sudo chmod +x /etc/nftables.conf
sudo nft -f /etc/nftables.conf
sudo systemctl restart nftables
```

#### 步骤 7：启动服务并验证
启动所有内容：

```bash
sudo systemctl start mihomo-net mihomo-tproxy AdGuardHome
```

验证：
- 检查 Mihomo：`sudo systemctl status mihomo-tproxy`（应为 active）。
- 检查路由：`ip rule show`（查找 fwmark 0x1 和本地查找）。
- 检查 nftables：`sudo nft list ruleset`（验证链）。
- 测试 DNS：从 LAN 客户端，`nslookup google.com 10.0.0.2`（应通过 AdGuardHome 解析）。
- 测试代理：从客户端 curl 站点（例如 `curl ipinfo.io`）—如果在 Mihomo 中配置，应显示代理 IP。
- 访问 Mihomo 仪表板：http://10.0.0.2:9090/ui（如果启用）。
- 访问 AdGuardHome：http://10.0.0.2:3000（默认初始端口，然后更改）。

#### 步骤 8：网络集成和故障排除
- **集成：** 将主路由器的网关设置为指向客户端到 10.0.0.2。对于单臂，确保设备处于桥接模式或如果需要使用 ARP 欺骗（此处未涵盖）。客户端应使用 10.0.0.2 作为 DNS。
- **故障排除：**
  - 无互联网：检查 `sysctl -a | grep net.ipv4` 以确保启用转发。验证 eth0 是否启动。
  - 循环问题：确保 MIHOMO_USER 正确设置以跳过自身流量。
  - DNS 未劫持：使用 `nft list table ip nat` 验证 NAT prerouting 规则。
  - 日志中的错误：`journalctl -u mihomo-tproxy` 或 `journalctl -u AdGuardHome`。
  - 自定义：编辑 Mihomo 配置以添加规则/代理。重启测试持久性：`sudo reboot`。

此设置提供了一个健壮的透明路由器。对于高级调整，请参考 Mihomo 文档或 AdGuardHome 维基。如果出现问题，请提供日志以进一步帮助。
