# Contributing to Autolab


## Reporting Bugs

1. Always update to the most recent master release; the bug may already be resolved.

2. Search for similar issues on the [Issue Tracker](https://github.com/autolab/Autolab/issues); it may already be an identified problem.

3. Make sure you can reproduce your problem and clearly describe the steps to reproduce it. Screenshots and error traces help a ton here!

5. If possible, submit a Pull Request with a failing test or fix the bug yourself (jump down to the "Contributing (Step-by-step)" section).

6. When the bug is fixed, we will do our best to update the issue on the tracker as soon as possible. Keep in mind that the bugfix will likely first land to the `develop` branch, but it won't be marked as resolved until it makes it into the `master` branch.

## Requesting New Features

1. Provide a clear and detailed explanation of the feature you want and why it's important to add. The feature must apply to a wide array of users of Autolab. You may also want to provide us with some advance documentation on the feature, which will help the community to better understand where it will fit.

2. If you're an awesome developer, build the feature yourself (refer to the "Contributing (Step-by-step)" section below).

## Contributing (Step-by-step)

1. Clone the Repo:

```
git clone git@github.com:autolab/Autolab.git
```

2. Create a new feature branch by branching off of the `origin/develop` branch.

```
cd Autolab
git checkout -b new_autolab_branch origin/develop
```

Please keep your code clean, and limit each branch to one feature or bug-fix. If you find multiple bugs you want to fix, make multiple branches and multiple respective pull requests.

3. Code
  * Adhere to common conventions you see in the existing code
  * Search to see if your new functionality has been discussed on [the Issue Tracker](https://github.com/autolab/Autolab/issues), and include updates as appropriate

4. Follow the Coding Conventions
  * two spaces, no tabs
  * no trailing whitespace, blank lines should have no spaces (you may want to consider getting a plugin for your text editor that shows you this information)
  * use spaces around operators, after commas, colons, semicolons, around `{` and before `}`
  * no space after `(`, `[` or before `]`, `)`
  * use Ruby 1.9 hash syntax: prefer `{ a: 1 }` over `{ :a => 1 }`
  * prefer `class << self; def method; end` over `def self.method` for class methods
  * prefer `{ ... }` over `do ... end` for single-line blocks, avoid using `{ ... }` for multi-line blocks

  > However, please note that **pull requests consisting entirely of style changes are not welcome on this project**. Style changes in the context of pull requests that also refactor code, fix bugs, improve functionality *are* welcome.

5. Commit

  Crafting good commit messages is a fine art. Good commit messages help organize your thoughts, document your thought for your future self, and communicate to the team why this commit was necessary.

  Please follow the conventions described by Tim Pope in [_A Note About Good Commit Messages_][commit-messages].


6. Update your branch

  ```
  git fetch origin
  git rebase origin/develop
  ```

7. After creating a personal fork of the Autolab repo through the GitHub interface, run:

  ```
  git remote add mine git@github.com:<your user name>/Autolab.git
  ```

  You may also be interested in tools like [`hub`][hub] which help automate forking.

8. Push to your remote

  ```
  git push mine new_autolab_branch
  ```

9. Issue a Pull Request

  Before submitting a pull-request, clean up the history, go over your commits and squash together minor changes and fixes into the corresponding commits. You can squash commits with the interactive rebase command:

  ```
  git fetch origin
  git checkout new_autolab_branch
  git rebase -i origin/develop

  # the editor opens and allows you to change the commit history
  # follow the instructions on the bottom of the editor to squash all your commits together

  git push -f mine new_autolab_branch
  ```


  In order to make a pull request,
  
  * Navigate to the Autolab repository you just pushed to (e.g. https://github.com/your-user-name/Autolab)
  * Click "Pull Request" and "New Pull Request".
  * Write your branch name in the branch field (this is filled with `master` by default)
  * Pick `develop` branch as the target branch on 
  * Click "Update Commit Range".
  * Ensure the changesets you introduced are included in the "Commits" tab.
  * Ensure that the "Files Changed" incorporate all of your changes.
  * Fill in some details about your potential patch including a meaningful title.
  * Click "Send pull request".

  Thanks for that -- we'll get to your pull request ASAP, we love pull requests!

10. Responding to Feedback

  The Autolab team may recommend adjustments to your code. Part of interacting with a healthy open-source community requires you to be open to learning new techniques and strategies; *don't get discouraged!* Remember: if the Autolab team suggest changes to your code, **they care enough about your work that they want to include it**, and hope that you can assist by implementing those revisions on your own.

  > Though we ask you to clean your history and squash commit before submitting a pull-request, please do not change any commits you've submitted already (as other work might be build on top).

[commit-messages]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[hub]: https://github.com/github/hub
