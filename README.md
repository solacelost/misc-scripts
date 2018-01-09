# Miscellanous Scripts
---
These miscellaneous scripts are just small bits I've built to make things easier on myself over the years that maybe someone else can use. The scripts are (usually) commented, and their operation should be understandable from the comments or from the help pages, if I saw fit to give them one.

### kernel-cleaner
---
Especially useful if you maintain a seperate boot partition. Removes all but the two most recent kernels from your boot and grub configurations. Built on Mint 18.1, should work on Mint or Ubuntu 16.04. Compatability for other versions not guaranteed. Set as a cron job if you like to keep it trim, or only use it when you need to.

### log
---
A utility that allows for multiple users to open logging sessions on a single logfile, executing commands and logging their output as well as their notes together in organized projects with timestamps. You can alternatively just use it in single-user mode and still get great benefit. Used to generate raw "opnotes" while working

### phonehome
---
A port knocking script for interfacing with SSH (or some other service, I suppose) hidden behind a port-knocking daemon, such as [knockd](https://github.com/jvinet/knock). Come default configuration parameters are set inside the script, and then it's customizable. There's a pretty thorough help page, but some code review might help, too.
