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
    # pipeline. EXPLICIT version pin — never a mutable tag.
    # 0.4.0 (2026-10-22): the honest-severities logging reform —
    # node-2 is the CANARY (joiner-first, as always): it moves to
    # 0.4.0 first while node-1 still runs 0.2.1; the mixed-version
    # release gate already proved 0.3.0↔0.4.0 in CI before the tag
    # could exist. Post-rollout, the note lines (nexus_join,
    # nexus_peer_version, nexus_mgmt_ticket, nexus_mgmt_audit
    # open/closed) ship at severity_text=INFO in VictoriaLogs (deny
    # = WARNING) — the retired severity-as-visibility ERROR notes are
    # gone; queries keyed on _msg prefixes are unaffected. The
    # acceptance soak (roadmap 2.4b): ERROR = 0/hr, WARNING ≈ 0/hr,
    # INFO ≈ boot narrative only.
    # 0.3.0 (2026-10-21): the Phase-3 OBSERVABLE-SKEW drill — the
    # joiner-first canary. node-2 (joiner) moved to the 0.3.0 compat
    # cut while node-1 (anchor) deliberately stayed at 0.2.1: the new
    # binary's peer-version observability must fire in VictoriaLogs
    # (nexus_peer_version peer=node-1 build=(none: pre-observability
    # binary) ours=0.3.0) while the join + cross-node recall keep
    # working — the exact scenario the 2.4a baseline drill proved
    # INVISIBLE. 0.2.0 was the first-join pin (the 2.4a baseline:
    # joined live, skew invisible, live seed-extraction lesson).
    containerImage = "ghcr.io/erykpecyna/nexus-node:0.4.0";
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