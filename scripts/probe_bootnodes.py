#!/usr/bin/env python3
"""probe every /wss bootnode in bootnodes.json. write a markdown report of
what's unreachable, and (with --clean) drop dead entries from the file.

uses the `websockets` library so we exercise the same path the browser
does: TLS + HTTP/1.1 Upgrade + 101. it deliberately does not run libp2p
Noise on top — see scripts/sync_bootnodes.py for the rationale. a node
that completes the WS upgrade is treated as reachable; one that doesn't
gets flagged.

usage:
    scripts/probe_bootnodes.py                            # probe + report only
    scripts/probe_bootnodes.py --clean                    # also drop dead entries
    scripts/probe_bootnodes.py --report path/to/file.md   # custom report path
"""

from __future__ import annotations

import argparse
import asyncio
import json
import re
import ssl
import sys
from collections import defaultdict
from pathlib import Path

import websockets

HOME = Path.home()
CONFIG = HOME / "rotko" / "config"
SRC = CONFIG / "bootnodes.json"
DEFAULT_REPORT = CONFIG / "BOOTNODES-HEALTH.md"

DNS_RE = re.compile(r"^/dns[46]?/([^/]+)")
IP4_RE = re.compile(r"^/ip4/([^/]+)")
IP6_RE = re.compile(r"^/ip6/([^/]+)")
TCP_PORT_RE = re.compile(r"/tcp/(\d+)")

PROBE_TIMEOUT = 6.0
CONCURRENCY = 20


def wss_url(multiaddr: str) -> str | None:
    if "/wss" not in multiaddr:
        return None
    host = (
        DNS_RE.match(multiaddr) or IP4_RE.match(multiaddr) or IP6_RE.match(multiaddr)
    )
    port = TCP_PORT_RE.search(multiaddr)
    if not host or not port:
        return None
    return f"wss://{host.group(1)}:{port.group(1)}"


async def probe_one(multiaddr: str) -> tuple[bool, str]:
    url = wss_url(multiaddr)
    if url is None:
        # /tcp-only — browsers can't reach it. don't grade; mark "skipped".
        return True, "tcp-only (not browser-reachable)"
    try:
        async with asyncio.timeout(PROBE_TIMEOUT):
            # default SSL context with system CAs. the server will probably
            # close right after our handshake completes (libp2p Noise
            # mismatch), which is fine — we only care that the WS upgrade
            # negotiated cleanly. websockets raises on handshake failure
            # and that's what we're testing for.
            async with websockets.connect(
                url,
                open_timeout=PROBE_TIMEOUT,
                close_timeout=1.0,
                ssl=ssl.create_default_context(),
            ):
                return True, "ok"
    except asyncio.TimeoutError:
        return False, f"timeout after {PROBE_TIMEOUT}s"
    except websockets.exceptions.InvalidStatus as e:
        return False, f"HTTP {e.response.status_code}"
    except websockets.exceptions.InvalidHandshake as e:
        return False, f"handshake: {e}"
    except ssl.SSLError as e:
        return False, f"TLS: {e}"
    except OSError as e:
        return False, f"net: {e}"
    except Exception as e:  # noqa: BLE001
        return False, f"{type(e).__name__}: {e}"


async def probe_all(bootnodes: dict) -> dict:
    """returns { chain → { member → [(multiaddr, ok, reason)] } }."""
    semaphore = asyncio.Semaphore(CONCURRENCY)

    async def gated(addr: str) -> tuple[bool, str]:
        async with semaphore:
            return await probe_one(addr)

    tasks: list[tuple[str, str, str, asyncio.Task]] = []
    for chain, obj in bootnodes.items():
        for member, addrs in obj.get("members", {}).items():
            for addr in addrs:
                tasks.append((chain, member, addr, asyncio.create_task(gated(addr))))

    print(f"probing {len(tasks)} multiaddrs (concurrency {CONCURRENCY})…", file=sys.stderr)
    results: dict[str, dict[str, list]] = defaultdict(lambda: defaultdict(list))
    done = 0
    for chain, member, addr, task in tasks:
        ok, reason = await task
        results[chain][member].append((addr, ok, reason))
        done += 1
        if done % 20 == 0:
            print(f"  {done}/{len(tasks)}…", file=sys.stderr)
    return results


def write_report(results: dict, path: Path, clean: bool) -> None:
    total = 0
    failed: list[tuple[str, str, str, str]] = []
    skipped = 0
    for chain, by_member in sorted(results.items()):
        for member, rows in sorted(by_member.items()):
            for addr, ok, reason in rows:
                total += 1
                if reason.startswith("tcp-only"):
                    skipped += 1
                    continue
                if not ok:
                    failed.append((chain, member, addr, reason))

    lines = [
        "# Bootnode health report",
        "",
        f"Probed **{total}** multiaddrs; **{skipped}** skipped (/tcp-only, not browser-reachable);",
        f"**{total - skipped - len(failed)}** reachable; **{len(failed)}** unreachable.",
        "",
    ]
    if clean:
        lines.append("Dead entries have been removed from `bootnodes.json` by this run.")
    else:
        lines.append("Run with `--clean` to drop the entries listed below from `bootnodes.json`.")
    lines.append("")

    lines.append("## Unreachable from WSS-101 probe")
    lines.append("")
    lines.append("Grouped by chain and member. `reason` is the underlying error returned")
    lines.append("by the WebSocket upgrade. Replace with current upstream addrs by running")
    lines.append("`scripts/sync_bootnodes.py` after `paritytech/chainspecs` has refreshed,")
    lines.append("or open a PR upstream with corrected addrs from the operator.")
    lines.append("")

    by_chain: dict[str, list[tuple[str, str, str]]] = defaultdict(list)
    for chain, member, addr, reason in failed:
        by_chain[chain].append((member, addr, reason))

    for chain, rows in sorted(by_chain.items()):
        lines.append(f"### {chain}")
        lines.append("")
        for member, addr, reason in sorted(rows):
            lines.append(f"- `{member}` — {reason}")
            lines.append(f"  - `{addr}`")
        lines.append("")

    path.write_text("\n".join(lines) + "\n")
    print(f"wrote {path}", file=sys.stderr)


def clean_bootnodes(bootnodes: dict, results: dict) -> dict:
    """drop unreachable multiaddrs from each member; drop members whose
    list goes empty; drop chains whose members object goes empty (rare)."""
    out: dict = json.loads(json.dumps(bootnodes))  # deep copy
    for chain, by_member in results.items():
        members = out.get(chain, {}).get("members", {})
        for member, rows in by_member.items():
            dead = {addr for addr, ok, reason in rows if not ok and not reason.startswith("tcp-only")}
            if not dead:
                continue
            kept = [a for a in members.get(member, []) if a not in dead]
            if kept:
                members[member] = kept
            else:
                members.pop(member, None)
        if not members:
            out.pop(chain, None)
    return out


async def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--clean", action="store_true", help="rewrite bootnodes.json without unreachable entries")
    ap.add_argument("--report", type=Path, default=DEFAULT_REPORT, help="markdown report path")
    args = ap.parse_args()

    bootnodes = json.loads(SRC.read_text())
    results = await probe_all(bootnodes)
    write_report(results, args.report, clean=args.clean)
    if args.clean:
        cleaned = clean_bootnodes(bootnodes, results)
        SRC.write_text(json.dumps(cleaned, indent=2) + "\n")
        print(f"rewrote {SRC}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
