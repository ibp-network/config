#!/usr/bin/env python3
"""sync IBP bootnodes from upstream chainspecs.

reads bootnodes.json, looks up each chain's upstream chainspec (paritytech
chainspecs + paseo-network chain-specs cloned in ~/rotko), and:

  - replaces amforc and stakeplus entries with the canonical multiaddrs
    from upstream (matched by hostname). drops the entry for a chain
    where the operator doesn't run a bootnode upstream.

  - drops member keys that are not in the current IBP roster. today that
    means luckyfriday and metaspan; the list `DROP_MEMBERS` below is the
    source of truth, edit it when the roster changes.

  - optionally probes every /wss multiaddr in the result for a successful
    WebSocket-101 upgrade and reports anything that fails. this catches
    upstream entries that paritytech kept but are actually dead — happens
    occasionally when a chainspec PR drags in a stale operator entry.

usage:
    scripts/sync_bootnodes.py --dry-run        # diff only, no write
    scripts/sync_bootnodes.py                  # apply
    scripts/sync_bootnodes.py --probe          # apply + WS-101 probe
"""

from __future__ import annotations

import argparse
import json
import os
import re
import socket
import ssl
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Iterable

HOME = Path.home()
CONFIG = HOME / "rotko" / "config"
SDK = HOME / "rotko" / "chainspecs" / "submodules" / "polkadot-sdk"
PASEO = HOME / "rotko" / "paseo-specs"

# chain → upstream chainspec file. relays live under polkadot-sdk/polkadot,
# system parachains under polkadot-sdk/cumulus, paseo lives in its own repo.
# entries pointing at non-existent files are skipped (the script logs them
# and leaves the corresponding chain's bootnodes untouched).
SPEC = {
    # westend discontinued in early 2026 per the cost-saving feedback to
    # the bounty top-up proposal. paseo is the IBP testnet now.
    "polkadot":              SDK / "polkadot/node/service/chain-specs/polkadot.json",
    "kusama":                SDK / "polkadot/node/service/chain-specs/kusama.json",
    "paseo":                 PASEO / "paseo.raw.json",
    "asset-hub-polkadot":    SDK / "cumulus/parachains/chain-specs/asset-hub-polkadot.json",
    "asset-hub-kusama":      SDK / "cumulus/parachains/chain-specs/asset-hub-kusama.json",
    "asset-hub-paseo":       PASEO / "paseo-asset-hub.smol.json",
    "bridge-hub-polkadot":   SDK / "cumulus/parachains/chain-specs/bridge-hub-polkadot.json",
    "bridge-hub-kusama":     SDK / "cumulus/parachains/chain-specs/bridge-hub-kusama.json",
    "bridge-hub-paseo":      PASEO / "paseo-bridge-hub.raw.json",
    "collectives-polkadot":  SDK / "cumulus/parachains/chain-specs/collectives-polkadot.json",
    "coretime-polkadot":     SDK / "cumulus/parachains/chain-specs/coretime-polkadot.json",
    "coretime-kusama":       SDK / "cumulus/parachains/chain-specs/coretime-kusama.json",
    "coretime-paseo":        PASEO / "paseo-coretime.raw.json",
    "people-polkadot":       SDK / "cumulus/parachains/chain-specs/people-polkadot.json",
    "people-kusama":         SDK / "cumulus/parachains/chain-specs/people-kusama.json",
    "people-paseo":          PASEO / "paseo-people.raw.json",
}

# member key → hostname substring that uniquely identifies its multiaddrs
# in any upstream chainspec. matched against the /dns(4|6)?/<host>/ segment.
UPDATE_MEMBERS = {
    "amforc":    "amforc.com",
    "stakeplus": "stake.plus",
}

# members no longer in the IBP roster — every chain's entry for these keys
# is dropped. edit this list when the roster changes (the canonical source
# is members_professional.json; keep them in sync).
DROP_MEMBERS = ["helikon", "luckyfriday", "metaspan", "polkadotters"]

DNS_RE = re.compile(r"^/dns[46]?/([^/]+)")
TCP_PORT_RE = re.compile(r"/tcp/(\d+)")


def host_of(multiaddr: str) -> str | None:
    m = DNS_RE.match(multiaddr)
    return m.group(1) if m else None


def filter_by_host(addrs: list[str], substr: str) -> list[str]:
    return [a for a in addrs if (h := host_of(a)) and substr in h]


def load_upstream_bootnodes(path: Path) -> list[str] | None:
    if not path.exists():
        return None
    spec = json.loads(path.read_text())
    return spec.get("bootNodes", [])


