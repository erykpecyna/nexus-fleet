{
  description = "nexus fleet — node archetypes and inventory (public)";

  inputs = {
    # Fleet's nixpkgs tracks the nexus repo's pin (follows nexus/nixpkgs):
    # the module/VM-test evidence lives against that exact nixpkgs, and
    # a divergent fleet pin could drift the closure. nexus bumps its
    # pin; fleet re-locks and inherits. (No url attr — a follows input
    # cannot also carry one.)
    nixpkgs.follows = "nexus/nixpkgs";

    # The nexus source. PRIVATE repo — pinned via git+ssh (evaluators
    # are the dev box + release CI with a deploy key; nodes never
    # evaluate this flake, they receive prebuilt closures via
    # nix copy / the attic substituter). Pinned BY TAG in steady
    # state: releases move this ref to the published tag (README
    # "Releasing a new nexus version"). Placeholder = current main
    # until the first release workflow exists.
    # TODO(3.3): point at the real release tag, e.g.
    #   nexus.url = "git+ssh://git@github.com/erykpecyna/nexus.git?ref=v0.1.0";
    nexus.url = "git+ssh://git@github.com/erykpecyna/nexus.git?ref=main";
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