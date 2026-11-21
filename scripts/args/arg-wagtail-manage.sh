#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The Wagtail project in this workspace.')
parser.add_argument('-r', '--run',
                    default="_none_",
                    help='A manage.py command to run in the site, with its arguments. Example: --run "update_index"')
parser.add_argument('-u', '--update',
                    action='store_true',
                    default=False,
                    help='Update Wagtail to the latest release of its line, migrate, collect the static files and restart the server (a new project; the demo pins its own releases).')
parser.add_argument('--restart',
                    action='store_true',
                    default=False,
                    help='Start the server again, and wait for it.')
parser.add_argument('-t', '--tidy',
                    action='store_true',
                    default=False,
                    help='Remove what a test run that was stopped half way left behind: the test content of the step pack (titled "Webship test").')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Add the default accounts. An account that is already there gets its password, address and group back.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts (never the workspace account). On the demo, its own editor and moderator, which the default accounts took over, are given back as the demo made them.')
ARGEOF
