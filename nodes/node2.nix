# Second fleet node — JOINER (roadmap 2.5: the first live two-node
# iroh join, deliberately version-skewed). node-1 is the standalone
# anchor; this node joins it via `seed` (iroh base32 NodeId).
#
# THE SKEW IS THE DRILL: 0.2.0 here vs 0.2.1 on node-1 — the
# compatibility-story baseline. Expectation: the join works (proto
# additive-only convention) and the skew is INVISIBLE (the wire's
# NodeMessage.version is a dead literal, never read). That silence
# is the finding 0.3.0 fixes with peer-build-version observability;
# the Phase-3 drill re-runs this scenario to make the skew visible.
{ ... }:
{
  networking.hostName = "nexus-node-2";

  services.nexus-node = {
    nodeId = "node-2";
    # Docker-only fleet: prebuilt image from the nexus release
    # pipeline. EXPLICIT version pin — never a mutable tag. 0.2.0
    # (deliberately one release behind node-1's 0.2.1): the skew
    # drill's whole point — a fleet of independent nodes must have a
    # defined cross-version story before it grows.
    containerImage = "ghcr.io/erykpecyna/nexus-node:0.2.0";
    # Module contract: null → key omitted from node.json (defaults
    # apply). Both fleet nodes sit at the default position (0,0) —
    # same partition, simple JoinAccept path at 2 nodes.
    latitude = null;
    longitude = null;
    # Join node-1: its iroh NodeId, HEX (64 chars — the seed parser,
    # iroh decode_base32_hex, accepts hex or base32 of the raw 32 key
    # bytes). NEVER slice this from a ticket by hand: the ticket body
    # is postcard-serialized ([variant byte][key][addrs]) then
    # base32'd, so its first chars are the variant byte + 31 key
    # bytes — parses as NOTHING, and the join silently retries every
    # 5s forever (live lesson 2026-10-21: node-2's first deploy
    # shipped such a slice; health's joined=false was the only
    # symptom). Extract with: scripts/seed-from-ticket.sh <TICKET>.
    seed = "ee321274ca781441f4242973aa4c19d2b8fdf3cfa1c378dd4799231023db83b4";
    # Log shipping to VictoriaLogs (OTLP ingest) — docker DNS name
    # on the .213 nexus-net network (Unraid custom networks cannot
    # reach the host's own IP; see node1.nix for the live lesson).
    logsUrl = "http://victorialogs:9428/insert/opentelemetry/v1/logs";
    # Metrics push (VictoriaMetrics OTLP ingest) — same nexus-net
    # DNS rationale; the node appears in Grafana on its first push.
    metricsOtlpUrl = "http://victoria-metrics:8428/opentelemetry/v1/metrics";
    # Mgmt tunnel from day one (same as node-1): operator SSH over
    # the iroh overlay, zero inbound ports. Per-node token; SAME
    # operator authorized_keys (one key, many targets). HOST-LOCAL
    # secrets on the Unraid appdata share, bind-mounted at the
    # canonical paths — never in the image or node.json.
    mgmt = {
      enable = true;
      tokenFile = "/mnt/user/appdata/nexus-node-2/mgmt.token";
      operatorKeysFile = "/mnt/user/appdata/nexus-node-2/authorized_keys";
      targetPort = 22;
    };
  };

  # Remaining identity is DATA (module design): provisioning may
  # write /etc/nexus/node.json out-of-band; anything set there wins
  # over module-prepopulated keys.
}