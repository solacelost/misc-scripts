#!/bin/bash

##Phone Home - A port knocking bash script
##Version 1.1, modified 11 April, 2017

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


function initialize_vars () {											#define once, use twice
	ports=( 1111 2222 3333 )											#default ports
	droppeduser='localunprivuser'										#default user to reduce privilege to
	remoteuser='remoteuser'												#default ssh user
	host='hostnameorip'													#default ssh host
	sshport=22															#default ssh port
	command=""															#clear variable, just in case
	defaultcommand='ssh -Y -p $sshport $remoteuser@$host'				#default action after knock
}

function print_usage () {
	echo "Usage: $0 [OPTION]... ['COMMAND']"
}

function print_help () {
	initialize_vars
	print_usage
	echo "
Phone Home version 1.1, a script to knock on remote server's ports to
open SSH, then optionally execute COMMAND. With no COMMAND, open an SSH
session with trusted X11 forwarding by default.

Arguments:
  -p,--ports PORT[,PORT[...]]   port sequence to knock, defined as a
                                  comma-separated sequence of numbers
                                  (ex: '-p 123,456,789')
                                  [ default: ${ports[@]} ]
  -l,--local-user USER          local user account to revert to after
                                  knocking
                                  [ default: $droppeduser ]
  -r,--remote-host HOST[:PORT]  HOST to ssh to; will revert to PORT 22
                                  when not specified
                                  (ignored if COMMAND is specified)
                                  [ default: $host:$sshport ]
  -u,--remote-user USER         remote user account for ssh
                                  (ignored if COMMAND is specified)
                                  [ default: $remoteuser ]
  -h,--help                     display this help and quit

Examples:
	Connect to your normally defined server using a different IP:
	# $0 -r 10.0.0.51

	Connect to a different user on your server than you usually do:
	# $0 -u myotheruser

	Use rsync to transfer some files from your server:
	# $0 'rsync -avz user@host:/path/to/files /home/directory'

	Use a lower privilege account locally that has a pre-defined id_rsa 
	  in their ~/.ssh directory to back your hosted website up to a 
	  dedicated backup server running ssh on a non-standard port:
	# $0 -l myotherlocaluser 'rsync -avz -e \"ssh -p 31337\" \\
	/var/www backupuser@backup.company.com:/mnt/www/rolling'

NOTE: $0 requires root privileges to knock, so please run it
from a root shell or with sudo (ex: sudo $0)

Copyright (c) 2017 James P. Harmison
Edit script for license information, and to change defaults."
}

function error_handler () {
	echo -e "$0 $1 requires an arguement\n"
	print_help
	exit 1
}

function print_diagnostics () {											#considering how easily this script
	if [[ -n $1 ]]; then												# could be abused in its intended
		command=( $@ )													# form, I don't see anything wrong
	else																# with a hidden diagnostic function
		command=( $(eval echo $defaultcommand) )
	fi
	echo "ports: ${ports[@]}"
	echo "number of ports: ${#ports[@]}"
	echo "sudo user: $droppeduser"
	echo "ssh user: $remoteuser"
	echo "ssh host: $host"
	echo "ssh port: $sshport"
	echo "command: ${command[@]}"
	echo "current user: $(whoami)"
	echo "hping3 installed: $(if [[ $(hping3 -h 2>/dev/null) ]]; then echo -ne 'yes'; else echo 'no'; fi)"
}

initialize_vars

