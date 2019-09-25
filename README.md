# Miscellanous Scripts
---
These miscellaneous scripts are just small bits I've built to make things easier on myself over the years that maybe someone else can use. The scripts are (usually) commented, and their operation should be understandable from the comments or from the help pages, if I saw fit to give them one.

### mkvenv
---
When you're working with a small Python script with requirements, or when you're working with a small package and using something robust like [tox](https://tox.readthedocs.io/en/latest/) wouldn't be appropriate to unify lots of building/testing/packaging/requirements checks, but you're sick of rebuilding environments over and over again to validate your script or package, there's mkvenv. I wanted to add some portability to definitions of my requirements, and some portability, consistency, and reproducability to some of my smaller packages during their development, and was getting really frustrated when I would try to get a friend or colleague to get it operational for some tests (or even just switching between VM's/distros), so I wanted an easy way to handle building the virtual environments required for the packages.

I started working on mkvenv.sh for one project, but it has now grown to the point where I would call it "universally useful" for Python package setup.py files, or for requirements.txt definitions. It supports specifying interpreters, auto-detection of appropriate interpreter (as far as python2/python3 at least) from setup.py files, development-mode installations for setuptools (egg-link files), completely rebuilding or incremental updates to existing venvs, and will go so far as to download and install pip in user mode for you if it needs to. All it needs is `python` and `python-distutils` from your native package manager, which most distros install in some capacity out of the box. It will warn you if it hits a bump in the road, and generate robust logs to troubleshoot problems (they would be appreciated if you consider opening an issue).

Using the `-q` flag you can integrate it as part of another script's workflow if that script is using my [output formatter](https://github.com/solacelost/output-formatter) for consistent output between your script and this one. It does a lot with a little, and I almost made it its own repository. It's really handy to just keep a copy in PATH or bootstrap it into your other script's setup process, though keep in mind its usage is intended primarily for development purposes - you shouldn't be trying to use this as part of your packaging and distribution toolkit. It's hacky and it works well for what it was designed for.

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
