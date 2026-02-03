#!/usr/bin/env python3
# Author: AI on Google Search
# ruff: noqa: ISC002
import json
import sys
import math
import os
import subprocess
import argparse
import re
import hashlib
from typing import Any, Optional

# --- STYLING CONSTANTS ---
FONT_FAMILY: str = "arial, sans-serif"
HEADER_FONT_SIZE: str = "1.1em"
DEP_FONT_SIZE: str = "1.0em"
EDGE_COLOR: str = "#555555"
DEP_BORDER_WIDTH: str = "0.15em"
ROOT_BORDER_WIDTH: str = "0.4em"
EDGE_WIDTH: str = "0.04em"
ARROW_SIZE: int = 45
PY_ICON: str = '<img src="https://cdn.simpleicons.org" width="14" height="14" />'


def format_size(size_bytes: float) -> str:
  if size_bytes == 0:
    return "0B"
  size_name: tuple[str, ...] = ("B", "KB", "MB", "GB")
  i: int = int(math.floor(math.log(max(size_bytes, 1), 1024)))
  p: float = math.pow(1024, i)
  s: float = round(size_bytes / p, 2)
  return f"{s} {size_name[i]}"


def get_node_colors(size: float, max_size: float) -> tuple[str, str]:
  if max_size == 0:
    return "#d1d1ff", "#4a4a8f"
  ratio: float = min(size / max_size, 1.0)
  r: int = int(200 + (55 * ratio))
  g: int = int(210 - (100 * ratio))
  b: int = int(255 - (100 * ratio))
  fill: str = f"#{r:02x}{g:02x}{b:02x}"
  br, bg, bb = int(r * 0.7), int(g * 0.7), int(b * 0.7)
  border: str = f"#{br:02x}{bg:02x}{bb:02x}"
  return fill, border


def get_node_id(path: str) -> str:
  h: str = hashlib.md5(path.encode()).hexdigest()[:8]
  return f"node_{h}"


def parse_name(path: str) -> tuple[str, str, bool]:
  basename: str = re.sub(r"\.drv$", "", path.split("/")[-1])
  if re.match(r"^[a-z0-9]{32}-", basename):
    basename = basename[33:]
  basename = re.sub(r"^python\d+\.\d+-", "", basename)
  match: Optional[re.Match] = re.search(r"^(.*)-([0-9].*)$", basename)
  pname, version = match.groups() if match else (basename, "")
  if version in ["bin", "lib"]:
    pname, version = f"{pname}.{version}", ""
  elif version.endswith("-bin"):
    pname, version = f"{pname}.bin", version[:-4]
  elif version.endswith("-lib"):
    pname, version = f"{pname}.lib", version[:-4]
  is_py: bool = "python" in path.lower()
  is_int: bool = bool(re.match(r"^python(\d+(\.\d+)?)?$", pname.lower()))
  return pname, version, (is_py and not is_int)


def get_closure_size(path: str, data: dict[str, Any], memo: dict[str, int]) -> int:
  if path in memo:
    return memo[path]
  info: dict[str, Any] = data.get(path, {})
  visited: set[str] = {path}
  stack: list[str] = list(info.get("references", []))
  size: int = info.get("narSize", 0)
  while stack:
    ref: str = stack.pop()
    if ref not in visited and ref in data:
      visited.add(ref)
      size += data[ref].get("narSize", 0)
      stack.extend(data[ref].get("references", []))
  memo[path] = size
  return size


