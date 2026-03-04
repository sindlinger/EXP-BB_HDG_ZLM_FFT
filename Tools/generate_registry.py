#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
IND_DIR = ROOT / "Indicators" / "Plugins"
STR_DIR = ROOT / "Strategies" / "Plugins"
GEN_DIR = ROOT / "Generated"
GEN_DIR.mkdir(parents=True, exist_ok=True)


def to_ident(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]", "_", name)


def list_plugins(folder: Path):
    return sorted([p for p in folder.glob("*.mqh") if p.is_file()])


def make_indicator_registry(files):
    lines = []
    lines.append("#ifndef __CSM_INDICATOR_REGISTRY_GENERATED_MQH__")
    lines.append("#define __CSM_INDICATOR_REGISTRY_GENERATED_MQH__")
    lines.append("")
    lines.append('#include "..\\Contracts\\Interfaces.mqh"')
    for f in files:
        lines.append(f'#include "..\\Indicators\\Plugins\\{f.name}"')
    lines.append("")
    lines.append("int IndicatorRegistry_ListIds(string &out[])")
    lines.append("{")
    lines.append(f"   ArrayResize(out, {len(files)});")
    for i, f in enumerate(files):
        stem = f.stem
        lines.append(f'   out[{i}] = "{stem}";')
    lines.append(f"   return({len(files)});")
    lines.append("}")
    lines.append("")
    lines.append("IIndicatorPlugin* IndicatorRegistry_CreateById(const string id)")
    lines.append("{")
    for f in files:
        stem = f.stem
        ident = to_ident(stem)
        lines.append(f'   if(id == "{stem}")')
        lines.append(f"      return(CreateIndicatorPlugin_{ident}());")
    lines.append("   return(NULL);")
    lines.append("}")
    lines.append("")
    lines.append("#endif")
    lines.append("")
    return "\n".join(lines)


def make_strategy_registry(files):
    lines = []
    lines.append("#ifndef __CSM_STRATEGY_REGISTRY_GENERATED_MQH__")
    lines.append("#define __CSM_STRATEGY_REGISTRY_GENERATED_MQH__")
    lines.append("")
    lines.append('#include "..\\Contracts\\Interfaces.mqh"')
    for f in files:
        lines.append(f'#include "..\\Strategies\\Plugins\\{f.name}"')
    lines.append("")
    lines.append("int StrategyRegistry_ListIds(string &out[])")
    lines.append("{")
    lines.append(f"   ArrayResize(out, {len(files)});")
    for i, f in enumerate(files):
        stem = f.stem
        lines.append(f'   out[{i}] = "{stem}";')
    lines.append(f"   return({len(files)});")
    lines.append("}")
    lines.append("")
    lines.append("IStrategyPlugin* StrategyRegistry_CreateById(const string id)")
    lines.append("{")
    for f in files:
        stem = f.stem
        ident = to_ident(stem)
        lines.append(f'   if(id == "{stem}")')
        lines.append(f"      return(CreateStrategyPlugin_{ident}());")
    lines.append("   return(NULL);")
    lines.append("}")
    lines.append("")
    lines.append("#endif")
    lines.append("")
    return "\n".join(lines)


if __name__ == "__main__":
    ind_files = list_plugins(IND_DIR)
    str_files = list_plugins(STR_DIR)

    (GEN_DIR / "IndicatorRegistry.generated.mqh").write_text(make_indicator_registry(ind_files), encoding="utf-8")
    (GEN_DIR / "StrategyRegistry.generated.mqh").write_text(make_strategy_registry(str_files), encoding="utf-8")

    print(f"Generated {len(ind_files)} indicator plugins and {len(str_files)} strategy plugins")
