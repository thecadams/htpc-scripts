import sys
from PyQt4 import QtGui, Qt, QtCore

class Transparent(QtGui.QWidget):

def __init__(self):
QtGui.QWidget.__init__(self)
self.setAttribute(Qt.Qt.WA_NoSystemBackground)
self.setAutoFillBackground(True)

pixmap = QtGui.QPixmap("test.png")
width = pixmap.width()
height = pixmap.height()

self.setWindowTitle("Status")
self.resize(width, height)

self.label = QtGui.QLabel(self)
self.label.setPixmap(QtGui.QPixmap("test.png"))

self.setMask(pixmap.mask())

def paintEvent(self,event):
self.setAttribute(Qt.Qt.WA_NoSystemBackground)

if __name__ == "__main__":
app = QtGui.QApplication(sys.argv)
x = Transparent()
x.show()
app.exec_()
