#!/usr/bin/env bash

# Wagtail for the Webship Workspace: build a site (a new project made with `wagtail start`, or the official
# Wagtail Bakery demo with its content), run manage.py on it, add its default accounts, and wire its step pack into
# the testing setup.
#
# Placed by `plugins.sh --install wagtail` in core/scripts/plugins/wagtail/functions/, where bootstrap sources it
# after the core's own functions. Everything runs in the project's containers (DDEV by default), never on the host:
# the web image gets uv and the Python the site runs on, the site lives in a virtual environment of the project,
# the web container runs it with uWSGI (the server of the demo's production image) as a daemon, the router of the
# container tool sends the project's address to it, PostgreSQL is the container tool's database, and the mail goes
# to the project's mail catcher.
#
# DDEV has no project type for Wagtail, so a Wagtail site is a generic project that the plugin claims with a file
# of its own (.ddev/config.wagtail.yaml: the daemon, its port, its settings), and four names are the ones the core's
# tools look for:
#   set_wagtail_users          the default accounts                         (cmd-tools-add-users.sh <project> wagtail)
#   add_wagtail_users          make them in the site's database             (the same tool, and --add-users of the builder)
#   cancel_wagtail_users       delete them (the demo's own two given back)  (cmd-tools-cancel-users.sh <project> wagtail)
#   testing_configure_wagtail  the step pack in the testing stack           (cmd-tools-testing.sh <project>)

# The step pack a Wagtail site is tested with, and the release line it is required at.
readonly WAGTAIL_STEPS_PACKAGE='@webship-js/wagtail-steps';
readonly WAGTAIL_STEPS_VERSION='^2.0.0';

# Where the site lives in the web container (the project of `wagtail start`, or the demo, in app/), the virtual
# environment, and the port uWSGI listens on.
readonly WAGTAIL_ROOT='/var/www/html';
readonly WAGTAIL_APP='/var/www/html/app';
readonly WAGTAIL_PORT='8000';
# The Python package a new project gets from `wagtail start` (its settings in mysite/settings/).
readonly WAGTAIL_PACKAGE='mysite';

# The release line the builder installs when --wagtail-version is not given (the current one; 7.4 is the
# long-term-support line), the Python of the site, and the uv release that installs it in the web image.
readonly WAGTAIL_DEFAULT_LINE='8.1';
readonly WAGTAIL_PYTHON='3.12';
readonly WAGTAIL_UV_VERSION='0.13.7';

# The Wagtail Bakery demo (github.com/wagtail/bakerydemo, BSD-3-Clause) at the commit that last ran on each release
# line: "Upgrade to Wagtail 8.1 final", and the last commit before "Upgrade to Wagtail 8.0".
function wagtail_bakerydemo_ref() {
  case "$1" in
    8.1) echo '890285b95dcf980215ab9e9942d64ed2b47c48c3' ;;
    7.4) echo '8e2b625755d8942412d5b7627b146a795933b8b2' ;;
    *) return 1 ;;
  esac
}

# The default accounts, the ones a scenario logs in as: a superuser, an editor (the Editors group: adds and changes
# pages, submits them for moderation), a moderator (the Moderators group: also publishes, locks, unlocks and
# reviews) and a member (no group: an account of the site with no access to the admin). Accounts are
# configuration, made once on the site; a test suite never creates or deletes one. The superuser --install makes is
# the workspace account and is not in this list. On the demo, editor and moderator are the demo's own accounts:
# they get the workspace's password.
function set_wagtail_users() {
  users=(administrator editor moderator member);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
  done
  user_administrator_role='superuser' ;
  user_editor_role='editor' ;
  user_moderator_role='moderator' ;
  user_member_role='none' ;
}

# Is this folder a Wagtail site of this plugin? The builder leaves .ddev/config.wagtail.yaml in it.
function wagtail_is_project() {
  [ -f "$1/.ddev/config.wagtail.yaml" ] ;
}

