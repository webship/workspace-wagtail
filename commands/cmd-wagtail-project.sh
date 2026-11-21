#!/usr/bin/env bash

# workspace-name: Wagtail (wagtail start, Bakery demo)

# Installed by the Wagtail plugin (plugins.sh --install wagtail); __WORKSPACE__ is the workspace it was installed into.
#
# Build a Wagtail site in containers: a new project made with `wagtail start`, or with --bakerydemo the official
# Wagtail Bakery demo with its content, at the current release line or the one --wagtail-version names, run in
# production by uWSGI at https://<name>.ddev.site. With --install the workspace account becomes its superuser; with
# --add-users it also gets the default accounts.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="wagtail";
distribution_title="Wagtail";
distribution_webroot="";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} project in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/wagtail/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/wagtail/args/arg-wagtail.sh || exit 1 ;

shift $#;

wagtail_build ;
