#!/usr/bin/env python3
"""
generate-configs.py

Generate Nginx site configs from YAML definitions and a Jinja2 template.

Each site definition in the YAML must include:
  - hostnames:     list of server_name values (first is used as filename)
  - upstream.name: upstream block name
  - upstream.servers: list of { host, port } objects

Optional per‑site keys:
  - client_max_body_size (e.g. "50M")

"""

import argparse
import logging
import sys
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader, TemplateNotFound

# Configure basic logger
LOG = logging.getLogger("generate-configs")
handler = logging.StreamHandler()
formatter = logging.Formatter("[%(levelname)s] %(message)s")
handler.setFormatter(formatter)
LOG.addHandler(handler)


def load_domains(path: Path):
    if not path.exists():
        LOG.error(f"Domains config not found: {path}")
        sys.exit(1)
    with path.open() as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict) or "sites" not in data:
        LOG.error(f"Invalid YAML structure in {path}, missing top‑level 'sites'")
        sys.exit(1)
    return data["sites"]


def validate_site(name: str, cfg: dict):
    required = {"hostnames", "upstream"}
    missing = required - cfg.keys()
    if missing:
        LOG.error(f"Site '{name}' is missing required keys: {missing}")
        return False

    if not isinstance(cfg["hostnames"], list) or not cfg["hostnames"]:
        LOG.error(f"Site '{name}' has invalid or empty 'hostnames'")
        return False

    up = cfg["upstream"]
    if not isinstance(up, dict) or "name" not in up or "servers" not in up:
        LOG.error(f"Site '{name}' has invalid 'upstream' definition")
        return False

    return True


def parse_args():
    p = argparse.ArgumentParser(
        description="Render Jinja2 templates to nginx/sites-enabled from domains.yml"
    )
    p.add_argument(
        "--domains-config", "-d",
        type=Path,
        default=Path("config/domains.yml"),
        help="Path to domains YAML file"
    )
    p.add_argument(
        "--templates-dir", "-t",
        type=Path,
        default=Path("config/templates"),
        help="Directory containing Jinja2 templates"
    )
    p.add_argument(
        "--output-dir", "-o",
        type=Path,
        default=Path("nginx/sites-enabled"),
        help="Directory to write rendered configs"
    )
    p.add_argument(
        "--template-name",
        default="site.conf.j2",
        help="Jinja2 template filename"
    )
    p.add_argument(
        "--clean", action="store_true",
        help="Remove any existing *.conf in output dir before writing"
    )
    p.add_argument(
        "--verbose", "-v", action="store_true",
        help="Increase logging verbosity"
    )
    return p.parse_args()


def main():
    args = parse_args()
    LOG.setLevel(logging.DEBUG if args.verbose else logging.INFO)

    LOG.info("Loading site definitions from %s", args.domains_config)
    sites = load_domains(args.domains_config)

    # Prepare Jinja environment
    if not args.templates_dir.is_dir():
        LOG.error("Templates directory not found: %s", args.templates_dir)
        sys.exit(1)
    env = Environment(
        loader=FileSystemLoader(str(args.templates_dir)),
        trim_blocks=True,
        lstrip_blocks=True,
    )
    try:
        template = env.get_template(args.template_name)
    except TemplateNotFound:
        LOG.error("Template not found: %s/%s", args.templates_dir, args.template_name)
        sys.exit(1)

    # Prepare output directory
    out_dir = args.output_dir
    if args.clean and out_dir.exists():
        LOG.info("Cleaning existing configs in %s", out_dir)
        for old in out_dir.glob("*.conf"):
            LOG.debug("Removing %s", old)
            old.unlink()

    out_dir.mkdir(parents=True, exist_ok=True)

    # Render each site
    for site_key, cfg in sites.items():
        if not validate_site(site_key, cfg):
            continue

        hostnames = cfg["hostnames"]
        upstream = cfg["upstream"]
        body = {
            "site_key": site_key,
            "hostnames": hostnames,
            "upstream": upstream,
            # pass client_max_body_size (or let template default to 1M)
            "client_max_body_size": cfg.get("client_max_body_size", "1M"),
            "force_https": cfg.get('force_https', False)
        }

        filename = f"{hostnames[0]}.conf"
        out_path = out_dir / filename
        LOG.info("Rendering %s → %s", site_key, out_path)

        try:
            content = template.render(**body)
        except Exception as e:
            LOG.error("Template render failed for %s: %s", site_key, e)
            continue

        out_path.write_text(content)
        LOG.debug("Wrote %d bytes", len(content))

    LOG.info("Done.")

if __name__ == "__main__":
    main()
