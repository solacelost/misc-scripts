#!/bin/bash
cat << 'ENDOFLICENSE' >> /dev/null
Copyright 2018 James Harmison <jharmison@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
ENDOFLICENSE

###############################################################################
# SECTION: Zenity box setup                                                   #
###############################################################################

# Some default arguments for zenity
genargs=('--title=Sleep Timer' '--window-icon=/usr/share/icons/hicolor/256x256/apps/preferences-system-time.png' '--width=250')

# Entry box to request a sleep timer duration
function getdur() {
    echo "Displaying duration gathering box" >&2
    dur=$(zenity "${genargs[@]}" --entry --text="Enter a duration for your sleep timer:" --entry-text=90m 2>/dev/null) || return 1
    echo "Box gathered $dur" >&2
    echo $(echo $dur | tr -d ' ')
}

# Yes/No box
function yesno() {
    echo -e "Displaying yes/no selection box for question:\n\t$1" >&2
    zenity "${genargs[@]}" --question --text="${1}" 2>/dev/null && \
        { echo 'Yes selected' >&2 ; return 0 ; } || \
        { echo 'No selected' >&2 ; return 1 ; }
}

# OK/Cancel box
function confirm() {
    echo -e "Displaying confirmation box for statement:\n\t$1" >&2
    zenity "${genargs[@]}" --ok-label=OK --cancel-label=Cancel --question --text="${1}" 2>/dev/null && \
        { echo 'OK selected' >&2 ; return 0 ; } || \
        { echo 'Cancel selected' >&2 ; return 1 ; }
}

# Error box
function error() {
    echo -e "Displaying error box for message:\n\t$1" >&2
    zenity "${genargs[@]}" --error --text="${1}" 2>/dev/null
}

# List box with checkboxes to select sleep timers from a list of those saved
function checklist() {
    echo "Displaying checklist box for following choices:" >&2
    declare -A list
    for timer in $@; do
        echo -e "\t$timer" >&2
        list[$(date -d '@'$timer)]=$timer
    done

    for timer in "${!list[@]}"; do
        echo -e "\n$timer"
    done | zenity "${genargs[@]}" --list --multiple --checklist \
        --separator='\n' --column='' --column="Timeout" \
        --text="Select any of the following timers you would like to keep, or choose cancel to erase them all:" \
        2>/dev/null | while IFS= read timer; do
            echo "User opted to keep timer ${list[$timer]}" >&2
            echo "${list[$timer]}"
        done
}

###############################################################################
# SECTION: Helper Functions                                                   #
###############################################################################

# Convert a basic timedelta spec into seconds
function rawseconds() {
    echo -e "Converting raw time spec to seconds:\n\t$1" >&2
    unit=$(echo $1 | tr -d '0-9')
    [ -z "$unit" ] && unit=m
    count=$(echo $1 | tr -d 'smhd')
    case $unit in
        s)
            mult=1
            unit=seconds
            ;;
        m)
            mult=60
            unit=minutes
            ;;
        h)
            mult=3600
            unit=hours
            ;;
        d)
            mult=86400
            unit=days
            ;;
        *)
            echo -e "Unknown unit:\n\t$unit" >&2
            return 1
            ;;
    esac
    sec=$(( $count * $mult ))
    echo "Identified $sec seconds in $count $unit" >&2
    echo $sec
}

# Validate timedelta spec and range of an input
function validtime() {
    [[ $1 =~ ^[0-9]+[smhd]?$ ]] || { echo -e "Invalid time spec:\n\t$1" >&2 ; return 1 ; }

    seconds=$(rawseconds $1)
    [ $seconds -ge 300 -a $seconds -le 172800 ] || { echo "Time ($seconds seconds) outside acceptable range" >&2 ; return 1 ; }

    echo "Valid time specified, $seconds seconds" >&2
    echo $seconds
}

# Retrieves and validates a timer duration, failing if user requests to cancel and echoing the raw seconds if they select "OK"
function gatherdur() {
    echo "Gathering a timer." >&2
    setdur=$(getdur) || return 1
    while ! seconds=$(validtime $setdur) ; do
        echo "Attempting to gather timer again" >&2
        error 'Invalid duration. Please select a time between five minutes and two days, omitting the unit for minutes or specifying the first letter of "second," "minute," "hour," or "day."'
        setdur=$(getdur) || return 1
    done
    echo $seconds
}

# Is the $1 an epochtime within $2 minutes of now?
function minutematch() {
    timer=$1
    diff=$2
    fmt='+%Y%m%d%H%M'

    [ $(( $(date $fmt) + $diff )) -ge $(date -d \@$timer $fmt) ] && return 0 || return 1
}

###############################################################################
# SECTION: Process Management Functions                                       #
###############################################################################

# Neatly quit the program without further work
function abort() {
    echo 'User requested operation cancelled' >&2
    exit 0
}

