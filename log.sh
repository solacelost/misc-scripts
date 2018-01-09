#!/bin/bash
##Copyright (c) 2017 James P. Harmison
##
##Permission is hereby granted, free of charge, to any person obtaining a copy
##of this software and associated documentation files (the "Software"), to deal
##in the Software without restriction, including without limitation the rights
##to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
##copies of the Software, and to permit persons to whom the Software is
##furnished to do so, subject to the following conditions:
##
##The above copyright notice and this permission notice shall be included in all
##copies or substantial portions of the Software.
##
##THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
##IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
##FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
##AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
##LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
##OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
##SOFTWARE.

printUsage() {
   echo "usage: $0 [OPTIONS] PROJECT_NAME PERSON_NAME [OUTDIR]" >&2
}

printHelp() {
   printUsage
   echo -e "
Log Helper v0.2 - A script to help generate timestamped project logs of
command execution.
   Permissions as executed will be retained for all commands, and
relative path will not change. If you need to chain commands (i.e. with
semi-colons), you can as long as all commands are on one line.
   Output of the commands are sent to the screen and the log file at the
same time, and all log entries are timestamped.
   You may additionally specify 'QUIT' or 'NOTE' (in any capitalization)
at the prompt to, respectively, exit the logging session and clean up
extra processes or to leave a text note in the log without execution.

OPTIONS:
   -h, --help              Print this help page then exit
   -t, --timestamp         Force timestamp in filename (Default: Off)

NOTE:
   Default file names will be {PROJECT_NAME}.log. Using
   the -t option will just add _{YYYYMMDD}
"
}

if [ $# -lt 2 ]; then
   echo "Incorrect number of parameters." >&2
   printHelp
   exit 1
fi


# Argument handling
while [ $# -gt 0 ]; do

   if [ "$(echo $1 | head -c 1)" = "-" ]; then
      case $1 in
         -h|--help)
            printHelp
            exit 0
            ;;
         -t|--timestamp)
            useTimestamp="True"
            ;;
         *)
            echo "Incorrect option switch ( $1 )"
            printHelp
            exit 1
            ;;
      esac
   else
      if [ -z "$projectName" ]; then
         projectName=$1
      elif [ -z "$personName" ]; then
         personName=$1
      elif [ -z "$outDir" ]; then
         outDir=$(echo $1 | sed 's/\/$//')
      else
         echo "Incorrect number of parameters." >&2
         printHelp
         exit 1
      fi
   fi
   
   shift
done

if [ -z "$projectName" -o -z "$personName" ]; then
   echo "Incorrect number of parameters." >&2
   printHelp
   exit 1
fi


# Save paths/file names, create output directory if necessary
if [ -z $outDir ]; then
   if [ -z $useTimestamp ]; then
      myLog="${projectName}.log"
   else
      myLog="${projectName}_$(date +'%Y%m%d').log"
   fi
else
   mkdir -p $outDir
   if [ $? -ne 0 ]; then
      echo "Unable to secure write permissions on output directory. Please elevate or choose another directory." >&2
      printUsage
      exit 2
   fi
   if [ -z $useTimestamp ]; then
      myLog="$outDir/${projectName}.log"
   else
      myLog="$outDir/${projectName}_$(date +'%Y%m%d').log"
   fi
fi
myFifo=".log.sh.temp"

# Prepare files
mkfifo $myFifo
if [ $? -ne 0 ]; then
   echo "Unable to secure write permissions on output directory. Please elevate or choose another directory." >&2
   printUsage
   exit 2
fi

if [ ! -f $myLog ]; then
   touch $myLog
fi

# Initialize log with this session
echo "************************************************************************" >> $myLog
echo "$personName @ $(date): Initialized logging from $(hostname)" >> $myLog

# Crank the pipe dumper
bash -c "while : ; do cat $myFifo | sed 's/^/\t- /' >> $myLog; done" >/dev/null 2>&1 &
fifoPipe=$!

# Process input
while : ; do
   read -p "$(whoami)@$(hostname):$PWD > " inputField
   case $inputField in
      [Qq][Uu][Ii][Tt])                                                 # Quit if they ask to
         echo "$personName @ $(date): Requested ending of logging." >> $myLog
         echo "************************************************************************" >> $myLog
         break
         ;;
      [Nn][Oo][Tt][Ee]*)                                                # Add a note instead of executing if they ask
         inputField=$(echo $inputField | sed 's/[Nn][Oo][Tt][Ee][^A-Za-z0-9]*//')
         echo "$personName @ $(date): ${inputField}" >> $myLog
         ;;
      *)                                                                # Otherwise do the command, output to screen and log with date/time
         echo "$personName @ $(date): ${inputField}" >> $myLog
         bash -c "${inputField}" 2>&1 | tee -a $myFifo
         ;;
   esac
done

# Clean up.
kill $fifoPipe >/dev/null 2>&1
rm $myFifo >/dev/null 2>&1
