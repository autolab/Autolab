<a href="http://autolabproject.com">
  <img src="public/images/autolab_banner.svg" width="380px" height="100px">
</a>

Autolab is a course management service, initially developed by a team of students at Carnegie Mellon University, that enables instructors to offer autograded programming assignments to their students over the Web. The two key ideas in Autolab are *autograding*, that is, programs evaluating other programs, and *scoreboards*.

Autolab also provides other services that instructors expect in a course management system, including gradebooks, rosters, handins/handouts, lab writeups, code annotation, manual grading, late penalties, grace days, cheat checking, meetings, partners, and bulk emails.

Since 2010, Autolab has had a transformative impact on education at CMU. Each semester, it is used by about 5,000 CMU students in courses in Pittsburgh, Silicon Valley, Qatar, and Rwanda. In Fall, 2014, we are releasing Autolab as an open-source system, where it will be available to schools all over the world, and hopefully have the same impact it's had at CMU.


<p>
<a href="https://autolab-slack.herokuapp.com" style="float:left">
  <img src="public/images/join_slack.svg" width="170px" height="44px">
</a>

<a href="https://docs.autolabproject.com/" style="float:left">
  <img src="public/images/read_the_docs.svg" width="170px" height="44px">
</a>

<a href="https://groups.google.com/g/autolabproject" style="float:left">
 <img src="public/images/mailing_list.svg" width="170px" height="44px">
</a>

</p>

[![Build Status](https://travis-ci.org/autolab/Autolab.svg)](https://travis-ci.org/autolab/Autolab)
![GitHub last commit](https://img.shields.io/github/last-commit/autolab/Autolab)

Subscribe to our [mailing list](https://groups.google.com/g/autolabproject) to recieve announcements about major releases and updates to the Autolab Project.

## Try It Out
We have a demo site running at https://nightly.autolabproject.com/. See the [docs](https://docs.autolabproject.com/#demonstration-site) for more information on how to login and suggestions on things to try.


## Installation

We released new documentation! Check it out [here](https://docs.autolabproject.com).

We are currently in the process of updating our documentation to work with our newest release of Autolab, v2.5.0, which has been upgraded to Rails 5 from Rails 4

## Testing

### Setting up Tests

1. Add a test database in `database.yml`

2. Create and migrate the database.
	```sh
	RAILS_ENV=test bundle exec rails db:create
	RAILS_ENV=test bundle exec rails db:migrate
	```
   Do not forget to use `RAILS_ENV=test bundle exec` in front of every rake/rails command.

3. Create necessary directories.

	```
	mkdir attachments/ tmp/
	```

### Running Tests

After setting up the test environment, simply run spec by:

```sh
bundle exec rails spec
```

## Rails 4 Support
Autolab is now running on Rails 5. However, we may still work on important bug fixes on the Rails 4 branch,
 partially because the deployment on CMU is currently still on Rails 4. Please file an issue
  if you believe that you have found a severe bug. The Rails 4 branch
 can be found on `master-rails-4`. 
 
 We will not be backporting new features from `master` to `master-rails-4`.

## Updating Docs
To install mkdocs, run
```bash
pip install --user mkdocs
```

We rely on the `mkdocs-material` theme, which can be installed with
```bash
pip install --user mkdocs-material
```

To run and preview this locally, run:

```bash
mkdocs serve
```

Once your updated documentation is in `master`, run:

```bash
mkdocs gh-deploy
```

This will build the site using the branch you are currently in (hopefully `master`), place the built HTML files into the `gh-pages` branch, and push to GitHub. GitHub will then automatically deploy the new content in `gh-pages`.

Finally, go to the repository Settings page, and set `docs.autolabproject.com` under the `Custom domain` field.

## Contributing

We encourage you to contribute to Autolab! Please check out the
[Contributing to Autolab Guide](https://github.com/autolab/Autolab/blob/master/CONTRIBUTING.md) for guidelines about how to proceed. You can also reach out to us on [Slack](https://autolab-slack.herokuapp.com) as well.

## License

Autolab is released under the [Apache License 2.0](http://opensource.org/licenses/Apache-2.0).

## Using Autolab

Please feel free to use Autolab at your school/organization. If you run into any problems, you can reach the core developers at `autolab-dev@andrew.cmu.edu` and we would be happy to help. On a case by case basis, we also provide servers for free. (Especially if you are an NGO or small high-school classroom)


## Changelog

### (2021/10/12) Moved from Uglifier to Terser
- Autolab has migrated from Uglifier to Terser for our Javascript compressor in order to support the latest Javascript syntax. Please change `Uglifier.new(harmony: true)` to `:terser` in your `production.rb`

### v2.5.0 (2020/02/22) Upgrade from Rails 4 Rails 5
- Autolab has been upgraded from Rails 4 to Rails 5 after almost a year of effort! There are still some small
bugs to be fixed, but it should not affect the core functionality of Autolab. Please file an issue if you believe
you have found a bug.


### [v2.4.0](https://github.com/autolab/Autolab/releases/tag/v2.4.0) (2020/02/08) Speedgrader - The new code viewer 
- The File Tree shows file hierarchy of student’s submission 
  - Click on a file to open 
  - Click on a folder to expand 
- The Symbol Tree allows you to jump quickly to functions in the student’s code 
  - Click on a function to jump 
- You can easily switch between submissions and files 
  - Up/down arrow keys change file 
  - Right/left arrow keys change submission 
- How to use new annotation system: 
  - Make annotations with grade adjustments 
  - Important: annotations can only be made for non-autograded problems (to preserve the original autograded score of the autograded problem) 
  - Annotations grade changes summarized by the Annotations table on the right 
- New: Score for problem automatically updates after annotation score changes based on the following formula (this no longer has to be done manually on the Gradebook): 

 `score = max_score + ∑(annotation score changes) `
- For example, a way to grade style in a deductive manner would be to set the max score for the Style problem, and make annotations with negative score for style violations and zero score for good style 

UI Enhancements 
- Tables are more standardized 
- Fixed text overflowing issues on Gradebook modals 
- Improved standardization and UI for annotations on PDF submissions 

Others 
- Course assistants are now able to submit assignments early 
