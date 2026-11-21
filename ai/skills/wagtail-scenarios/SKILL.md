---
name: wagtail-scenarios
description: Write webship-js scenarios for a Wagtail site of the Webship Workspace from phrases that exist — the Wagtail step pack's steps by area (the session and its refusals, the dashboard and the menus, the page explorer and its tree, the editor with its fields, blocks, preview, drafts, publishing, schedule and autosave, revisions and locks, the moderation workflow and its mail, the image and document libraries, snippets, forms and submissions, users and groups, redirects, reports, the site's search and quick actions), the handles of the users registry, the traps found on real sites, and three features that pass on the Wagtail Bakery demo built with the default accounts. Use when writing or fixing a scenario for a Wagtail site, choosing a step for a screen of its admin, or turning a manual check of the editor, the workflow or a form into a feature.
---

# wagtail-scenarios

Scenarios for a site built with the Wagtail plugin (`bash cmd-wagtail-project.sh <site> --install --add-users`, a new
project; `--bakerydemo` for the Wagtail Bakery demo) in a container-based workspace (DDEV by default), tested with
webship-js and `@webship-js/wagtail-steps` once `bash cmd-tools-testing.sh <site>` set the project up. Every phrase
below exists in the pack or in webship-js; a scenario names no platform.

## Accounts

- `Given I am a logged in user with the "editor" user`: `administrator` (a superuser), `editor` (the Editors group:
  adds and changes pages, submits them for moderation), `moderator` (the Moderators group: also publishes, locks and
  reviews), `member` (no access to the admin: the login refuses it). `Given I am not logged in` for a visitor.
- The accounts are made by the build (`cmd-tools-wagtail-manage.sh <site> --add-users`); a suite never creates or
  deletes one, and never writes a password: it logs in by the handle.

## Phrases by area

| Area | Steps |
| --- | --- |
| Session | `I log in as "editor" with the login form`, `I try to log in as "member" with the login form`, `I log in with the username "…" and the password "…"`, `the login should be refused with "…"`, `I am not logged in`, `I log out`, `I should be logged in`, `I should not be logged in`, `I should be logged in as "editor"`, `I should be on the login page`, `I should not be allowed to open "/admin/users/"`, `I ask for a password reset link for "editor"`, `I set the password of "editor" on the reset page` |
| Admin | `I am on the dashboard`, `the dashboard should show the panel "Awaiting your review"`, `the panel "…" should list "…"`, `the site summary should count 39 images`, `I open "Users" from the "Settings" menu`, `I open "Images" from the main menu`, `the main menu should offer "Settings"`, `the "Settings" menu should offer "Users"`, `I should see the success message "…"` (`error`, `warning`, or any `message`), `I search the admin for "…"`, `the admin search should find the page "…"` |
| Page explorer | `I go to the page explorer of "…"` (or `of the home page`), `the page explorer should list "…"`, `the page explorer should count 7 pages`, `I search the page explorer for "…"`, `the page "About" should have the status "live"`, `the page "Contact Us" should be shown as locked`, `I explore the child pages of "Breads"`, `I add a "Standard page" under "…"` (or `under the home page`), `"Breads" should offer the page type "Bread page"` (`the home page should offer …`), `I edit the page "…"`, `I edit the home page`, `I open the page tree`, `I open "Breads" in the page tree` (`I open the home page in the page tree`), `the page tree should show "…"` |
| Editor | `I set "Title" to "…"`, `I set these fields:` (a table), `"Slug" should be set to "…"`, `I save the draft`, `I publish the page`, `I unpublish the page`, `I submit the page for moderation`, `I choose "Replace current draft" in the editor`, `the editor should offer "Publish"`, `I delete the page` (`I delete the page "…"`), `the status panel should say "Draft"`, `I schedule the page to go live at "2030-01-01 09:00"`, `I lock the page`, `I unlock the page`, `the preview should show "…"`, `the edits should be saved by themselves` (Wagtail 8.0 and later), `the "Title" field should have the error "This field is required."` |
| Blocks | `I add a "Heading block" block to "Page body"`, `I set "Heading text" to "…" in block 1 of "Page body"`, `I move block 2 of "Page body" up`, `I duplicate block 1 of "Page body"`, `I remove block 1 of "Page body"`, `"Page body" should have 2 blocks`, `the blocks of "Page body" should be "Heading block", "Paragraph block"` |
| Revisions | `I open the history of the page` (`… "…"`), `the history should list "Published"`, `the newest entry of the history should be "…"`, `I compare the live version with the current draft`, `I compare the current draft with the previous version`, `the comparison should show "Introduction" changed from "First" to "Second"`, `I revert the page to the live version` |
| Workflow | `I approve the page "…"` (`… with the comment "…"`), `I request changes to the page "…" with the comment "…"`, `the page "…" should be awaiting my review`, `my page "…" should be "Changes requested at Moderators approval"` |
| Images and documents | `I upload the image "webship-test-loaf.png" with the title "…"` (`… to the collection "Other"`), `I upload the document "webship-test-recipe.pdf" with the title "…"`, `I go to the image library`, `I search the image library for "…"`, `I filter the image library by the collection "…"`, `the image library should list "…"`, `I edit the image "…"`, `I set the focal point of the image to the area from 55% 40% to 75% 65%`, `the focal point of the image "…" should be centred at 65% 52%`, `the image "…" should be in the collection "…"`, `I delete the image "…"`, `I add the collection "…"`, `the collections should list "…"`, `I delete the collection "…"` |
| Snippets | `I go to the "Bread types" snippets`, `I add to the "Bread types" snippets:` (a table), `the "Bread types" snippets should list "…"`, `the "Bread types" snippets should count 17`, `I delete "…" from the "Bread types" snippets` |
| Forms | `I send the form of this page with:` (a table), `the form of this page should not be sent for "Subject"`, `I go to the submissions of the form "Contact Us"`, `the submissions should list "…"`, `the submissions should have the columns "Subject", "Body"`, `I delete the submission "…"` |
| Users and groups | `the users list should show "administrator" with the access level "Admin"`, `the users list should show "member" as active`, `the group "Editors" should be allowed to "Edit" the pages under "Root"`, `the group "Editors" should have the permission "Can add footer text"` |
| Redirects | `I add a temporary redirect from "/old-path" to the page "Breads"` (`permanent`; `… to "https://example.com/"`), `the redirects should list "/old-path" to "Breads"`, `"/old-path" should redirect temporarily to "/breads/"`, `I delete the redirect "/old-path"` |
| Reports | `I open the "Locked pages" report`, `the report should list "…"`, `the report row "…" should show "…" in the "…" column` |
| Site | `I search the site for "bread"`, `the search results should list "…"`, `I should see the quick actions of the admin`, `I choose "Edit this page" from the quick actions` |
| Mail | `an email with the subject "has been submitted for approval" should be sent to "moderator"`, `the email with the subject "…" to "…" should contain "…"`, `I open the "/password_reset/" link of the email with the subject "Password reset" to "editor"`, `no email should be sent to "…"` |
| Test content | `there is no page "…"` (`image`, `document`, `redirect`, `collection`), `there is no "…" in the "Bread types" snippets` |

