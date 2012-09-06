htpc-scripts
==============

A collection of scripts and config files I've created for my home theatre PC, in varying states of being unfinished.

These were mostly weekend projects; I had combined them all into a slick setup. You'll find a bunch of places using absolute paths, shouldn't be too much trouble to fix. The system is pretty much an appliance:

- Automatically gets recordings
- Wakes itself up to record TV shows
- Shuts down when it's done

Because it's usually off, it also updates a Google Calendar with the shows it's been set up to record.

It also won't shut down if you're doing something - eg. you're SSHed into the box, you're accessing a samba file share, you're watching something in XBMC or MythTV, Transmission is downloading, you're using Firefox etc. - that's all in shutdown.pl which calls out to various utlities to ask if things are idle.

There are scripts here to do several things..

## Remote control

- Handle various buttons on the remote
- Allow a button on the remote to be used to prevent shutdown
- Switch between XBMC, Firefox and MythTV with a remote control button
- Control the mouse from the remote (a better implementation of lircmd)
- Recognise input from all the remotes in my theatre setup
- Integrate my IR emitter with squeezebox, to both automatically and manually control the stereo
- A custom squeezebox script to use the IR emitter from iPeng, the iPhone app for squeezebox
- Integrate my IR emitter with the rest of the components in the theatre setup

## Monitoring

- Monitor CPU, GPU and hard drive temperatures from MythWeb
- Send recordings to, and schedule recordings from, Google Calendar


## Power Management

- Check whether the system's X window servers are idle, and how long it's been since a button was pressed on the remote control
- Shut down the system when the user hasn't been doing anything for a while
- Shut down the system if the user wishes, but only if it's not doing things like fetching program guide data
- Have a custom main menu on MythTV, which can go to XBMC or Firefox
- Ensure that no matter how the system is shut down, it still checks for recordings in future and sets itself to wake up