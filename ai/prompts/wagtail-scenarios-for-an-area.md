Write and run the webship-js scenarios of one area of a Wagtail site (the session, the page explorer, the editor, the blocks, revisions and locks, the moderation workflow, the libraries, snippets, forms, users and groups, redirects, reports, the site), from the step pack's own phrases.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Write and run the scenarios of <area> for the Wagtail site <site> of this sites folder
# ~/workspace/<dev|test|sandboxes|demos> · https://<site>.ddev.site · the admin at /admin/ · container-based (DDEV by default)
# the area: <session|page explorer|editor|blocks|revisions and locks|moderation workflow|images and documents|snippets|forms|users and groups|redirects|reports|site>
# every phrase from the step pack or webship-js (the wagtail-scenarios skill lists them by area): never invent a step, never name the platform in a step phrase
# accounts are configuration: never create or delete one in a suite, never write a password into a feature; take away the test content you make, named "Webship test …"
# a feature to write or a run to read: the book Automated Functional Testing Recipes first (its README.md, then the matching chapter), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

1. bash cmd-tools-testing.sh <site>
   (once: webship-js, the step pack, the users registry)
2. Open the screens of the area in the Playwright MCP browser, in a tab of your own, as the account each scenario uses; note what a person reads, the actions offered and the messages after each.
3. Write tests/features/<area>.feature from those notes: one scenario per behaviour, a "Given there is no …" for each piece of test content it makes, @js-off on the scenarios of a refusal the site answers with an error status.
4. bash cmd-tools-testing.sh <site> --dry-run --path tests/features/<area>.feature
5. bash cmd-tools-testing.sh <site> --run --path tests/features/<area>.feature
6. Run it a second time: it must pass again (the scenarios take away what they make).

If a scenario fails, read its message and its screenshot, look at the screen again in the browser, then fix the scenario, not the step pack. A run stopped half way leaves its test content: bash cmd-tools-wagtail-manage.sh <site> --tidy
When the feature is green twice: the scenarios, the steps, and anything the screens did that surprised you.
"""
```
