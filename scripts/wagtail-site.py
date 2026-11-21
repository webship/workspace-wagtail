"""A Wagtail site in the containers of a test project: its settings there, its address and its accounts.

Run with the site's Python, in the folder of manage.py, in the project's container:

    python wagtail-site.py settings         write the settings of the containers (<package>/settings/container.py)
    python wagtail-site.py site <host>      the address of the site: https://<host>, as a deployment sets it
    python wagtail-site.py accounts <verb>  owner, add, cancel or list
    python wagtail-site.py tidy             remove what a run of the step pack that was stopped half way left

It works for the Wagtail Bakery demo and for a project made with `wagtail start`: both keep their settings in
<package>/settings/ (base.py, dev.py, production.py).

The accounts come as base64 of a JSON object, in a first line the caller puts before this script on the standard
input of Python (WAGTAIL_SITE_ACCOUNTS = "..."), or in the environment variable of that name: no password is written
into a file of the project or onto a command line, and no quoting can break a value:

    {"owner": {"name": ..., "email": ..., "password": ...},
     "accounts": [{"name": ..., "email": ..., "password": ..., "role": "superuser|editor|moderator|none"}]}

The roles are Wagtail's own: a superuser, the Editors group (adds and changes pages, submits them for moderation)
and the Moderators group (also publishes, locks and unlocks pages, and reviews what is submitted). "none" is an
account that may log in to nothing of the admin: no group, no permission, not staff. The groups are the ones Wagtail
makes when it is installed (the demo loads its own copies of them), so the same accounts fit a new site and the demo.

"accounts cancel" deletes the accounts of the list, except one that the site's own fixtures make (the demo's editor
and moderator, which the default accounts take over): that one is given back as its fixture made it (its address, its
names, its password, its group), so the pages, revisions and workflow of the demo keep their authors, and adding the
default accounts again takes it over again.
"""

import base64
import json
import os
import sys
from pathlib import Path

HERE = Path.cwd()

CONTAINER_SETTINGS = '''"""Settings of the site in the containers of its project (written by wagtail-site.py settings).

The site's production settings (DEBUG off: its own 404 and 500 pages), with what a deployment of it adds: the
database of the project's container (DATABASE_URL), the secret key and the address of the admin's links from the
environment of the web container (DJANGO_SECRET_KEY, PRIMARY_HOST), the router's HTTPS, and the mail sent over SMTP
to the project's mail catcher (Mailpit), so that a password reset or a moderation notice can be read there.
"""

import os
from urllib.parse import urlparse

from .production import *  # noqa: F401,F403

if os.environ.get("DATABASE_URL", "").startswith(("postgres://", "postgresql://")):
    _db = urlparse(os.environ["DATABASE_URL"])
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": _db.path.lstrip("/"),
            "USER": _db.username,
            "PASSWORD": _db.password,
            "HOST": _db.hostname,
            "PORT": str(_db.port or 5432),
            "CONN_MAX_AGE": 500,
        }
    }
    # Wagtail's database search backend indexes with PostgreSQL's own indexes, which need Django's PostgreSQL app:
    # the demo adds it to its settings by itself, a project made with `wagtail start` does not.
    if "django.contrib.postgres" not in INSTALLED_APPS:  # noqa: F405
        INSTALLED_APPS = [*INSTALLED_APPS, "django.contrib.postgres"]  # noqa: F405

if os.environ.get("DJANGO_SECRET_KEY"):
    SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]

# The site answers at the project's address, behind the router of the container tool, over HTTPS.
ALLOWED_HOSTS = ["*"]
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
if os.environ.get("PRIMARY_HOST"):
    WAGTAILADMIN_BASE_URL = "https://" + os.environ["PRIMARY_HOST"]
    CSRF_TRUSTED_ORIGINS = ["https://" + os.environ["PRIMARY_HOST"]]

EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = os.environ.get("EMAIL_HOST", "127.0.0.1")
EMAIL_PORT = int(os.environ.get("EMAIL_PORT", "1025"))
DEFAULT_FROM_EMAIL = os.environ.get("DEFAULT_FROM_EMAIL", "site@example.com")
SERVER_EMAIL = DEFAULT_FROM_EMAIL
'''


