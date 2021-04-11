#!/bin/bash

# driver.sh - The simplest autograder we could think of. It checks
#   that students can write a C program that compiles, and then
#   executes with an exit status of zero.
#   Usage: ./driver.sh

# Compile the code
echo "Compiling hello.c"
(make clean; make)
status=$?
if [ ${status} -ne 0 ]; then
    echo "Failure: Unable to compile hello.c (return status = ${status})"
    echo "{\"scores\": {\"Correctness\": 0}}"
    exit
fi

# Run the code
echo "Running ./hello"
./hello
status=$?
if [ ${status} -eq 0 ]; then
    echo "Success: ./hello runs with an exit status of 0"
    echo "{\"scores\": {\"Correctness\": 100}}"
else
    echo "Failure: ./hello fails or returns nonzero exit status of ${status}"
    echo "{\"scores\": {\"Correctness\": 0}}"
fi

exit

