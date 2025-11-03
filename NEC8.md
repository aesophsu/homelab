## ✨ NixOS All-in-One 终极架构配置描述

**描述概述：** 本文档提供对NixOS All-in-One终极架构的全面、详尽描述，旨在作为蓝图，帮助AI或其他工具生成完整的NixOS配置代码（如configuration.nix、flake.nix、模块文件和脚本）。描述基于声明式原则，覆盖硬件适配、系统架构、网络流量管理、存储策略、服务容器化、监控机制以及应用层服务分组。整个系统针对NEC i5-8600 CPU（6核/12线程）、32GB RAM、5网口主机优化，运行无GUI的NixOS（纯CLI管理），实现高性能家庭数据中心和主路由功能。系统管理约60个OCI容器服务（扩展自50+），支持原子更新、故障恢复和自动化运维。预计系统负载：峰值200+并发连接，CPU利用率<75%，内存<26GB，存储I/O优化为媒体自动化和下载场景。所有配置必须符合NixOS的纯函数式、可重现性，确保通过`nixos-rebuild switch --flake .#nixos`一键部署和回滚。

**更新说明（基于推荐更优方案 + 权限控制强化）：**
- **权限控制集成**：加强整体安全性，防止重要配置文件（如`/etc/nixos/*.nix`、YAML秘密）被误改。核心措施：（1）Git版本控制管理`/etc/nixos`（跟踪变更、pre-commit检查）；（2）文件immutable属性（chattr +i，root也需解锁才能改）；（3）sops-nix加密敏感配置（如Mihomo YAML、Nextcloud凭证）；（4）监控未授权变更（auditd日志 + Prometheus警报）。这些深度防御机制集成到模块中，支持声明式应用。
- **其他**：存储保持BTRFS（单盘优化）；流量分流daily更新；网口VLAN隔离；容器Podman；版本最新LTS；资源总24GB/8 vCPU；健康检查优化。

**系统目标与整体架构：**
- **主要目标：** 构建一个高效、可维护的家庭服务器，集成主路由（流量分流、代理）、BTRFS存储（数据冗余、快照）、媒体自动化（PT下载、影音管理）、实用工具和监控仪表盘。系统强调安全性（最小权限、加密流量、权限控制）、性能（资源限额、缓存优化）和可用性（自动化更新、告警通知）。所有服务通过NixOS模块化配置管理，避免手动干预，支持远程CLI访问（SSH/Cockpit）。
- **架构原则：** 
  - **声明式配置：** 所有设置（网络、容器、BTRFS、权限）均在Nix文件中定义，支持Flake结构（inputs/outputs/modules）。
  - **模块化设计：** 分离核心模块（如nftables.nix、btrfs.nix、containers.nix、permissions.nix），每个模块对应功能域，便于AI生成独立文件。
  - **原子性运维：** 使用`nixos-rebuild`进行更新/回滚；取代Watchtower等工具。
  - **安全性强化：** 默认drop规则、容器非root运行、HTTPS强制、Fail2Ban防暴力破解；新增权限控制（Git + immutable + sops-nix + auditd）。
  - **性能调优：** sysctl参数调整（e.g., net.core.somaxconn=2048）、BTRFS zstd压缩、Podman OCI驱动。
  - **故障恢复：** BTRFS快照回溯、容器健康检查、Prometheus告警（集成Email/Slack/Telegram）；权限变更日志支持回滚。
  - **扩展性：** 支持IPv6、VLAN隔离、外部备份（rsync或Nextcloud同步）。
- **硬件详细适配：**
  - **CPU/RAM：** i5-8600（基频3.1GHz，睿频4.3GHz），分配：系统核心10%、容器70%、BTRFS缓存20%（限8GB）。
  - **网口：** 5个千兆口分配（优化为安全隔离）：eth0 (WAN: PPPoE外网接入)、eth1 (主LAN: 10.0.0.0/24，核心设备如PC/手机)、eth2 (智能设备VLAN: 子网10.1.0.0/24，nftables限制访问主LAN，只允许必要流量如MQTT/Home Assistant)、eth3 (Guest/DMZ: 子网10.2.0.0/24，访客或暴露服务)、eth4 (备用/监控: e.g., 备份网或Prometheus专用)。
  - **存储：** 单盘SSD BTRFS（根分区+subvolumes），统一挂载/data用于所有持久化；总容量>500GB，启用TRIM/compress。
  - **电源/散热：** 确保稳定供电，监控温度（lm-sensors + Prometheus）。
