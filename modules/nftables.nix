# modules/nftables.nix
# This module configures nftables for routing, policy routing, DNS hijacking, and traffic diversion.
# It includes VLAN isolation, TProxy to Mihomo, IP sets for China/Non-China, and DDoS protection.
# Dependencies: Requires systemd-networkd for interfaces; integrates with containers.nix for Mihomo.
# The ruleset is defined in a file and loaded via nftables.rulesetFile.
# Also sets up daily IP sets update timer and service, referencing scripts/update-ipsets.sh.
# Usage: Imported in configuration.nix.

{ config, pkgs, lib, ... }:

{
  # Enable nftables and disable iptables compatibility
  networking.nftables.enable = true;
  networking.firewall.enable = false;  # Use nftables exclusively

  # Systemd-networkd for interface management
  systemd.network.enable = true;

  # IP forwarding for routing
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # nftables ruleset definition (written to a file)
  environment.etc."nftables.conf".text = ''
    table inet filter {
      set china_ipv4 {
        type ipv4_addr;
        flags interval;
      }
      set china_ipv6 {
        type ipv6_addr;
        flags interval;
      }

      chain input {
        type filter hook input priority 0; policy drop;
        iif "lo" accept;
        ct state established,related accept;
        ct state invalid drop;
        # VLAN isolation example: restrict IoT VLAN (vlan10) to specific ports
        iifname "vlan10" tcp dport != 1883 drop;  # Allow MQTT only for Home Assistant
        iifname "vlan20" accept;  # DMZ/Guest more permissive if needed
        # DDoS protection: rate limit per IP
        ip saddr != 127.0.0.0/8 limit rate 100/second burst 150 packets accept else drop;
        # Accept SSH, etc., with Fail2Ban handling
        tcp dport 22 accept;
      }

      chain forward {
        type filter hook forward priority 0; policy accept;
        # Forward between LANs with restrictions
        iifname "eth1" oifname "eth0" accept;  # LAN to WAN
        iifname "vlan10" oifname "eth1" drop;  # Isolate IoT from main LAN
      }

      chain output {
        type filter hook output priority 0; policy accept;
      }
    }

    table inet nat {
      chain prerouting {
        type nat hook prerouting priority -100;
        # DNS hijacking: redirect 53 to AdGuard 5353
        tcp dport 53 redirect to 5353;
        udp dport 53 redirect to 5353;
        # Mark non-China traffic
        ip saddr != @china_ipv4 meta mark set 1;
        ip6 saddr != @china_ipv6 meta mark set 1;
        # TProxy diversion to Mihomo 7893
        meta mark 1 tproxy to :7893;
      }

      chain postrouting {
        type nat hook postrouting priority 100;
        # Masquerade for WAN
        oifname "eth0" masquerade;
      }
    }
  '';
  networking.nftables.rulesetFile = "/etc/nftables.conf";

  # PPPoE for WAN (eth0)
  services.ppp = {
    enable = true;
    peers.wan = {
      enable = true;
      config = ''
        plugin pppoe.so
        nic-eth0
        user "your-pppoe-username"  # Use sops for secrets
        password "your-pppoe-password"  # Use sops
        persist
        maxfail 0
        holdoff 5
        defaultroute
        usepeerdns
      '';
    };
  };
  sops.secrets.pppoe-username = { path = "/etc/ppp/secrets/username"; };
  sops.secrets.pppoe-password = { path = "/etc/ppp/secrets/password"; };

  # Dynamic DNS (ddclient) if needed
  services.ddclient = {
    enable = true;
    configFile = config.sops.secrets.ddclient-config.path;  # Encrypted config
  };

  # IP sets update timer and service
  systemd.timers.update-ipsets = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  systemd.services.update-ipsets = {
    description = "Update nftables IP sets for China/Non-China";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${./scripts/update-ipsets.sh}";
    };
  };

  # Open necessary firewall ports (supplemental to nftables)
  networking.firewall = {
    allowedTCPPorts = [ 7893 ];  # Mihomo TProxy
    allowedUDPPorts = [ 7893 ];
  };
}