def setup_django():
    sys.path.insert(0, str(HERE))
    if not os.environ.get("DJANGO_SETTINGS_MODULE"):
        sys.exit("DJANGO_SETTINGS_MODULE is not set: run this in the web container of the project.")
    import django

    django.setup()


def settings_package():
    """The folder of the settings modules: <package>/settings/ beside manage.py."""
    for candidate in sorted(HERE.glob("*/settings/production.py")):
        return candidate.parent
    sys.exit("No <package>/settings/production.py here: run this in the folder of manage.py.")


def write_settings():
    target = settings_package() / "container.py"
    target.write_text(CONTAINER_SETTINGS)
    print(f"Wrote {target.relative_to(HERE)}")


def set_site(host):
    setup_django()
    from wagtail.models import Site

    site = Site.objects.filter(is_default_site=True).first() or Site.objects.first()
    if site is None:
        sys.exit("The site has no Site record: migrate it first.")
    site.hostname = host
    site.port = 443
    site.save()
    print(f"The site {site.site_name or site.hostname} answers at https://{host}")


def payload():
    raw = globals().get("WAGTAIL_SITE_ACCOUNTS") or os.environ.get("WAGTAIL_SITE_ACCOUNTS", "")
    return json.loads(base64.b64decode(raw).decode()) if raw else {}


def put_account(account):
    """Make the account, or give one that is there its address, password, state and group back."""
    from django.contrib.auth import get_user_model
    from django.contrib.auth.models import Group

    User = get_user_model()
    user, created = User.objects.get_or_create(username=account["name"])
    user.email = account["email"]
    user.is_active = True
    role = account.get("role", "none")
    user.is_superuser = role == "superuser"
    user.is_staff = role == "superuser"
    user.set_password(account["password"])
    user.save()
    user.user_permissions.clear()
    groups = {"editor": "Editors", "moderator": "Moderators"}
    if role in groups:
        group = Group.objects.filter(name=groups[role]).first()
        if group is None:
            sys.exit(f"The group {groups[role]} is not on the site: Wagtail makes it when it is installed.")
        user.groups.set([group])
    else:
        user.groups.clear()
    print(("Made" if created else "Put back") + f" {user.username} ({role}, {user.email})")


def site_own_accounts():
    """The accounts the site's own fixtures make, by user name: the demo's people (its editor and its moderator among
    them), from <package>/base/fixtures/*.json. A site made with `wagtail start` has none."""
    import glob

    found = {}
    for path in sorted(glob.glob(str(HERE / "*" / "fixtures" / "*.json")) + glob.glob(str(HERE / "*" / "*" / "fixtures" / "*.json"))):
        try:
            with open(path, encoding="utf-8") as handle:
                rows = json.load(handle)
        except (OSError, ValueError):
            continue
        for row in rows if isinstance(rows, list) else []:
            fields = row.get("fields") if isinstance(row, dict) and row.get("model") == "auth.user" else None
            if isinstance(fields, dict) and fields.get("username"):
                found[fields["username"]] = fields
    return found


def give_back(user, fields):
    """Put an account the site's fixture made back as the fixture made it: its address, names, state, password and
    groups (by name, or by id). Its pages, revisions and workflow keep it as their author."""
    from django.contrib.auth.models import Group
    from django.db.models import Q

    for name in ("email", "first_name", "last_name", "is_active", "is_staff", "is_superuser"):
        if name in fields:
            setattr(user, name, fields[name])
    if fields.get("password"):
        user.password = fields["password"]
    user.save()
    user.user_permissions.clear()
    groups = fields.get("groups") or []
    names = [g[0] for g in groups if isinstance(g, list) and g]
    ids = [g for g in groups if isinstance(g, int)]
    user.groups.set(Group.objects.filter(Q(name__in=names) | Q(pk__in=ids)))


