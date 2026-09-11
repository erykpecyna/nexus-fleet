# MIRROR of the nexus repo's nix/module.nix — DOCKER MODE ONLY.
# (PLAN_GHCR_FLEET.md WS3; policy: "grabbing a built binary is ok,
# reading source IS NOT" — this repo is public and must never hold a
# credential that reads the private nexus repo, so it cannot import
# the canonical module.)
#
# Keep the option names + semantics in sync with the canonical module;
# it is the source of truth. The eval gates in .github/workflows/
# eval.yml assert this mirror's surface and act as a tripwire when
# the canonical schema drifts.
#
# The image this module runs is built ONLY in the nexus repo:
#   - release pipeline: release.yml pushes it to
#     ghcr.io/erykpecyna/nexus-node:<version>
#   - local iteration:  nix build .#nexus-node-docker (nexus repo)
#     produces the IDENTICAL image — dev-testing = rehearsing
#     production.
# Image contract: REST 8080, gRPC 9090 (legacy), metrics 9464, state
# VOLUME /var/lib/nexus (iroh key persistence), config
# /etc/nexus/node.json, NEXUS_LOKI_URL + NEXUS_METRICS_OTLP_URL read
# by the binary.
{ config, lib, pkgs, ... }:

let
  cfg = config.services.nexus-node;

  # Same key set as the canonical module's docker mode. Null values
  # are omitted; the image wrapper's defaults apply for missing keys.
  nodeJson = lib.filterAttrs (_: v: v != null) {
    id = cfg.nodeId;
    lat = cfg.latitude;
    lng = cfg.longitude;
    seed = cfg.seed;
    advertise_address = cfg.advertiseAddress;
    data_dir = cfg.dataDir;
    transport = cfg.transport;
    key_path = cfg.keyPath;
    relay_urls = if cfg.relayUrls != [ ] then cfg.relayUrls else null;
    loki_url = cfg.lokiUrl;
    metrics_otlp_url = cfg.metricsOtlpUrl;
    rest_port = 8080;
    metrics_port = if cfg.metricsEnabled then 9464 else null;
  } // (if cfg.mgmt.enable then {
    # Same contract as the canonical module's docker mode: node.json
    # points at the canonical container path; the ExecStart below
    # bind-mounts the host token file there.
    mgmt_listen = true;
    mgmt_token_file = "/etc/nexus/mgmt.token";
    mgmt_target_port = cfg.mgmt.targetPort;
  } else { });
