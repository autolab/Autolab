# Welcome to the Autolab Docs

Autolab is a course management platform that enables instructors to offer autograded programming assignments to their students. The two key ideas in Autolab are _autograding_ that is, programs evaluating other programs, and _scoreboards_ that display the latest autograded scores for each student. Autolab also provides gradebooks, rosters, handins/handouts, lab writeups, code annotation, manual grading, late penalties, grace days, cheat checking, meetings, partners, and bulk emails.

For information on how to use Autolab for your course see the [Guide for Instructors](/instructors). To learn how to write an autograded lab see the [Guide for Lab Authors](/lab). 


## Installation

Autolab consists of two services: (1) the Ruby on Rails frontend, and (2) [Tango](/tango), the RESTful Python autograding server. Either service can run independently without the other. But in order to use all features of Autolab, we highly recommend installing both services.

Installation instructions can be found in our comprehensive [installation guide](/installation/overview)

## Demonstration Site
If you would like to check out Autolab prior to installation, go over to our <a href="https://demo.autolabproject.com" target="_blank">Demo Site</a>! Login through `Developer Login` with the email: `admin@foo.bar`. 

This is a demonstration website. It refreshes at 0,6,12,18 Hours (UTC) daily, and it is publicly accessible, so please only use it for your exploration. Do not use this site to store important information.

Try the following in order:

### Create a new course 
Click on `Manage Autolab` (top-right navigation bar) > `Create New Course`. Fill in the name and semester, and then create to see your course on the homepage.

(NOTE: the email doesn't need to be real here)

### Create an Autograded Lab Assessment. 
Go into the course you have just created, click on `Install Assessment`. You can install a simple autograded lab, called hello lab.
[Download hello.tar](https://github.com/autolab/Autolab/raw/master/examples/hello.tar) and install it using the `Import from Tarball` option. 

In the `hello` lab, students are asked to write a file called `hello.c`. The autograder checks that the submitted hello.c program compiles and runs with an exit status of zero. If so, the submission gets 100 points. Otherwise it gets 0 points. 

**Try submitting to the autograded hello lab**

1. Create and submit a `hello.c` file. 
       
        //hello.c
        #include <stdio.h>
        int main()
        {
                printf("Hello, World!");
                return 0;
        }

2. Refresh the submitted entries page to see the autograded score appear
3. Click on a sub score, in this case the `100.0` under the `Correctness` heading, to see the output from the autograder.

For more information on `hello` lab, or how to create your own lab, go to [Guide for Lab Authors](/lab)! 

### Create a PDF homework assessment
Autolab can also handle pdf submissions as well!

Click on `Install Assessment`, then on `Assessment Builder`. Name your assessment, and give it a category and click `Create Assessment`!. 

Because it defaults to accepting `.c` files, we would like to change it to `*.pdf`. Click on `Edit Assessment` > `Handin` and then change the `Handin filename` to `handin.pdf` instead of `handin.c` and save the changes

**Try submitting to the pdf homework asssessment.**

1. Submit a `.pdf` file.
2. Look at your submission using the magnifying glass icon

### Grading submissions
Click on `Grade Submissions`, and then the arrow button to open up student submissions. For details on the relevant features for an Instructor, go to [Guide for Instructor](/instructors)


## FAQ

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

`eventmachine`

```bash
bundle config build.eventmachine --with-cppflags=-I/usr/local/opt/openssl/include
```

`libv8`

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

### Undefined method 'devise' for User
You most likely missed the step of copying 'config/initializers/devise.rb.template' to 'config/initializers/devise.rb' and setting your secret key in the setup instructions.