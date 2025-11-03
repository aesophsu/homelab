# flake.nix
# This file defines the Flake inputs and outputs for the NixOS system.
# It includes nixpkgs and sops-nix as dependencies.
# The system configuration is defined for hostname 'nixos'.
# Usage: nixos-rebuild switch --flake .#nixos

{
  description = "NixOS All-in-One Family Server Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";  # Ensure sops-nix follows the same nixpkgs version
  };

  outputs = { self, nixpkgs, sops-nix }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";  # Adjust if needed for other architectures
      modules = [
        sops-nix.nixosModules.sops  # Import sops-nix for secrets management
        ./configuration.nix  # Main configuration that imports all modules
      ];
    };
  };
}
