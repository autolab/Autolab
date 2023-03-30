This is a general list of questions that we get often. If you find a solution to an issue not mentioned here,
please contact us at <autolab-dev@andrew.cmu.edu>

#### Ubuntu Script Bugs

If you get the following error

```bash
Failed to fetch http://dl.google.com/linux/chrome/deb/dists/stable/Release
Unable to find expected entry 'main/binary-i386/Packages' in Release file (Wrong sources.list entry or malformed file)
```

then follow the solution in [this post](http://askubuntu.com/questions/743814/unable-to-find-expected-entry-main-binary-i386-packages-chrome).

#### Where do I find the MySQL username and password?
If this is your first time logging into MySQL, your username is 'root'. You may also need to set the root password:

Start the server:

```bash
sudo /usr/local/mysql/support-files/mysql.server start
```

Set the password:

```bash
mysqladmin -u root password "[New_Password]"
```

If you lost your root password, refer to the [MySQL wiki](http://dev.mysql.com/doc/refman/5.7/en/resetting-permissions.html)

#### Bundle Install Errors
This happens as gems get updated. These fixes are gem-specific, but two common ones are

#####  `eventmachine`

```bash
bundle config build.eventmachine --with-cppflags=-I/usr/local/opt/openssl/include
```

##### `libv8`

```bash
bundle config build.libv8 --with-system-v8
```

Run `bundle install` again

If this does not work, another option would be

```bash
bundle update libv8
```

Because updating libv8 has dependency on other gems, it might fail due to a need to update other gems. Just do

```bash
bundle update <gem>
```

according to the error messages until all gems are up to date.

Run `bundle install` again

If neither of these works, try exploring [this StackOverflow link](http://stackoverflow.com/questions/23536893/therubyracer-gemextbuilderror-error-failed-to-build-gem-native-extension)

##### `mimemagic`

Another error that may occur on macOS when running `bundle install` is that the dependancy mimemagic may fail to install, causing `bundle install` to fail. A possible fix is if you have homebrew installed, run:
```bash
brew install shared-mime-info
bundle install
```
For more information, read the following [github issues link](https://github.com/mimemagicrb/mimemagic/issues/162).

#### Can't connect to local MySQL server through socket
Make sure you've started the MySQL server and double-check the socket in `config/database.yml`

The default socket location is `/tmp/mysql.sock`.

#### I forgot my MySQL root password

You can reset it following the instructions on [this Stack Overflow post](http://stackoverflow.com/questions/6474775/setting-the-mysql-root-user-password-on-os-x)

If `mysql` complains that the password is expired, follow the instructions on the second answer on [this post](http://stackoverflow.com/questions/33326065/unable-to-access-mysql-after-it-automatically-generated-a-temporary-password)

#### MySQL Syntax Error

If you get the following error

```bash
Mysql2::Error: You have an error in your SQL syntax
```

this may be an issue with using an incompatible version of MySQL. Try switching to MySQL 5.7 if you are currently using a different version.

#### Undefined method 'devise' for User
You most likely missed the step of copying `config/initializers/devise.rb.template` to `config/initializers/devise.rb` and setting your secret key in the setup instructions.

#### Suggested Development Configuration for config/database.yml

**MySQL**
Change the <username> and <password> fields in `config/database.yml` to the username and password that has been set up for the mysql. For example if your username is `user1`, and your password is `123456`, then your yml would be

    :::yml
    development:
        adapter: mysql2
        database: autolab_development
        pool: 5
        username: user1
        password: '123456'
        socket: /var/run/mysqld/mysqld.sock # /tmp/mysql.sock on Mac OSX
        host: localhost
        variables:
            sql_mode: NO_ENGINE_SUBSTITUTION

    test:
        adapter: mysql2
        database: autolab_test
        pool: 5
        username: user1
        password: '123456'
        socket: /var/run/mysqld/mysqld.sock # /tmp/mysql.sock on Mac OSX
        host: localhost
        variables:
            sql_mode: NO_ENGINE_SUBSTITUTION

**SQLite**
Comment out the configurations meant for MySQL in `config/database.yml`, and insert the following

    :::yml
    development:
        adapter: sqlite3
        database: db/autolab_development
        pool: 5
        timeout: 5000

    test:
        adapter: sqlite3
        database: db/autolab_test
        pool: 5
        timeout: 5000

#### No space left on device

If you get the following error

```bash
No space left on device @ rb_sysopen - /path/to/autolab/tmp/cache/.raw_score_includes_unreleased[...]
```

it is likely that you need to purge the cache. This is because `FileStore` caches are not purged automatically.

To purge the cache, click on `Manage Autolab` followed by `Clear Cache` to clear expired entries.

Alternatively, run `rake user:cleanup_cache` (to clear expired entries) or `rake user:clear_cache` (to clear **all** entries) in your terminal.

#### MacOS: OpenSSL error

If you get the following error when trying to run rake or rails


```bash
Library not loaded: libssl.1.1.dylib (LoadError)
```

paths to OpenSSL may not be properly set up. To enable proper linking:

```bash
brew install openssl@1.1
brew link openssl@1.1. --force
```

You may need to export paths as well during this process, which homebrew will display. You may also need to reinstall the
`mysql2` gem (the following command is for Apple Silicon):

```bash
gem install mysql2 -v "{version}" -- --with-ldflags=-L/opt/homebrew/opt/openssl@1.1/lib --with-cppflags=-I/opt/homebrew/opt/openssl@1.1/include
```