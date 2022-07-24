# Tango Command Line Client

This is a guide to use the command-line client (`clients/tango-cli.py`) to test and collect other valuable information from Tango. Please [setup Tango](/installation/tango) before moving forward. This guide assumes an instance of Tango is already up and running.

## Running a Sample Job

The CLI supports two ways to run a sample job, [individual steps](/tango-cli/#individual-steps) or in a [single all-in-one command](/tango-cli/#single-command). The first option is better for debugging each individual API call, whereas the second option is best for quickly running a job. Other Tango CLI commands are also discussed [below](/tango-cli/#miscellaneous-commands).

The Tango directory contains various different jobs in the `clients/` directory; `clients/README.md` discusses the function of each job.

Find out more information about the Tango REST API [here](/tango-rest/).

### Single Command

The `--runJob` command simply runs a job from a directory of files by uploading all the files in the directory. You can use this to submit an autograding job by running

```bash
$ python clients/tango-cli.py -P 3000 -k test -l assessment1 --runJob clients/job1/ --image autograding_image
```

The args are -P <port\>, -k <key\>, -l <unique_job_name\> --runJob <job_files_path\> --image <autograde_image\>

### Individual Steps

1. Open a `courselab` on Tango. This will create a directory for tango to store the files for the job.

        :::bash
        $ python clients/tango-cli.py -P <port> -k <key> -l <courselab> --open

2. Upload files necessary for the job.

        :::bash
        $ python clients/tango-cli.py -P <port> -k <key> -l <courselab> \
            --upload --filename <clients/job1/hello.sh>
        $ python clients/tango-cli.py -P <port> -k <key> -l <courselab> \
            --upload --filename <clients/job1/autograde-Makefile>

3. Add the job to the queue. Note: `localFile` is the name of the file that was uploaded and `destFile` is the name of the file that will be on the VM. One of the `destFile` attributes must be `Makefile`. Furthermore, `image` references the name of the VM image you want the job to be run on. For Docker it is `autograding_image`.

        :::bash
        $ python clients/tango-cli.py -P <port> -k <key> -l <courselab> \
            --addJob --infiles \
            '{"localFile" : "hello.sh", "destFile" : "hello.sh"}' \
            '{"localFile" : "autograde-Makefile", "destFile" : "Makefile"}' \
            --image <image> --outputFile <outputFileName> \
            --jobname <jobname> --maxsize <maxOutputSize> --timeout <jobTimeout>

4. Get the job output.

        :::sh
        $ python clients/tango-cli.py -P <port> -k <key> -l <courselab> \
            --poll --outputFile <outputFileName>

    The output file will have the following header:

        :::bash
        Autograder [<date-time>]: Received job <jobname>:<jobid>
        Autograder [<date-time>]: Success: Autodriver returned normally
        Autograder [<date-time>]: Here is the output from the autograder:

## Miscellaneous Commands

The CLI also implements a list of commands to invoke the [Tango REST API](/tango-rest/), including `--info`, `--prealloc`, and `--jobs`. For a full list of commands, run:

```bash
python clients/tango-cli.py --help
```

The general form for each command is as follows:

```bash
python clients/tango-cli.py -P <port> -k <key> <command>
```
