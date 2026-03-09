# Contributing Guidelines

## General Feedback

Create a new issue on our [Issues page](https://github.com/aumosita/AntiElectricity/issues). We welcome feedback in English or Korean.

Instead of listing multiple features or issues in a single post, create an issue for each topic.

### Issue reports

Create a new post using the "Bug report" template.

Before submitting an issue, please make sure of the following:

- Confirm that you are using the latest version of AntiElectricity and macOS, and that the issue still occurs.
- Confirm that the issue is specific to AntiElectricity.
- Search for existing issues related to your problem. If you find a similar issue, add your case to that thread instead of creating a new issue.

If possible, attach screenshots or screen recordings that show the issue clearly.


### Feature requests

Create a new post using the "Feature request" template.

Before submitting a request, please make sure of the following:

- Search for existing feature requests. If your idea is already posted, comment on that thread instead of creating a new issue.



## Pull Requests

### General Code Improvements

Bug fixes and improvements are always welcome. However, if you are considering adding a new feature or making a significant change, please consult the team beforehand to ensure it aligns with the project's direction.

Instead of modifying multiple features in a single pull request, create a pull request for each feature.

When contributing code, please adhere to our coding style guide for consistency and maintainability.


### Syntaxes

#### Adding a new bundled syntax

Put just your new syntax into the `/CotEditor/Resources/syntaxes/` directory. You don't need to modify the `SyntaxMap.json` file because it will be automatically generated in the build phase.


### Themes

You can distribute your own themes and add a link to our wiki page.


## Coding Style Guide

Please follow the style of the existing code.

- Respect the existing coding style.
- Leave reasonable comments.
- Never omit `self` except in `willSet`/`didSet`.
- Add `final` to classes and extension methods by default.
- Insert a blank line after a class/function statement line.
    ```Swift
    /// Says moof.
    func bark() {
        
        print("moof")
    }
    ```
- Write the `guard` statement in one line by just returning a simple value.
    ```Swift
    // prefer
    guard !foo.isEmpty else { return nil }

    // instead of
    guard !foo.isEmpty else {
        return nil
    }
    ```


## Acknowledgment

AntiElectricity is forked from [CotEditor](https://coteditor.com) by 1024jp.
The original CotEditor project's contribution guidelines and community standards have been adapted for this project.
