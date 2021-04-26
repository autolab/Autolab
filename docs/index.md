# Welcome to the Autolab Docs

##Rationale

Autolab is a course management platform that enables instructors to offer autograded programming assignments to their students. The two key ideas in Autolab are _autograding_–that is, programs evaluating other programs, and _scoreboards_ that display the latest autograded scores for each student.

<b>Autograding</b>: The model for a traditional programming class is that students work on their code, hand it in once, and then get feedback a week or two later, at which point they've already moved on to the next assignment. Autograding, on the other hand, allows students to get immediate feedback on their performance and become more motivated to refine their coursework.

<b>Scoreboard</b>: The scoreboard is a fun and powerful motivation for students. When coupled with autograding, it creates a sense of community and healthy competition that benefits everyone. Students anonymize themselves on the scoreboard by giving themselves nicknames. A mix of curiosity and competitiveness drives the stronger students to be at the top of the scoreboard, and all students have a clear idea of what they need for full credit.

Autolab also provides gradebooks, rosters, handins/handouts, lab writeups, code annotation, manual grading, late penalties, grace days, cheat checking, meetings, partners, and bulk emails.

For more of the rationale behind Autolab, please check out <a href="https://autolab.github.io/2015/03/autolab-autograding-for-all/" target="_blank">this blog post</a>.

<!-- For information on how to use Autolab for your course see the [Guide for Instructors](/instructors). To learn how to write an autograded lab see the [Guide for Lab Authors](/lab). 
 -->
##Components

Autolab consists of two services: (1) the Autolab frontend which is implemented using Ruby on Rails, and (2) Tango, the RESTful Python autograding server. <b>Either service can run independently without the other.</b> But in order to use all features of Autolab, we highly recommend installing both services.

While the Autolab frontend supports Autolab's web application framework, the backend Tango is responsible for distributing and completing autograding jobs, which run in virtual machines or containers. We currently support Docker and AWS virtual machines. When Tango is done running a job, it then sends the autograded result back to the frontend. Below is a visualization of the typical workflow of the Autolab system.

![Autolab System](/images/autolab_system.png)

As you can see on the left, the Autolab frontend receives handin files from the clients through either traditional browser interaction or [the command line interface (CLI)](/command-line-interface). The frontend then sends the files through http requests to Tango. Tango would add them to a job queue, assign them to available containers/virtual machines for grading through ssh, and shepherd the jobs through the process. On the right, inside the box of VM domain for Docker at CMU, we show 3 VM pools, rhel, rhel122, and rhel411, each with potentially different software packages. At the bottom right, we show an example of AWS VM domain with VM pools rhelPKU and ubuntu. Tango assigns jobs only to the virtual machine instances from their corresponding course’s VM pool. For example, jobs with handin files for the course 122 would only go to rhel122’s instances. Once a job is done, the feedback will be copied back to Tango through ssh and further sent back to the Autolab frontend through http. The frontend can then display the feedback in the browser or through CLI. It also updates the scoreboard if applicable and stores the feedback into the database, which is displayed at the bottom left.

Apart from client usage, both the Autolab frontend and Tango provide application programming interfaces (API) for developers. The specific guides are included in the [Reference](/reference) section.

##Demonstration Website
Installation instructions can be found in our comprehensive [installation guide](/installation/overview). However, if this is your first experience with Autolab, we encourage you to try out some key features on Autolab's <a href="https://demo.autolabproject.com" target="_blank">Demo Site</a>. You can login through `Developer Login` with the email: `admin@foo.bar`. The demonstration website refreshes at 0,6,12,18 Hours (UTC) daily, and it is publicly accessible, so please only use it for your exploration. Do not use this site to store important information.

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


<!-- ## FAQ

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
You most likely missed the step of copying 'config/initializers/devise.rb.template' to 'config/initializers/devise.rb' and setting your secret key in the setup instructions. -->