#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Give the site its superuser: the workspace account.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts (administrator, editor, moderator, member): the ones the test scenarios log in as.')
parser.add_argument('-b', '--bakerydemo',
                    action='store_true',
                    default=False,
                    help='Build the official Wagtail Bakery demo with its content (pages, images, documents, snippets, a form, redirects, a workflow) instead of a new project made with wagtail start.')
parser.add_argument('-w', '--wagtail-version',
                    default="",
                    help='A release line (8.1, 7.4) or one release (8.1.0); empty means the current line, 8.1. The demo runs on the lines 8.1 and 7.4 (the long-term-support one). Example: --wagtail-version 7.4')
parser.add_argument('--python-version',
                    default="",
                    choices=['3.14', '3.13', '3.12'],
                    help='The Python of the site, installed in the web image; empty means 3.12, the one of the demo. Example: --python-version 3.13')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the admin in a browser when the site is ready.')
ARGEOF
