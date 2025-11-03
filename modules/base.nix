# modules/base.nix
# This module configures base services for the NixOS system, including SSH, Cockpit, Fail2Ban, Prometheus, and Grafana.
# Dependencies: Relies on nixpkgs for packages; integrates with permissions.nix for auditd if needed.
# It sets up monitoring with exporters, alert thresholds, and notification channels.
# Usage: Imported in configuration.nix.

{ config, pkgs, lib, ... }:

{
  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";  # Disable root login for security
      PasswordAuthentication = false;  # Use keys only
      X11Forwarding = false;
    };
  };

  # Cockpit for web-based system management
  services.cockpit = {
    enable = true;
    port = 9090;  # Default port
    openFirewall = true;
  };

  # Fail2Ban for intrusion prevention
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    ignoreIP = [ "127.0.0.1/8" "::1" ];  # Ignore local IPs
    jails = {
      sshd = true;  # Protect SSH
      podman = true;  # Protect Podman if applicable
    };
  };

  # Prometheus monitoring
  services.prometheus = {
    enable = true;
    port = 9090;  # Prometheus web UI port
    scrapeInterval = "15s";
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" "processes" "cpu" "diskstats" "filesystem" "meminfo" "netdev" "loadavg" ];
        port = 9100;
      };
      # Podman exporter (adjust if using custom exporter for Podman metrics)
      podman = {
        enable = true;
        port = 9882;  # Default Podman metrics port
      };
    };
    alertmanager = {
      enable = true;
      configuration = {
        route = {
          receiver = "telegram";  # Default receiver
        };
        receivers = {
          telegram = {
            botToken = { _secret = config.sops.secrets.telegram-bot-token.path; };  # From sops
            chatId = { _secret = config.sops.secrets.telegram-chat-id.path; };
          };
          email = {
            to = "admin@example.com";  # Configure email receiver
            smtp = {
              from = "alerts@example.com";
              smarthost = "smtp.example.com:587";
              auth_username = { _secret = config.sops.secrets.email-username.path; };
              auth_password = { _secret = config.sops.secrets.email-password.path; };
            };
          };
        };
      };
    };
    rules = [
      (pkgs.writeText "alerts.yml" ''
        groups:
        - name: system_alerts
          rules:
          - alert: HighCPUUsage
            expr: rate(node_cpu_seconds_total{mode="idle"}[5m]) > 0.8
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "High CPU usage detected"
              description: "CPU usage is above 80% for more than 5 minutes."
          - alert: BTRFSError
            expr: btrfs_errors > 0  # Adjust metric based on exporter
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "BTRFS error detected"
              description: "BTRFS filesystem error count is greater than 0."
          - alert: HighMemoryUsage
            expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.8
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "High memory usage detected"
              description: "Memory usage is above 80% for more than 5 minutes."
          - alert: ConfigFileChange
            expr: audit_config_changes > 0  # Metric from auditd exporter or custom
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "Configuration file change detected"
              description: "Unauthorized change to /etc/nixos detected."
      '')
    ];
  };

  # Grafana for visualization
  services.grafana = {
    enable = true;
    settings.server = {
      http_port = 3000;
      http_addr = "127.0.0.1";  # Local access; proxy via Traefik if needed
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://localhost:9090";
        }
      ];
      dashboards.settings.providers = [
        {
          name = "system";
          orgId = 1;
          folder = "";
          type = "file";
          disableDeletion = false;
          updateIntervalSeconds = 10;
          options.path = ./dashboards/system.json;  # Import JSON dashboard
        }
      ];
    };
  };

  # lm-sensors for hardware monitoring
  hardware.sensor.lm_sensors.enable = true;

  # Open firewall ports for base services
  networking.firewall.allowedTCPPorts = [ 22 9090 3000 9100 9882 ];  # SSH, Cockpit, Prometheus, Grafana, exporters
}
