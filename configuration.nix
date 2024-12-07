{ config, pkgs, ... }:

{
  imports = 
    [
      ./hardware-configuration.nix
    ];
  users.users.jacky = {
    isNormalUser = true;
    description = "jacky"
    extraGroup = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = [
        "SHA256:fwDU+/pMt7JubrGPpYp8qdksU5MlxzYq+aVRroCBWKU"
    ];
    packages = with pkgs; [
      #firefox
    ];
  };

  services.openssh = {
    enable = true;
    setting = {
      X11Forwarding = true;
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    openFirewall = true;
  };
}
