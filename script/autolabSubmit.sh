#!/bin/bash

# Official submit script for Autolab
# By Hunter Pitelka (hpitelka@andrew.cmu.edu)
# WARNING: handin filenames must be alphanumeric (no puctuation)

###################################
## IMPORTANT!!!!
# You must fill in these values for each assignment
course='15213-s11'
assessment='datalab'
###################################

usage() {
  echo "usage: $0 [-sh] -f file [-u username]"
  echo 
  echo "-s: Use SSH to handin file (Necessary if not on an Andrew machine"
  echo "-f: File to handin"
  echo "-u: specify a username to handin for"
  echo "-h: show this help"
  echo
  echo "If in doubt, use -s."
  echo 
  echo "WARNING: Handin filenames must be alphanumeric (no puctuation)"
}


user=$USER
handinURL="http://unofficial.fish.ics.cs.cmu.edu/officialSubmit.rb"


while getopts "hu:f:s" OPTION; do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    u)
      user=$OPTARG
      ;;
    f)
      file=$OPTARG
      ;;
    s)
      ssh="true"
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done

if [[ -z $file ]]; then
  echo "Missing Required Argument (-f)"
  usage
  exit 1
fi

onAndrew=`hostname | grep cmu.edu`
if [[ -z $onAndrew ]]; then
  echo "WARNING!!!!!!!!!"
  echo "It appears that you are not logged into a CMU.EDU machine. "
  echo "We recommend using SSH (-s) to submit if you are on a non-andrew "
  echo " machine.  Are you sure you want to continue? (y/[n])"
  echo -n "-->"
  read cont
  if [[ $cont != "y" ]]; then
    echo "Exiting..... "
    exit
  fi
fi

handinDir=`wget -q -O- "${handinURL}?course=${course}&user=${user}&assessment=${assessment}"`
if [[ `echo ${handinDir} | grep ERROR | wc -l` == "1" ]]; then
  echo "There was an error submitting your code:"
  echo "****************************"
  echo ${handinDir}
  echo "****************************"
  echo "Please contact your course staff for help"
  exit
fi

# Copy the file over to the handin directory
if [[ ! -r ${file} ]]; then
  echo "ERROR: File (${file}) is not readable"
  exit 1
fi


echo "Copying ${file} to handin folder..."

if [[ -n $ssh ]]; then
  #Use SSH to handin file
  scp ${file} ${user}@shark.ics.cs.cmu.edu:${handinDir}
else
  # Just copy the file
  cp ${file} ${handinDir}
fi

filename=`basename ${file}`

# Let autolab know the file is uploaded
result=`wget -q -O- "${handinURL}?course=${course}&user=${user}&assessment=${assessment}&submit=${filename}"`

echo ${result}
