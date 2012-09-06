#!/usr/bin/python
# Check that no Squeezebox players are currently playing
import socket
import urllib
s = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.connect(('127.0.0.1',9090))
f = s.makefile('r',0)
f.write('player count ?\n')
playercount = f.readline().replace('player count ','').rstrip()
#print 'Player count: ' + playercount
for i in range(0,int(playercount)):
	si = str(i)
	f.write('player id ' + si + ' ?\n')
	playerid = urllib.unquote(f.readline().replace('player id ' + si + ' ','').rstrip())
	f.write('player name ' + si + ' ?\n')
	playername = urllib.unquote(f.readline().replace('player name ' + si + ' ','').rstrip())
	f.write(playerid + ' mode ?\n')
	playermode = urllib.unquote(f.readline()).lstrip(playerid + ' mode ').rstrip()
	print playername + ' (' + playerid + ') mode: ' + playermode

s.close()