while [[ $# -gt 0 ]]; do												#option switch handling, done
	case $1 in															# entirely manually for granularity
		-r|--remote-host)
			if [[ $(echo $2 | head -c 1) == '-' || -z $2 ]]; then		#error handling if arguements don't
				error_handler "$1"										# follow the switch
			fi
			host="$(echo $2 | cut -d ':' -f 1)"
			sshport="$(echo $2 | cut -d ':' -f 2)"
			if [[ $host == $sshport ]]; then							#this happens when they don't specify
				sshport=22												# a port with the remote host
			fi
			if [ "$(echo $sshport | grep [^0-9])" ]; then				#ports are numbers, though we should
				echo -e "invalid remote port specification, $sshport\n"	# probably also make sure they're
				print_help												# in the right range
				exit 1
			fi				
			shift
		;;
		-p|--ports)
			if [[ $(echo $2 | head -c 1) == '-' || -z $2 ]]; then		#error handling if arguements don't
				error_handler "$1"										# follow the switch
			fi
			ports=()
			for thisport in $(echo $2 | tr ',' ' '); do					#this loop builds the new array of
				if [ "$(echo $thisport | grep [^0-9])" ]; then			# ports, supposing they're numbers
					echo -e "invalid port specification, $thisport, in $2\n"
					print_help
					exit 1
				fi
				ports=(${ports[@]} $thisport)
			done
			shift
		;;
		-l|--local-user)
			if [[ $(echo $2 | head -c 1) == '-' || -z $2 ]]; then		#error handling if arguements don't
				error_handler "$1"										# follow the switch
			fi
			droppeduser="$2"											#should maybe check if user exists,
			shift														# but sudo will fail if it doesn't
		;;
		-u|--remote-user)
			if [[ $(echo $2 | head -c 1) == '-' || -z $2 ]]; then		#error handling if arguements don't
				error_handler "$1"										# follow the switch
			fi
			remoteuser="$2"
			shift
		;;
		-h|--help)
			print_help
			exit 0
		;;
		-d|--debug)														#useful to check your syntax, but
			print_diagnostics $2										# should be last switch, but
			exit 0														# COMMAND may follow it
		;;
		*)
			if [[ $(echo "$1" | head -c 1) == '-' ]]; then				#necessary to retrieve command,
				echo -e "Unknown option $1 \n"							# but also to filter bad options
				print_help
				exit 1
			fi
			command=( "$1" )											#this defines our command as an array
		;;																# array, which becomes important
	esac																# later
	shift
done

# Variable expansion happens at assignment when you use double quotes, so we have to build our command 
#   after other variables are set, unless one is specified above. Using eval here along with single quotes
#   in our original $defaultcommand assignment is a neat trick to expand our variables after the fact, 
#   if a different command weren't set in our option handling above. Additionally, it must be an array
#   given the strange way we call it later.
if [[ ! $command ]]; then
	command=( "$(eval echo $defaultcommand)" )
fi

if [[ ! $(hping3 -h 2>/dev/null) ]]; then								#verify we have hping3
	echo "$0 requires hping3. Install it from your distribution's
repositories and ensure that it's in the path before attempting to run
$0 again."
	exit 1
fi

if [[ $(whoami) != 'root' ]]; then										#hping3 requires root
	echo -e "$0 must run as root.\nUse '$0 -h' for details\n"
	exit 1
fi

# If we got this far, then we can knock!

echo -ne "Knocking"

for port in ${ports[@]}; do												#iterate through ports array
	echo -ne "."														#fancy progress indicator
	sleep .5															#small sleep to ensure packets arrive
																		# in order at the distant end
	hping3 $host -S -p $port -c 1 > /dev/null 2>&1						#send a single TCP SYN to each port
done

echo -ne "\nOpen sesame!\n\n"											#may as well be theatrical about it
sleep .5

# This script has been building to this moment. Here, we call a new instance of bash, because the way
#   we're using the commands inside an array, which can include quotes within them, doesn't allow us
#   to use a normal subshell. We have to pass the entire array, as a subcomponent of a string, to another
#   command in a way that will allow us to interact with it, or allow us to include strange syntax within
#   that variable. Instead of writing the command to another script, calling that script (which effectively
#   does the same thing as this single line), and then deleting the script afterwards, this method is
#   cleaner, and no more dangerous. In the end, whatever you've asked it to do, it will do with the
#   context of the lower-privilege user.
sudo -u $droppeduser bash -c "${command[@]}"
