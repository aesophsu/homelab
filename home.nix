{ config, pkgs, ...};

{
  home.username = "jacky";
  home.homeDirectory = "/home/jacky"
  home.packages = with pkgs;[
    tree
  ];
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;
}
