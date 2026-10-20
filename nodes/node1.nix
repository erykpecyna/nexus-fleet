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
    # 0.2.1 (2026-10-20): the 2.4 update-rehearsal bump (pure version
    # change; carries the wrapper EROFS fix). 0.2.0 was the FIRST
    # released cut — 0.1.x never shipped on this plane. The 2.4
    # rehearsal (update → commanded rollback → roll-forward, NodeId
    # stable throughout) proved version-tag pinning end-to-end;
    # digest pinning (@sha256:…, digests in each release run
    # summary) remains optional hardening.
    containerImage = "ghcr.io/erykpecyna/nexus-node:0.2.1";
    # Module contract: null → key omitted from node.json.
    # TODO(operator): real geographic location of the VM host.
    latitude = null;
    longitude = null;
    # Log shipping to VictoriaLogs (OTLP ingest). Docker DNS name on
    # the .213 `nexus-net` user-defined network — Unraid custom
    # networks (br0, macvlan OR ipvlan) cannot reach the host's own
    # IP, so the URL is a container name, never 192.168.0.213 (found
    # live 2026-10-19: every OTLP push from a br0 node timed out;
    # node-1 runs dual-network br0 + nexus-net).
    logsUrl = "http://victorialogs:9428/insert/opentelemetry/v1/logs";
    # Metrics push (VictoriaMetrics OTLP ingest) — same nexus-net
    # DNS rationale; the node appears in Grafana on its first push.
    metricsOtlpUrl = "http://victoria-metrics:8428/opentelemetry/v1/metrics";
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