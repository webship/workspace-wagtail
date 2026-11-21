Feature: The session and the dashboard
  The login and its refusals, and what the dashboard of each account shows.

  Scenario: A visitor is sent to the login page
    Given I am not logged in
    When I go to "/admin/pages/"
    Then I should be on the login page

  Scenario: A wrong password and an account without access to the admin are refused
    Given I am not logged in
    When I log in with the username "editor" and the password "Wrong-password-1"
    Then the login should be refused with "didn't match"
    When I try to log in as "member" with the login form
    Then the login should be refused with "You do not have permission to access the admin."

  Scenario: The moderator's dashboard shows what awaits its review
    Given I am a logged in user with the "moderator" user
    When I go to the dashboard
    Then the dashboard should show the panel "Awaiting your review"
    And the panel "Awaiting your review" should list "Southern Cornbread"

  Scenario: The editor follows what it submitted, and may not manage the accounts
    Given I am a logged in user with the "editor" user
    When I go to the dashboard
    Then the dashboard should show the panel "Your pages and snippets in a workflow"
    And the "Settings" menu should not offer "Users"
    And I should not be allowed to open "/admin/users/"