# Returns true if another copy of this script is currently displaying a Zenity prompt, False otherwise
function promptactive() {
    zenity_pids=$(grep -l 'zenity' /proc/*/status | cut -d/ -f3)
    for pid in $zenity_pids; do
        ppid=$(awk '/^PPid/ { print $2 }' /proc/$pid/status)
        [ $ppid -ne $$ ] && grep -Fq "$(basename $0)" /proc/$ppid/status && echo $ppid && return 0
    done
    return 1
}

# Set everything on fire, burn all the other timers to the ground. I am the one true timer.
function killemall() {
    for pid in $(grep -Fl "$(basename $0)" /proc/*/status | cut -d/ -f3 | grep -v $$); do
        echo "Killing previously running instance at PID $pid" >&2
        kill -9 $pid
    done
}

# Infanticide is not a crime if you're early enough
function killmychildren() {
    for pid in $(grep -Fl 'zenity' /proc/*/status | cut -d/ -f3); do
        grep -Fq "$(basename $0)" /proc/$(awk '/^PPid/ { print $2 }' /proc/$pid/status)/status && kill -9 $pid
    done
}

###############################################################################
# SECTION: Initial Setup                                                      #
###############################################################################

# Quit if things are scary
pid=$(promptactive) && echo "Identified a running instance of $(basename $0) with open prompts at PID $pid, cowardly aborting" >&2 && exit 1

# Debug output throughout; here we get our tracker primed
echo "Zenity args: ${genargs[@]}" >&2
tracker="$(realpath ~/.sleeptimer)"
echo "Tracker path: $tracker" >&2
[ -f $tracker ] && echo "Tracker exists" >&2 || { echo "Creating tracker" >&2 && touch $tracker ; }

# Pull all the timers from the tracker, ditch the old ones
echo "Identifying timers in tracker as of $(date +'%s')" >&2
timers=()
for line in $(cat $tracker) ; do
    [ $(date +'%s') -lt ${line#@} ] && echo "Identified timer: $line" >&2 && timers+=( ${line#@} ) || echo "Aborting expired timer: $line" >&2
done
echo "Value of all valid timers: ${timers[@]}" >&2

###############################################################################
# SECTION: Timer Prompting and Configuration                                  #
###############################################################################

# Work with existing timers
if [ ${#timers[@]} -eq 0 ]; then # there weren't any, so we'll prompt for one
    echo "No timers identified from file" >&2
    # This line does a lot, but at the end you know how many seconds until they want the computer to sleep
    seconds=$(gatherdur) || abort
    echo "$seconds seconds successfully selected for tracker at $(date), aka $(date +'%s') seconds" >&2
    # So just save it in our array
    timers+=( $(( $(date +'%s') + $seconds )) )
else # there was an existing timer
    echo "Validating existing timers" >&2
    # This just forces you to choose which of the existing timers you want to keep and forgets about all the others
    timers=( $(checklist ${timers[@]}) )
    echo "Value of all remaining timers: ${timers[@]}" >&2
    if yesno "Would you like to set a new timer?"; then # we'll ask for one
        seconds=$(gatherdur) || abort
        echo "$seconds will be added to other timers at $(date), aka $(date +'%s') seconds" >&2
        timers+=( $(( $(date +'%s') + $seconds )) )
    else # You maybe modified the list of saved timers, but you haven't added to it
        echo "User opted not to add additional timers" >&2
    fi
fi

###############################################################################
# SECTION: Clean-up and Timer Prep                                            #
###############################################################################

# We should rewrite the tracker as soon as we're able because we might not
#  prompt anything for a while, so we need to ensure our tracker is up to
#  date in case the user spawns another timer and we end up dead.
echo "Rewriting tracker with the following timers:" >&2
echo ${timers[@]} | tr ' ' '\n' | sed 's/^/\t/g' >&2
rm -f $tracker ; touch $tracker
for timer in "${timers[@]}"; do
    echo \@$timer >> $tracker
done

# Speaking of killing other threads..
killemall

# Just pick the soonest timer for now, if the computer's on later then it's on
nexttimer=$(echo ${timers[@]} | tr ' ' '\n' | sort -n | head -1)

###############################################################################
# SECTION: Timer Queueing and Control                                         #
###############################################################################

if [ -n "$nexttimer" ]; then # If we haven't ended up with an empty list by now
    echo "Beginning timer, looking for $nexttimer" >&2
    while sleep 30; do # hang out, i guess
        # This will return true when $nexttimer is within 5 minutes from now
        minutematch $nexttimer 5 && break
    done

    # We need to fire a thread to check for 0, and suspend when it's time. Our next prompt will hang the script.
    (while sleep 30; do minutematch $nexttimer 0 && break ; done ; echo "Initiating syspend now!" >&2 ; killmychildren ; systemctl suspend -i ) &

    # Five minute warning... if user cancels we destroy timer, kill other process from above (and any extras, tbh), and gracefully bring the thread down.
    echo "Five minute warning period now for $nexttimer" >&2
    confirm "Your computer will go to sleep in five minutes or less." || { sed -i "/$nexttimer/d" $tracker ; killemall ; abort ; }
else # I guess we did end up with a big empty list. Bye.
    echo "No remaining timers, closing." >&2
fi
