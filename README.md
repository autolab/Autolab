![Welcome to Autolab](https://github.com/autolab/Autolab/blob/master/public/images/autolab_logo.png)

Autolab is a course management service, initially developed by a team of students at Carnegie Mellon University, that enables instructors to offer autograded programming assignments to their students over the Web. The two key ideas in Autolab are *autograding*, that is, programs evaluating other programs, and *scoreboards*.

Autolab also provides other services that instructors expect in a course management system, including gradebooks, rosters, handins/handouts, lab writeups, code annotation, manual grading, late penalties, grace days, cheat checking, meetings, partners, and bulk emails.

Since 2010, Autolab has had a transformative impact on education at CMU. Each semester, it is used by about 3,000 CMU students in courses in Pittsburgh, Silicon Valley, Qatar, and Rwanda. In Fall, 2014, we are releasing Autolab as an open-source system, where it will be available to schools all over the world, and hopefully have the same impact it's had at CMU.

## Installation

We released new documentation! Check it out [here](https://autolab.github.io/docs).


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
