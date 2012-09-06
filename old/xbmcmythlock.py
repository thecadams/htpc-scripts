#!/usr/bin/python

idleThreshold=300;
maxUnlockAttempts=10;
lockCmd='/usr/bin/mythshutdown -l';
unlockCmd='/usr/bin/mythshutdown -u';
statusCmd='/usr/bin/mythshutdown -s; echo -n $? > /tmp/temp.out';
tmpFile='/tmp/temp.out';

import time
import os
import sys

# If xbmc cannot be imported, the script was run from the command line
# Remove the shutdown lock
try:
	import xbmc
except:
	print 'XBMCIdleMythLock: allowing shutdown by unlocking';
	unlockAttempts = 0;
	while 1:
		if unlockAttempts >= maxUnlockAttempts:
			print 'XBMCIdleMythLock: unlock failed after %d attempts (max %d)'%(unlockAttempts,maxUnlockAttempts);
			sys.exit(1);
		os.system(statusCmd);
		status = int(open(tmpFile).read());
		if status < 0:
			print 'XBMCIdleMythLock: bad status %d; giving up'%status;
			sys.exit(2);
		elif status & 16 == 0:
			print 'XBMCIdleMythLock: unlock succeeded (status %d) after %d attempts (max %d)'%(status,unlockAttempts,maxUnlockAttempts);
			sys.exit(0);
		unlockAttempts += 1;	
		print 'XBMCIdleMythLock: unlock required (status %d), attempt %d'%(status,unlockAttempts+1);
		os.system(unlockCmd);



def allowShutdown():
	xbmc.log(msg='XBMCIdleMythLock: allowing shutdown by unlocking', level=xbmc.LOGINFO);
	unlockAttempts = 0;
	while 1:
		if unlockAttempts >= maxUnlockAttempts:
			xbmc.log(msg='XBMCIdleMythLock: unlock failed after %d attempts (max %d)'%(unlockAttempts,maxUnlockAttempts), level=xbmc.LOGINFO);
			break;
		os.system(statusCmd);
		status = int(open(tmpFile).read());
		if status < 0:
			xbmc.log(msg='XBMCIdleMythLock: bad status %d; giving up'%status, level=xbmc.LOGINFO);
			break;
		elif status & 16 == 0:
			xbmc.log(msg='XBMCIdleMythLock: unlock succeeded (status %d) after %d attempts (max %d)'%(status,unlockAttempts,maxUnlockAttempts), level=xbmc.LOGINFO);
			break;
		unlockAttempts += 1;	
		xbmc.log(msg='XBMCIdleMythLock: unlock required (status %d), attempt %d'%(status,unlockAttempts+1), level=xbmc.LOGINFO);
		os.system(unlockCmd);

def disallowShutdown():
	xbmc.log(msg='XBMCIdleMythLock: disallowing shutdown by locking', level=xbmc.LOGINFO);
	os.system(statusCmd);
	status = int(open(tmpFile).read());
	if status < 0:
		xbmc.log(msg='XBMCIdleMythLock: bad status %d; giving up'%status, level=xbmc.LOGINFO);
	elif status & 16 == 0:
		xbmc.log(msg='XBMCIdleMythLock: unlocked (status %d); locking'%(status), level=xbmc.LOGINFO);
		os.system(lockCmd);
	else:
		xbmc.log(msg='XBMCIdleMythLock: already locked (status %d); nothing was done'%status, level=xbmc.LOGINFO);


try:
	while 1:
		currentIdleTime = xbmc.getGlobalIdleTime();
		xbmc.log(msg='XBMCIdleMythLock: Idle for %d sec (threshold %d)'%(currentIdleTime,idleThreshold), level=xbmc.LOGINFO);
		if currentIdleTime < idleThreshold:
			disallowShutdown();
		else:
			allowShutdown();
		time.sleep(60);
except:
	xbmc.log(msg='XBMCIdleMythLock: Exception: %s: %s %s'%(sys.exc_info()[0],sys.exc_info()[1],sys.exc_info()[2]), level=xbmc.LOGINFO);
	allowShutdown();
