# modules/prometheus.nix
# This module configures Prometheus for monitoring, including exporters, Grafana for visualization, and Alertmanager for alerts.
# It sets scrape intervals, rules for CPU, memory, BTRFS, and config changes, with notifications via Telegram and Email.
# Dependencies: Integrates with base.nix for ports; uses sops for sensitive credentials.
# Usage: Imported in configuration.nix (or replace base.nix monitoring section).

{ config, pkgs, lib, ... }:

{
  # Prometheus server
  services.prometheus = {
    enable = true;
    port = 9090;  # Web UI port
    scrapeInterval = "15s";
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" "processes" "cpu" "diskstats" "filesystem" "meminfo" "netdev" "loadavg" ];
        port = 9100;
      };
      podman = {
        enable = true;
        port = 9882;  # Podman metrics
      };
    };
    alertmanager = {
      enable = true;
      configuration = {
        route = {
          receiver = "telegram";  # Default to Telegram; group by severity if needed
        };
        receivers = {
          telegram = {
            webhook_config = {
              url = "https://api.telegram.org/bot${config.sops.secrets.telegram-bot-token.path}/sendMessage?chat_id=${config.sops.secrets.telegram-chat-id.path}";
            };
          };
          email = {
            to = "admin@example.com";
            from = "alerts@example.com";
            smarthost = "smtp.example.com:587";
            auth_username = config.sops.secrets.email-username.path;
            auth_password = config.sops.secrets.email-password.path;
          };
        };
      };
    };
    rules = [
      (pkgs.writeText "system-alerts.yml" ''
        groups:
        - name: system_alerts
          rules:
          - alert: HighCPUUsage
            expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "High CPU usage on {{ $labels.instance }}"
              description: "CPU usage is above 80% (current value: {{ $value }}%)"
          - alert: HighMemoryUsage
            expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 80
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "High memory usage on {{ $labels.instance }}"
              description: "Memory usage is above 80% (current value: {{ $value }}%)"
          - alert: BTRFSError
            expr: node_filesystem_errors{ fstype="btrfs" } > 0
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "BTRFS error detected on {{ $labels.device }}"
              description: "BTRFS filesystem errors > 0 (current value: {{ $value }})"
          - alert: ConfigFileChange
            expr: rate(audit_config_changes[5m]) > 0  # Assuming custom metric from auditd
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "Configuration file change detected"
              description: "Unauthorized change detected in monitored directories."
      '')
    ];
  };

  # Grafana for dashboards
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
      };
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://localhost:${toString config.services.prometheus.port}";
          isDefault = true;
        }
      ];
      dashboards.settings.providers = [
        {
          name = "default";
          orgId = 1;
          folder = "";
          type = "file";
          disableDeletion = false;
          updateIntervalSeconds = 10;
          options.path = ./dashboards;  # Directory with JSON files
        }
      ];
    };
  };

  # lm-sensors for hardware monitoring (integrated into node_exporter)
  environment.systemPackages = with pkgs; [ lm_sensors ];
  services.prometheus.exporters.node.enabledCollectors = lib.mkAfter [ "hwmon" ];  # Hardware monitors

  # Firewall openings for monitoring
  networking.firewall.allowedTCPPorts = [
    9090  # Prometheus
    3000  # Grafana
    9100  # Node exporter
    9882  # Podman exporter
  ];

  # Sops secrets for alertmanager
  sops.secrets = {
    telegram-bot-token = { };
    telegram-chat-id = { };
    email-username = { };
    email-password = { };
  };
}
