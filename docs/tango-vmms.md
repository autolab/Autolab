This page documents the interface for Tango's Virtual Machine Management Systems' (VMMSs) API and instructions for setting up VMMSs. 

See <a href="https://github.com/autolab/Tango/tree/master/vmms" target="_blank">the vmms directory</a> in Tango for example implementations. 

We currently provide [Docker VMMS](/installation/tango/#docker-vmms-setup) and the [Amazon EC2 VMMS](/installation/tango/#amazon-ec2-vmms-setup) interfaces. The following API is for developers who intend to use a different kind of VMMS for Tango's autograding purposes.


## API

The functions necessary to implement the API are documented here. Note that for certain implementations, some of these methods will be no-ops since the VMMS doesn't require any particular instructions to perform the specified actions. Furthermore, throughout this document, we use the term "VM" liberally to represent any container-like object on which Tango jobs may be run.

### initializeVM

```python
initializeVM(self, vm)
```

Creates a new VM instance for the VMMS based on the fields of `vm`, which is a `TangoMachine` object defined in `tangoObjects.py`.

### waitVM

```python
waitVM(self, vm, max_secs)
```

Waits at most `max_secs` for a VM to be ready to run jobs. Returns an error if the VM is not ready after `max_secs`.

### copyIn

```python
copyIn(self, vm, inputFiles)
```

Copies the input files for a job into the VM. `inputFiles` is a list of `InputFile` objects defined in `tangoObjects.py`. For each `InputFile` object, `file.localFile` is the name of the file on the Tango host machine and `file.destFile` is what the name of the file should be on the VM.

### runJob

```python
runJob(self, vm, runTimeout, maxOutputFileSize)
```

Runs the autodriver binary on the VM. The autodriver runs `make` on the VM (which in turn runs the job via the `Makefile` that was provided as a part of the input files for the job). The output from the autodriver most likely should be redirected to some feedback file to be used in the next method of the API.

### copyOut

```python
copyOut(self, vm, destFile)
```

Copies the output file for the job out of the VM into `destFile` on the Tango host machine.

### destroyVM

```python
destroyVM(self, vm)
```

Removes a VM from the Tango system.

### safeDestroyVM

```python
safeDestroyVM(self, vm)
```

Removes a VM from the Tango system and makes sure that it has been removed.

### getVMs

```python
getVMs(self)
```

Returns a complete list of VMs associated with this Tango system.
