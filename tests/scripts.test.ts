import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-wagtail.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['tsx/cjs'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/**
 * A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled.
 * A Wagtail project of this plugin has the builder's .ddev/config.wagtail.yaml.
 */
function project(kind: 'wagtail' | 'drupal') {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'wagtail-plugin-'));
  const dir = path.join(root, 'dev', 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: site1\ntype: ${kind === 'wagtail' ? 'generic' : 'drupal11'}\n`);
  if (kind === 'wagtail') fs.writeFileSync(path.join(dir, '.ddev', 'config.wagtail.yaml'), 'web_extra_daemons: []\n');
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'site1', devDependencies: { 'webship-js': '^2.0.6' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'wagtail'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'site.feature'), path.join(scripts, 'plugins', 'wagtail', 'site.feature'));
  fs.copyFileSync(path.join(PKG, 'scripts', 'wagtail-site.py'), path.join(scripts, 'plugins', 'wagtail', 'wagtail-site.py'));
  return { root, dir, scripts };
}

/**
 * Run bash with the plugin's functions sourced and `ddev` replaced by a recorder of its calls (and of what it reads on
 * stdin: its first line whole, then the start of the rest); asked for a status code (the site answering), the
 * recorder says 200.
 */
function bash(script: string, env: Record<string, string> = {}) {
  const fake = 'ddev() { echo "ddev $*" >> "${DDEV_LOG:-/dev/null}" ; case "$*" in *http_code*) echo 200 ;; esac ; if [ ! -t 0 ] ; then IFS= read -r first ; echo "  stdin first line: ${first}" >> "${DDEV_LOG:-/dev/null}" ; head -c 120 | sed "s/^/  stdin: /" >> "${DDEV_LOG:-/dev/null}" ; echo >> "${DDEV_LOG:-/dev/null}" ; fi ; return 0 ; }';
  return spawnSync('bash', ['-c', `${fake}\nsource ${FUNCTIONS}\n${script}`], { encoding: 'utf8', env: { ...process.env, ...env } });
}

/**
 * The accounts a recorded call of wagtail-site.py carried: the base64 of their JSON object, in the first line of its
 * standard input, never on its command line.
 */
function payloadOf(log: string, call: string) {
  assert.doesNotMatch(call, /WAGTAIL_SITE_ACCOUNTS|password/i, 'no account on the command line');
  const lines = log.split('\n');
  const first = lines[lines.indexOf(call) + 1] || '';
  const m = first.match(/^  stdin first line: WAGTAIL_SITE_ACCOUNTS = "([A-Za-z0-9+\/=]+)"$/);
  assert.ok(m, `the accounts come first on stdin: ${first}`);
  return JSON.parse(Buffer.from(m![1], 'base64').toString('utf8'));
}

test('the default accounts are a superuser, an editor, a moderator and a member, with example addresses', () => {
  const r = bash('set_wagtail_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; g="user_${u}_role" ; echo "${!n}|${!m}|${!p}|${!g}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['administrator', 'editor', 'moderator', 'member']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['superuser', 'editor', 'moderator', 'none']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.ok(password.length >= 10, 'long enough for the password rules of a site');
  }
});

test('the accounts are written by the site script with the site\'s Python, in the folder of manage.py, never in a file or on a command line', () => {
  const p = project('wagtail');
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, account_name: 'owner1', account_mail: 'owner1@example.com', account_pass: 'Owner-pass-1' };
  const r = bash('set_wagtail_users ; add_wagtail_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const written = fs.readFileSync(log, 'utf8');
  const call = written.split('\n').find((l) => l.startsWith('ddev exec -d /var/www/html/app')) as string;
  assert.match(call, /\/var\/www\/html\/\.venv\/bin\/python - accounts add$/);
  assert.match(written, /stdin: """A Wagtail site in the containers of a test project/, 'the script goes in on stdin');
  const payload = payloadOf(written, call);
  assert.deepStrictEqual(payload.accounts.map((a: any) => [a.name, a.role]), [['administrator', 'superuser'], ['editor', 'editor'], ['moderator', 'moderator'], ['member', 'none']]);
  assert.strictEqual(payload.owner.name, 'owner1');
  assert.deepStrictEqual(fs.readdirSync(p.dir).filter((f) => !['.ddev', 'cucumber.js', 'package.json'].includes(f)), [], 'no file with a password is left in the project');
});

test('cancelling the accounts deletes the default ones through the site script', () => {
  const p = project('wagtail');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_wagtail_users ; cancel_wagtail_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, account_name: 'owner1', account_mail: 'owner1@example.com', account_pass: 'x' });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const written = fs.readFileSync(log, 'utf8');
  const call = written.split('\n').find((l) => l.includes(' - accounts cancel')) as string;
  assert.ok(call, 'the cancel verb is called');
  assert.deepStrictEqual(payloadOf(written, call).accounts.map((a: any) => a.name), ['administrator', 'editor', 'moderator', 'member']);
});

test('a --wagtail-version is a release line or one release; the demo runs on the lines it was proven on', () => {
  const r = bash('for v in "" 8.1 7.4 8.1.0 latest 8 ; do wagtail_requirement "$v" || echo "refused $v" ; done');
  assert.deepStrictEqual(r.stdout.trim().split('\n'), ['wagtail~=8.1.0', 'wagtail~=8.1.0', 'wagtail~=7.4.0', 'wagtail==8.1.0', 'refused latest', 'refused 8']);
  const d = bash('for v in 8.1 7.4 8.0 ; do wagtail_bakerydemo_ref "$v" || echo "refused $v" ; done');
  assert.deepStrictEqual(d.stdout.trim().split('\n'), ['890285b95dcf980215ab9e9942d64ed2b47c48c3', '8e2b625755d8942412d5b7627b146a795933b8b2', 'refused 8.0']);
});

test('the builder writes the claim of the plugin: uWSGI as a daemon behind the router, the settings, the Python of the site', () => {
  const p = project('wagtail');
  const r = bash(`PROJECT_NAME=site1 ; wagtail_write_ddev_config ${p.dir} 3.12 bakerydemo`);
  assert.strictEqual(r.status, 0, r.stderr);
  const config = fs.readFileSync(path.join(p.dir, '.ddev', 'config.wagtail.yaml'), 'utf8');
  assert.match(config, /container_port: 8000\n\s+http_port: 80\n\s+https_port: 443/);
  assert.match(config, /\.venv\/bin\/uwsgi --http-socket :8000 .* --static-map \/media\/=\/var\/www\/html\/app\/bakerydemo\/media --wsgi-file bakerydemo\/wsgi\.py/);
  assert.match(config, /DJANGO_SETTINGS_MODULE=bakerydemo\.settings\.container/);
  assert.match(config, /DATABASE_URL=postgres:\/\/db:db@db:5432\/db/);
  assert.match(config, /PRIMARY_HOST=site1\.ddev\.site/);
  assert.match(config, /DJANGO_SECRET_KEY=\S{40,}/, 'a secret key of its own for the project');
  const docker = fs.readFileSync(path.join(p.dir, '.ddev', 'web-build', 'Dockerfile.wagtail'), 'utf8');
  assert.match(docker, /uv python install 3\.12/);
  assert.match(docker, /releases\/download\/0\.13\.7\/uv-\$\{arch\}-unknown-linux-gnu\.tar\.gz/);
});

test('the testing hook adds the step pack, the users registry, the admin\'s settings, the tags and a first feature, once', () => {
  const p = project('wagtail');
  const log = path.join(p.root, 'ddev.log');
  const run = () => bash(`cd ${p.dir} && testing_configure_wagtail ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, account_name: 'owner1', account_mail: 'owner1@example.com', account_pass: 'x' });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/wagtail-steps'], '^2.0.0');
  assert.strictEqual(pkg.devDependencies['webship-js'], '^2.0.6', 'what was there stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/wagtail-steps/tests/step-definitions/**/*.js',", 'the pack is listed right after webship-js');
  assert.match(cucumber, /administrator: \{ username: process\.env\.WAGTAIL_ADMINISTRATOR_USERNAME \|\| 'administrator', password: process\.env\.WAGTAIL_ADMINISTRATOR_PASSWORD \|\| '[^']+', email: process\.env\.WAGTAIL_ADMINISTRATOR_EMAIL \|\| 'administrator@example\.com' \},/);
  assert.match(cucumber, /member: \{ username: process\.env\.WAGTAIL_MEMBER_USERNAME \|\| 'member'/);
  assert.match(cucumber, /adminPath: process\.env\.ADMIN_PATH \|\| '\/admin\/',/);
  assert.match(cucumber, /mailUrl: process\.env\.MAIL_URL \|\| 'https:\/\/site1\.ddev\.site:8026',/);
  assert.match(cucumber, /tags: process\.env\.CUCUMBER_TAGS \|\| 'not @wip and not @must-fail',/);
  assert.match(cucumber, /ignore: 'axe\\\\\.run results'/);
  assert.match(cucumber, /launchUrl: process\.env\.LAUNCH_URL \|\| 'https:\/\/site1\.ddev\.site'/, 'the site\'s address in place of the scaffold\'s');
  // Still a module node can load, with the registry where webship-js reads it.
  const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; console.log(JSON.stringify([c.require, Object.keys(c.worldParameters.users), c.tags, c.worldParameters.users.editor.username, c.worldParameters.javascript.mode, c.worldParameters.javascript.ignore]))`], { encoding: 'utf8', env: { ...process.env, CUCUMBER_TAGS: '' } });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, tags, username, mode, ignore] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires.length, 3);
  assert.deepStrictEqual(handles, ['administrator', 'editor', 'moderator', 'member']);
  assert.match(tags, /not @must-fail/);
  assert.strictEqual(username, 'editor');
  assert.strictEqual(mode, 'warn');
  assert.ok(new RegExp(ignore).test('axe.run results [Object]'), 'the accessibility checker\'s findings are ignored');
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')));
  assert.match(fs.readFileSync(log, 'utf8'), / - accounts add$/m, 'the site gets the default accounts');
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), 'Feature: mine\n');
});

test('the testing hook leaves a project of another platform alone', () => {
  const p = project('drupal');
  const r = bash(`cd ${p.dir} && testing_configure_wagtail ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
});

test('the manage.py tool refuses a project that is not a Wagtail site of the plugin', () => {
  const p = project('drupal');
  const r = bash('PROJECT_NAME=site1 ; RUN="check" ; trim_project_name() { :; } ; wagtail_manage_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev' });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /is not a Wagtail site of this plugin/);
});

