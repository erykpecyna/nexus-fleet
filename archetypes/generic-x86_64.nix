# Generic x86_64 nexus node archetype (PLAN_FLEET_ROADMAP.md 2.2).
#
# Every node module imports this and overlays machine-specific
# settings (hostname, id, location, seed). The nexus-node service,
# sshd, firewall and the updater trust anchor are fixed here so one
# archetype defines what "a nexus node" is.
{ nexus }:
{ config, lib, pkgs, ... }:
{
  imports = [ nexus.nixosModules.nexus-node ];

  services.nexus-node = {
    enable = true;
    # metrics/loki defaults come from the nexus module; per-node
    # overrides belong in nodes/*.nix, not here.
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  users.users.root.openssh.authorizedKeys.keys = [
    # Operator's provisioning key (roadmap 2.2 close-out).
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFJKbSslrYfa1Kcs0wgiQjwdPOfgr9YQJE9iLhf2MIc1 eryk.pecyna@gmail.com"
  ];

  networking.firewall.allowedTCPPorts = [ 22 ];

  # Trust anchor for the updater (minisign public key; see
  # PLAN_FLEET_ROADMAP.md 2.1/3.3). Provisioned at image build;
  # replaced by re-imaging, never edited in place.
  environment.etc."nexus/update-trust.pub" = {
    source = ../keys/update-trust.pub;
    mode = "0644";
  };

  # Bound disk/generation growth on unattended nodes.
  nix.gc.automatic = lib.mkDefault true;
  nix.gc.options = lib.mkDefault "--delete-older-than 30d";
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 10;

  # NixOS 25.05 was current when the fleet repo was created. Bump only
  # deliberately (migration notes per release).
  system.stateVersion = "25.05";
}
