<a href="https://autolabproject.com">
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

[![Build Status](http://autolab-d01.club.cc.cmu.edu:8080/buildStatus/icon?job=autolab+demosite)](http://autolab-d01.club.cc.cmu.edu:8080/job/autolab%20demosite/)
[![Better Uptime Badge](https://betteruptime.com/status-badges/v1/monitor/95ro.svg)](https://betteruptime.com/?utm_source=status_badge)
![GitHub last commit](https://img.shields.io/github/last-commit/autolab/Autolab)

Subscribe to our [mailing list](https://groups.google.com/g/autolabproject) to receive announcements about major releases and updates to the Autolab Project.

## Try It Out
We have a demo site running at https://nightly.autolabproject.com/. See the [docs](https://docs.autolabproject.com/#demonstration-site) for more information on how to log in and suggestions on things to try.

## Installation

We released new documentation! Check it out [here](https://docs.autolabproject.com).

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

## Rails 5 Support
Autolab is now running on Rails 6. The Rails 5 branch can be found on `master-rails-5`. 
We will not be backporting any new features from `master` to `master-rails-5`, and we have discontinued Rails 5 support.

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

Once your updated documentation is in `master`, Jenkins will automatically run a job to update the docs. You can trigger a manual update with

```bash
mkdocs gh-deploy
```

This will build the site using the branch you are currently in (hopefully `master`), place the built HTML files into the `gh-pages` branch, and push them to GitHub. GitHub will then automatically deploy the new content in `gh-pages`.

## Contributing

We encourage you to contribute to Autolab! Please check out the
[Contributing to Autolab Guide](https://github.com/autolab/Autolab/blob/master/CONTRIBUTING.md) for guidelines about how to proceed. You can reach out to us on [Slack](https://autolab-slack.herokuapp.com) as well.

## License

Autolab is released under the [Apache License 2.0](http://opensource.org/licenses/Apache-2.0).

## Using Autolab

Please feel free to use Autolab at your school/organization. If you run into any problems, you can reach the core developers at `autolab-dev@andrew.cmu.edu` and we would be happy to help. On a case-by-case basis, we also provide servers for free. (Especially if you are an NGO or small high-school classroom)


## Changelog
### [v2.9.0](https://github.com/autolab/Autolab/releases/tag/v2.9.0) (2022/08/08) Metrics Excluded Categories and New Speedgrader Interface
- Instructors can now exclude selected categories of assessments from metrics watchlist calculations
- Introduced new speedgrader interface which utilizes the Golden Layout library, amongst other new features
- Numerous bug fixes and improvements

### [v2.8.0](https://github.com/autolab/Autolab/releases/tag/v2.8.0) (2021/12/20) GitHub Integration and Roster Upload Improvement
- Students can now submit code via GitHub
- Improved Roster Upload with better error reporting
- Numerous bug fixes and improvements

### (2021/10/12) Moved from Uglifier to Terser
- Autolab has migrated from Uglifier to Terser for our Javascript compressor to support the latest Javascript syntax. Please change `Uglifier.new(harmony: true)` to `:terser` in your `production.rb`

### [v2.7.0](https://github.com/autolab/Autolab/releases/tag/v2.7.0) (2021/05/29) Autolab Docker Compose, Student Metrics, Redesigned Documentation
- Integration with new Docker Compose [installation method](https://github.com/autolab/docker)
- Student Metrics Feature, which allows instructors to identify students who may require attention
- Redesigned Autolab documentation
- Numerous bug fixes and improvements

### [v2.6.0](https://github.com/autolab/Autolab/releases/tag/v2.6.0) (2020/10/24) Formatted Feedbacks, Course Dashboard, Accessibility
- Formatted Feedback feature
- Introduction of Course Dashboards
- Numerous bug fixes and improvements

### v2.5.0 (2020/02/22) Upgrade from Rails 4 to Rails 5
- Autolab has been upgraded from Rails 4 to Rails 5 after almost a year of effort! There are still some small
bugs to be fixed, but they should not affect the core functionality of Autolab. Please file an issue if you believe
you have found a bug.

**For older releases, please check out the [releases page](https://github.com/autolab/Autolab/releases).**