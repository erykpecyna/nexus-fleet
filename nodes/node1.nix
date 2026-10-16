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
    # NOTE (2026-10-16): 0.2.0 is the FIRST released cut — 0.1.x was
    # never shipped on this plane (the flake version jumped straight
    # to 0.2.0 when the mgmt tunnel landed in the image).
    # TODO(2.4 rehearsal): consider digest pinning
    # (ghcr.io/erykpecyna/nexus-node@sha256:...).
    containerImage = "ghcr.io/erykpecyna/nexus-node:0.2.0";
    # Module contract: null → key omitted from node.json.
    # TODO(operator): real geographic location of the VM host.
    latitude = null;
    longitude = null;
    # Log shipping to the monitoring stack on .213 (VictoriaLogs
    # OTLP ingest).
    logsUrl = "http://192.168.0.213:9428/insert/opentelemetry/v1/logs";
    # Metrics push (VictoriaMetrics OTLP ingest) — the node appears
    # in Grafana on its first push; no scrape config needed.
    metricsOtlpUrl = "http://192.168.0.213:8428/opentelemetry/v1/metrics";
    # Mgmt tunnel (docs/MGMT_TUNNEL.md in the private repo): operator
    # SSH over the iroh overlay — zero inbound ports (the tunnel rides
    # the node's own iroh endpoint; the firewall above is unchanged).
    # Token + operator authorized_keys are HOST-LOCAL data on the
    # Unraid appdata share, bind-mounted read-only into the container
    # at the canonical paths — never in the image, never in node.json
    # (which is 0644). The paths mirror the actual .213 deployment.
    mgmt = {
      enable = true;
      tokenFile = "/mnt/user/appdata/nexus-node-1/mgmt.token";
      operatorKeysFile = "/mnt/user/appdata/nexus-node-1/authorized_keys";
      targetPort = 22;
    };
  };

  # Remaining identity is DATA (module design): provisioning may
  # write /etc/nexus/node.json out-of-band; anything set there wins
  # over module-prepopulated keys.
}