# modules/btrfs.nix
# This module configures BTRFS storage, snapshots, shares (Samba/NFS), and backups.
# It includes Nextcloud and OpenList containers for file management and WebDAV.
# Dependencies: Relies on Podman from virtualisation; integrates with permissions.nix for group access.
# Sets up weekly scrub, snapper timelines, and rsync backup timer.
# Usage: Imported in configuration.nix.

{ config, pkgs, lib, ... }:

{
  # BTRFS filesystem configuration
  fileSystems."/data" = {
    device = "/dev/sda";  # Adjust to your SSD device
    fsType = "btrfs";
    options = [ "subvol=data" "compress=zstd" "autodefrag" "noatime" ];
  };

  # Additional subvolumes (created via activation script)
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    btrfs subvolume create /data/logs || true
    btrfs subvolume create /data/snapshots || true
  '';

  # BTRFS autoScrub
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    fileSystems = [ "/data" ];
  };

  # Snapper for snapshots
  services.snapper = {
    configs.data = {
      subvolume = "/data";
      allowUsers = [ "admin" ];  # Allow admin to manage snapshots
      timelineCreate = true;
      timelineCleanup = true;
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 3;
    };
  };

  # Shared group for data access
  users.groups.data = { };

  # Samba sharing
  services.samba = {
    enable = true;
    openFirewall = true;
    extraConfig = ''
      [data]
      path = /data
      browseable = yes
      writable = yes
      guest ok = no
      valid users = @data
    '';
  };

  # NFS sharing
  services.nfs.server = {
    enable = true;
    exports = ''
      /data *(rw,sync,no_subtree_check)
    '';
  };
  networking.firewall.allowedTCPPorts = [ 2049 ];  # NFS port
  networking.firewall.allowedUDPPorts = [ 2049 ];

  # Nextcloud container (WebDAV integrated)
  virtualisation.oci-containers.containers.nextcloud = {
    image = "nextcloud:latest";
    autoStart = true;
    volumes = [ "/data/nextcloud:/var/www/html" ];
    ports = [ "8080:80" ];
    environment = {
      TZ = "Asia/Shanghai";
    };
    extraOptions = [ "--network=bridge" "--restart=unless-stopped" "--log-driver=journald" ];
    dependsOn = [ ];  # No dependencies
    limits = { cpu = "1"; memory = "1G"; };
    healthcheck = {
      test = [ "CMD-SHELL" "curl -f http://localhost || exit 1" ];
      interval = "30s";
    };
  };
  networking.firewall.allowedTCPPorts = [ 8080 ];  # Nextcloud port

  # OpenList container (file browser)
  virtualisation.oci-containers.containers.openlist = {
    image = "some/openlist-image:latest";  # Replace with actual image
    autoStart = true;
    volumes = [ "/data:/data" ];
    ports = [ "8081:80" ];  # Example port
    environment = {
      TZ = "Asia/Shanghai";
    };
    extraOptions = [ "--network=bridge" "--restart=unless-stopped" "--log-driver=journald" ];
    dependsOn = [ ];  # No dependencies
    limits = { cpu = "0.5"; memory = "512M"; };
    healthcheck = {
      test = [ "CMD-SHELL" "curl -f http://localhost || exit 1" ];
      interval = "30s";
    };
  };
  networking.firewall.allowedTCPPorts = [ 8081 ];  # OpenList port

  # Backup timer and service (rsync weekly)
  systemd.timers.backup-data = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  systemd.services.backup-data = {
    description = "Rsync backup of /data";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.rsync}/bin/rsync -a --delete /data/ remote:/backup/data/";  # Adjust remote destination
    };
  };

  # TRIM support for SSD
  services.fstrim.enable = true;
}
