# First fleet node — standalone seed (no `seed` key in node.json).
{ ... }:
{
  networking.hostName = "nexus-node-1";

  services.nexus-node = {
    nodeId = "node-1";
    # Docker-only fleet: run the prebuilt image published by the
    # nexus release pipeline. EXPLICIT version pin — never a mutable
    # tag (:latest is the same trade as nixpkgs-unstable: convenient
    # for dev, wrong for a node you don't watch). Bump on release.
    # TODO(2.4 rehearsal): consider digest pinning
    # (ghcr.io/erykpecyna/nexus-node@sha256:...).
    containerImage = "ghcr.io/erykpecyna/nexus-node:0.1.0";
    # Module contract: null → key omitted from node.json.
    # TODO(operator): real geographic location of the VM host.
    latitude = null;
    longitude = null;
    # Log shipping to the monitoring stack on .213.
    lokiUrl = "http://192.168.0.213:3100/otlp/v1/logs";
  };

  # Remaining identity is DATA (module design): provisioning may
  # write /etc/nexus/node.json out-of-band; anything set there wins
  # over module-prepopulated keys.
}