def accounts(verb):
    setup_django()
    from django.contrib.auth import get_user_model

    User = get_user_model()
    data = payload()
    if verb == "owner":
        owner = data.get("owner") or {}
        if not owner.get("name"):
            sys.exit("accounts owner: no owner in WAGTAIL_SITE_ACCOUNTS.")
        put_account(dict(owner, role="superuser"))
    elif verb == "add":
        for account in data.get("accounts", []):
            put_account(account)
    elif verb == "cancel":
        own = site_own_accounts()
        for account in data.get("accounts", []):
            user = User.objects.filter(username=account["name"]).first()
            if user is None:
                print("No account " + account["name"])
            elif account["name"] in own:
                give_back(user, own[account["name"]])
                print(f"Gave back {user.username}: the site's own account, as its fixture made it")
            else:
                user.delete()
                print("Deleted " + account["name"])
    elif verb == "list":
        for user in User.objects.order_by("username"):
            groups = ", ".join(user.groups.values_list("name", flat=True))
            state = "superuser" if user.is_superuser else (groups or "no group")
            print(f"{user.username}\t{user.email}\t{state}\t{'active' if user.is_active else 'inactive'}")
    else:
        sys.exit("accounts: owner, add, cancel or list")


def tidy():
    """What a run of the step pack that was stopped half way can leave behind.

    The suite takes away what it makes as it goes; this is for a run that was killed before its own clean-up. Its
    test content carries "Webship test" in its title or name ("/webship-test" in a redirect's path): those pages
    (with their children), images, documents, collections, bread types, redirects and form submissions go, and
    the locks and workflows the suite put on the demo's own pages are taken off.
    """
    setup_django()
    from django.apps import apps
    from wagtail.models import Collection, Page

    removed = []
    for page in Page.objects.filter(title__startswith="Webship test").order_by("-depth"):
        if Page.objects.filter(pk=page.pk).exists():
            page.delete()
            removed.append(f"page {page.title}")
    for label in ("wagtailimages.Image", "wagtaildocs.Document"):
        model = apps.get_model(label)
        for item in model.objects.filter(title__startswith="Webship test"):
            item.delete()
            removed.append(f"{model._meta.verbose_name} {item.title}")
    for collection in Collection.objects.filter(name__startswith="Webship test").order_by("-depth"):
        collection.delete()
        removed.append(f"collection {collection.name}")
    if apps.is_installed("wagtail.contrib.redirects"):
        Redirect = apps.get_model("wagtailredirects.Redirect")
        for redirect in Redirect.objects.filter(old_path__startswith="/webship-test"):
            redirect.delete()
            removed.append(f"redirect {redirect.old_path}")
    if apps.is_installed("wagtail.contrib.forms"):
        FormSubmission = apps.get_model("wagtailforms.FormSubmission")
        for submission in FormSubmission.objects.all():
            if any(str(v).startswith("Webship test") for v in (submission.form_data or {}).values()):
                submission.delete()
                removed.append("a form submission")
    try:
        BreadType = apps.get_model("breads.BreadType")
        for item in BreadType.objects.filter(title__startswith="Webship test"):
            item.delete()
            removed.append(f"bread type {item.title}")
    except LookupError:
        pass
    print(f"Removed {len(removed)} item(s) of test content" + (": " + ", ".join(removed) if removed else "."))


def main(argv):
    verb = argv[1] if len(argv) > 1 else ""
    if verb == "settings":
        write_settings()
    elif verb == "site":
        if len(argv) < 3:
            sys.exit("site: give the host name of the project")
        set_site(argv[2])
    elif verb == "accounts":
        accounts(argv[2] if len(argv) > 2 else "")
    elif verb == "tidy":
        tidy()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
