#!/usr/bin/env python3
"""print and write the (chain × member) bootnode coverage matrix.

every active member of the IBP is expected to operate at least one
bootnode per chain in their assignment. this script reads
bootnodes.json and members_professional.json, then reports for every
(chain × active member) cell:

  ✓✓  — at least one /wss and at least one /tcp entry (best)
  ws  — /wss only (browser-reachable but no CLI-friendly /tcp)
  tcp — /tcp only (CLI-usable but smoldot can't reach it)
  –   — nothing at all (the operator hasn't provided a bootnode)

writes BOOTNODES-COVERAGE.md alongside the json.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Iterable

HOME = Path.home()
CONFIG = HOME / "rotko" / "config"
BOOTNODES = CONFIG / "bootnodes.json"
ROSTER = CONFIG / "members_professional.json"
REPORT = CONFIG / "BOOTNODES-COVERAGE.md"

# keep in sync with site/src/data/network.ts memberKeyAliases — the same
# bootnodes.json key-to-canonical-name mapping the site uses.
ALIASES = {
    "amforc":      "Amforc",
    "dwellir":     "Dwellir",
    "gatotech":    "Gatotech",
    "radiumblock": "RadiumBlock",
    "rotko":       "Rotko Networks",
    "stakeplus":   "Stake Plus",
    "turboflakes": "Turboflakes",
}


def cell(addrs: list[str] | None) -> str:
    if not addrs:
        return "–"
    has_wss = any("/wss" in a for a in addrs)
    has_tcp = any("/wss" not in a and "/tcp" in a for a in addrs)
    if has_wss and has_tcp:
        return "✓✓"
    if has_wss:
        return "ws"
    if has_tcp:
        return "tcp"
    return "?"


def main() -> int:
    bootnodes = json.loads(BOOTNODES.read_text())
    roster = json.loads(ROSTER.read_text())

    # active member keys (bootnodes.json convention, lowercase no spaces)
    roster_keys: list[str] = []
    for canonical in roster.keys():
        match = next(
            (k for k, v in ALIASES.items() if v == canonical),
            canonical.lower().replace(" ", ""),
        )
        roster_keys.append(match)
    roster_keys.sort()

    chains = sorted(bootnodes.keys())

    # build coverage matrix
    matrix: dict[str, dict[str, str]] = {}
    for chain in chains:
        members_obj = bootnodes[chain].get("members", {})
        row: dict[str, str] = {}
        for m in roster_keys:
            row[m] = cell(members_obj.get(m))
        matrix[chain] = row

    # collect missing entries for the per-member summary
    missing_by_member: dict[str, list[str]] = {m: [] for m in roster_keys}
    ws_only_by_member: dict[str, list[str]] = {m: [] for m in roster_keys}
    tcp_only_by_member: dict[str, list[str]] = {m: [] for m in roster_keys}
    for chain, row in matrix.items():
        for m, v in row.items():
            if v == "–":
                missing_by_member[m].append(chain)
            elif v == "ws":
                ws_only_by_member[m].append(chain)
            elif v == "tcp":
                tcp_only_by_member[m].append(chain)

    # ─── render markdown ──────────────────────────────────────────────
    lines: list[str] = []
    lines.append("# Bootnode coverage matrix")
    lines.append("")
    lines.append(
        f"`{len(roster_keys)}` active members × `{len(chains)}` chains = "
        f"`{len(roster_keys) * len(chains)}` cells expected."
    )
    lines.append("")
    lines.append("Legend: `✓✓` /tcp + /wss · `ws` /wss only · `tcp` /tcp only · `–` nothing")
    lines.append("")

    # column header
    header = ["chain"] + roster_keys
    lines.append("| " + " | ".join(header) + " |")
    lines.append("| " + " | ".join(["---"] * len(header)) + " |")
    for chain in chains:
        row_cells = [chain] + [matrix[chain][m] for m in roster_keys]
        lines.append("| " + " | ".join(row_cells) + " |")
    lines.append("")

    # totals
    total_cells = len(chains) * len(roster_keys)
    missing_total = sum(len(v) for v in missing_by_member.values())
    ws_only_total = sum(len(v) for v in ws_only_by_member.values())
    tcp_only_total = sum(len(v) for v in tcp_only_by_member.values())
    full_total = total_cells - missing_total - ws_only_total - tcp_only_total
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- ✓✓ both transports: **{full_total}**")
    lines.append(f"- ws only: **{ws_only_total}**")
    lines.append(f"- tcp only: **{tcp_only_total}** (not smoldot-reachable)")
    lines.append(f"- missing: **{missing_total}**")
    lines.append("")

    # per-member breakdown
    lines.append("## Per-member gaps")
    lines.append("")
    for m in roster_keys:
        miss = missing_by_member[m]
        tcp_only = tcp_only_by_member[m]
        ws_only = ws_only_by_member[m]
        canonical = ALIASES.get(m, m)
        lines.append(f"### {canonical} (`{m}`)")
        lines.append("")
        if not miss and not tcp_only and not ws_only:
            lines.append("Full coverage — both transports on every chain.")
            lines.append("")
            continue
        if miss:
            lines.append(f"**Missing entirely ({len(miss)}):** {', '.join(miss)}")
            lines.append("")
        if tcp_only:
            lines.append(
                f"**/tcp only, no smoldot path ({len(tcp_only)}):** {', '.join(tcp_only)}"
            )
            lines.append("")
        if ws_only:
            lines.append(
                f"**/wss only, no CLI fallback ({len(ws_only)}):** {', '.join(ws_only)}"
            )
            lines.append("")

    # per-chain breakdown
    lines.append("## Per-chain gaps")
    lines.append("")
    for chain in chains:
        row = matrix[chain]
        miss = [m for m, v in row.items() if v == "–"]
        tcp_only = [m for m, v in row.items() if v == "tcp"]
        ws_only = [m for m, v in row.items() if v == "ws"]
        if not miss and not tcp_only and not ws_only:
            continue
        lines.append(f"### {chain}")
        lines.append("")
        if miss:
            lines.append(f"- missing: {', '.join(miss)}")
        if tcp_only:
            lines.append(f"- /tcp only (no smoldot): {', '.join(tcp_only)}")
        if ws_only:
            lines.append(f"- /wss only (no CLI fallback): {', '.join(ws_only)}")
        lines.append("")

    out = "\n".join(lines) + "\n"
    REPORT.write_text(out)
    print(out, end="")
    print(f"\nwrote {REPORT}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
