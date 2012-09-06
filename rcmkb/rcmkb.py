#!/usr/bin/env python
from Xlib.display import Display
from Xlib import X
from Xlib.protocol import event
from datetime import datetime,timedelta
import sys,tty,termios,pprint,Xlib.ext.xtest,pylirc

# Config
ACCEL_MAX_MS=800 # Repeat key before this number of milliseconds to accelerate

# Move: precise movement
MOVE_MIN=1 # Initial movement
MOVE_ACCEL=1.4 # Multiplier for each key repeat within the repeat period
MOVE_MAX=200 # Max to multiply to

# Hop: mid-range movement (if you have spare keys on your remote!)
HOP_MIN=20
HOP_ACCEL=1.2
HOP_MAX=200

# Jump: large movement
JUMP_MIN=80
JUMP_ACCEL=1.2
JUMP_MAX=200

# Constants
COS45=0.707

display=Display()
#fd=sys.stdin.fileno()
#old_termsettings = termios.tcgetattr(fd)

# Directions
NODIR=0
N=1
NE=2
E=3
SE=4
S=5
SW=6
W=7
NW=8

def mouse_click(button):
	"""1=left, 2=middle, 3=right"""
	Xlib.ext.xtest.fake_input(display,Xlib.X.ButtonPress,button)
	display.sync()
	Xlib.ext.xtest.fake_input(display,Xlib.X.ButtonRelease,button)
	display.sync()

def move_abs(x,y):
	"""move to absolute co-ordinate"""
	display.screen().root.query_pointer().child.warp_pointer(x,y)
	display.sync()

def move_rel(x,y):
	"""move to relative co-ordinate"""
	display.warp_pointer(x,y)
	display.sync()

def move_accel(direction,min,accel,max):
	global last_movedist, last_movetm, last_direction, last_min, last_accel, last_max
	movedist = min
	movetm = datetime.now()
	try:
		# Accel if pressed twice within one second
		tmdelta = movetm - last_movetm
		if direction == last_direction and min == last_min and accel == last_accel and max == last_max and tmdelta < timedelta(milliseconds=ACCEL_MAX_MS):
			movedist = last_movedist
			movedist *= accel
			if (movedist > max):
				movedist = max
	except NameError:
		pass
	if direction == N:
		x = 0
		y = movedist * -1
	elif direction == NE:
		x = movedist * COS45 # cos(45deg) or sin(45deg)
		y = x * -1
	elif direction == E:
		x = movedist
		y = 0
	elif direction == SE:
		x = movedist * COS45
		y = x
	elif direction == S:
		x = 0
		y = movedist
	elif direction == SW:
		x = movedist * COS45 * -1
		y = x * -1
	elif direction == W:
		x = movedist * -1
		y = 0
	elif direction == NW:
		x = movedist * COS45 * -1
		y = x
	print "move(",x,",",y,")\n"
	move_rel(x,y)
	last_movedist = movedist
	last_movetm = movetm
	last_direction = direction
	last_min = min
	last_accel = accel
	last_max = max

def nomove():
	last_direction = NODIR

def move(direction):
	move_accel(direction,MOVE_MIN,MOVE_ACCEL,MOVE_MAX)

def hop(direction):
	move_accel(direction,HOP_MIN,HOP_ACCEL,HOP_MAX)

def jump(direction):
	move_accel(direction,JUMP_MIN,JUMP_ACCEL,JUMP_MAX)

if pylirc.init("rcmkb","/home/myth/src/rcmkb/rcmkb_lircrc",1) == 0:
	sys.exit(1)
try:
	while 1:
		s = pylirc.nextcode(1)
		if s is not None:
			for (code) in s:
				print "Command: %s, Repeat: %d" % (code["config"], code["repeat"])
				if code["config"] == "mouse1":
					mouse_click(1)
				elif code["config"] == "mouse2":
					mouse_click(2)
				elif code["config"] == "mouse3":
					mouse_click(3)
				elif code["config"] == "mouse4":
					mouse_click(4)
				elif code["config"] == "mouse5":
					mouse_click(5)
				elif code["config"] == "move_n":
					move(N)
				elif code["config"] == "hop_n":
					hop(N)
				elif code["config"] == "jump_n":
					jump(N)
				elif code["config"] == "move_ne":
					move(NE)
				elif code["config"] == "hop_ne":
					hop(NE)
				elif code["config"] == "jump_ne":
					jump(NE)
				elif code["config"] == "move_e":
					move(E)
				elif code["config"] == "hop_e":
					hop(E)
				elif code["config"] == "jump_e":
					jump(E)
				elif code["config"] == "move_se":
					move(SE)
				elif code["config"] == "hop_se":
					hop(SE)
				elif code["config"] == "jump_se":
					jump(SE)
				elif code["config"] == "move_s":
					move(S)
				elif code["config"] == "hop_s":
					hop(S)
				elif code["config"] == "jump_s":
					jump(S)
				elif code["config"] == "move_sw":
					move(SW)
				elif code["config"] == "hop_sw":
					hop(SW)
				elif code["config"] == "jump_sw":
					jump(SW)
				elif code["config"] == "move_w":
					move(W)
				elif code["config"] == "hop_w":
					hop(W)
				elif code["config"] == "jump_w":
					jump(W)
				elif code["config"] == "move_nw":
					move(NW)
				elif code["config"] == "hop_nw":
					hop(NW)
				elif code["config"] == "jump_nw":
					jump(NW)
finally:
	pylirc.exit()

# old test keyboard code
#try:
#	tty.setraw(fd)
#	while 1:
#		c = sys.stdin.read(1)
#		if c == chr(3):
#			break
#
#		# Click checks
#		if c == "s":
#			mouse_click(1)
#		elif c == "r":
#			mouse_click(2)
#		elif c == "f":
##			mouse_click(3)
##
#		# Movement checks
#		if c == "w":
#			move(N)
#		elif c == "e":
#			move(NE)
#		elif c == "d":
#			move(E)
#		elif c == "c":
#			move(SE)
#		elif c == "x":
#			move(S)
#		elif c == "z":
#			move(SW)
#		elif c == "a":
#			move(W)
#		elif c == "q":
#			move(NW)
#		elif c == "8":
#			jump(N)
#		elif c == "9":
#			jump(NE)
#		elif c == "6":
#			jump(E)
#		elif c == "3":
#			jump(SE)
#		elif c == "2":
#			jump(S)
#		elif c == "1":
#			jump(SW)
#		elif c == "4":
#			jump(W)
#		elif c == "7":
#			jump(NW)
#		else:
#			nomove()
#finally:
#	termios.tcsetattr(fd, termios.TCSADRAIN, old_termsettings)
