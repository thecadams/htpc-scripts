#!/usr/bin/python
# ir_emit
#
# When a new song is queued, turn on the stereo system
# When player is paused, stopped or turns off, turn off stereo
# When signalled to quit, turn off the stereo system

import subprocess, time, socket, urllib

def stereoShouldTurnOn(str):
	return False

def stereoShouldTurnOff(str):
	return False

def turnOnStereo():
	global stereoOn
	if stereoOn:
		return
	proc = ['/usr/bin/irsend', '-d', '/dev/lircd1', 'send_once', 'Panasonic_EUR7702260', 'poweron', 'dvd', 'dvd', 'dvd']
	res = subprocess.call(proc)
	print 'turnOnStereo: res: ' + str(res)
	if res != 0:
		print 'turnOnStereo: retrying irsend'
		time.sleep(2)
		subprocess.call(proc)
	stereoOn = True

def turnOffStereo():
	global stereoOn
	if not stereoOn:
		return
	proc = ['/usr/bin/irsend', '-d', '/dev/lircd1', 'send_once', 'Panasonic_EUR7702260', 'poweroff']
	res = subprocess.call(proc)
	print 'turnOffStereo: res: ' + str(res)
	if res != 0:
		print 'turnOffStereo: retrying irsend'
		time.sleep(2)
		subprocess.call(proc)
	stereoOn = False

stereoOn = False

s = socket.create_connection(['localhost','9090'])
if s is None:
	print 'Error: unable to connect to socket'
else:
	s.send('listen\n')
	s.recv(1024)
	while True:
		data = s.recv(1024)
		if data:
#REVISIT: split into single lines of output
			data = urllib.unquote(data).rstrip('\n')
			print 'Data received: ' + data
			if stereoShouldTurnOn(data):
				turnOnStereo()
			if stereoShouldTurnOff(data):
				turnOffStereo()
		else:
			print 'No data received'
