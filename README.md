# nexus-fleet

Public fleet repository: node archetypes + inventory for the
[nexus](https://github.com/erykpecyna/nexus) overlay. Nodes are
self-sufficient; there are no secrets in this repo.

**Docker-only fleet (policy)**: this repo never reads or builds the
nexus source — "grabbing a built binary is ok, reading source is
NOT." Nodes run the prebuilt image `ghcr.io/erykpecyna/nexus-node:<version | canary | stable>`
published by the nexus repo's release pipeline (immutable `:X.Y.Z`
releases plus the two channel tags — see "Updating a node image").
This repo therefore holds no nexus input and no nexus-read
credentials, ever.

## Layout

- `flake.nix` — pins nixpkgs (matching the nexus repo's pin) +
  nixos-generators; NO nexus input
- `modules/nexus-node-fleet.nix` — MIRROR of the nexus NixOS module,
  docker mode only (prebuilt-image `docker run` service; option
  names must stay in sync with the canonical module in the nexus
  repo — it is the source of truth)
- `archetypes/generic-x86_64.nix` — standard node: nexus-node
  docker service, sshd (key-only), update-trust pubkey at
  `/etc/nexus/update-trust.pub`
- `nodes/*.nix` — one file per node: hostname, id, lat/lng, seed,
  image tag (channel or version pin)
- `keys/update-trust.pub` — minisign trust anchor

## Provisioning a new node

1. Copy `nodes/node1.nix` to `nodes/<name>.nix`; edit hostName,
   `nodeId`, lat/lng. A node that joins an existing overlay sets
   `services.nexus-node.seed` (iroh NodeId hex of a member); a node
   that starts its own overlay (standalone seed) leaves it unset.
   Set the image: `containerImage =
   "ghcr.io/erykpecyna/nexus-node:stable"` (a canary node would
   track `:canary`; an explicit `:X.Y.Z` pin also passes the eval
   gate).
2. Add the node to `flake.nix` (a `nixosConfigurations.<name>` entry
   plus a `packages.<system>.<name>-qcow2` following the node1
   pattern).
3. Evaluate (fast, no build, no nexus source):
   `nix eval .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath`
4. Build the disk image (fast — no nexus compilation; the node pulls
   its nexus image at runtime):
   `nix build .#packages.x86_64-linux.<name>-qcow2`
5. Import the qcow2 into the hypervisor; boot; SSH in with your key
   (root, port 22).
6. Write per-node identity if needed out-of-band:
   `/etc/nexus/node.json` (`id`, `lat`, `lng`; NO `seed` key on a
   hub/seed node).

## Updating a node image (2.4c — channel tags)

node-2 tracks `:canary`, node-1 tracks `:stable` (set in
`nodes/*.nix` — the files no longer change per release). The tags
move only inside logged nexus-repo workflow runs:

- `:canary` moves automatically as the LAST step of every release
  run (after the §6 mixed-version gate + GH release).
- `:stable` moves via the manual `promote` dispatch, once node-2 has
  soaked the canary. Promote doubles as the ROLLBACK lever.

Update procedure (no repo change, no yaml transfer):

1. Press "update stack" in the Unraid compose UI on node-2 (or
   `docker compose pull && docker compose up -d` on the host);
   verify the soak (health version, VL notes, cross-node recall).
2. From the nexus repo: `gh workflow run promote -f
   version=<X.Y.Z> -f channel=stable`, then press "update stack"
   on node-1.
   Pressing update on node-1 before the promote re-pulls the same
   digest and does nothing — canary-first ordering is enforced by
   the pipeline, not by discipline.

Rollback = promote an older version, press update stack. The ledger
of what runs where = GH releases + promote run history + VL
`nexus_peer_version` notes. While the GHCR package is private,
hosts need a one-time `docker login ghcr.io` (PAT with
`read:packages`; keep the PAT on the host only — never in this
repo).

## Local iteration (dev box, nexus repo)

Image development happens in the PRIVATE nexus repo — this repo
never builds images. `nix build .#nexus-node-docker && docker load <
result` there produces the identical image the release pipeline
publishes, so a locally tested image is exactly what a fleet node
runs (local = prod).

## Known TODOs

- ~~`keys/update-trust.pub` still says UNCONFIGURED~~ RESOLVED
  (minisign key `192AB4D245840C75`, 2026-08-31).
- ~~archetype root ssh key still `UNCONFIGURED`~~ RESOLVED
  (operator `id_ed25519.pub`, 2026-08-31).
- ~~nexus source pinned as a private flake input~~ RESOLVED 2026-09-04:
  docker-only fleet; input removed, mirror module added.
- Updater (Phase 4) will move nodes by digest-pinned image tags;
  rehearsal at roadmap 2.4.
- GHCR package is private for now — pull-smoke CI waits for the
  visibility flip.