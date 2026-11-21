import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';

import { register, assistantContext, PLATFORM, COMMANDS, AGENTS } from '../src/index';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const read = (f: string) => fs.readFileSync(path.join(PKG, f), 'utf8');
const manifest = JSON.parse(read('package.json')).workspacePlugin;

test('the manifest names the platform, and every file it names ships', () => {
  assert.strictEqual(manifest.name, PLATFORM);
  const named = [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args, ...manifest.scripts.machine,
    ...manifest.ai.agents, ...manifest.ai.skills, ...manifest.ai.commands, ...manifest.ai.prompts, ...manifest.features];
  for (const f of named) assert.ok(fs.existsSync(path.join(PKG, f)), `${f} is in the package`);
  assert.deepStrictEqual(manifest.commands.files.map((f: string) => path.basename(f)), COMMANDS);
  assert.deepStrictEqual(manifest.ai.agents.map((f: string) => path.basename(f, '.md')), AGENTS);
  assert.deepStrictEqual(manifest.commands.types, ['sites'], 'the commands go to sites folders only');
  const files: string[] = JSON.parse(read('package.json')).files;
  for (const f of named) assert.ok(files.includes(f.split('/')[0]), `${f} is published with the package`);
  // The machine files land side by side in core/scripts/plugins/wagtail/: no two may share a name.
  const names = manifest.scripts.machine.map((f: string) => path.basename(f));
  assert.strictEqual(new Set(names).size, names.length, 'the machine files have names of their own');
});

