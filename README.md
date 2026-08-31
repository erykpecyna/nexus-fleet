# nexus-fleet

Public fleet repository: NixOS archetypes + node inventory for the
[nexus](https://github.com/erykpecyna/nexus) overlay. Nodes are
self-sufficient; there are no secrets in this repo.

## Layout

- `flake.nix` — pins nixpkgs and nexus (by tag once releases exist)
- `archetypes/generic-x86_64.nix` — standard node: nexus-node service,
  sshd (key-only), update-trust pubkey at `/etc/nexus/update-trust.pub`
- `nodes/*.nix` — one file per node: hostname, id, lat/lng, seed
- `keys/update-trust.pub` — minisign trust anchor (see UNCONFIGURED)

## Provisioning a new node

1. Copy `nodes/node1.nix` to `nodes/<name>.nix`; edit id/hostName/
   lat/lng. A node that joins an existing overlay sets
   `services.nexus-node.seed`; a node that starts its own overlay
   (standalone seed) leaves it unset.
2. Add the node to `flake.nix` (a `nixosConfigurations.<name>` entry
   plus a `packages.<system>.<name>-qcow2` following the node1
   pattern).
3. Evaluate (fast, no build):
   `nix eval .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath`
4. Build the disk image (slow; builds nexus-node from source until a
   binary cache exists):
   `nix build .#packages.x86_64-linux.<name>-qcow2`
5. Import the qcow2 into the hypervisor; boot; SSH in with your key
   (root, port 22).
6. Write per-node identity if needed out-of-band:
   `/etc/nexus/node.json` (`id`, `lat`, `lng`; NO `seed` key on a
   hub/seed node).

## Releasing a new nexus version (once the release workflow exists)

Bump the `nexus` input to the release tag:

    nix flake lock --update-input nexus

The release workflow in the nexus repo will do this automatically
(planned Phase 3.3); the manual path here is only a fallback.

## Known TODOs

- `keys/update-trust.pub` still says UNCONFIGURED
  (operator: `cp ~/nexus-trust/update-trust.pub keys/update-trust.pub`).
- archetype root ssh key still `UNCONFIGURED`.
- Binary cache (attic) deferred; image builds are source builds.