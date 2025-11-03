# modules/base.nix
{ config, pkgs, ... }:

{
  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Cockpit
  services.cockpit.enable = true;

  # Fail2Ban
  services.fail2ban = {
    enable = true;
    jails = {
      sshd = true;
      podman = true;
    };
  };

  # ddclient for dynamic DNS (example with Cloudflare)
  services.ddclient = {
    enable = true;
    protocol = "cloudflare";
    zones = [ "example.com" ];
    username = "your-email";
    password = "your-api-token";
    domains = [ "your-domain.example.com" ];
  };

  # lm-sensors for hardware monitoring
  environment.systemPackages = with pkgs; [ lm_sensors ];
}