in
{
  options.services.nexus-node = {
    enable = lib.mkEnableOption "nexus overlay node (prebuilt docker image)";

    # NOTE: no `package` option — this repo never builds nexus from
    # source (the whole point of the mirror).

    containerImage = lib.mkOption {
      type = lib.types.str;
      description =
        "Docker image to run. Pin an explicit version tag — a node "
        + "must never float on a mutable tag (e.g. "
        + ''ghcr.io/erykpecyna/nexus-node:0.1.0, NOT :latest).'';
    };

    nodeId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Stable node identifier (writes /etc/nexus/node.json).";
    };
    latitude = lib.mkOption {
      type = lib.types.nullOr lib.types.float;
      default = null;
    };
    longitude = lib.mkOption {
      type = lib.types.nullOr lib.types.float;
      default = null;
    };
    seed = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Seed node to join: iroh NodeId hex. Null = standalone seed.";
    };
    advertiseAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    dataDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Directory containing restaurant.json. Null = empty profile.";
    };
    restPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Host-side REST port (container listens on 8080; this is the -p mapping).";
    };

    metricsEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Prometheus metrics endpoint on the node.";
    };
    metricsPort = lib.mkOption {
      type = lib.types.port;
      default = 9464;
      description = "Host-side Prometheus metrics port (container listens on 9464; this is the -p mapping).";
    };

    lokiUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description =
        "OTLP/HTTP URL for Loki log ingest "
        + "(e.g. http://loki:3100/otlp/v1/logs). Null = disabled.";
    };

    metricsOtlpUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description =
        "OTLP/HTTP push URL for metrics — VictoriaMetrics "
        + "(e.g. http://vm:8428/opentelemetry/v1/metrics). Null = "
        + "disabled; the pull endpoint (metricsPort) is independent "
        + "of this. Push is how nodes appear in Grafana on first boot.";
    };

    transport = lib.mkOption {
      type = lib.types.enum [ "grpc" "iroh" ];
      default = "iroh";
      description =
        "Node-to-node transport backend. iroh is the fleet default; "
        + "grpc is legacy (kept until retired after burn-in).";
    };

    keyPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description =
        "Path to the iroh secret key file, container-internal "
        + "(base32, auto-generated on first boot; iroh transport "
        + "only). Default when null: /var/lib/nexus/node.key (the "
        + "state bind mount — persistent across container restarts).";
    };

    relayUrls = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Custom iroh relay URLs (empty = n0 public relays; iroh transport only).";
    };

    # Mgmt tunnel (option parity with the canonical module's
    # services.nexus-node.mgmt — docs/MGMT_TUNNEL.md in the private
    # repo). Operator SSH over the overlay, no inbound ports; a
    # shared token gates the tunnel, sshd's authorized_keys gates
    # the shell.
    mgmt = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable the mgmt tunnel ALPN (iroh transport only): operator SSH over the overlay, no inbound ports.";
      };
      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Host path to the shared tunnel token (single line, mode 0600). Bind-mounted into the container at /etc/nexus/mgmt.token (node.json points the binary there). Null/empty = mgmt enabled but nobody allowed.";
      };
      operatorKeysFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Host path to an authorized_keys-format file with the fleet operator public key (0600, provisioned at deploy like tokenFile). Bind-mounted into the container at /etc/nexus/authorized_keys (the in-image sshd's AuthorizedKeysFile — the image ships sshd on 127.0.0.1:22, key-only). Never bake keys into the image or node.json. Null = tunnel up but sshd permits no one (fail-closed).";
      };
      targetPort = lib.mkOption {
        type = lib.types.port;
        default = 22;
        description = "Container-local port mgmt tunnels reach (default 22 = the in-image sshd). Only this port is ever dialable, loopback only.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;

    # Identity is DATA: same node.json contract as the canonical
    # module (mounted read-only into the container).
    environment.etc."nexus/node.json" = lib.mkIf (nodeJson != { }) {
      text = builtins.toJSON nodeJson;
      mode = "0644";
    };

    systemd.services.nexus-node = {
      description = "Nexus overlay node (docker)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "docker.service" ];
      wants = [ "network-online.target" "docker.service" ];
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " ([
          "${pkgs.docker}/bin/docker"
          "run"
          "--rm"
          "--name nexus-node"
          "-v /etc/nexus/node.json:/etc/nexus/node.json:ro"
          "-v /var/lib/nexus:/var/lib/nexus"
          "-p ${toString cfg.restPort}:8080"
        ] ++ lib.optionals cfg.metricsEnabled [
          "-p ${toString cfg.metricsPort}:9464"
        ] ++ lib.optionals (cfg.transport == "grpc") [
          "-p 9090:9090"
        ] ++ lib.optionals (cfg.lokiUrl != null) [
          "-e NEXUS_LOKI_URL=${cfg.lokiUrl}"
        ] ++ lib.optionals (cfg.metricsOtlpUrl != null) [
          "-e NEXUS_METRICS_OTLP_URL=${cfg.metricsOtlpUrl}"
        ] ++ lib.optionals (cfg.mgmt.enable && cfg.mgmt.tokenFile != null) [
          # Host-local secret material — bind-mounted read-only, never
          # baked into the image or the world-readable node.json.
          "-v ${toString cfg.mgmt.tokenFile}:/etc/nexus/mgmt.token:ro"
        ] ++ lib.optionals (cfg.mgmt.enable && cfg.mgmt.operatorKeysFile != null) [
          # Operator identity is mounted data too: the in-image sshd
          # reads /etc/nexus/authorized_keys (key-only, loopback
          # only — reachable solely through the token-gated tunnel).
          # The image wrapper normalizes ownership/mode before sshd
          # starts (sshd StrictModes).
          "-v ${toString cfg.mgmt.operatorKeysFile}:/etc/nexus/authorized_keys:ro"
        ] ++ [
          cfg.containerImage
        ]);
        ExecStop = "-${pkgs.docker}/bin/docker stop nexus-node";
        Restart = "always";
        RestartSec = 5;
        StateDirectory = "nexus";
      };
    };

    # iroh needs no inbound ports (QUIC + hole-punching/relays by
    # design); rest/metrics are host-side -p mappings.
    networking.firewall.allowedTCPPorts =
      [ cfg.restPort ]
      ++ lib.optionals (cfg.transport == "grpc") [ 9090 ]
      ++ lib.optionals cfg.metricsEnabled [ cfg.metricsPort ];
  };
}