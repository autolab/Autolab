# Git Submission

Git Submission is a feature that allows students to submit their code via Github instead of manual file uploads. This has pedagogical benefits such as encouraging the use of version control among students, and also makes the process of submitting code much easier for students, as they no longer have to create submission tarfiles.

Autograders written for assessments that allow Git Submission must expect a `.tgz` handin file. See the [Handin Format section](#handin-format) for more information.

## Installation
Follow these steps on the [installation page](/installation/github_integration) in order to configure your Autolab deployment to support Github submission.

## Enabling Git Submission
Git Submission can be enabled in the `Handin` tab of the `Edit Assessment` page. It can be toggled via a checkbox:

![Github submission enable screenshot](/images/github_submission_enable.png)

## How Git Submission Works
Git Submission works by having students performing OAuth with your Github application in order to be granted access to access their private repositories. Only the minimum set of permissions to achieve this is requested. This allows your Autolab deployment to be able to query and clone their selected private repositories on the submission page. Autolab will create a compressed `.tgz` archive from the cloned repository, which ignores the `.git` directory (in case the student accidentally committed large files in the past), which is then saved and sent to Tango for autograding, if necessary. The cloned folder will be deleted.

## Handin Format
Due to how [Github Submission works](#how-git-submission-works), autograders on Git Submission enabled assessments must expect a `.tgz` archive. Depending on the design of your autograder, it may also be necessary for your autograder to only copy out relevant handin files from the uncompressed archive for use in autograding.

Other than this requirement, using Github submission does not change any other part of the autograding/submission process.

## API Limits
By default, each token is entitled to 5000 API requests per hour. Github counts all API requests (other than querying for your current API quota) against the token limits. This count is performed against the token that was used, and therefore it means that every student is able to make 5000 requests/hr, and not that the entire Autolab deployment can only make 5000 API requests/hr, which should be more than sufficient.

## Revoking Github Tokens
Students can revoke their Github tokens on their profile page via the button `Revoke Github Token`. This will both destroy the token with Github, and also remove the token from the database. In order to use Github Submission again, the student will need to perform the OAuth workflow again.

## Best Practices and Common Issues

### Github Classroom
Consider using [Github Classroom](https://classroom.github.com/) to initialize the repositories containing starter code for assessments for students, with a comprehensive `.gitignore` file to prevent students from checking in unnecessary files.

### Handin Sizes
The default handin size is quite small (2MB), and it is possible that starter code sizes could easily exceed that, so consider raising the limit based on what is reasonable. However, it is also a common mistake for students to accidentally check-in unnecessary logfiles or core dumps that could significantly inflate the size of their submission, and therefore the limit should not be too high to avoid a high rate of disk space usage.