Text, links, buttons, fields and status codes are webship-js's own: `I should see "…"`, `I press "…"`, `I go to "…"`,
`I click the "Promote" tab`, `the response status code should be 404`.

## A scenario, start to end

A page written with blocks, previewed and published, then taken away again:

```gherkin
Feature: A page with blocks
  Scenario: A page is written with blocks, previewed and published
    Given I am a logged in user with the "administrator" user
    And there is no page "Webship test page"
    When I add a "Standard page" under the home page
    And I set "Title" to "Webship test page"
    And I add a "Paragraph block" block to "Page body"
    And I set "Paragraph block" to "Fresh bread every morning." in block 1 of "Page body"
    Then the preview should show "Fresh bread every morning."
    When I publish the page
    And I go to "/webship-test-page/"
    Then I should see "Fresh bread every morning."
    When I delete the page "Webship test page"
```

## Traps found on real sites

- The editor of Wagtail 8 saves a draft by itself a moment after a field is left (autosave): a new page exists from
  its first edit, so a scenario that adds content starts with `there is no page "…"` and ends with a delete. A
  snippet with an editor of its own is saved the same way ("updated" rather than "created" when you save it).
- The home page is named by its place, not its title: its title is the site's own words ("Welcome to the Wagtail
  Bakery!" on the demo), so a phrase says `the home page` (`I add a "Standard page" under the home page`).
- The slug follows the title once the title field is left: set the title with `I set "Title" to "…"` (it leaves the
  field), not by typing into it.
- A heading block shows nothing on the page until its "Size" is chosen.
- The editor's actions depend on the account and on the page: an editor has "Submit to Moderators approval" and no
  "Publish"; a locked page offers nothing but "Page locked"; a scheduled page is "Locked by schedule".
- "Compare with previous version" compares the newest draft with the revision just before it, which the autosave may
  have made with the same words: compare with the live version instead.
- A lock is told as information ("'…' was locked by you on …"), not as a success; check it with `I should see the
  message "…"`.
- The demo keeps its people's images (Muddy Waters) in the collection "Other".
- A form refused by the server answers 400 and the browser logs a failed request: tag those scenarios `@js-off`.
- The admin's accessibility checker writes its findings to the browser console as errors ("axe.run results"): the
  testing setup ignores them.

## Examples

- [`examples/session-and-dashboard.feature`](examples/session-and-dashboard.feature): the login, the refusals, the dashboard of each account.
- [`examples/editing.feature`](examples/editing.feature): a page with blocks, previewed, published and deleted.
- [`examples/workflow.feature`](examples/workflow.feature): a page submitted, sent back with a comment, approved, and the mail of each step.

Copy them into `tests/features/` of a project of the Wagtail Bakery demo and run them:

```bash
bash cmd-tools-testing.sh <site> --run --path tests/features/editing.feature
```

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For Wagtail.** Start with `ch26-testing-cms-applications.md` (drafts, publishing, media, roles and the editorial
  workflow across roles), `ch10-authentication-authorization.md` (logins and refusals), `ch07-waiting-dynamic-content.md`
  (waiting on the site's own signals) and `ch44-javascript-and-friendly-errors.md` (the browser messages of a page).