- **软件版本假设：** NixOS 25.11（“Xantusia”，2025年11月发布，提供6个月支持），Podman 5.3+（2025年10月稳定版），nftables 1.1.5（2025年9月稳定版）。所有容器镜像从官方源拉取，支持arm64/x86兼容。

**核心技术栈（详尽描述）：**

以下表格详述每个领域的技术选型、配置要求、优化点和伪Nix代码示例。AI生成代码时，应基于这些生成完整Nix表达式，确保导入依赖（如pkgs.lib、pkgs.fetchurl、sops-nix）。

| 领域 | 选定技术/方案 | 关键配置要求 | 优化点与详尽说明 | Nix/脚本伪代码示例 |
|------|---------------|--------------|------------------|---------------------|
| **I. 网络架构** | NixOS主路由 + 原生nftables策略路由 + systemd-networkd | 配置WAN PPPoE/LAN接口（静态/DHCP）；启用IP转发（IPv4/IPv6）；nftables处理所有规则（NAT、转发、过滤）；支持VLAN（802.1q）隔离智能设备。 | 集成DDoS防护（rate limit per IP）；端口敲门（knockd）增强安全；动态DNS（ddclient）；负载均衡（可选HAProxy）。详尽流程：WAN接入外网，LAN分发内网（VLAN标记智能流量），nftables链式规则（input/forward/output/prerouting/postrouting）。性能：conntrack限10k连接。 | ```nix
| **II. 代理与 DNS** | Mihomo (Clash Meta内核，Host模式) + AdGuard Home (非标端口5353) | Mihomo容器Host网络，监听TProxy 7893 (TCP/UDP)；AdGuard监听5353，支持上游DoH/DoT；集成规则订阅（YAML配置文件）。 | Failover机制（多节点切换）；加密DNS（TLS1.3）；缓存优化（AdGuard TTL>1h）；日志旋转（journald）。详尽：Mihomo处理非中国流量，AdGuard过滤广告/跟踪。配置放置：/data/mihomo/config.yaml（sops加密）。 | ```nix<br>virtualisation.oci-containers.containers.mihomo = {<br>  image = "dreamacro/clash-premium";<br>  network = "host";<br>  volumes = [ "/data/mihomo:/root/.config/clash" ];<br>  cmd = [ "-d" "/root/.config/clash" "-ext-ui" "/ui" ];<br>  ports = [ "7893:7893/tcp" "7893:7893/udp" ];<br>  autoStart = true;<br>  extraOptions = [ "--cap-add=NET_ADMIN" "--privileged" ];  # TProxy所需<br>};<br>virtualisation.oci-containers.containers.adguard = {<br>  image = "adguard/adguardhome";<br>  ports = [ "5353:53/tcp" "5353:53/udp" ];  # 重定向到5353<br>  volumes = [ "/data/adguard:/opt/adguardhome/work" ];<br>};<br>sops.secrets.mihomo-config = { path = "/data/mihomo/config.yaml"; };  # 加密秘密<br>``` |
| **III. 流量分流** | nftables + 自动化IP Sets (systemd.timer脚本更新) | 1. DNS劫持：所有53端口流量redirect到5353（AdGuard）。2. 自动化脚本：daily更新China/Non-China IP列表（来源：ipdeny.com, APNIC, GeoIP数据库），注入nft set（ipv4_addr/ipv6_addr类型）。3. 基于set标记流量（fwmark 1 for non-China），TProxy重定向到Mihomo 7893。4. 全局应用：所有容器/主机出站遵循策略，支持例外规则（e.g., bypass for local）。 | IPv6支持（dual-stack sets）；更新频率daily；错误处理（fallback旧set）；日志记录（nft log）。详尽流程：prerouting链捕获流量 → match set → mark → tproxy。脚本使用curl下载、awk解析、nft add element批量注入。 | ```nix<br>systemd.timers.update-ipsets = {<br>  wantedBy = [ "timers.target" ];<br>  timerConfig = { OnCalendar = "daily"; Persistent = true; };<br>};<br>systemd.services.update-ipsets = {<br>  script = ''#!/bin/bash<br>    curl -s https://www.ipdeny.com/ipblocks/data/aggregated/cn-aggregated.zone > /tmp/cn_ips<br>    nft flush set inet filter china_ipv4<br>    while read -r ip; do nft add element inet filter china_ipv4 { $ip }; done < /tmp/cn_ips<br>    # 同理Non-China和IPv6<br>  '';<br>};<br>```<br>nft规则：chain prerouting { type nat hook prerouting priority -100; udp dport 53 redirect to 5353; ip saddr != @china_ipv4 meta mark set 1; meta mark 1 tproxy to :7893; } |
| **IV. 存储与数据** | BTRFS文件系统 (带autoScrub/snapper) + Samba/NFS共享 + Nextcloud容器 (WebDAV集成) + OpenList容器 | 启用BTRFS内核支持；创建subvolume /data；autoScrub weekly（全盘校验）；snapper快照（hourly=24, daily=7, weekly=4, monthly=3）；Samba/NFS共享/data（read/write权限）；Nextcloud容器提供WebDAV/文件同步；OpenList容器浏览文件。 | TRIM支持（SSD）；压缩（zstd）；quota限（per subvolume）；备份（rsync到远程，timer每周）；权限（ACL + group data）。详尽：BTRFS确保数据完整性，快照允许回滚误删；Nextcloud增强共享兼容Windows/Linux/浏览器客户端。 | ```nix<br>boot = {<br>  supportedFilesystems = [ "btrfs" ];<br>};<br>fileSystems."/data" = { device = "/dev/sda"; fsType = "btrfs"; options = [ "subvol=data" "compress=zstd" "autodefrag" ]; };<br>services.btrfs.autoScrub = { enable = true; interval = "weekly"; };<br>services.snapper = {<br>  configs.data = { subvolume = "/data"; timelineCleanup = true; timelineCreate = true; hourly = 24; daily = 7; weekly = 4; monthly = 3; };<br>};<br>services.samba = { enable = true; shares.data = { path = "/data"; "valid users" = "@data"; }; };<br>services.nfs.server = { enable = true; exports = "/data *(rw,sync,no_subtree_check)"; };<br>users.groups.data = {};  # 共享组<br>virtualisation.oci-containers.containers.nextcloud = { image = "nextcloud"; volumes = [ "/data/nextcloud:/var/www/html" ]; ports = [ "8080:80" ]; };<br>sops.secrets.nextcloud-credentials = { path = "/data/nextcloud/config/credentials.yaml"; };  # 加密凭证<br>```<br>备份脚本：btrfs subvolume snapshot /data /data/.snapshots/weekly; rsync -a /data remote:/backup |
| **V. 服务管理** | Podman OCI容器 (Multi-Compose结构) | 使用virtualisation.oci-containers管理多Compose文件（per模块）；autoStart所有容器；资源限额（CPU/Memory，总24GB/8 vCPU）；健康检查（interval 30s）；日志driver journald。 | 取代Watchtower（nix rebuild更新镜像）；依赖顺序（dependsOn）；网络隔离（bridge/host）；卷统一/data/<module>/<app>。详尽：Compose YAML转换为Nix attrset，支持环境变量注入。 | ```nix<br>virtualisation = {<br>  oci-containers = {<br>    backend = "podman";<br>    containers = {  # 或composeFiles = [ ./compose/network.yml ];<br>      example-app = { image = "nginx"; volumes = [ "/data/example:/app" ]; limits = { cpu = "1"; memory = "512M"; }; healthcheck = { test = [ "CMD-SHELL" "curl -f http://localhost/health || exit 1" ]; interval = "30s"; }; };<br>    };<br>  };<br>};<br>``` |
| **VI. 监控** | Prometheus + Grafana栈 + Exporters (node/docker) | 部署node_exporter (系统指标)、docker_exporter (容器)；Grafana dashboard可视化（CPU/RAM/IO/容器TPS）；Alertmanager告警（阈值：CPU>80%、BTRFS error>0）。 | 自定义dashboard（JSON import）；远程write（长期存储）；集成Slack/Email/Telegram；采样15s。详尽：监控覆盖系统全栈，包括文件变更警报。 | ```nix<br>services.prometheus = {<br>  enable = true;<br>  scrapeInterval = "15s";<br>  exporters = { node.enable = true; docker.enable = true; };<br>  alertmanager = { enable = true; configuration = { route = { receiver = "telegram"; }; receivers.telegram = { botToken = "..."; chatId = "..."; }; }; };<br>};<br>services.grafana = { enable = true; provision.dashboards = [ { name = "system"; json = ./dashboards/system.json; } ]; };<br>security.auditd.enable = true;  # 监控文件变更日志<br>``` |
| **VII. 权限控制** | Git版本控制 + Immutable文件 + sops-nix秘密管理 + auditd监控 | Git管理`/etc/nixos`（init repo, pre-commit hook检查nix flake check）；chattr +i使关键nix文件不可变；sops-nix加密敏感YAML/凭证（age密钥）；auditd日志未授权变更，集成Prometheus警报。 | 防止误改（Git历史回滚）；加密秘密（sops解密仅rebuild时）；监控变更（inotify/alert）。详尽：权限模块确保root最小权限，结合Fail2Ban。Flake inputs: sops-nix.url = "github:Mic92/sops-nix"。 | ```nix<br>environment.systemPackages = [ pkgs.git ];  # Git安装<br>system.activationScripts = {<br>  gitInit.text = ''cd /etc/nixos; git init || true; git add .; git commit -m "Auto commit" || true;'';  # 初始化repo<br>  setImmutable.text = ''chattr +i /etc/nixos/*.nix;'';  # Immutable<br>};<br>sops = { defaultSopsFile = ./secrets.yaml; age.keyFile = "/var/lib/sops/age-keys.txt"; };  # 加密<br>security.auditd.rules = [ "-w /etc/nixos -p wa -k config-change" ];  # 监控变更<br>``` |

### 应用层：60+ 容器服务分组 (NixOS模块化详尽描述)

所有容器统一配置：volumes /data/<module>/<app>；restart unless-stopped；环境变量注入（e.g., TZ=Asia/Shanghai）；资源限额（总24GB RAM/8 vCPU分配）；网络bridge/host per需；健康检查CMD。分组为7模块，每个对应Nix模块（modules/<name>.nix）和Compose YAML（compose/<name>.yml），总60服务（扩展实用/备份）。AI生成时，确保模块导入flake.nix（imports = [ ./modules/network.nix ];）。推荐挑选子集（20-30服务，e.g., 启用网络/媒体/存储，添加Home Assistant支持智能设备）。

| 模块名称 (NixOS/Compose) | 核心功能详述 | 包含的主要应用 (完整60+服务清单) | 资源建议 & 配置详点 |
|--------------------------|--------------------|-----------------------------------|----------------------|
| **I. 网络核心与基础设施** (10服务) | 管理路由、代理、DNS、系统访问；提供基础网络工具和VPN；集成智能设备管理。详尽：Mihomo全局代理，AdGuard广告过滤，Cockpit Web UI管理，Traefik反代所有服务，Home Assistant智能家居。 | Mihomo (TProxy核心), AdGuard Home (DNS过滤), Cockpit (系统管理), EasyNode (节点监控), Myip (公网IP查询), DockerPort (端口映射工具), Traefik (反向代理+HTTPS), WireGuard (VPN隧道), Pi-hole (备用DNS+DHCP), Home Assistant (智能设备核心)。 | 3GB RAM/2 vCPU；Host网络 for Mihomo/AdGuard；Traefik labels for auto-discovery；volumes /data/network/<app>；ports 80/443暴露；Home Assistant MQTT端口1883。 |
| **II. 媒体自动化栈 (PT/影音)** (12服务) | 自动化下载、做种、字幕、通知；集成PT站点同步。详尽：MoviePilot调度下载/整理，qBittorrent/Tr处理torrent，IYUU跨站辅种，微信通知失败/完成。 | MoviePilot (自动化核心), qBittorrent (下载器), Transmission (备用做种), IYUU (PT同步), Vertex (标签/整理), Cookiecloud (Cookie管理), ChineseSubFinder (字幕下载/翻译), WeChatNotify (通知bot), Jackett (索引器聚合), Prowlarr (搜索器), Sonarr (TV自动化), Radarr (电影自动化), Lidarr (音乐自动化)。 | 8GB RAM/4 vCPU；高IO (SSD)；dependsOn MoviePilot；环境 PUID=1000 for权限。 |
| **III. 影音媒体库** (9服务) | 媒体服务器/播放；支持转码、流媒体。详尽：Emby中央库，Navidrome音乐流，Audiobookshelf有声书播放，支持手机App同步。 | Emby (媒体服务器核心), Navidrome (音乐库), Audiobookshelf (有声书), Melody (音乐播放精灵), MoonTV (直播聚合), LibreTV (开源TV服务器), MediaGo (媒体浏览器), Jellyfin (开源Emby替代), Plex (兼容商业库)。 | 5GB RAM/2 vCPU；硬件加速 (VAAPI/QuickSync via Intel CPU)；volumes /data/media/library；ports 8096 for Emby。 |
| **IV. 图书与阅读库** (10服务) | 管理漫画/电子书/RSS；聚合订阅。详尽：Komga书库服务器，FreshRSS RSS阅读，RSSHub生成自定义源。 | Komga (漫画/书库核心), Tachidesk (Manga阅读), Calibre (电子书管理), Reader (通用阅读器), FreshRSS (RSS聚合), RSSHub (RSS生成器), WeweRSS (微信RSS), Huntly (书签/阅读列表), Ubooquity (书库服务器), Kavita (小说/漫画管理)。 | 2GB RAM/1 vCPU；低资源；集成Calibre web UI；volumes /data/books。 |
| **V. 实用工具与存储** (10服务) | 文件管理/转换/监控；云同步。详尽：OpenList文件浏览器，UptimeKuma服务监控，Nextcloud私有云。 | OpenList (文件列表核心), Filecode (代码/文件托管), PairDrop (AirDrop-like传输), ConvertX (格式转换), StringPDF (PDF编辑), Handbrake (视频转码), Squoosh (图像压缩), UptimeKuma ( uptime监控), Nextcloud (云存储/WebDAV), Syncthing (P2P同步)。 | 4GB RAM/2 vCPU；I/O优先；Syncthing原生Nix服务 fallback。 |
| **VI. 内容抓取与记录** (9服务) | 录制/下载/笔记/签到；定时任务。详尽：Bilivego B站直播录制，Memos私人笔记，qd自动化签到。 | Bilivego (直播录制), Metube (YouTube下载), EasyVDL (视频DL工具), Memos (笔记核心), qd (签到框架), Notepad (简单备忘), yt-dlp (通用下载容器), Streamlink (流媒体捕获), Obsidian-sync (笔记同步)。 | 2GB RAM/1 vCPU；timer for qd (daily)；volumes /data/downloads。 |
| **VII. 门户与仪表盘** (8服务) | 统一入口/监控/书签；动态UI。详尽：Homepage中央仪表盘（集成服务状态），Netdata实时图表。 | Homepage (仪表盘核心), NewsNOW (新闻聚合), Myicon (图标管理), Flink (书签链接), Heimdall (应用门户), Organizr (服务组织), Dashy (自定义仪表盘), Netdata (实时监控)。 | 1GB RAM/1 vCPU；Traefik代理；Homepage widgets for UptimeKuma/Prometheus。 |

**扩展服务（跨模块，3服务）**：BackupPC (全备份), Vaultwarden (密码管理), MinIO (S3对象存储) — 集成到相关模块。

---

### 核心配置需求（详尽总结 & 生成指南）

1. **NFTables核心模块 (nftables.nix)**：定义完整规则集（tables: filter/nat；chains: input/forward/prerouting）；DNS劫持 (redirect dport 53 to 5353)；IP Sets (china_ipv4 { type ipv4_addr; flags interval; }，自动化脚本注入）；TProxy (meta mark 1 tproxy ip to 127.0.0.1:7893)；日志 (log level info prefix "divert: ")；DDoS (counter bytes >1M drop)；IPv6镜像规则；VLAN隔离 (iifname "vlan10" drop特定流量)。生成时：输出到rulesetFile，确保与systemd-networkd兼容。

2. **BTRFS与共享模块 (btrfs.nix)**：subvolume创建 (btrfs subvolume create /data)；/data挂载 + 权限（users.groups.data = { members = [ "podman" ]; }）；snapper快照（保留策略）；Scrub（weekly，警报集成Prometheus）；Samba/NFS（services.nfs.server.enable = true;）；Nextcloud容器（WebDAV端口8080）。备份：rsync timer（weekly）。

3. **基础服务模块 (base.nix)**：SSH（services.openssh.enable = true; settings.PermitRootLogin = "no";）；Cockpit（services.cockpit.enable = true;）；Prometheus/Grafana（global scrape 15s, rules for BTRFS alerts e.g., btrfs_errors >0）；Fail2Ban（jails sshd/podman）；ddclient（动态DNS）；lm-sensors (硬件监控)。生成时：集成alert receivers（Telegram）。

4. **容器部署模块 (containers.nix)**：定义所有60+容器attrset（image, volumes, ports, env, limits, healthcheck, dependsOn）；Multi-Compose (e.g., compose.network.yml for Mihomo/AdGuard)；统一extraOptions (--restart=unless-stopped --log-driver=journald)；Mihomo特权 (NET_ADMIN for tproxy)；AdGuard upstream (1.1.1.1:53 tls://)；应用层per模块子文件 (e.g., modules/media.nix imports containers.media)。生成时：使用lib.mapAttrs生成动态列表，后端Podman。

5. **权限控制模块 (permissions.nix)**：Git init /etc/nixos（auto commit）；immutable nix文件；sops加密秘密；auditd监控变更（-w /etc/nixos -p wa）。生成时：添加Flake inputs sops-nix；警报阈值（file_change >0）。

**整体Flake结构指南（为AI生成代码准备）：**
```
├── flake.nix  # inputs { nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11"; sops-nix.url = "github:Mic92/sops-nix"; }; outputs = { self, nixpkgs, sops-nix }: { nixosConfigurations.nixos = nixpkgs.lib.nixosSystem { modules = [ sops-nix.nixosModules.sops ./configuration.nix ]; }; };
├── configuration.nix  # imports = [ ./modules/base.nix ./modules/btrfs.nix ./modules/nftables.nix ./modules/containers.nix ./modules/permissions.nix ];
├── modules/  # 子模块如 network.nix (nftables + mihomo)
├── compose/  # YAML文件，如 network.yml (services: mihomo, adguard)
├── scripts/  # update-ipsets.sh 等
├── secrets.yaml  # sops加密文件
└── dashboards/  # Grafana JSON
```

**运维与最佳实践详述：**
- **部署流程：** 安装NixOS -> btrfs subvolume create -> nixos-rebuild switch -> 容器pull/start -> 测试流量/监控/权限。
- **安全性：** 容器cap drop all；nft default drop；HTTPS (Traefik acme)；用户隔离 (PUID/PGID)；权限控制（Git revert误改，sops防泄露）。
- **性能：** BTRFS compress=zstd；Podman cgroup v2；sysctl (rmem/wmem max 4M)。
- **恢复：** btrfs snapshot rollback /data/.snapshots/last；nixos-rebuild --rollback；Git revert。
- **测试：** VM模拟 (nixos-rebuild build-vm)；负载 (stress-ng)；日志 (journalctl -u podman)；权限测试 (chattr -i 编辑)。
- **自定义点：** 根据用户硬件调整网口/IP；添加服务时扩展模块。

此描述足够详尽，可直接输入AI（如Grok）生成完整Nix代码。如需进一步细化特定模块，请提供反馈。
