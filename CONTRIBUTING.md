# Contributing to Autolab


## Reporting Bugs

1. Always update to the most recent master release; the bug may already be resolved.

2. Search for similar issues on the [Issue Tracker](https://github.com/autolab/Autolab/issues); it may already be an identified problem.

3. Make sure you can reproduce your problem and clearly describe the steps to reproduce it.

5. If possible, submit a Pull Request with a failing test or fix the bug yourself (jump down to the "Contributing (Step-by-step)" section).

6. When the bug is fixed, we will do our best to update the issue on the tracker as soon as possible.

## Requesting New Features

1. Do not submit a feature request on GitHub; all feature requests on GitHub will be closed. Instead, e-mail the team at `autolab-dev@andrew.cmu.edu`

2. Provide a clear and detailed explanation of the feature you want and why it's important to add. The feature must apply to a wide array of users of Autolab. You may also want to provide us with some advance documentation on the feature, which will help the community to better understand where it will fit.

3. If you're an awesome developer, build the feature yourself (refer to the "Contributing (Step-by-step)" section below).

## Contributing (Step-by-step)

1. Clone the Repo:

        git clone git@github.com:autolab/Autolab.git

2. Create a new Branch:

        cd Autolab
        git checkout -b new_autolab_branch

 > Please keep your code clean: one feature or bug-fix per branch. If you find another bug, you want to fix while being in a new branch, please fix it in a separated branch instead.

3. Code
  * Adhere to common conventions you see in the existing code
  * Search to see if your new functionality has been discussed on [the Issue Tracker](https://github.com/autolab/Autolab/issues), and include updates as appropriate

4. Follow the Coding Conventions
  * two spaces, no tabs
  * no trailing whitespaces, blank lines should have no spaces
  * use spaces around operators, after commas, colons, semicolons, around `{` and before `}`
  * no space after `(`, `[` or before `]`, `)`
  * use Ruby 1.9 hash syntax: prefer `{ a: 1 }` over `{ :a => 1 }`
  * prefer `class << self; def method; end` over `def self.method` for class methods
  * prefer `{ ... }` over `do ... end` for single-line blocks, avoid using `{ ... }` for multi-line blocks

  > However, please note that **pull requests consisting entirely of style changes are not welcome on this project**. Style changes in the context of pull requests that also refactor code, fix bugs, improve functionality *are* welcome.

5. Commit

  For every commit please write a short (max 72 characters) summary in the first line followed with a blank line and then more detailed descriptions of the change. Use markdown syntax for simple styling.

  **NEVER leave the commit message blank!** Provide a detailed, clear, and complete description of your commit!


6. Update your branch

  ```
  git fetch origin
  git rebase origin/master
  ```

7. Fork

  ```
  git remote add mine git@github.com:<your user name>/Autolab.git
  ```

8. Push to your remote

  ```
  git push mine new_autolab_branch
  ```

9. Issue a Pull Request

  Before submitting a pull-request, clean up the history, go over your commits and squash together minor changes and fixes into the corresponding commits. You can squash commits with the interactive rebase command:

  ```
  git fetch origin
  git checkout new_autolab_branch
  git rebase origin/master
  git rebase -i

  < the editor opens and allows you to change the commit history >
  < follow the instructions on the bottom of the editor >

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


