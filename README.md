![Welcome to Autolab](https://github.com/autolab/autolab-src/blob/master/public/images/autolab_logo.png)

Autolab is a course management service that enables instructors to offer autograded programming assignments to their students over the web.

The project has started in 2006 and has been extensively used at Carnegie Mellon University since then.

This is the main repository that includes the application layer of the project. Installing other services are optional but highly recommended for full functionality. For further information:

* [Tango Service] (https://github.com/autolab/Tango)


## Getting Started


1. Install rbenv (Basic GitHub Checkout method): [Github rbenv](https://github.com/sstephenson/rbenv)


2. Install ruby-build (as an rbenv plugin): [Github ruby-build](https://github.com/sstephenson/ruby-build)
	```sh
	git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
	```
	
	_(You might need to restart your shell at this point in order to start using your newly installed rbenv)_
3. Install the version of ruby in the text file `.ruby-version`:
	```sh
	rbenv install 2.1.2
	```
 At this point, confirm that `rbenv` is working (depending on your shell, you might need to logout and log back in):

  ```
  $ which ruby
  ~/.rbenv/shims/ruby

  $ which rake
  ~/.rbenv/shims/rake
  ```

5. Install `bundler`:

  ```
  gem install bundler
  rbenv rehash
  ```

5. `cd` into `autolab-src` and install the required gems:
	
  ```sh
  bundle install
  ```
  You need to have MySQL installed before hand.
 

5.  Configure your database next. You need to fill the `username` and `password` fields on 		`config/database.yml.template` and rename it to `config/database.yml.template`.

6. Create and initialize the database tables:

	```sh
	bundle exec rake db:create	
	bundle exec rake db:migrate
	```
   Do not forget to use `bundle exec` in fron of every rake/rails command.
   

7. (Optional) Populate dummy data for development purposes:

	```sh
	rake autolab:populate
	```

	(#TODO: make it so that setup.sh initiates the directories)


8. Start rails server:

	```sh
	bundle exec rails s -p 3000
	```

9. Go to <yoururl>:3000 to see if the application is running. You can use the `Developer Login` option with the email "admin@foo.bar".


## Testing

You can run the tests by:

```sh
bundle exec rake spec
```

We have a very testing suit at the moment, but we are working on it.

## Contributing

We encourage you to contribute to Autolab! Please check out the
[Contributing to Autolab Guide](#) for guidelines about how to proceed. [Join us!](http://contributors.autolabproject.org)



## License

Autolab is released under the [Apache License 2.0](http://opensource.org/licenses/Apache-2.0). 

## Using Autolab

Please feel free to use Autolab at your school/organization. If you run into any problems, you can reach the core developers at `autolab-dev@andrew.cmu.edu` and we would be happy to help. On a case by case basis, we also provide servers for free. (Especially if you are an NGO or small high-school classroom)
