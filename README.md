![Welcome to Autolab](https://github.com/autolab/Autolab/blob/master/public/images/autolab_logo.png)

Autolab is a course management service, initially developed by a team of students at Carnegie Mellon University, that enables instructors to offer autograded programming assignments to their students over the Web. The two key ideas in Autolab are *autograding*, that is, programs evaluating other programs, and *scoreboards*.

Autolab also provides other services that instructors expect in a course management system, including gradebooks, rosters, handins/handouts, lab writeups, code annotation, manual grading, late penalties, grace days, cheat checking, meetings, partners, and bulk emails.

**Autograding.** Each time a student submits their work, the system autogrades it and stores the results in a gradebook. Autograders and the programs they evaluate can be written in any language and use any software packages. The model for a traditional programming class is that students work on their code, hand it in once, and then get feedback a week or two later, at which point they've already moved on to the next assignment. Autograding, on the other hand, allows students to get immediate feedback on their performance.

**Scoreboard.** The latest autograded scores for each student are displayed, rank ordered, on a real-time scoreboard. The scoreboard is a fun and powerful motivation for students. When coupled with autograding, it creates a sense of community and a healthy competition that seems to benefit everyone. Students anonymize themselves on the scoreboard by giving themselves nicknames. A mix of curiosity and competitiveness drives the stronger students to be at the top of the scoreboard, and all students have a clear idea of what they need for full credit. In our experience, everyone wins.

Since 2010, Autolab has had a transformative impact on education at CMU. Each semester, it is used by about 3,000 CMU students in courses in Pittsburgh, Silicon Valley, Qatar, and Rwanda. In Fall, 2014, we are releasing Autolab as an open-source system, where it will be available to schools all over the world, and hopefully have the same impact it's had at CMU.

This is the main repository that includes the application layer of the project. Installing other services are optional but highly recommended for full functionality. For further information:

* [Tango Service] (https://github.com/autolab/Tango)


## Getting Started

We've moved all our documentation to the [Wiki](wiki), and it looks pretty good! For a super-quick setup guide, check out [Installing Autolab on Ubuntu](wiki/Installing-Autolab-on-Ubuntu). Mac OS X setup instructions coming soon!


## Testing

### Setting up Tests

1. Add a test database in `database.yml`

2. Create and migrate the database.
	```sh
	RAILS_ENV=test bundle exec rake db:create
	RAILS_ENV=test bundle exec rake db:migrate
	```
   Do not forget to use `RAILS_ENV=test bundle exec` in front of every rake/rails command.

3. Create necessary directories.

	```
	mkdir attachments/ tmp/
	```

### Running Tests

After setting up the test environment, simply run spec by:

```sh
bundle exec rake spec
```


[![Build Status](https://travis-ci.org/autolab/Autolab.svg)](https://travis-ci.org/autolab/Autolab) [![Code Climate](https://codeclimate.com/github/autolab/Autolab/badges/gpa.svg)](https://codeclimate.com/github/autolab/Autolab) [![Test Coverage](https://codeclimate.com/github/autolab/Autolab/badges/coverage.svg)](https://codeclimate.com/github/autolab/Autolab)


## Contributing

We encourage you to contribute to Autolab! Please check out the
[Contributing to Autolab Guide](https://github.com/autolab/Autolab/blob/master/CONTRIBUTING.md) for guidelines about how to proceed. [Join us!](http://contributors.autolabproject.org)


## License

Autolab is released under the [Apache License 2.0](http://opensource.org/licenses/Apache-2.0).


## Using Autolab

Please feel free to use Autolab at your school/organization. If you run into any problems, you can reach the core developers at `autolab-dev@andrew.cmu.edu` and we would be happy to help. On a case by case basis, we also provide servers for free. (Especially if you are an NGO or small high-school classroom)
