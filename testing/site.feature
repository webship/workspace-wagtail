Feature: The site answers, its admin's login works and its accounts log in
  As the owner of the site
  I want the login of the admin and each default account to work, each in its role
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-wagtail-manage.sh --add-users); a scenario logs in by a handle of the
  # users registry in cucumber.js, so no password is written here. It passes on a site built with --install
  # --add-users: a new project made with wagtail start, or the Wagtail Bakery demo (--bakerydemo).

  @critical
  Scenario: A visitor who opens the admin is sent to the login page
    Given I am not logged in
    When I go to "/admin/pages/"
    Then I should be on the login page
    And I should not be logged in

  Scenario Outline: The <account> account logs in through the login form
    Given I am not logged in
    When I log in as "<account>" with the login form
    Then I should be logged in as "<account>"
    And the main menu should offer "Pages"

    Examples:
      | account       |
      | administrator |
      | editor        |
      | moderator     |

  Scenario: A wrong password is refused
    Given I am not logged in
    When I log in with the username "editor" and the password "Wrong-password-1"
    Then the login should be refused with "Your username and password didn't match. Please try again."

  Scenario: An account without access to the admin is refused
    Given I am not logged in
    When I try to log in as "member" with the login form
    Then the login should be refused with "You do not have permission to access the admin."

  Scenario: Each account gets the menus of its work
    Given I am a logged in user with the "administrator" user
    Then the "Settings" menu should offer "Users"
    Given I am a logged in user with the "editor" user
    Then the "Settings" menu should not offer "Users"
    And I should not be allowed to open "/admin/users/"
