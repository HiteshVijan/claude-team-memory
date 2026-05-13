#!/usr/bin/env python3
"""
Standalone skill routing table generator.

Reads all SKILL.md files from a skills directory, parses YAML frontmatter
(handles >, >-, | multiline formats), groups by category, and writes a
markdown routing table.

Usage:
    python3 generate_skill_routing.py
    python3 generate_skill_routing.py --skills-dir /path/to/skills --output /path/to/output.md
"""

import argparse
import glob
import os
import re
import sys


# ── Category mapping ──────────────────────────────────────────
# Map skill directory names to display categories.
# Skills not in any list are placed in "Other".
# Customize this for your team's skill library.
CATEGORIES = {
    "AI & Agents": [
        "adk-agent", "agent-dev-lifecycle", "datascience-agent",
        "dispatching-parallel-agents", "genai-accelerators",
        "google-adk-patterns", "google-adk-python", "manage-agent-engine",
        "rag", "subagent-driven-development",
    ],
    "Data Engineering": [
        "bigquery", "data-pipeline", "data-science", "gcs",
    ],
    "Architecture & Design": [
        "arb-review", "arch-gate", "architecture-design",
        "architecture-documentation", "estimation", "requirements-elaboration",
    ],
    "CI/CD & Deployment": [
        "app-dev-lifecycle", "cap-deployment", "create-github-repo",
        "deploy-shared-flow", "deploy-gke", "gha-ci-node",
        "gha-ci-python", "docker-publish", "terraform",
    ],
    "Code Quality": [
        "test-driven-development", "systematic-debugging",
        "requesting-code-review", "receiving-code-review",
        "e2e-verify", "changelog-generator",
        "verification-before-completion",
    ],
    "Security": [
        "security-guardrails", "sentry", "snyk-autofix",
        "security-scanning",
    ],
    "Utilities": [
        "mermaid-rendering", "mcp-builder", "skill-creator",
        "dev-onboarding", "proxy-vpn-config", "socratic",
        "writing-skills",
    ],
}


def build_reverse_lookup(categories: dict) -> dict:
    """Build skill_name → category reverse mapping."""
    lookup = {}
    for cat, skills in categories.items():
        for s in skills:
            lookup[s] = cat
    return lookup


def parse_yaml_value(lines: list, start_idx: int) -> str:
    """Parse a YAML value that might use multiline indicators (>, >-, |, |-)."""
    line = lines[start_idx]
    match = re.match(r"^(\w+):\s*(.*)", line)
    if not match:
        return ""

    value = match.group(2).strip()

    # Simple single-line value (possibly quoted)
    if value and value not in (">", ">-", "|", "|-"):
        return value.strip('"').strip("'")

    is_folded = value in (">", ">-")
    is_literal = value in ("|", "|-")

    if not (is_folded or is_literal):
        return value.strip('"').strip("'")

    # Collect indented continuation lines
    parts = []
    indent = None

    for i in range(start_idx + 1, len(lines)):
        l = lines[i]
        if not l.strip() or l.startswith("---"):
            break

        stripped = l.lstrip()
        line_indent = len(l) - len(stripped)

        if indent is None:
            indent = line_indent
        if line_indent < indent:
            break

        parts.append(stripped)

    if is_folded:
        return " ".join(parts)
    return "\n".join(parts)


def parse_skill_md(filepath: str) -> tuple:
    """Extract name and description from SKILL.md YAML frontmatter."""
    try:
        with open(filepath, "r") as f:
            content = f.read()
    except Exception:
        return None, None

    if not content.startswith("---"):
        return None, None

    end = content.find("---", 3)
    if end == -1:
        return None, None

    frontmatter = content[3:end].strip()
    lines = frontmatter.split("\n")

    name = None
    description = None

    for i, line in enumerate(lines):
        if line.startswith("name:"):
            name = parse_yaml_value(lines, i)
        elif line.startswith("description:"):
            description = parse_yaml_value(lines, i)

    return name, description


def generate_routing_table(skills_dir: str, output_path: str, categories: dict) -> int:
    """Generate the skill routing markdown table."""
    skill_to_cat = build_reverse_lookup(categories)
    skills = {}

    for skill_md in sorted(glob.glob(os.path.join(skills_dir, "*/SKILL.md"))):
        dir_name = os.path.basename(os.path.dirname(skill_md))
        name, description = parse_skill_md(skill_md)

        if not name:
            name = dir_name
        if not description:
            description = f"(no description — add one to {dir_name}/SKILL.md)"

        skills[name] = description

    # Group by category
    categorized = {}
    for name, desc in sorted(skills.items()):
        cat = skill_to_cat.get(name, "Other")
        categorized.setdefault(cat, []).append((name, desc))

    # Ordered output
    category_order = list(categories.keys()) + ["Other"]

    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, "w") as f:
        f.write("## Skill Routing Table (Auto-Generated)\n")
        f.write(
            "Check this table before every response. "
            "If the user's intent matches a description, auto-invoke the skill.\n\n"
        )

        for cat in category_order:
            if cat not in categorized:
                continue
            f.write(f"### {cat}\n")
            f.write("| Skill | When to invoke |\n")
            f.write("|-------|---------------|\n")
            for name, desc in categorized[cat]:
                if len(desc) > 120:
                    desc = desc[:117] + "..."
                f.write(f"| `/{name}` | {desc} |\n")
            f.write("\n")

        # Any categories not in the ordered list
        for cat in sorted(categorized.keys()):
            if cat in category_order:
                continue
            f.write(f"### {cat}\n")
            f.write("| Skill | When to invoke |\n")
            f.write("|-------|---------------|\n")
            for name, desc in categorized[cat]:
                if len(desc) > 120:
                    desc = desc[:117] + "..."
                f.write(f"| `/{name}` | {desc} |\n")
            f.write("\n")

    return len(skills)


def main():
    parser = argparse.ArgumentParser(description="Generate skill routing table from SKILL.md files")
    parser.add_argument(
        "--skills-dir",
        default=os.path.expanduser("~/.claude/skills"),
        help="Path to skills directory (default: ~/.claude/skills)",
    )
    parser.add_argument(
        "--output",
        default=os.path.expanduser("~/.claude/cache/skills_routing.md"),
        help="Output file path (default: ~/.claude/cache/skills_routing.md)",
    )
    args = parser.parse_args()

    if not os.path.isdir(args.skills_dir):
        print(f"Skills directory not found: {args.skills_dir}", file=sys.stderr)
        sys.exit(1)

    count = generate_routing_table(args.skills_dir, args.output, CATEGORIES)
    print(f"Generated routing table: {count} skills → {args.output}")


if __name__ == "__main__":
    main()