test('every command finds the workspace by itself, names its folder, and sources its args from where the installer puts them', () => {
  for (const f of manifest.commands.files) {
    const src = read(f);
    assert.match(src, /^#!\/usr\/bin\/env bash/, `${f} is a bash script`);
    assert.match(src, /WORKSPACE_SCRIPTS="\$\{WORKSPACE_SCRIPTS:-\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)\/\.\.\/core\/scripts" && pwd\)\}"/, `${f} locates the tooling from its own path`);
    assert.match(src, /workspace\.__WORKSPACE__\.settings\.yml/, `${f} loads the settings of the folder it is installed into`);
    assert.match(src, /source \$\{WORKSPACE_SCRIPTS\}\/plugins\/wagtail\/args\/arg-[a-z-]+\.sh \|\| exit 1 ;/, `${f} reads its arguments from the plugin's args`);
    assert.match(src, /^distribution_name="wagtail";$/m, `${f}: the user list of the core's tools is wagtail`);
    const last = src.trim().split('\n').pop() as string;
    assert.match(read('scripts/functions/fun-wagtail.sh'), new RegExp(`^function ${last.replace(/ ;$/, '')}\\(\\)`, 'm'), `${f} ends by calling a function the plugin defines`);
  }
  assert.match(read('commands/cmd-wagtail-project.sh'), /^# workspace-name: Wagtail/m, 'the builder carries the name the Build list shows');
  assert.doesNotMatch(read('commands/cmd-tools-wagtail-manage.sh'), /^# workspace-name:/m, 'a tool is not a builder');
});

test('every shell script parses', () => {
  for (const f of [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args]) {
    const r = spawnSync('bash', ['-n', path.join(PKG, f)], { encoding: 'utf8' });
    assert.strictEqual(r.status, 0, `${f}: ${r.stderr}`);
  }
});

test('the site script is Python the site can run, with every verb the functions call', () => {
  const src = read('scripts/wagtail-site.py');
  for (const verb of ['settings', 'site', 'accounts', 'tidy']) assert.match(src, new RegExp(`verb == "${verb}"`), `wagtail-site.py has the verb ${verb}`);
  for (const verb of ['owner', 'add', 'cancel', 'list']) assert.match(src, new RegExp(`verb == "${verb}"`), `wagtail-site.py has accounts ${verb}`);
  const r = spawnSync('python3', ['-c', 'import ast, sys; ast.parse(open(sys.argv[1]).read())', path.join(PKG, 'scripts', 'wagtail-site.py')], { encoding: 'utf8' });
  assert.strictEqual(r.status, 0, r.stderr);
  assert.match(src, /from \.production import \*/, 'the settings of the containers build on the site\'s own production settings');
  assert.match(src, /EMAIL_BACKEND = "django\.core\.mail\.backends\.smtp\.EmailBackend"/, 'the mail goes to the mail catcher');
  assert.match(src, /if "django\.contrib\.postgres" not in INSTALLED_APPS:.*\n\s+INSTALLED_APPS = \[\*INSTALLED_APPS, "django\.contrib\.postgres"\]/, 'the search index of a new project on PostgreSQL needs Django\'s PostgreSQL app');
});

test('the claim file is the plugin\'s own name, and is a real overlay of the container tool: the daemon, the port, the settings', () => {
  const src = read('scripts/functions/fun-wagtail.sh');
  assert.match(src, /\.ddev\/config\.wagtail\.yaml/, 'the file the core reads as the plugin\'s claim (#490): config.<plugin>.yaml');
  const yaml = (src.match(/config\.wagtail\.yaml" <<YAMLEOF\n([\s\S]*?)\nYAMLEOF/) || [])[1] || '';
  assert.match(yaml, /^web_extra_exposed_ports:\n  - name: wagtail\n    container_port: \$\{WAGTAIL_PORT\}\n    http_port: 80\n    https_port: 443$/m, 'the router sends the project\'s address to the server\'s port');
  assert.match(yaml, /^web_extra_daemons:\n  - name: wagtail\n    command: ".*exec \$\{WAGTAIL_ROOT\}\/\.venv\/bin\/uwsgi /m, 'the web container runs uWSGI as a daemon');
  assert.match(yaml, /DJANGO_SETTINGS_MODULE=\$\{package\}\.settings\.container/, 'the settings of the containers');
  assert.match(yaml, /DATABASE_URL=postgres:\/\/db:db@db:5432\/db/, 'the container\'s own database');
  assert.match(src, /^function set_wagtail_users\(\) \{/m, 'the claim names a plugin with a user list: set_<plugin>_users');
});

test('the functions carry the names the core\'s tools look for, and build the site the official way', () => {
  const src = read('scripts/functions/fun-wagtail.sh');
  for (const fn of ['set_wagtail_users', 'add_wagtail_users', 'cancel_wagtail_users', 'testing_configure_wagtail', 'wagtail_build', 'wagtail_manage_tool']) {
    assert.match(src, new RegExp(`^function ${fn}\\(\\) \\{`, 'm'), `${fn} is defined`);
  }
  assert.doesNotMatch(src, /^function build_wagtail\(\)/m, 'the core\'s own example function is not redefined');
  assert.match(src, /--project-type=generic --webserver-type=generic --docroot=""/, 'a generic project: the container tool has no type for Wagtail');
  assert.match(src, /--database=postgres:16/, 'PostgreSQL from the container tool');
  assert.match(src, /\/bin\/wagtail start \$\{package\} app/, 'a new project, as wagtail start makes it');
  assert.match(src, /codeload\.github\.com\/wagtail\/bakerydemo\/tar\.gz\/\$\{ref\}/, 'the official demo, at a commit');
  assert.match(src, /manage load_initial_data/, 'the demo\'s own content');
  assert.match(src, /uv python install \$\{python\}/, 'the Python of the site comes with the web image');
  assert.match(src, /--nodejs-version=\$\(ddev_nodejs_version\)/, 'the build runs the Node.js of the workspace rule');
  assert.doesNotMatch(src, /ddev stop -y/, 'ddev stop takes no -y');
});

test('each agent is a definition the AI Agents folder can list: named after its file, described, on the fable model', () => {
  for (const f of manifest.ai.agents) {
    const src = read(f);
    const head = src.split('\n---\n')[0];
    assert.match(head, /^---\n/, `${f} opens with frontmatter`);
    assert.match(head, new RegExp(`^name: ${path.basename(f, '.md')}$`, 'm'));
    assert.match(head, /^description: .{80,}$/m, `${f} says when to use it`);
    assert.match(head, /^model: fable$/m);
    assert.match(head, /^tools:\n(  - \S+\n?)+/m);
    assert.match(src, /cmd-tools-testing\.sh|cmd-wagtail-project\.sh/, `${f} names the plugin's commands`);
  }
  const tester = read('ai/agents/wagtail-tester.md');
  assert.match(tester, /Never create or delete an account in a suite/);
  assert.match(tester, /No platform name in a step phrase/);
  assert.match(tester, /Playwright MCP browser first/);
});

test('register() adds the assistant context and nothing else', () => {
  const calls: string[] = [];
  const api: any = { name: 'wagtail', addAssistantContext: (fn: () => string) => calls.push(fn()) };
  register(api);
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0], assistantContext());
  for (const c of COMMANDS) assert.ok(calls[0].includes(c), `the assistant is told about ${c}`);
  for (const a of AGENTS) assert.ok(calls[0].includes(a), `the assistant is told about ${a}`);
});

test('the docs say container-based, name only what ships, and carry no personal value', () => {
  const docs = ['README.md', ...manifest.ai.agents, 'scripts/functions/fun-wagtail.sh'];
  for (const f of docs) {
    const src = read(f);
    assert.doesNotMatch(src, /DDEV-only/i, `${f}: the workspace is container-based, DDEV by default`);
    assert.doesNotMatch(src, /\/home\/(?!YOUR_USER)[a-z]/, `${f} carries no personal path`);
    const mails = src.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[a-z]{2,}/g) || [];
    for (const m of mails) assert.match(m, /@example\.(com|org)$/, `${f}: ${m} is not an example address`);
  }
  for (const c of COMMANDS) assert.ok(read('README.md').includes(c), `the README lists ${c}`);
});

test('the builder lets the daemon start the server, and a failure shows the web container\'s log', () => {
  const src = read('scripts/functions/fun-wagtail.sh');
  // The daemon starts uWSGI by itself once .ready is there; a restart at that moment can stop it half way.
  const afterReady = src.split('touch "${project_path}/.ready" ;')[1] || '';
  const nextCall = (afterReady.match(/\b(wagtail_wait|wagtail_restart|supervisorctl \w+)\b/) || [])[1];
  assert.strictEqual(nextCall, 'wagtail_wait', 'after .ready the builder waits for the site, it does not restart the server');
  assert.match(src, /function wagtail_wait\(\) \{[\s\S]*?ddev logs -s web --tail \d+[\s\S]*?\n\}/, 'the site not answering shows the end of the web container\'s log');
  assert.doesNotMatch(src, /supervisorctl tail/, 'the daemons have no log file of their own');
  assert.match(src, /function wagtail_restart\(\) \{\n[^\n]*supervisorctl restart webextradaemons:wagtail[^\n]*\n\s+wagtail_wait ;/, 'a restart is judged by the site\'s answer');
});
