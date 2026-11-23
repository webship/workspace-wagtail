# @webship.co/workspace-wagtail

Wagtail for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder that makes a real
Wagtail site in containers (a new project made with `wagtail start`, or the official Wagtail Bakery demo with its
content, at the current Wagtail release or the long-term-support one, run in production by uWSGI with PostgreSQL),
with what a site adds once it goes to work (the settings of the containers: its database, the router's HTTPS, its mail
sent to the project's mail catcher, its site answering at the project's address), a tool that runs `manage.py` for
the site, the default accounts, the [Wagtail step pack](https://github.com/webship/wagtail-steps) wired into the
workspace's testing setup, and its AI items — two agents, a skill, a command and two prompts — each listed in the
workspace folder of its kind.

The workspace is container-based (DDEV by default): a Wagtail site is a row like any other, so the row menus the core
draws (start, stop, launch, clone, remove, tests) work on it unchanged. The plugin claims its sites with a file of its
own (`.ddev/config.wagtail.yaml`), so the Tests menu of the row offers the plugin's test users (Workspace core 1.0.27
and later; see [The default accounts](#the-default-accounts)).

It is made from the reference platform plugin, `@webship.co/workspace-wordpress`, and keeps the shape of the Django
plugin's projects: a generic project whose web container runs the site as a daemon, with the router of the container
tool sending the project's address to the site's port. Where the Django plugin runs Django's development server, this
one runs the site the way the Wagtail Bakery demo's production image does: uWSGI, with DEBUG off.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require @webship.co/workspace-wagtail --with-needs   # npm install into the dashboard
bash core/scripts/plugins.sh --activate wagtail --with-needs                        # plugins.wagtail in settings.yml
bash core/scripts/plugins.sh --install wagtail                                      # commands, functions, args, AI items
bash core/scripts/plugins.sh --configure wagtail                                    # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is idempotent.
`--uninstall` removes what it placed; an AI item you edited stays. `--remove wagtail` then takes the package out of
the dashboard.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-wagtail-project.sh`, `cmd-tools-wagtail-manage.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The agents `wagtail-site-builder`, `wagtail-tester` | `ai-agents/` |
| The skill `wagtail-scenarios` | `ai-skills/` |
| The command `/wagtail-test` | `ai-commands/` |
| The prompts `wagtail-build-and-test`, `wagtail-scenarios-for-an-area` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate wagtail --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install wagtail
```

Everything the builder runs for a site runs in containers, through the container tool the workspace already needs:
Python, Wagtail and the site are the containers'. On the machine it uses curl (the demo's code), tar and Python 3
(which the workspace's own argument parsing already needs). The plugin asks for no command of its own on the machine.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-wagtail-project.sh` | The builder, in the Build list as **Wagtail (wagtail start, Bakery demo)**, installed into every sites folder |
| `commands/cmd-tools-wagtail-manage.sh` | `manage.py` and the run of a site: what the site is and its accounts, a manage.py command, an update within its release line, a restart, the test content a stopped run left, the default accounts |
| `scripts/functions/fun-wagtail.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_wagtail_users`, `add_wagtail_users`, `cancel_wagtail_users`, `testing_configure_wagtail`) |
| `scripts/args/arg-wagtail.sh`, `arg-wagtail-manage.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `scripts/wagtail-site.py` | The site's side of the build (the step pack's own script), run with the site's Python in the web container: the settings of the containers (`<package>/settings/container.py`, on top of the site's production settings), the site's address, the accounts, the clean-up of test content |
| `testing/site.feature` | The first feature a site gets when testing is set up |
| `ai/agents/wagtail-site-builder.md` | The agent that builds and maintains sites with these commands |
| `ai/agents/wagtail-tester.md` | The agent that writes and runs scenarios with the Wagtail step pack |
| `ai/skills/wagtail-scenarios/` | The skill: the step pack's phrases by area, the traps found on real sites, three example features |
| `ai/commands/wagtail-test.md` | The slash command `/wagtail-test <site>`: set up, match every step, run, report |
| `ai/prompts/wagtail-build-and-test.md`, `wagtail-scenarios-for-an-area.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about Wagtail here |
| `features/wagtail.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## What is different from a PHP platform

A Wagtail site is a Django project with its own server, and DDEV has no project type for it. The plugin keeps the
shape of the reference and changes only this:

| | WordPress (the reference) | Wagtail |
| --- | --- | --- |
| Project | `--project-type=wordpress`, nginx and PHP | `--project-type=generic --webserver-type=generic --docroot="" --database=postgres:16`: the web container runs uWSGI as a daemon and the router sends ports 80 and 443 of the project's address to its port (8000) |
| Recognised by | The DDEV project type | The file `.ddev/config.wagtail.yaml`: the daemon of the site, its port, its settings module, its database address, its secret key, and the plugin's claim on the project |
| The runtime | PHP of the web image | Python at `--python-version` (3.12 by default, the demo's), installed by uv in the web image (`.ddev/web-build/Dockerfile.wagtail`); the site's packages in a virtual environment of the project (`.venv/`) |
| Getting the code | `wp core download` | `wagtail start mysite app` in the web container, or with `--bakerydemo` the demo's code at the commit that last ran on the release line asked for |
| Install | `wp core install` | The settings of the containers, the migrations, the demo's content (`load_initial_data`), the static files collected, the site's address; `--install`: the workspace account as its superuser |
| Database | The container tool's MariaDB | The container tool's PostgreSQL 16 |
| Running it | PHP-FPM | uWSGI (its binary wheel, `pyuwsgi`) with the site's production settings, DEBUG off, behind the router's HTTPS; it serves the static and the media files too |
| Mail | The container tool's mail catcher | The same: the site sends over SMTP to it (`https://<name>.ddev.site:8026`) |
| Accounts | WP-CLI | The site's own user model, through the plugin's script, the accounts on its standard input |
| Removing it | `ddev delete` | The same, and the project's folder takes the virtual environment with it |
| Tests menu of the row | Reads the project type | The plugin's claim: core 1.0.27 and later offer the plugin's test users (`wagtail`) |

No public domain, no hosted service and no account anywhere: the site answers at `https://<name>.ddev.site` through
the container tool's router.

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build a site

```bash
cd ~/workspace/dev
bash cmd-wagtail-project.sh mysite --install --add-users                             # a new project, as wagtail start makes it
bash cmd-wagtail-project.sh bakery --install --add-users --bakerydemo                # the Wagtail Bakery demo with its content
bash cmd-wagtail-project.sh bakerylts --install --add-users --bakerydemo --wagtail-version 7.4   # the demo on the long-term-support line
```

| Flag | What it does |
| --- | --- |
| `--install` | Give the site its superuser: the workspace account. Without it the site is built with no account |
| `--add-users` | With `--install`: add the default accounts |
| `--bakerydemo` | Build the official Wagtail Bakery demo (BSD-3-Clause) with its content — pages with blocks, images, documents, snippets, a contact form, redirects, the "Moderators approval" workflow — instead of a new project made with `wagtail start` |
| `--wagtail-version <line>` | A release line (`8.1`, the current one, by default; `7.4`, the long-term-support one) or one release (`8.1.0`) for a new project; the demo runs on the lines `8.1` and `7.4` |
| `--python-version <x.y>` | The Python of the site: `3.12` (the demo's) by default, `3.13`, `3.14` |
| `--launch` | Open the admin when the site is ready |

The site answers at `https://mysite.ddev.site`, its admin at `/admin/` and its mail catcher at
`https://mysite.ddev.site:8026`. A project of the same name is deleted first. A new project's Python package is
`mysite` (the demo's is `bakerydemo`), in `app/` of the project.

A build takes about three minutes the first time (the web image with uv and its Python, then the site's packages) and
two after that; the site then uses about 750 MB of memory with PostgreSQL once it has served a run of the suite. Check the free memory and disk first
(`free -g`, `df -h /`), and build one site at a time on a machine others use.

### Work on a site

```bash
bash cmd-tools-wagtail-manage.sh mysite                              # what the site is, its versions, addresses and accounts
bash cmd-tools-wagtail-manage.sh mysite --run "update_index"         # a manage.py command, in the folder of manage.py in the web container
bash cmd-tools-wagtail-manage.sh mysite --run "createsuperuser --help"
bash cmd-tools-wagtail-manage.sh mysite --update                     # Wagtail at the latest release of its line, migrated, static files, restart
bash cmd-tools-wagtail-manage.sh mysite --restart                    # restart uWSGI and wait for the site
bash cmd-tools-wagtail-manage.sh mysite --tidy                       # remove the test content a stopped run left ("Webship test …")
bash cmd-tools-wagtail-manage.sh mysite --add-users                  # the default accounts
bash cmd-tools-wagtail-manage.sh mysite --cancel-users               # delete them again (the demo's own two are given back)
```

`manage.py` runs with the Python of the site's virtual environment and the settings of the containers. The demo pins
its own releases, so `--update` refuses it: build it again with `--bakerydemo --wagtail-version` instead. The site's
code is in `app/` of the project: change it, then `--restart` (and `--run "collectstatic --noinput"` after a change
to its static files).

### The default accounts

| Account | Address | Role | Handle in the tests |
| --- | --- | --- | --- |
| `administrator` | `administrator@example.com` | a superuser | `administrator` |
| `editor` | `editor@example.com` | the Editors group: adds and changes pages, uploads images and documents, submits pages for moderation | `editor` |
| `moderator` | `moderator@example.com` | the Moderators group: also publishes, locks and unlocks pages, and reviews what is submitted | `moderator` |
| `member` | `member@example.com` | no group: an account of the site that the admin's login refuses | `member` |

Each account has the password of the workspace's other default lists. They are made by the plugin's script through
the site's own user model, the accounts on Python's standard input (never on a command line or in a file); an account
that is there already gets its password, its address, its state and its group back. The groups are the ones Wagtail
makes when it is installed, so the same accounts fit a new project and the demo, whose own `editor` and `moderator`
they take over. Cancelling deletes the default accounts, except those two of the demo: they are given back as the
demo made them (their names, the demo's own password, their group), so the demo's pages, revisions and workflow keep
their authors and adding the default accounts again takes them over again. An account of your own, and the
workspace account, stay when the default accounts are added or cancelled. They are for local sites and for tests.

The row's Tests menu offers **Add the test users** and **Cancel the test users** for a site this plugin claims
(Workspace core 1.0.27 and later): they run the same list as

```bash
bash cmd-tools-add-users.sh mysite wagtail       # the core's tool, with the plugin's list
bash cmd-tools-cancel-users.sh mysite wagtail
```

On a core older than 1.0.27 the Tests menu hands every project that is not of a known type the Webship distribution's
list (which starts by adding Drush with Composer): leave those two items alone there and use the manage tool.

### Test a site

```bash
bash cmd-tools-testing.sh mysite                  # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh mysite --run            # run the suite in the container
bash cmd-tools-testing.sh mysite --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a Wagtail site it also adds `@webship-js/wagtail-steps` to
`package.json`, lists its step definitions in `cucumber.js` after webship-js's own, writes where the admin is
(`/admin/`), the mail catcher, the browser messages that are no error of the site (the admin's accessibility checker
writes its findings to the console), the users registry (the handles above, overridable with
`WAGTAIL_<HANDLE>_USERNAME`, `WAGTAIL_<HANDLE>_PASSWORD` and `WAGTAIL_<HANDLE>_EMAIL`), the tags that keep the pack's
assertions that must fail out of a normal run, and the site's address in place of the starter's
`http://localhost:8080`. It places `tests/features/site.feature` when the project has none, and makes sure the default
accounts are in the site once it answers again (installing the webship-js add-on restarts the project, and the site
with it). Run it again and it adds what is missing and keeps what you changed.

Until `@webship-js/wagtail-steps` is on npm, give the testing setup its tarball (`npm pack` of the pack) with
`bash cmd-tools-testing.sh mysite --add-steps <path to the tarball>`, then run the setup again.

A scenario of your own reads like this one, from the step pack's phrases (the skill `wagtail-scenarios` lists them by
area):

```gherkin
Feature: Moderation
  Scenario: The editor submits a page and the moderator sends it back
    Given I am a logged in user with the "administrator" user
    And there is no page "Webship test news"
    Given I am a logged in user with the "editor" user
    When I add a "Standard page" under the home page
    And I set "Title" to "Webship test news"
    And I submit the page for moderation
    Then an email with the subject "has been submitted for approval" should be sent to "moderator"
    Given I am a logged in user with the "moderator" user
    When I request changes to the page "Webship test news" with the comment "A photo, please."
    Then an email with the subject "has been rejected" should be sent to "editor"
    Given I am a logged in user with the "administrator" user
    When I delete the page "Webship test news"
```

`tests/features/site.feature` passes on a site built with `--install --add-users`, a new project or the demo, and the
features of the step pack pass on the demo built the same way (`--bakerydemo`).

## The AI items

`ai/` in the package holds one folder per kind, the manifest's `ai` block names each item, and `--install` places it
in the workspace folder of that kind.

| Kind | Item | Use it to |
| --- | --- | --- |
| Agent | `wagtail-site-builder` | Build, maintain or remove a site with the commands above, in containers only |
| Agent | `wagtail-tester` | Set the testing stack up, look at the admin in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |
| Skill | `wagtail-scenarios` | Write a scenario from phrases that exist: the pack's steps by area, the handles of the users registry, the traps found on real sites, and three features that pass on the demo with the default accounts |
| Command | `/wagtail-test <site> [feature or @tag]` | Run the suite of a site from inside a session: set up when missing, match every step, run, report what failed and why |
| Prompt | `wagtail-build-and-test` | Start a session that builds a site, says what it is, sets the testing stack up and runs the first feature |
| Prompt | `wagtail-scenarios-for-an-area` | Start a session that writes and runs the scenarios of one area of a site |

After `--install` each is in its folder on the dashboard. **Install** there puts an agent, a skill or a command into
Claude Code (`~/.claude/agents`, `~/.claude/skills`, `~/.claude/commands`), or from the command line:

```bash
cd ~/workspace/ai-agents   && bash cmd-tools-ai-items.sh wagtail-tester --install
cd ~/workspace/ai-skills   && bash cmd-tools-ai-items.sh wagtail-scenarios --install
cd ~/workspace/ai-commands && bash cmd-tools-ai-items.sh wagtail-test --install
```

A prompt is not installed: it is the whole `claude …` launch command of a new session, and the dashboard's **New
screen** form lists it as a template. By hand, fill the placeholders in and run the command of the file from the
folder it names.

The items are written for any AI CLI, with Claude Code as the default shape: the frontmatter and the file layout are
Claude Code's, the body of each item is plain Markdown that names no tool or feature of one CLI, a command says in
words what its arguments are, and the text between the triple quotes of a prompt can be given to another AI CLI as it
is.

Every step phrase the items show is checked against the definitions of the step pack and of webship-js
(`tests/fixtures/step-definitions.txt`), and every command and flag against the plugin's own.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the AI items, the functions against a scaffolded project
```

CI runs the same on Node.js 24 and 26, parses every shell script, and runs the plugin's `features/wagtail.feature`
against a dashboard with this plugin installed (`webship/workspace/.github/workflows/plugin-browser-suite.yml`).

The Wagtail name is a trademark of its owner; this plugin is not affiliated with or endorsed by them.
