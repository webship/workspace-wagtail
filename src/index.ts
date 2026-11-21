/**
 * Wagtail for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the manage.py tool in the
 * sites folders, their functions and argparse under core/scripts/plugins/wagtail/ (with wagtail-site.py, which the
 * builder runs with the site's Python, and the first feature of a site), and its AI items (ai/ in this package) in the
 * folder of their kind: the agents in AI Agents, the skill in AI Skills, the command in AI Commands, the prompts in AI
 * Prompts. The dashboard needs nothing drawn for it: the builder is in the Build list because it is a
 * cmd-*-project.sh, the row menus are the core's, the AI items are listed like any other. What register() adds is
 * what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the dashboard's own
 * files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/**
 * The plugin's name. A Wagtail site is a generic DDEV project: the plugin claims it with .ddev/config.wagtail.yaml,
 * and the core's tools call its functions under wagtail.
 */
export const PLATFORM = 'wagtail';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-wagtail-project.sh', 'cmd-tools-wagtail-manage.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['wagtail-site-builder', 'wagtail-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['wagtail-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['wagtail-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['wagtail-build-and-test', 'wagtail-scenarios-for-an-area'];

/** What the assistant is told about Wagtail in this workspace. */
export function assistantContext(): string {
  return [
    'Wagtail (a plugin, @webship.co/workspace-wagtail): a site is built with',
    '`bash cmd-wagtail-project.sh <name> --install --add-users` from a sites folder (dev, test, sandboxes, demos):',
    'a new project made with `wagtail start`, or with `--bakerydemo` the official Wagtail Bakery demo with its content,',
    'at the current release line (`--wagtail-version 8.1`; 7.4 is the long-term-support line), on Python in the web image,',
    'run in production by uWSGI in the web container of a generic DDEV project with PostgreSQL, at https://<name>.ddev.site (the admin at /admin/), its mail caught at https://<name>.ddev.site:8026;',
    '`--install` makes the workspace account its superuser, `--add-users` adds the default accounts (administrator, editor in Editors, moderator in Moderators, member with no access to the admin), each @example.com.',
    '`bash cmd-tools-wagtail-manage.sh <name>` says what the site is and lists its accounts; `--run "<command>"` runs manage.py in the container,',
    '`--update` updates Wagtail within its line, `--restart` restarts the server, `--tidy` removes the test content a stopped run left, `--add-users` and `--cancel-users` manage the default accounts.',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the Wagtail step pack; `--run` runs the suite.',
    `For Wagtail work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <site>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run pip, manage.py or Python on the host for a project; removing the project removes its packages too.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
