#!/usr/bin/env python
from Xlib.display import Display
from Xlib import X
from Xlib.protocol import event
import time,pprint,Xlib.ext.xtest

display=Display()

def mouse_click(button):
	"""1=left, 2=middle, 3=right"""
	Xlib.ext.xtest.fake_input(display,Xlib.X.ButtonPress,button)
	display.sync()
	Xlib.ext.xtest.fake_input(display,Xlib.X.ButtonRelease,button)
	display.sync()

def move_abs(x,y):
	"""move to absolute co-ordinate"""
	display.screen().root.query_pointer().child.warp_pointer(x,y)

def move_rel(x,y):
	"""move to relative co-ordinate"""
	display.warp_pointer(x,y)


#move_abs(200,200)
#move_rel(200,200)
#move_rel(-100,-100)
mouse_click(5)
