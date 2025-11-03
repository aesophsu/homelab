# modules/containers.nix
# This module defines all Podman OCI containers for the system (approximately 60 services).
# Containers are grouped by functional modules for modularity.
# Each container follows uniform conventions: volumes under /data/<module>/<app>, restart policy, logging to journald, resource limits, and health checks.
# Dependencies: Relies on Podman enabled in configuration.nix; uses sops for sensitive env vars if needed.
# For extension, add new attrsets or import sub-modules (e.g., ./containers/network.nix).
# Usage: Imported in configuration.nix.

{ config, pkgs, lib, ... }:

let
  # Uniform container options
  defaultOptions = {
    autoStart = true;
    extraOptions = [ "--restart=unless-stopped" "--log-driver=journald" ];
    environment = { TZ = "Asia/Shanghai"; };
    healthcheck = {
      test = [ "CMD-SHELL" "curl -f http://localhost/health || exit 1" ];  # Adjust per app if needed
      interval = "30s";
    };
  };

  # Helper to merge defaults with specific config
  mkContainer = name: cfg: lib.recursiveUpdate defaultOptions cfg;

in {
  virtualisation.oci-containers = {
    backend = "podman";
    containers = lib.mkMerge [
      # I. Network Core and Infrastructure (containers only; Cockpit is native service)
      (mkContainer "mihomo" {
        image = "dreamacro/clash-premium:latest";
        network = "host";
        volumes = [ "/data/network/mihomo:/root/.config/clash" ];
        cmd = [ "-d" "/root/.config/clash" "-ext-ui" "/ui" ];
        ports = [ "7893:7893/tcp" "7893:7893/udp" ];
        extraOptions = [ "--cap-add=NET_ADMIN" "--privileged" ];  # For TProxy
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "adguardhome" {
        image = "adguard/adguardhome:latest";
        volumes = [ "/data/network/adguard:/opt/adguardhome/work" ];
        ports = [ "5353:53/tcp" "5353:53/udp" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "easynode" {
        image = "easynode/image:latest";  # Placeholder; replace with actual
        volumes = [ "/data/network/easynode:/config" ];
        ports = [ "someport:80" ];
        limits = { cpu = "0.5"; memory = "256M"; };
      })
      (mkContainer "myip" {
        image = "myip/image:latest";  # Placeholder
        volumes = [ "/data/network/myip:/config" ];
        ports = [ "someport:80" ];
        limits = { cpu = "0.2"; memory = "128M"; };
      })
      (mkContainer "dockerport" {
        image = "dockerport/image:latest";  # Placeholder
        volumes = [ "/data/network/dockerport:/config" ];
        ports = [ "someport:80" ];
        limits = { cpu = "0.3"; memory = "256M"; };
      })
      (mkContainer "traefik" {
        image = "traefik:latest";
        volumes = [ "/data/network/traefik:/etc/traefik" "/var/run/podman/podman.sock:/var/run/docker.sock:ro" ];
        ports = [ "80:80" "443:443" ];
        cmd = [ "--api.insecure=true" "--providers.docker=true" ];  # Adjust for HTTPS/LetsEncrypt
        limits = { cpu = "1"; memory = "512M"; };
      })
      (mkContainer "wireguard" {
        image = "linuxserver/wireguard:latest";
        volumes = [ "/data/network/wireguard:/config" ];
        extraOptions = [ "--cap-add=NET_ADMIN" "--sysctl=net.ipv4.conf.all.src_valid_mark=1" ];
        limits = { cpu = "0.5"; memory = "256M"; };
      })
      (mkContainer "pihole" {
        image = "pihole/pihole:latest";
        volumes = [ "/data/network/pihole:/etc/pihole" ];
        ports = [ "53:53/tcp" "53:53/udp" "80:80" ];  # Backup DNS
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "homeassistant" {
        image = "homeassistant/home-assistant:latest";
        volumes = [ "/data/network/homeassistant:/config" ];
        ports = [ "8123:8123" "1883:1883" ];  # HA UI and MQTT
        extraOptions = [ "--network=host" "--privileged" ];  # For device access
        limits = { cpu = "2"; memory = "2G"; };
      })

      # II. Media Automation Stack
      (mkContainer "moviepilot" {
        image = "moviepilot/image:latest";  # Placeholder
        volumes = [ "/data/media-automation/moviepilot:/config" ];
        ports = [ "someport:80" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "qbittorrent" {
        image = "linuxserver/qbittorrent:latest";
        volumes = [ "/data/media-automation/qbittorrent:/config" "/data/downloads:/downloads" ];
        ports = [ "6881:6881" "6881:6881/udp" "8080:8080" ];
        limits = { cpu = "2"; memory = "2G"; };
      })
      (mkContainer "transmission" {
        image = "linuxserver/transmission:latest";
        volumes = [ "/data/media-automation/transmission:/config" "/data/downloads:/downloads" ];
        ports = [ "9091:9091" "51413:51413" "51413:51413/udp" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "iyuu" {
        image = "iyuu/image:latest";  # Placeholder
        volumes = [ "/data/media-automation/iyuu:/config" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "vertex" {
        image = "vertex/image:latest";  # Placeholder
        volumes = [ "/data/media-automation/vertex:/config" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "cookiecloud" {
        image = "cookiecloud/image:latest";  # Placeholder
        volumes = [ "/data/media-automation/cookiecloud:/config" ];
        limits = { cpu = "0.3"; memory = "256M"; };
      })
      (mkContainer "chinesesubfinder" {
        image = "chinesesubfinder/image:latest";  # Placeholder
        volumes = [ "/data/media-automation/chinesesubfinder:/config" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "wechatnotify" {
        image = "wechatnotify/image:latest";  # Placeholder
        volumes = [ "/data/media-automation/wechatnotify:/config" ];
        limits = { cpu = "0.2"; memory = "128M"; };
      })
      (mkContainer "jackett" {
        image = "linuxserver/jackett:latest";
        volumes = [ "/data/media-automation/jackett:/config" ];
        ports = [ "9117:9117" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "prowlarr" {
        image = "linuxserver/prowlarr:latest";
        volumes = [ "/data/media-automation/prowlarr:/config" ];
        ports = [ "9696:9696" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "sonarr" {
        image = "linuxserver/sonarr:latest";
        volumes = [ "/data/media-automation/sonarr:/config" "/data/media/tv:/tv" ];
        ports = [ "8989:8989" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "radarr" {
        image = "linuxserver/radarr:latest";
        volumes = [ "/data/media-automation/radarr:/config" "/data/media/movies:/movies" ];
        ports = [ "7878:7878" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "lidarr" {
        image = "linuxserver/lidarr:latest";
        volumes = [ "/data/media-automation/lidarr:/config" "/data/media/music:/music" ];
        ports = [ "8686:8686" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })

      # III. Media Library
      (mkContainer "emby" {
        image = "emby/embyserver:latest";
        volumes = [ "/data/media-library/emby:/config" "/data/media:/media" ];
        ports = [ "8096:8096" "8920:8920" ];
        limits = { cpu = "2"; memory = "2G"; };
        extraOptions = [ "--device=/dev/dri:/dev/dri" ];  # Hardware transcoding
      })
      (mkContainer "navidrome" {
        image = "deluan/navidrome:latest";
        volumes = [ "/data/media-library/navidrome:/data" "/data/media/music:/music" ];
        ports = [ "4533:4533" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "audiobookshelf" {
        image = "ghcr.io/advplyr/audiobookshelf:latest";
        volumes = [ "/data/media-library/audiobookshelf:/config" "/data/media/audiobooks:/audiobooks" ];
        ports = [ "13378:80" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "melody" {
        image = "melody/image:latest";  # Placeholder
        volumes = [ "/data/media-library/melody:/config" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "moontv" {
        image = "moontv/image:latest";  # Placeholder
        volumes = [ "/data/media-library/moontv:/config" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "libretv" {
        image = "libretv/image:latest";  # Placeholder
        volumes = [ "/data/media-library/libretv:/config" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "mediago" {
        image = "mediago/image:latest";  # Placeholder
        volumes = [ "/data/media-library/mediago:/config" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "jellyfin" {
        image = "jellyfin/jellyfin:latest";
        volumes = [ "/data/media-library/jellyfin:/config" "/data/media:/media" ];
        ports = [ "8096:8096" ];
        limits = { cpu = "2"; memory = "2G"; };
      })
      (mkContainer "plex" {
        image = "plexinc/pms-docker:latest";
        volumes = [ "/data/media-library/plex:/config" "/data/media:/media" ];
        ports = [ "32400:32400" ];
        limits = { cpu = "2"; memory = "2G"; };
      })

      # IV. Books and Reading Library
      (mkContainer "komga" {
        image = "gotson/komga:latest";
        volumes = [ "/data/books/komga:/config" "/data/books/library:/books" ];
        ports = [ "25600:25600" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "tachidesk" {
        image = "suwayomi/tachidesk:latest";
        volumes = [ "/data/books/tachidesk:/home/suwayomi/.local/share/Tachidesk" ];
        ports = [ "4567:4567" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "calibre" {
        image = "linuxserver/calibre:latest";
        volumes = [ "/data/books/calibre:/config" "/data/books/library:/library" ];
        ports = [ "8080:8080" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "reader" {
        image = "reader/image:latest";  # Placeholder
        volumes = [ "/data/books/reader:/config" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "freshrss" {
        image = "freshrss/freshrss:latest";
        volumes = [ "/data/books/freshrss:/var/www/FreshRSS/data" ];
        ports = [ "80:80" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "rsshub" {
        image = "diygod/rsshub:latest";
        volumes = [ "/data/books/rsshub:/app/data" ];
        ports = [ "1200:1200" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "wewerss" {
        image = "wewerss/image:latest";  # Placeholder
        volumes = [ "/data/books/wewerss:/config" ];
        limits = { cpu = "0.3"; memory = "256M"; };
      })
      (mkContainer "huntly" {
        image = "huntly/image:latest";  # Placeholder
        volumes = [ "/data/books/huntly:/config" ];
        limits = { cpu = "0.3"; memory = "256M"; };
      })
      (mkContainer "ubooquity" {
        image = "linuxserver/ubooquity:latest";
        volumes = [ "/data/books/ubooquity:/config" "/data/books/library:/books" ];
        ports = [ "2202:2202" "2203:2203" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "kavita" {
        image = "kiza/kavita:latest";
        volumes = [ "/data/books/kavita:/kavita/config" "/data/books/library:/books" ];
        ports = [ "5000:5000" ];
        limits = { cpu = "1"; memory = "1G"; };
      })

      # V. Utility and Storage Tools (Nextcloud and OpenList in btrfs.nix; add others)
      (mkContainer "filecode" {
        image = "filecode/image:latest";  # Placeholder
        volumes = [ "/data/utility/filecode:/config" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "pairdrop" {
        image = "schlagmichdoch/pairdrop:latest";
        volumes = [ "/data/utility/pairdrop:/config" ];
        ports = [ "3000:3000" ];
        limits = { cpu = "0.3"; memory = "256M"; };
      })
      (mkContainer "convertx" {
        image = "convertx/image:latest";  # Placeholder
        volumes = [ "/data/utility/convertx:/config" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "stringpdf" {
        image = "stringpdf/image:latest";  # Placeholder
        volumes = [ "/data/utility/stringpdf:/config" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "handbrake" {
        image = "jlesage/handbrake:latest";
        volumes = [ "/data/utility/handbrake:/config" "/data/media:/storage:ro" ];
        ports = [ "5800:5800" ];
        limits = { cpu = "2"; memory = "2G"; };
      })
      (mkContainer "squoosh" {
        image = "squoosh/image:latest";  # Placeholder
        volumes = [ "/data/utility/squoosh:/config" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "uptimekuma" {
        image = "louislam/uptime-kuma:latest";
        volumes = [ "/data/utility/uptimekuma:/app/data" ];
        ports = [ "3001:3001" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "syncthing" {
        image = "syncthing/syncthing:latest";
        volumes = [ "/data/utility/syncthing:/var/sync" ];
        ports = [ "8384:8384" "22000:22000/tcp" "22000:22000/udp" "21027:21027/udp" ];
        limits = { cpu = "1"; memory = "1G"; };
      })

      # VI. Content Capture and Recording
      (mkContainer "bilivego" {
        image = "bilivego/image:latest";  # Placeholder
        volumes = [ "/data/content/bilivego:/config" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "metube" {
        image = "alexta69/metube:latest";
        volumes = [ "/data/content/metube:/downloads" ];
        ports = [ "8081:8081" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "easyvdl" {
        image = "easyvdl/image:latest";  # Placeholder
        volumes = [ "/data/content/easyvdl:/config" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "memos" {
        image = "neosr/memos:latest";
        volumes = [ "/data/content/memos:/var/opt/memos" ];
        ports = [ "5230:5230" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "qd" {
        image = "qd/image:latest";  # Placeholder
        volumes = [ "/data/content/qd:/config" ];
        limits = { cpu = "0.3"; memory = "256M"; };
      })
      (mkContainer "notepad" {
        image = "notepad/image:latest";  # Placeholder
        volumes = [ "/data/content/notepad:/config" ];
        limits = { cpu = "0.3"; memory = "256M"; };
      })
      (mkContainer "ytdlp" {
        image = "tzahi12345/youtubedl-material:latest";
        volumes = [ "/data/content/ytdlp:/app/appdata" "/data/downloads:/app/downloads" ];
        ports = [ "17442:17442" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "streamlink" {
        image = "streamlink/image:latest";  # Placeholder
        volumes = [ "/data/content/streamlink:/config" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "obsidiansync" {
        image = "obsidiansync/image:latest";  # Placeholder
        volumes = [ "/data/content/obsidiansync:/config" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })

      # VII. Portal and Dashboard
      (mkContainer "homepage" {
        image = "ghcr.io/gethomepage/homepage:latest";
        volumes = [ "/data/portal/homepage:/app/config" ];
        ports = [ "3000:3000" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "newsnow" {
        image = "newsnow/image:latest";  # Placeholder
        volumes = [ "/data/portal/newsnow:/config" ];
        limits = { cpu = "0.3"; memory = "256M"; };
      })
      (mkContainer "myicon" {
        image = "myicon/image:latest";  # Placeholder
        volumes = [ "/data/portal/myicon:/config" ];
        limits = { cpu = "0.2"; memory = "128M"; };
      })
      (mkContainer "flink" {
        image = "flink/image:latest";  # Placeholder
        volumes = [ "/data/portal/flink:/config" ];
        limits = { cpu = "0.3"; memory = "256M"; };
      })
      (mkContainer "heimdall" {
        image = "linuxserver/heimdall:latest";
        volumes = [ "/data/portal/heimdall:/config" ];
        ports = [ "80:80" "443:443" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "organizr" {
        image = "organizr/organizr:latest";
        volumes = [ "/data/portal/organizr:/config" ];
        ports = [ "80:80" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "dashy" {
        image = "lissy93/dashy:latest";
        volumes = [ "/data/portal/dashy:/app/public/conf.yml" ];
        ports = [ "80:80" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "netdata" {
        image = "netdata/netdata:latest";
        volumes = [ "/proc:/host/proc:ro" "/sys:/host/sys:ro" "/var/run/podman:/host/var/run/docker:ro" ];
        ports = [ "19999:19999" ];
        extraOptions = [ "--cap-add=SYS_PTRACE" ];
        limits = { cpu = "1"; memory = "1G"; };
      })

      # Extension Services
      (mkContainer "backuppc" {
        image = "adferrand/backuppc:latest";
        volumes = [ "/data/extension/backuppc:/config" "/data:/data:ro" ];
        ports = [ "80:80" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
      (mkContainer "vaultwarden" {
        image = "vaultwarden/server:latest";
        volumes = [ "/data/extension/vaultwarden:/data" ];
        ports = [ "80:80" ];
        limits = { cpu = "0.5"; memory = "512M"; };
      })
      (mkContainer "minio" {
        image = "minio/minio:latest";
        volumes = [ "/data/extension/minio:/data" ];
        ports = [ "9000:9000" "9001:9001" ];
        cmd = [ "server" "/data" "--console-address" ":9001" ];
        limits = { cpu = "1"; memory = "1G"; };
      })
    ];
  };

  # Firewall openings for container ports (examples; add as needed)
  networking.firewall.allowedTCPPorts = [
    7893  # Mihomo
    5353  # AdGuard
    80 443  # Traefik
    8123 1883  # Home Assistant
    # Add others like 8096 for Emby, etc.
  ];
  networking.firewall.allowedUDPPorts = [
    7893  # Mihomo
    5353  # AdGuard
  ];
}
