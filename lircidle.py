#!/usr/bin/python
import os, socket, time, sys, syslog, pylirc, select
from threading import Thread

global lastInput
global stopThreads

lastInput=time.time()
stopThreads=0
sck='/tmp/.lircidle'

class InputListener(Thread):
	def __init__(self):
		Thread.__init__(self)
	def run(self):
		try:
			global lastInput
			global stopThreads
			if (pylirc.init("lircidle","/home/myth/scripts/lircrc_lircidle",0) == 0):
				syslog.syslog('lircidle.py: unable to init lirc')
				print('lircidle.py: unable to init lirc')
				sys.exit(1)
			while 1:
				time.sleep(1)
				c = pylirc.nextcode()
				if c is not None:
					#for (code) in c:
					#	syslog.syslog('lircidle.py (debug): code received (' + str(code["config"]) + ')')
					#	print('lircidle.py (debug): code received (' + str(code["config"]) + ')')
					lastInput = time.time()
				if stopThreads != 0: break
		except:
			syslog.syslog('lircidle.py: unexpected exception: ' + str(sys.exc_info()))
			print('lircidle.py: unexpected exception: ' + str(sys.exc_info()))
		finally:
			pylirc.exit()
			syslog.syslog('lircidle.py: exiting lirc thread')
			print('lircidle.py: exiting lirc thread')

def getIdleTimeFromServer():
	cs = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
	try:
		cs.connect(sck)
		data = cs.recv(1024)
		return str(data)
	finally:
		cs.close()

def daemonize():
	# Ensure we're not already a daemon.
	if (os.getppid() == 1): return
	try: 
		pid = os.fork() 
		if pid > 0:
			# exit parent
			sys.exit(0) 
	except OSError, e: 
		print >>sys.stderr, "fork #1 failed: %d (%s)" % (e.errno, e.strerror) 
		sys.exit(1)

	# Decouple from parent environment.
	os.chdir("/") 
	os.setsid() 
	os.umask(0) 

	import resource		# Resource usage information.
	maxfd = resource.getrlimit(resource.RLIMIT_NOFILE)[1]
	if (maxfd == resource.RLIM_INFINITY):
		maxfd = 1024

	# Iterate through and close all file descriptors.
	for fd in range(0, maxfd):
		try:
			os.close(fd)
		except OSError:	# ERROR, fd wasn't open to begin with (ignored)
			pass

	# This call to open is guaranteed to return the lowest file descriptor,
	# which will be 0 (stdin), since it was closed above.
	os.open("/dev/null", os.O_RDWR)	# standard input (0)
	os.dup2(0, 1)			# standard output (1)
	os.dup2(0, 2)			# standard error (2)

def runServer():
	try:
		s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
		s.bind(sck)
		t = InputListener()
		t.start()
		while 1:
			try:
				s.listen(1)
				conn, addr = s.accept()
				if conn is not None:
					conn.send(str(time.time()-lastInput))
					conn.close()
			except:
				syslog.syslog('lircidle.py: unexpected exception: ' + str(sys.exc_info()))
				print('lircidle.py: unexpected exception: ' + str(sys.exc_info()))
				sys.exit(1)
	except:
		syslog.syslog('lircidle.py: unexpected exception: ' + str(sys.exc_info()))
		print('lircidle.py: unexpected exception: ' + str(sys.exc_info()))
		sys.exit(1)

try:
	print getIdleTimeFromServer()
except socket.error:
	print 0
	if os.path.exists(sck): os.unlink(sck)
	daemonize()
	runServer()
