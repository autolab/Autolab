This page documents the REST API for submitting jobs to Tango.

### Authentication

In order to have access to the REST interface of the Tango server, clients will first have to obtain a key from the Tango server. This key is a unique identifier of the client and it must be supplied with every HTTP request to the Tango server. If the Tango server fails to recognize the key, it does not entertain the request and returns an error message as part of the response body.

### Job Requests

Here is a description of the requests that clients use to submit jobs:

#### open

A request to `open` consists of the client's key and an identifier for every lab, which is likely to be a combination of the course name and the lab name (i.e. `courselab` for autograding jobs). `open` checks if a directory for `courselab` exists. If a directory for `courselab` exists, a dict of MD5 hashes corresponding to every file in that directory is returned. If the directory does not exist, it is created and a folder for output files is also created within the `courselab` directory. Since no files exist in the newly created directory, an empty dict of MD5 hashes is returned.

Request header: `GET /open/key/courselab/`  
Request body: empty  
Response body:

```json
{
  "statusMsg": <string>,
  "statusId": <int>,
  "files": { <fileName1> : <md5hash1>, <fileName2> : <md5hash2> ... },
}
```

#### upload

After receiving a list of MD5 hashes of files that exist on the Tango server, the client can choose to upload files that are different from the ones on the Tango server via successive `upload` commands. For each upload, the client must supply a `filename` header that gives the name of the file (on the local machine) to be uploaded to Tango. One of these files must be a Makefile, which needs to contain a rule called `autograde` (command to drive the autograding process).

Request header: `POST /upload/key/courselab/`  
Request body: `<file>`  
Response body:

```json
{
  "statusMsg": <string>,
  "statusId": <int>
}
```

#### addJob

After uploading the appropriate files, the client uses this command to run the job for the files specified as `files` in the `courselab` and on an instance of a particular VM `image`. Each file has `localFile` and `destFile` attributes which specify what the file is called on the Tango server and what it should be called when copied over to a VM (for autograding) respectively. Exactly one of the specified `files` should have the `destFile` attribute set to `Makefile`, and the Makefile must contain a rule called `autograde`. Clients can also specify an optional timeout value (`timeout`) and maximum output file size (`max_kb`). This command is non-blocking and returns immediately with a status message. Additionally, the command accepts an optional parameter, `callback_url`. If the `callback_url` is specified, then the Tango server sends a `POST` request to the `callback_url` with the output file once the job is terminated. If the `callback_url` is not specified, the client can then send a `poll` request for the `output_file` to check the status of that job and retrieve the output file from the Tango server if autograding is complete.

Request header: `POST /addJob/key/courselab/`  
Request body:

```json
{
  "image": <string>,                            # required VM image (e.g. "rhel.img")
  "files": [ { "localFile": <string>,
               "destFile": <string> }, ...],    # required list of files to be used for autograding
  "jobName": <string>,                          # required name of job
  "output_file": <string>,                      # required name of output file
  "timeout": <int>,                             # optional timeout value (secs)
  "max_kb": <int>,                              # optional max output file size (KB)
  "callback_url": <string>                      # optional URL for POST callback from server to client
}
```

Response body:

```json
{
  "statusMsg": <string>,
  "statusId": <int>,
  "jobId": <int>
}
```

#### poll

Check if the job for `outputFile` has completed. If not, return `404: Not Found` and a status message, otherwise return the file in the response body, and free all resources held by the job.

Request header: `GET /poll/key/courselab/outputFile/`  
Request body:

```json
{
  <empty>
}
```

Response body:  
`<autograder output file>` if autograding successful otherwise:

```json
{
  "statusMsg": <string>,
  "statusId": <int>
}
```

### Administrative Requests

Here are the requests that administrators use to manage the Tango service, typically from a command line client.

#### /info

This is the "hello, world" request for the service. It returns a JSON object with some basic stats about the service, such as uptime, number of jobs, etc.

Request header: `GET /info/<KEY>/`  
Request body:

```json
{
  <empty>
}
```

Response body:

```json
{
  "info": {
            "num_threads": <int>,
            "job_requests": <int>,
            "waitvm_timeouts": <int>,
            "runjob_timeouts": <int>,
            "elapsed_secs": <float>,
            "runjob_errors": <int>,
            "job_retries": <int>,
            "copyin_errors": <int>,
            "copyout_errors": <int>
          },
  "statusMsg": "Found info successfully",
  "statusId": 0
}
```

#### /jobs

Return a list of jobs. If deadjobs is set to 1, then return a list of recently completed jobs. Otherwise, return the list of currently running jobs. Note: This isn't strictly an admin request, since clients might find it useful to display jobs status, as we do in the Autolab front end.

Request header: `POST autograde.me/jobs/key/deadjobs/`  
Request body: empty
Response body: JSON `jobs` object

#### pool

Returns a JSON object that provides info about the current state of a pool of instances spawned from some `image`. The response gives the total number of instances in the pool, and the number of free instances not currently allocated to any job.

Request header: `GET /pool/key/image/`  
Response body: JSON `pool` object

#### prealloc

Creates a pool of `num` identical instances spawned from `image` (e.g. "rhel.img).

Request header: `POST /prealloc/key/image/num/`  
Request body:

```json
{
    "vmms": <string>,     # vmms to use (e.g. "localSSH")
    "cores": <int>,       # number of cores per VM
    "memory": <int>,      # amount of memory per VM
}
```

Response body: `{ "status": <string> }`

### Implementation Notes

Tango will maintain a directory for each of the labs in a course, which is created by `open`. All output files are stored within a specified output folder in this directory. Besides the runtime job queue, no other state is necessary.

At job execution time, Tango will copy files specified by the `files` parameter in `addJob` to the VM. When the VM finishes, it will copy the output file back to the lab directory.
