This is a general list of Tango-related issues that we get often. If you are encountering or find a solution to an issue not mentioned here,
please let us know on our [Slack](https://communityinviter.com/apps/autolab/autolab-project).

## Clearing Tango job queue
Due to faulty configs or other reasons, you may have a large backlog of jobs waiting to run that are stuck. 
Restarting Tango does not solve this issue as the jobs are persisted on a Redis queue. You can drop everything in Redis using the `redis-cli` client as follows:

```bash
$ redis-cli
127.0.0.1:6379> FLUSHALL
OK
127.0.0.1:6379> 
```

## Tango jobs completed but scores are not updated
If you are accessing Autolab on localhost, Tango will attempt to send the autograder logs to its own localhost instead. 

To fix this, add `127.0.0.1 autolab` to your `/etc/hosts` file and access Autolab via `http://autolab` instead of `http://localhost`.

If you are accessing Autolab on a different host, add `<your public_ip> <your fqdn> autolab` to your `/etc/hosts` file and access Autolab via `http://autolab`.