test('the first feature names no platform in a step, and no password', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'site.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s, /wagtail|django|python/i, s);
  assert.doesNotMatch(feature, /dD\.123123ddd"/);
  assert.doesNotMatch(feature, /createsuperuser/i, 'a suite never creates an account');
});

test('cancelling gives back an account the site\'s own fixtures make (the demo\'s editor), and deletes the others', () => {
  // The part of the site script that needs no Django: which accounts the site's fixtures make, read from a folder laid
  // out as the demo's (bakerydemo/base/fixtures/bakerydemo.json); a site made with wagtail start has none.
  const site = fs.mkdtempSync(path.join(os.tmpdir(), 'wagtail-site-'));
  fs.mkdirSync(path.join(site, 'bakerydemo', 'base', 'fixtures'), { recursive: true });
  fs.writeFileSync(path.join(site, 'bakerydemo', 'base', 'fixtures', 'bakerydemo.json'), JSON.stringify([
    { model: 'auth.user', pk: 4, fields: { username: 'editor', email: 'editor@example.com', first_name: 'Eddy', password: 'pbkdf2_sha256$1$x$y', groups: [['Editors']] } },
    { model: 'auth.group', pk: 1, fields: { name: 'Editors' } },
    { model: 'wagtailcore.page', pk: 2, fields: { title: 'Root' } },
  ]));
  const probe = 'import importlib.util, json, sys\n'
    + 'spec = importlib.util.spec_from_file_location("site", sys.argv[1])\n'
    + 'module = importlib.util.module_from_spec(spec)\n'
    + 'spec.loader.exec_module(module)\n'
    + 'print(json.dumps(sorted(module.site_own_accounts())))\n';
  // No bytecode is written next to the script: the package ships its scripts folder as it is.
  const run = (cwd: string) => spawnSync('python3', ['-c', probe, path.join(PKG, 'scripts', 'wagtail-site.py')], { cwd, encoding: 'utf8', env: { ...process.env, PYTHONDONTWRITEBYTECODE: '1' } });
  const demo = run(site);
  assert.strictEqual(demo.status, 0, demo.stderr);
  assert.deepStrictEqual(JSON.parse(demo.stdout), ['editor'], 'the demo\'s own account is known, and only accounts');
  const plain = run(fs.mkdtempSync(path.join(os.tmpdir(), 'wagtail-plain-')));
  assert.strictEqual(plain.status, 0, plain.stderr);
  assert.deepStrictEqual(JSON.parse(plain.stdout), [], 'a new project has no accounts of its own');
  const src = fs.readFileSync(path.join(PKG, 'scripts', 'wagtail-site.py'), 'utf8');
  assert.match(src, /elif account\["name"\] in own:\n\s+give_back\(user, own\[account\["name"\]\]\)/, 'cancel gives such an account back');
  assert.match(src, /else:\n\s+user\.delete\(\)/, 'and deletes the others');
});
