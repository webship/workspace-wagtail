#!/usr/bin/env bash

# Installed by the Wagtail plugin (plugins.sh --install wagtail); __WORKSPACE__ is the workspace it was installed into.
#
# manage.py of one Wagtail site of this workspace, with the site's Python, in its container: say what the site is,
# run a command, update Wagtail within its release line, restart the server, remove the test content a stopped run
# left, add or cancel the default accounts. Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="wagtail";

ARGPARSE_DESCRIPTION="Run manage.py of a Wagtail site of __WORKSPACE__: status, a command, an update, a restart, a tidy-up, the default accounts"
# The args file comes with the plugin: core/scripts/plugins/wagtail/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/wagtail/args/arg-wagtail-manage.sh || exit 1 ;

shift $#;

wagtail_manage_tool ;
