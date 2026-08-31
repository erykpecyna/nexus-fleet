# First fleet node — standalone seed (no `seed` key in node.json).
{ ... }:
{
  networking.hostName = "nexus-node-1";

  services.nexus-node = {
    nodeId = "node-1";
    # Module contract: null → key omitted from node.json.
    # TODO(operator): real geographic location of the VM host.
    latitude = null;
    longitude = null;
  };

  # Remaining identity is DATA (module design): provisioning may
  # write /etc/nexus/node.json out-of-band; anything set there wins
  # over module-prepopulated keys.
}