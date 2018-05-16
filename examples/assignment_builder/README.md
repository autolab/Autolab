This is an example of a project that can build assessments for a python class.
NOTE: This project was built on OSX and [gtar](https://medium.com/@moschan/installing-gnu-tar-on-mac-827a494b1c1) was required to create a compatible tar file.

To build the lab:
```bash
$ make clean
$ make
```

To test offline:
```bash
$ (cd output/test-autograder; make)
```

## Basic files created by the lab author
| File / Directory | Description |
| - | - |
| Makefile | Builds the lab from src/ |
| README.md | This file |
| assignments/ | Location for the assignments we wish to build |
| output/ | Location for the compiled output files that can be uploaded to autolab |

## Files created by running make
| File / Directory | Description |
| - | - |
| output/autograde/ | The directory that gets put into autograde.tar |
| output/autograde.tar | Archive of the output/autograde directory which is copied to the autograding instance |
| output/autograde-Makefile | Copied to the autograding instance along with the student file |
| output/handout/ | The directory that gets put into handout.tar |
| output/handout.tar | Archive of output/handout directory |

## Configuration Files
| File / Directory | Description |
| - | - |
| assignments/_assignment_/project | Location of the source code, unit tests, and all dependencies required to run the project |
| assignments/_assignment_/project/driver.py | Python file that runs the unit tests |
| assignments/_assignment_/project/problems.yml | Configuration file that maps problems to unit tests |
| assignments/_assignment_/writeup | Description of the project |


## Files created and managed by Autolab
| File / Directory | Description |
| - | - |
| handin/ | All students handin files |
| _assignment_.rb | Config file |
| _assignment_.yml | Database properties that persist from semester to semester |
| log.txt | Log of autograded submissions |
