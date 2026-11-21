Feature: A page with blocks
  A page written with blocks, previewed, published, and taken away again.

  Scenario: A page is written with blocks, previewed, published and deleted
    Given I am a logged in user with the "administrator" user
    And there is no page "Webship test page"
    When I add a "Standard page" under the home page
    And I set "Title" to "Webship test page"
    And I add a "Heading block" block to "Page body"
    And I set "Heading text" to "Our oven" in block 1 of "Page body"
    And I set "Size" to "H2" in block 1 of "Page body"
    And I add a "Paragraph block" block to "Page body"
    And I set "Paragraph block" to "Fresh bread every morning." in block 2 of "Page body"
    Then the blocks of "Page body" should be "Heading block", "Paragraph block"
    And the preview should show "Our oven"
    When I publish the page
    Then I should see the success message "has been published"
    When I go to "/webship-test-page/"
    Then I should see "Fresh bread every morning."
    When I delete the page "Webship test page"
    Then I should see the success message "deleted"
