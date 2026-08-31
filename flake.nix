{
  description = "nexus fleet — node archetypes and inventory (public)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The nexus source. Pinned BY TAG in steady state: releases move
    # this ref to the published tag (README "Releasing a new nexus
    # version"). Placeholder = current main until the first release
    # workflow exists.
    # TODO(3.3): point at the real release tag, e.g.
    #   nexus.url = "github:erykpecyna/nexus/v0.1.0";
    nexus.url = "github:erykpecyna/nexus/main";
    nexus.flake = true;

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nexus, nixos-generators, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      archetype = import ./archetypes/generic-x86_64.nix { inherit nexus; };
    in
    {
      # Per-node configs (inventory). node1 = first VM. Imports the
      # qcow format module so the toplevel is disk-bootable (and
      # identical to what nixosGenerate builds below).
      nixosConfigurations.node1 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          archetype
          ./nodes/node1.nix
          nixos-generators.nixosModules.qcow
        ];
      };

      # Bootable qcow2 disk image for node1 (hypervisor import).
      # NOTE: first build compiles nexus-node from source via the
      # nexus input (no binary cache yet). Evaluation stays fast.
      packages.${system}.node1-qcow2 =
        nixos-generators.nixosGenerate {
          inherit system;
          format = "qcow";
          modules = [ archetype ./nodes/node1.nix ];
        };
    };
}