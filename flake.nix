{
  description = "nexus fleet — node archetypes and inventory (public)";

  inputs = {
    # Pinned directly (was follows = nexus/nixpkgs — the follows
    # workaround existed only because this repo consumed the private
    # nexus source, which it no longer does; POLICY: the fleet is
    # docker-only, it never reads nexus source, only prebuilt
    # ghcr.io/erykpecyna/nexus-node:<version> images). The pin
    # matches the nexus repo's nixpkgs rev (its module/VM-test
    # evidence lives against that nixpkgs); bump deliberately.
    nixpkgs.url = "github:NixOS/nixpkgs/d2f67949798825fe853f7c5d0492b8bf016d3f88";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, ... }:
    let
      system = "x86_64-linux";
      archetype = import ./archetypes/generic-x86_64.nix;
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
      # Docker-only fleet: no nexus source build here — the node boots
      # and pulls its nexus image at runtime. Evaluation is fast.
      packages.${system}.node1-qcow2 =
        nixos-generators.nixosGenerate {
          inherit system;
          format = "qcow";
          modules = [ archetype ./nodes/node1.nix ];
        };
    };
}