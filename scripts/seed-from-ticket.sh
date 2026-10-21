#!/usr/bin/env bash
# seed-from-ticket.sh — extract a node's iroh NodeId from its
# EndpointTicket (the nexus_mgmt_ticket line). This is the --seed
# value for the NEXT node joining it.
#
# USAGE:
#   seed-from-ticket.sh <TICKET>        # TICKET = "endpoint..."
#   echo "$TICKET" | seed-from-ticket.sh
#
# WHY THIS EXISTS (2026-10-21 live lesson, node-2's first deploy):
# the ticket is NOT "NodeId + relay + addrs" concatenated. It is
#   "endpoint" + base32-nopad(
#     postcard(TicketWireFormat::Variant1(Variant1EndpointTicket {
#       addr: Variant1EndpointAddr {
#         id: PublicKey,                 # 32 raw bytes
#         info: Variant1AddrInfo { addrs } } })))
# i.e. the body decodes to [0x00 variant byte][32 raw key bytes]
# [serialized addrs...]. Hand-slicing "the first N chars" of the
# ticket yields the variant byte + 31 key bytes — an INVALID key.
# public_key_from_base32 rejects it with no ERROR-level trace, the
# join silently retries every 5s forever, and health's joined=false
# is the ONLY symptom.
#
# The binary's --seed parser (iroh decode_base32_hex) accepts HEX
# (64 chars) or BASE32 (52 chars) of the raw 32 NodeId bytes. This
# script prints HEX.
set -euo pipefail
T="${1:-$(cat)}"
[[ "$T" == endpoint* ]] || { echo "not an endpoint ticket: ${T:0:20}..." >&2; exit 1; }
python3 - "$T" <<'EOF'
import base64, sys
b = sys.argv[1][len("endpoint"):]
assert all(c in "abcdefghijklmnopqrstuvwxyz234567" for c in b), "non-base32 char in ticket body"
pad = (8 - len(b) % 8) % 8
body = base64.b32decode(b.upper() + "=" * pad)
assert body[0] == 0, "unexpected ticket variant byte"
print(body[1:33].hex())
EOF