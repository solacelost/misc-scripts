# Miscellanous Scripts
---
These miscellaneous scripts are just small bits I've built to make things easier on myself over the years that maybe someone else can use. The scripts are (usually) commented, and their operation should be understandable from the comments or from the help pages, if I saw fit to give them one.

### cryptstring
---
Just a little python to handle securely generating Unix-like sha512 crypt strings, suitable for use in a shadow file or elsewhere. Based originally on a stackoverflow answer for what to use when you don't have access to `crypt`, it has grown with some extra functionality and I find myself using it in all kinds of situations. Will prompt, or accept piped input. Prompted input will also confirm, and you can change the prompts if you like.

### kernel-cleaner
---
Especially useful if you maintain a seperate boot partition. Removes all but the two most recent kernels from your boot and grub configurations. Built on Mint 18.1, should work on Mint or Ubuntu 16.04. Compatability for other versions not guaranteed. Set as a cron job if you like to keep it trim, or only use it when you need to.

### log
---
A utility that allows for multiple users to open logging sessions on a single logfile, executing commands and logging their output as well as their notes together in organized projects with timestamps. You can alternatively just use it in single-user mode and still get great benefit. Used to generate raw "opnotes" while working

### nmappoll
---
A tool that continuously nmaps a host (or whatever you tell it to) and gives you clean output information on completion of the first scan, as well as a summary of the differences (marked by +, -, or ~), after each subsequent scan. Saves first and most recent scans in XML format automatically, so there's more you can do with that if you like. Good to watch changes take effect, make sure changes _aren't_ taking effect, etc. Requires [libnmap](http://libnmap.readthedocs.io/en/latest) be in your current Python environment.

### phonehome
---
A port knocking script for interfacing with SSH (or some other service, I suppose) hidden behind a port-knocking daemon, such as [knockd](https://github.com/jvinet/knock). Some default configuration parameters are set inside the script, and then you can change things with some command line switches. There's a pretty thorough help page, but some code review might help, too.

### timeuntil
---
A script that can maintain some countdowns for you, with full `date` specification support.

### Set-SleepTimer
---
My wife uses her computer connected to the TV in our bedroom, and falls asleep with it on. When we set the sleep timer on the TV, the computer keeps streaming Netflix (or whatever) through its own speakers/screen. This is awful. If the computer goes to sleep, however, the TV will time itself out and turn off - so here you go, dear. A powershell script to hibernate or sleep your computer on a timer, which warns you when your time is coming up. If you prefer Sleep behavior over Hibernate, from an elevated prompt run `powercfg -h off` prior to running the script. Ensure your PowerShell ExecutionPolicy is set appropriately to run, or bypass it from the shortcut (e.g. Target: `"%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe" -executionpolicy bypass -command C:\path\to\Set-SleepTimer.ps1`)

### sleeptimer
---
Okay, so I've finally convinced her to use Linux on the computer hooked to the TV since I got HBO Go to work effectively in a native Linux browser. Basically, this does what the above does, but in bash instead of PowerShell. A few tweaks to just a couple conditionals and you could make it run on generic shell, too, but you'll have to either have zenity or swap it out for something on your Mac or whatever. Outputs debug information to stderr, but I start it with `Terminal=false` in the .desktop file for the most part.