# Go to the project a tool was asked about, or say why not.
function wagtail_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! wagtail_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a Wagtail site of this plugin (it has no .ddev/config.wagtail.yaml)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# The Python package of a project's site: the folder beside manage.py that holds settings/ (bakerydemo, mysite).
function wagtail_package() {
  local settings ;
  settings="$(ls -d "${1:-.}"/app/*/settings 2>/dev/null | head -n 1)" ;
  [ -n "${settings}" ] && basename "$(dirname "${settings}")" || echo "${WAGTAIL_PACKAGE}" ;
}

# Is the site of a project the Wagtail Bakery demo?
function wagtail_is_bakerydemo() {
  [ -f "${1:-.}/app/bakerydemo/base/fixtures/bakerydemo.json" ] ;
}

# What the container tool is told about the site, which is also the plugin's claim on the project: the router sends
# ports 80 and 443 of the project's address to uWSGI, which the web container runs as a daemon once the build has
# finished (.ready), with the site's own production settings and the ones of the containers (container.py), its
# static files and its media files served by uWSGI. The web image gets uv and the Python of the site.
function wagtail_write_ddev_config() {
  local project_path="$1" python="$2" package="$3" secret ;
  secret="$(python3 -c 'import secrets; print(secrets.token_urlsafe(50))')" || return 1 ;
  mkdir -p "${project_path}/.ddev/web-build" || return 1 ;
  cat > "${project_path}/.ddev/config.wagtail.yaml" <<YAMLEOF
# Wagtail in this project, and the claim of the workspace's Wagtail plugin on it. Written by the Wagtail builder of
# the workspace; build again rather than editing by hand. The web container serves no files of its own: the router
# sends ports 80 and 443 of the project's address to uWSGI, which the web container runs as a daemon once the build
# has finished (.ready), with the site's production settings (DEBUG off) and the ones of the containers
# (${package}/settings/container.py: the database, the address, the mail to the mail catcher); uWSGI serves the
# static files and the media files too.
web_extra_exposed_ports:
  - name: wagtail
    container_port: ${WAGTAIL_PORT}
    http_port: 80
    https_port: 443
web_extra_daemons:
  - name: wagtail
    command: "bash -c 'while [ ! -f ${WAGTAIL_ROOT}/.ready ]; do sleep 2; done; cd ${WAGTAIL_APP} && exec ${WAGTAIL_ROOT}/.venv/bin/uwsgi --http-socket :${WAGTAIL_PORT} --master --workers 2 --threads 4 --http-keepalive --http-auto-chunked --lazy-apps --wsgi-env-behaviour holy --virtualenv ${WAGTAIL_ROOT}/.venv --static-map /static/=${WAGTAIL_APP}/static --static-map /static/=${WAGTAIL_APP}/${package}/collect_static --static-map /media/=${WAGTAIL_APP}/media --static-map /media/=${WAGTAIL_APP}/${package}/media --wsgi-file ${package}/wsgi.py --die-on-term'"
    directory: ${WAGTAIL_ROOT}
web_environment:
  - DJANGO_SETTINGS_MODULE=${package}.settings.container
  - DATABASE_URL=postgres://db:db@db:5432/db
  - DJANGO_SECRET_KEY=${secret}
  - PRIMARY_HOST=${PROJECT_NAME}.ddev.site
  - PYTHONUNBUFFERED=1
YAMLEOF
  cat > "${project_path}/.ddev/web-build/Dockerfile.wagtail" <<DOCKEREOF
# Python for the Wagtail site, in the web image: uv (${WAGTAIL_UV_VERSION}), and the Python the site runs on (${python}),
# installed by uv. Written by the Wagtail builder of the workspace.
ENV UV_PYTHON_INSTALL_DIR=/opt/python
# The packages are copied into the project's virtual environment (the cache is on another file system).
ENV UV_LINK_MODE=copy
RUN arch="\$(uname -m)" \\
    && curl -sSfL "https://github.com/astral-sh/uv/releases/download/${WAGTAIL_UV_VERSION}/uv-\${arch}-unknown-linux-gnu.tar.gz" \\
       | tar -xz --strip-components=1 -C /usr/local/bin \\
    && uv python install ${python} \\
    && chmod -R a+rX /opt/python
DOCKEREOF
}