def sync(bootnodes: dict, dry_run: bool) -> tuple[dict, list[str]]:
    """returns (updated bootnodes, log lines)."""
    log: list[str] = []
    out = json.loads(json.dumps(bootnodes))  # deep copy

    for chain, chain_obj in out.items():
        members = chain_obj.get("members", {})

        # drop offboarded members for every chain unconditionally.
        for m in DROP_MEMBERS:
            if m in members:
                log.append(f"  drop  {chain:<24} {m}")
                del members[m]

        # update members whose upstream entries may have rotated. requires
        # an upstream spec — if we can't resolve one, leave them alone and
        # log so the user can investigate.
        spec_path = SPEC.get(chain)
        if spec_path is None:
            log.append(f"  skip  {chain:<24} no upstream mapping")
            continue
        upstream = load_upstream_bootnodes(spec_path)
        if upstream is None:
            log.append(f"  skip  {chain:<24} upstream file missing ({spec_path})")
            continue

        for member, host_substr in UPDATE_MEMBERS.items():
            existing = members.get(member, [])
            new = filter_by_host(upstream, host_substr)
            if not new:
                # operator doesn't run a bootnode for this chain upstream —
                # drop our (presumably stale) entry. if the operator
                # legitimately runs one that paritytech just hasn't pulled
                # in yet, the right fix is upstream, not here.
                if existing:
                    log.append(f"  drop  {chain:<24} {member} (not in upstream)")
                    del members[member]
                continue
            if sorted(existing) == sorted(new):
                continue
            log.append(f"  fix   {chain:<24} {member}: {len(existing)} → {len(new)} addrs")
            members[member] = new

    return out, log


def wss_url(multiaddr: str) -> str | None:
    if "/wss" not in multiaddr:
        return None
    host = host_of(multiaddr)
    port_m = TCP_PORT_RE.search(multiaddr)
    if not host or not port_m:
        return None
    return f"{host}:{port_m.group(1)}"


def probe_wss(addr: str, timeout: float = 5.0) -> bool:
    """one TCP+TLS+HTTP-upgrade roundtrip. returns True iff server replies
    with `HTTP/1.1 101`. does not run libp2p — that's the deeper layer
    and we deliberately leave it out, see README.md in this directory."""
    target = wss_url(addr)
    if not target:
        # /tcp-only or malformed multiaddr — nothing reasonable to probe
        # from outside an actual libp2p stack, return True so it doesn't
        # show up as a failure for the wrong reason.
        return True
    host, port = target.split(":")
    try:
        with socket.create_connection((host, int(port)), timeout=timeout) as sock:
            ctx = ssl.create_default_context()
            with ctx.wrap_socket(sock, server_hostname=host) as tls:
                req = (
                    f"GET / HTTP/1.1\r\n"
                    f"Host: {host}\r\n"
                    f"Upgrade: websocket\r\n"
                    f"Connection: Upgrade\r\n"
                    f"Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
                    f"Sec-WebSocket-Version: 13\r\n"
                    f"\r\n"
                ).encode()
                tls.sendall(req)
                tls.settimeout(timeout)
                buf = b""
                while b"\r\n\r\n" not in buf and len(buf) < 4096:
                    chunk = tls.recv(1024)
                    if not chunk:
                        break
                    buf += chunk
                status_line = buf.split(b"\r\n", 1)[0] if buf else b""
                return b"101" in status_line
    except Exception:
        return False


def probe_all(bootnodes: dict) -> tuple[list[str], list[str]]:
    addrs: list[tuple[str, str, str]] = []
    for chain, obj in bootnodes.items():
        for member, list_ in obj.get("members", {}).items():
            for a in list_:
                addrs.append((chain, member, a))
    ok, bad = [], []
    print(f"\nprobing {len(addrs)} multiaddrs (WSS-101 only):", file=sys.stderr)
    with ThreadPoolExecutor(max_workers=16) as pool:
        futures = {pool.submit(probe_wss, a[2]): a for a in addrs}
        for fut in as_completed(futures):
            chain, member, addr = futures[fut]
            try:
                up = fut.result()
            except Exception:
                up = False
            label = f"{chain}/{member}: {addr}"
            (ok if up else bad).append(label)
    return ok, bad


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="print diff only, don't write")
    ap.add_argument("--probe", action="store_true", help="WS-101 probe every /wss multiaddr after sync")
    args = ap.parse_args()

    src = CONFIG / "bootnodes.json"
    bootnodes = json.loads(src.read_text())
    updated, log = sync(bootnodes, args.dry_run)

    print("\n=== changes ===", file=sys.stderr)
    if not log:
        print("  (none)", file=sys.stderr)
    for line in log:
        print(line, file=sys.stderr)

    if not args.dry_run:
        # match the upstream formatting exactly: 2-space indent, sorted keys
        # off (preserves the ecosystem grouping in the file).
        out = json.dumps(updated, indent=2) + "\n"
        src.write_text(out)
        print(f"\nwrote {src}", file=sys.stderr)
    else:
        print("\n(dry-run; bootnodes.json not modified)", file=sys.stderr)

    if args.probe:
        ok, bad = probe_all(updated if not args.dry_run else updated)
        print(f"\n=== probe results: {len(ok)} ok, {len(bad)} failed ===", file=sys.stderr)
        for label in sorted(bad):
            print(f"  fail  {label}", file=sys.stderr)
        return 1 if bad else 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
