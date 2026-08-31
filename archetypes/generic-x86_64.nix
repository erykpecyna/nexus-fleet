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
    # TODO(operator): replace with the operator's real id_ed25519.pub
    "ssh-ed25519 UNCONFIGURED provisioning"
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
}