# manage.py in the container, with the Python of the site's virtual environment, in the folder of manage.py.
function wagtail_manage() {
  ddev exec -d "${WAGTAIL_APP}" "${WAGTAIL_ROOT}/.venv/bin/python manage.py $*" < /dev/null ;
}

# The releases of Wagtail and Django the site runs.
function wagtail_versions() {
  ddev exec "${WAGTAIL_ROOT}/.venv/bin/python -c 'import wagtail, django; print(\"Wagtail\", wagtail.__version__, \"on Django\", django.get_version())'" < /dev/null 2>/dev/null | tr -d '\r' ;
}

# The pip requirement for a --wagtail-version: a release line ("8.1": its latest release) or one release ("8.1.0").
function wagtail_requirement() {
  local version="${1:-${WAGTAIL_DEFAULT_LINE}}" ;
  if [[ "${version}" =~ ^[0-9]+\.[0-9]+$ ]] ; then
    echo "wagtail~=${version}.0" ;
  elif [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
    echo "wagtail==${version}" ;
  else
    return 1 ;
  fi
}

# Wait until the site answers its admin login page on its own port.
function wagtail_wait() {
  local attempt code ;
  for attempt in $(seq 1 90) ; do
    code="$(ddev exec "curl -s -o /dev/null -w '%{http_code}' -H 'X-Forwarded-Proto: https' http://127.0.0.1:${WAGTAIL_PORT}/admin/login/" < /dev/null 2>/dev/null | tr -d '\r')" ;
    if [ "${code}" == '200' ] ; then
      return 0 ;
    fi
    sleep 2 ;
  done
  # The daemons of the web container write to the container's log, not to a log file of their own.
  echo "The site did not answer; the end of the web container's log:" ;
  ddev logs -s web --tail 60 < /dev/null 2>/dev/null ;
  return 1 ;
}

# Start the server again (the daemon of the web container), and wait for it. A first start that fails is tried again by
# supervisor, so the site's answer decides, not supervisorctl's.
function wagtail_restart() {
  ddev exec "supervisorctl restart webextradaemons:wagtail" < /dev/null > /dev/null 2>&1 ;
  wagtail_wait ;
}

# Run a verb of wagtail-site.py (settings, site <host>, accounts <verb>, tidy) with the site's Python, in the folder of
# manage.py. The script is piped to the Python of the site, and the accounts travel as base64 of a JSON object, so no
# password is written into a file of the project and no quoting can break a value.
function wagtail_site() {
  local script="${WORKSPACE_SCRIPTS}/plugins/wagtail/wagtail-site.py" rows="" user name mail password role payload ;
  if [ ! -f "${script}" ] ; then
    echo "wagtail-site.py is not in ${WORKSPACE_SCRIPTS}/plugins/wagtail: install the plugin (plugins.sh --install wagtail)." ;
    return 1 ;
  fi
  for user in "${users[@]}" ; do
    name="user_${user}_name"; mail="user_${user}_mail"; password="user_${user}_password"; role="user_${user}_role";
    rows="${rows}${!name}"$'\x1f'"${!mail}"$'\x1f'"${!password}"$'\x1f'"${!role}"$'\x1e' ;
  done
  payload="$(WAGTAIL_OWNER_NAME="${account_name}" WAGTAIL_OWNER_MAIL="${account_mail}" WAGTAIL_OWNER_PASS="${account_pass}" \
    WAGTAIL_ROWS="${rows}" python3 -c '
import base64, json, os
accounts = [dict(zip(("name", "email", "password", "role"), row.split("\x1f"))) for row in os.environ["WAGTAIL_ROWS"].split("\x1e") if row]
print(base64.b64encode(json.dumps({
    "owner": {"name": os.environ["WAGTAIL_OWNER_NAME"], "email": os.environ["WAGTAIL_OWNER_MAIL"], "password": os.environ["WAGTAIL_OWNER_PASS"]},
    "accounts": accounts,
}).encode()).decode())')" || return 1 ;
  # The accounts go in a first line before the script, on Python's standard input: never on a command line.
  { printf 'WAGTAIL_SITE_ACCOUNTS = "%s"\n' "${payload}" ; cat "${script}" ; } \
    | ddev exec -d "${WAGTAIL_APP}" "${WAGTAIL_ROOT}/.venv/bin/python - $*" ;
}

# Build a Wagtail site from nothing: the containers, the packages, a new project made with `wagtail start` (or the
# Wagtail Bakery demo with --bakerydemo), the database and its content, the static files, the site's address; with
# --install the workspace account as its superuser, with --add-users the default accounts.
function wagtail_build() {
  trim_project_name ;
  local base_url="https://${PROJECT_NAME}.ddev.site" ;
  local version="${WAGTAIL_VERSION:-${site_wagtail_version:-${WAGTAIL_DEFAULT_LINE}}}" ;
  local python="${PYTHON_VERSION:-${site_python_version:-${WAGTAIL_PYTHON}}}" ;
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" ;
  local requirement="" ref="" package="${WAGTAIL_PACKAGE}" kind="a new project made with wagtail start" ;

  if [ "${BAKERYDEMO}" == 'yes' ] ; then
    if ! ref="$(wagtail_bakerydemo_ref "${version}")" ; then
      echo "--bakerydemo runs on the release lines 8.1 (the current one) and 7.4 (the long-term-support one), not ${version}. Nothing was changed." ;
      exit 1 ;
    fi
    package='bakerydemo' ;
    kind="the Wagtail Bakery demo with its content" ;
  elif ! requirement="$(wagtail_requirement "${version}")" ; then
    echo "--wagtail-version takes a release line (8.1, 7.4) or one release (8.1.0), not ${version}. Nothing was changed." ;
    exit 1 ;
  fi
  if [ "${ADD_USERS}" == 'yes' ] && [ "${INSTALL}" != 'yes' ] ; then
    echo "--add-users needs --install: the default accounts go to a site that has its superuser." ;
    exit 1 ;
  fi
  if [ ${#PROJECT_NAME} -gt 40 ] || ! [[ "${PROJECT_NAME}" =~ ^[a-z0-9][a-z0-9-]*$ ]] ; then
    echo "The project name ${PROJECT_NAME} must be small letters, digits and dashes (its address and its container take it). Nothing was changed." ;
    exit 1 ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  # A project of the same name goes first, with its containers and its database.
  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}/app" ;
  cd "${project_path}" || exit 1 ;

  # A generic web server: no nginx and no PHP are started. The database is PostgreSQL 16.
  ddev config --project-type=generic --webserver-type=generic --docroot="" --project-name=${PROJECT_NAME} \
    --database=postgres:16 --nodejs-version=$(ddev_nodejs_version) < /dev/null || exit 1 ;
  wagtail_write_ddev_config "${project_path}" "${python}" "${package}" || exit 1 ;
  ddev_up start -y < /dev/null || exit 1 ;

  if [ "${BAKERYDEMO}" == 'yes' ] ; then
    echo "Getting the Wagtail Bakery demo at ${ref} (Wagtail ${version})." ;
    curl -sSfL "https://codeload.github.com/wagtail/bakerydemo/tar.gz/${ref}" | tar -xz --strip-components=1 -C app \
      || { echo "The demo could not be downloaded." ; exit 1 ; } ;
    echo "Installing the demo's packages on Python ${python} in a virtual environment." ;
    ddev exec "uv venv --clear --seed --python ${python} ${WAGTAIL_ROOT}/.venv && uv pip install --python ${WAGTAIL_ROOT}/.venv/bin/python -r ${WAGTAIL_APP}/requirements/base.txt 'psycopg[binary]>=3.3,<3.4' 'whitenoise>=6.11,<7' 'pyuwsgi>=2.0.30,<2.1'" < /dev/null \
      || { echo "The install of the demo's packages failed." ; exit 1 ; } ;
  else
    echo "Installing ${requirement} on Python ${python} in a virtual environment." ;
    ddev exec "uv venv --clear --seed --python ${python} ${WAGTAIL_ROOT}/.venv && uv pip install --python ${WAGTAIL_ROOT}/.venv/bin/python '${requirement}' 'psycopg[binary]>=3.3,<3.4' 'pyuwsgi>=2.0.30,<2.1'" < /dev/null \
      || { echo "The install of Wagtail failed." ; exit 1 ; } ;
    ddev exec -d "${WAGTAIL_ROOT}" "${WAGTAIL_ROOT}/.venv/bin/wagtail start ${package} app" < /dev/null \
      || { echo "wagtail start failed." ; exit 1 ; } ;
  fi

  users=() ;
  wagtail_site settings || exit 1 ;
  wagtail_manage migrate --noinput || { echo "manage.py migrate failed." ; exit 1 ; } ;
  if [ "${BAKERYDEMO}" == 'yes' ] ; then
    wagtail_manage load_initial_data || { echo "The demo content could not be loaded." ; exit 1 ; } ;
  fi
  wagtail_manage collectstatic --noinput -v 0 || { echo "manage.py collectstatic failed." ; exit 1 ; } ;
  wagtail_site site "${PROJECT_NAME}.ddev.site" || exit 1 ;

  if [ "${INSTALL}" == 'yes' ] ; then
    wagtail_site accounts owner || { echo "The superuser could not be made." ; exit 1 ; } ;
    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_wagtail_users ;
      add_wagtail_users || exit 1 ;
      cd "${project_path}" || exit 1 ;
    fi
  fi

  # The daemon has waited for .ready since the project started, and starts uWSGI within two seconds of it. No restart
  # here: one that lands while the daemon is starting the server stops it half way, and the next start finds the port
  # still held ("spawn error").
  touch "${project_path}/.ready" ;
  echo "Starting the site (uWSGI)." ;
  wagtail_wait || exit 1 ;

  echo "${doc_name} ${PROJECT_NAME} has been built: ${kind}, $(wagtail_versions), at ${base_url}." ;
  echo "The admin: ${base_url}/admin/ · the mail catcher: ${base_url}:8026" ;
  if [ "${INSTALL}" == 'yes' ] ; then
    echo "Log in as ${account_name}." ;
    [ "${ADD_USERS}" == 'yes' ] && echo "The default accounts: administrator (superuser), editor (Editors), moderator (Moderators), member (no access to the admin), each @example.com with the workspace's shared password." ;
  else
    echo "No superuser yet: give it one with bash cmd-tools-wagtail-manage.sh ${PROJECT_NAME} --run createsuperuser (or build with --install)." ;
  fi
  users=() ;

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch /admin/ ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Make the default accounts in the site's database. An account that is already there gets its password, address,
# state and group back. The list is loaded by the caller (set_wagtail_users): the core's add_users, the builder, the
# manage.py tool.
function add_wagtail_users() {
  wagtail_enter_project || return 1 ;
  local user user_name user_mail user_password user_role ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role}";
    echo " ================================================================= ";
  done
  local status=0 ;
  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y < /dev/null || status=1 ;
  fi
  wagtail_site accounts add || status=1 ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# Delete the default accounts (never the workspace account). What they did stays in the site's history. On the demo,
# its own editor and moderator, which the default accounts took over, are given back as the demo made them instead,
# so its pages, revisions and workflow keep their authors (wagtail-site.py, accounts cancel).
function cancel_wagtail_users() {
  wagtail_enter_project || return 1 ;
  local user user_name ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
  done
  local status=0 ;
  wagtail_site accounts cancel || status=1 ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# What cmd-tools-wagtail-manage.sh does: the first of --run, --update, --restart, --tidy, --add-users,
# --cancel-users that was asked for; with none of them, what the site is.
function wagtail_manage_tool() {
  trim_project_name ;
  wagtail_enter_project || exit 1 ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y < /dev/null || exit 1 ;
  fi

  if [ ! "${RUN}" == '_none_' ] ; then
    # Unquoted on purpose: --run "update_index" is a command and its arguments.
    wagtail_manage ${RUN} ;
    exit $? ;
  fi

  if [ "${UPDATE}" == 'yes' ] ; then
    if wagtail_is_bakerydemo . ; then
      echo "The demo pins its own releases (its requirements): build it again with --bakerydemo --wagtail-version to change them." ;
      exit 1 ;
    fi
    local installed line ;
    installed="$(ddev exec "${WAGTAIL_ROOT}/.venv/bin/python -c 'import wagtail; print(wagtail.__version__)'" < /dev/null | tr -d '\r')" ;
    line="$(echo "${installed}" | cut -d. -f1,2)" ;
    echo "Wagtail ${installed} is installed." ;
    ddev exec "uv pip install --python ${WAGTAIL_ROOT}/.venv/bin/python --upgrade 'wagtail~=${line}.0'" < /dev/null || exit 1 ;
    wagtail_manage migrate --noinput || exit 1 ;
    wagtail_manage collectstatic --noinput -v 0 || exit 1 ;
    wagtail_restart || exit 1 ;
    echo "$(wagtail_versions) is running." ;
  elif [ "${RESTART}" == 'yes' ] ; then
    wagtail_restart || exit 1 ;
    echo "$(wagtail_versions) is running." ;
  elif [ "${TIDY}" == 'yes' ] ; then
    users=() ;
    wagtail_site tidy ;
  elif [ "${ADD_USERS}" == 'yes' ] ; then
    set_wagtail_users ;
    add_wagtail_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    set_wagtail_users ;
    cancel_wagtail_users ;
  else
    local what='a project made with wagtail start' ;
    wagtail_is_bakerydemo . && what='the Wagtail Bakery demo' ;
    echo "${doc_name}/${PROJECT_NAME}: ${what}, $(wagtail_versions)" ;
    echo "  the site:         https://${PROJECT_NAME}.ddev.site" ;
    echo "  the admin:        https://${PROJECT_NAME}.ddev.site/admin/" ;
    echo "  the mail catcher: https://${PROJECT_NAME}.ddev.site:8026" ;
    echo "Accounts:" ;
    users=() ;
    wagtail_site accounts list | sed 's/^/  /' ;
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a Wagtail site. The core's testing_configure calls this in the project folder
# once webship-js is scaffolded and before the dependencies are installed; for a project that is not one of this
# plugin's it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's own, gives
# cucumber.js the tags that keep the pack's assertions that must fail out of a normal run, the path of the admin, the
# mail catcher, the browser messages that are no error of the site (the admin's accessibility checker writes its
# findings to the console), the users registry of the default accounts (a handle a scenario reads, mapped to an
# account; never the workspace account), and the site's address in place of the starter's, and writes a first
# feature when the project has none of its own. Every part is skipped when it is already there, so a second run
# adds what the first missed and never resets a suite.
function testing_configure_wagtail() {
  local project_path="$1";
  wagtail_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Wagtail: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the Wagtail step pack (${WAGTAIL_STEPS_PACKAGE} ${WAGTAIL_STEPS_VERSION}).";
  set_wagtail_users ;
  local registry="" user user_name user_mail user_password site_name ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail"; user_password="user_${user}_password";
    registry="${registry}${user}|${!user_mail}|${!user_password}|${!user_name}"$'\n' ;
  done
  site_name="$(sed -n 's/^name:[[:space:]]*"\{0,1\}\([A-Za-z0-9._-]*\)"\{0,1\}[[:space:]]*$/\1/p' "${project_path}/.ddev/config.yaml" | head -n 1)" ;

  python3 - "${project_path}" "${WAGTAIL_STEPS_PACKAGE}" "${WAGTAIL_STEPS_VERSION}" 'WAGTAIL' "${registry}" "https://${site_name:-${PROJECT_NAME}}.ddev.site" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry, address = sys.argv[1:7]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=4) + '\n')
    print('  package.json: %s %s' % (pack, version))

cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        block = [
            pad + "// The pack's assertions that must fail are no part of a normal run.",
            pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail',",
        ]
        src = src[:default.end()] + '\n' + '\n'.join(block) + src[default.end():]
        print('  cucumber.js: the tags that keep the assertions that must fail out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
pad = world.group(1) + '  '
additions = []
if not re.search(r"^[ \t]*adminPath:", src, re.M):
    additions += [
        pad + "// Where the admin is on the site (/admin/ in a project made with wagtail start, and in the demo), and the",
        pad + "// mail catcher the site sends its mail to (a password reset, the notices of a workflow).",
        pad + "adminPath: process.env.ADMIN_PATH || '/admin/',",
        pad + "mailUrl: process.env.MAIL_URL || '%s:8026'," % address,
    ]
if not re.search(r"^[ \t]*javascript:", src, re.M):
    additions += [
        pad + "// Browser messages that are no error of the site: the findings of the admin's accessibility checker,",
        pad + "// which it writes to the console as errors (\"axe.run results\").",
        pad + "javascript: { mode: process.env.WEBSHIP_JS_ERROR_MODE || 'warn', levels: ['error'], ignore: 'axe\\\\.run results', beforeScenario: false, afterScenario: true },",
    ]
if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    additions += [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of this site (the default",
        pad + "// accounts: cmd-tools-wagtail-manage.sh --add-users). Override one with %s_<HANDLE>_USERNAME," % prefix,
        pad + "// %s_<HANDLE>_PASSWORD and %s_<HANDLE>_EMAIL." % (prefix, prefix),
        pad + "users: {",
    ]
    for handle, email, password, name in rows:
        env = '%s_%s' % (prefix, handle.upper())
        additions.append(pad + "  %s: { username: process.env.%s_USERNAME || '%s', password: process.env.%s_PASSWORD || '%s', email: process.env.%s_EMAIL || '%s' }," % (handle, env, name, env, password, env, email))
    additions.append(pad + "},")
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))
if additions:
    src = src[:world.end()] + '\n' + '\n'.join(additions) + src[world.end():]

# The address the suite opens when LAUNCH_URL is not set: the placeholder of the scaffold becomes the site's.
placeholder = "process.env.LAUNCH_URL || 'http://localhost:8080'"
if placeholder in src:
    src = src.replace(placeholder, "process.env.LAUNCH_URL || '%s'" % address)
    print('  cucumber.js: the address of the site (%s)' % address)

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the site yet: the login page, each default account, a refused
  # login, the dashboard, the page explorer, a page written and deleted.
  local feature="${WORKSPACE_SCRIPTS}/plugins/wagtail/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the site" ;
  fi

  # The scenarios log in as the default accounts: make sure the site has them, once it answers again (installing
  # the webship-js add-on restarts the project, and the site with it).
  if ( cd "${project_path}" && wagtail_wait > /dev/null 2>&1 ) && ( add_wagtail_users > /dev/null 2>&1 ) ; then
    echo "  the default accounts are on the site (${users[*]})" ;
  else
    echo "  The default accounts could not be written: is the site running (ddev start in ${project_path})?" ;
  fi
}
