# modules/permissions.nix
# This module handles permissions control, including Git version management for /etc/nixos,
# making key files immutable, sops-nix for secrets encryption, and auditd for monitoring changes.
# It enhances security by preventing accidental modifications and logging changes.
# Dependencies: sops-nix from flake inputs; integrates with Prometheus for alerts on changes.
# Usage: Imported in configuration.nix.

{ config, pkgs, lib, ... }:

{
  # Install Git for version control
  environment.systemPackages = with pkgs; [ git ];

  # Git initialization and auto-commit for /etc/nixos
  # Runs on activation to ensure repo exists and commits changes
  system.activationScripts.gitInit = {
    text = ''
      cd /etc/nixos
      if [ ! -d .git ]; then
        git init
        git add .
        git commit -m "Initial commit" || true
      else
        git add .
        git commit -m "Auto commit on activation" || true
      fi
    '';
    deps = [ ];  # No dependencies
  };

  # Make key Nix files immutable (chattr +i)
  system.activationScripts.setImmutable = {
    text = ''
      chattr +i /etc/nixos/*.nix || true  # Apply to all .nix files
      chattr +i /etc/nixos/flake.nix || true
      chattr +i /etc/nixos/configuration.nix || true
    '';
    deps = [ "gitInit" ];  # After Git init
  };

  # Sops-nix configuration (already in flake, but override defaults if needed)
  sops = {
    defaultSopsFile = ./secrets.yaml;  # Encrypted file
    age.keyFile = "/var/lib/sops/age-keys.txt";  # Secure key path
    # Example secrets (expand as needed)
    secrets = {
      example-secret = { path = "/etc/secret-file"; };  # Generic example
    };
  };

  # Auditd for monitoring configuration changes
  security.auditd = {
    enable = true;
    rules = [
      "-w /etc/nixos -p wa -k config-change"  # Watch writes/appends to /etc/nixos
      "-w /data -p wa -k data-change"  # Optional: watch /data for changes
    ];
  };

  # Integrate auditd logs with Prometheus for alerts (custom exporter or log parsing)
  # Note: Requires a custom auditd exporter or parsing script for metric
  services.prometheus.rules = lib.mkAfter [
    (pkgs.writeText "audit-alerts.yml" ''
      groups:
      - name: audit_alerts
        rules:
        - alert: ConfigChangeDetected
          expr: rate(audit_config_changes[5m]) > 0
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Configuration change detected"
            description: "Unauthorized change to monitored files (e.g., /etc/nixos)."
    '')
  ];

  # Pre-commit hook setup for Git (optional script)
  # This can be expanded with a custom hook script
  environment.etc."nixos/.git/hooks/pre-commit".text = ''
    #!/bin/sh
    nix flake check || { echo "Nix flake check failed"; exit 1; }
  '';
  environment.etc."nixos/.git/hooks/pre-commit".mode = "0755";
}
