Feature: The Wagtail plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the Wagtail builder, each AI folder lists the
  items of its kind the plugin ships, and the Plugins page lists the plugin with its steps.

  # Settings lists every plugin that was added; the package and what the plugin ships are on its own page.
  Scenario: Settings lists the plugin, and its own page names its package and what it ships
    Given I am on "/settings"
     Then I should see "Wagtail"
     When I go to "/settings/plugin/wagtail"
     Then I should see "@webship.co/workspace-wagtail"
      And I should see "cmd-wagtail-project.sh"
      And I should see "wagtail-site-builder"

  Scenario: A sites folder offers the Wagtail builder
    Given I am on "/dev"
     Then "option[value='cmd-wagtail-project.sh']" should be attached

  # The AI folders are searched by name: with every plugin on, a folder lists more than one page of items.
  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents?q=wagtail-"
     Then I should see "wagtail-site-builder"
      And I should see "wagtail-tester"

  Scenario: The AI Skills folder lists the skill the plugin ships
    Given I am on "/ai-skills?q=wagtail-scenarios"
     Then I should see "wagtail-scenarios"

  Scenario: The AI Commands folder lists the command the plugin ships
    Given I am on "/ai-commands?q=wagtail-test"
     Then I should see "wagtail-test"

  Scenario: The AI Prompts folder lists the prompts the plugin ships
    Given I am on "/ai-prompts?q=wagtail-"
     Then I should see "wagtail-build-and-test"
      And I should see "wagtail-scenarios-for-an-area"
