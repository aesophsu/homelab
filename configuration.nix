# configuration.nix
{ config, pkgs, ... }:

{
  imports = [
    ./modules/base.nix
    ./modules/btrfs.nix
    ./modules/nftables.nix
    ./modules/containers.nix
    ./modules/permissions.nix
  ];

  # System-wide settings
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos-server";
  time.timeZone = "Asia/Shanghai";

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
  ];

  users.users.root = {
    openssh.authorizedKeys.keys = [ "your-ssh-public-key-here" ];
  };

  system.stateVersion = "25.11";
}
