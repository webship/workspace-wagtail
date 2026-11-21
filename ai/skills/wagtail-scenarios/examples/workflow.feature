Feature: A page through moderation
  An editor submits a page, a moderator sends it back with a comment, then approves it; each step is told by mail.

  Scenario: A page is submitted, sent back, resubmitted and approved
    Given I am a logged in user with the "administrator" user
    And there is no page "Webship test page"
    Given I am a logged in user with the "editor" user
    When I add a "Standard page" under the home page
    And I set "Title" to "Webship test page"
    And I submit the page for moderation
    Then an email with the subject "has been submitted for approval" should be sent to "moderator"
    Given I am a logged in user with the "moderator" user
    When I request changes to the page "Webship test page" with the comment "Please add an introduction."
    Then an email with the subject "has been rejected" should be sent to "editor"
    Given I am a logged in user with the "editor" user
    When I edit the page "Webship test page"
    And I set "Introduction" to "An introduction, as asked."
    And I submit the page for moderation
    Given I am a logged in user with the "moderator" user
    When I approve the page "Webship test page"
    Then an email with the subject "has been approved" should be sent to "editor"
    Given I am a logged in user with the "administrator" user
    When I delete the page "Webship test page"