def gen_mermaid(filtered_data: dict[str, Any], closure_memo: dict[str, int], target_path: str, max_dep_size: int, num_hidden: int, min_bytes: float) -> str:
  lines = ["graph TD"]
  init = (
    f"  %%{{init: {{ 'themeVariables': {{ 'fontFamily': "
    f"'{FONT_FAMILY}', 'edgeColor': '{EDGE_COLOR}' }}, "
    f"'flowchart': {{ 'markerEndHeight': {ARROW_SIZE}, "
    f"'markerEndWidth': {ARROW_SIZE}, 'rankSpacing': 100, "
    f"'nodeSpacing': 100, 'htmlLabels': true, "
    f"'useMaxWidth': false }} }} }}%%"
  )
  lines.append(init)
  lines.append(f"  classDef summaryNode font-family:{FONT_FAMILY},font-size:{HEADER_FONT_SIZE},fill:#fff,stroke:#ccc,stroke-width:0.1em,text-align:left")
  lines.append(f"  classDef rootNode font-family:{FONT_FAMILY},font-size:{HEADER_FONT_SIZE},stroke-width:{ROOT_BORDER_WIDTH}")
  lines.append(f"  classDef depNode font-family:{FONT_FAMILY},font-size:{DEP_FONT_SIZE},stroke-width:{DEP_BORDER_WIDTH}")
  lines.append("  classDef invisible fill:none,stroke:none")
  lines.append("  subgraph SummaryArea [ ]")
  summary = f"<div style='white-space:nowrap; display:inline-block;'>Nodes: {len(filtered_data)}<br/>Hidden: {num_hidden} (min: {format_size(min_bytes)})</div>"
  lines.append(f'    SummaryNode["{summary}"]')
  lines.append("  end")
  lines.append("  class SummaryArea invisible")
  lines.append("  class SummaryNode summaryNode")
  for path, info in filtered_data.items():
    nid = get_node_id(path)
    pname, ver, is_py = parse_name(path)
    title = f"{PY_ICON} {pname}" if is_py else pname
    sz, cls_sz = info.get("narSize", 0), closure_memo[path]
    is_root = path == target_path
    lbl = f"<div style='white-space:nowrap; display:inline-block;'><b>{title} {ver}</b><br/>{format_size(sz)} ({format_size(cls_sz)})</div>"
    fill, border = get_node_colors(sz, max_dep_size)
    lines.append(f'    {nid}(["{lbl}"])')
    cls = "rootNode" if is_root else "depNode"
    lines.append(f"    class {nid} {cls}")
    lines.append(f"    style {nid} fill:{fill},stroke:{border}")
  lines.append(f"    linkStyle default stroke-width:{EDGE_WIDTH},stroke:{EDGE_COLOR}")
  for path, info in filtered_data.items():
    sid = get_node_id(path)
    for ref in info.get("references", []):
      if ref != path and ref in filtered_data:
        lines.append(f"    {sid} ==> {get_node_id(ref)}")
  return "\n".join(lines)


def main() -> None:
  parser = argparse.ArgumentParser()
  parser.add_argument("store_path", nargs="?", default="./result")
  parser.add_argument("--mode", choices=["runtime", "build"], default="runtime")
  parser.add_argument("--min-size", type=float, default=0)
  args = parser.parse_args()
  try:
    if args.mode == "runtime":
      target_path = os.path.realpath(args.store_path)
      res = subprocess.check_output(
        ["nix", "path-info", "--json", "--recursive", target_path],
        text=True,
      )
      data = json.loads(res)
    else:
      drv_p = subprocess.check_output(["nix", "path-info", "--derivation", args.store_path], text=True).strip()
      res = subprocess.check_output(
        ["nix", "path-info", "--json", "--recursive", "--derivation", drv_p],
        text=True,
      )
      data = json.loads(res)
      out_to_drv = {}
      for d_path, info in data.items():
        for out in info.get("outputs", {}).values():
          p = out.get("path")
          if p:
            out_to_drv[p] = d_path
      o_pts = list(out_to_drv.keys())
      if o_pts:
        s_res = subprocess.check_output(
          ["nix", "path-info", "--json"] + o_pts,
          text=True,
        )
        s_dat = json.loads(s_res)
        for info in data.values():
          info["narSize"] = 0
        for out_path, s_info in s_dat.items():
          d_path = out_to_drv[out_path]
          data[d_path]["narSize"] += s_info.get("narSize", 0)
      target_path = drv_p
  except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)

  min_bytes = args.min_size * 1024 * 1024
  closure_memo: dict[str, int] = {}
  for path in data:
    get_closure_size(path, data, closure_memo)

  filtered_data = {p: info for p, info in data.items() if closure_memo.get(p, 0) >= min_bytes or p == target_path}
  num_hidden = len(data) - len(filtered_data)
  dep_sizes = [i.get("narSize", 0) for p, i in filtered_data.items() if p != target_path]
  max_dep_size = max(dep_sizes) if dep_sizes else 1

  total_closure_size = sum(v.get("narSize", 0) for v in data.values())

  print(f"Total nodes: {len(data)}", file=sys.stderr)
  print(f"Filtered nodes: {len(filtered_data)}", file=sys.stderr)
  print(f"Total closure size: {format_size(total_closure_size)}", file=sys.stderr)

  print(gen_mermaid(filtered_data, closure_memo, target_path, max_dep_size, num_hidden, min_bytes))


if __name__ == "__main__":
  main()
