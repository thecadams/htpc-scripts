#include <stdio.h>
#include <X11/extensions/scrnsaver.h>

/* To compile: gcc -o xidle xidle.c */

int main() {
 XScreenSaverInfo *info = XScreenSaverAllocInfo();
 Display *display = XOpenDisplay(NULL);
 if (display == NULL) { return 1; }
 XScreenSaverQueryInfo(display, DefaultRootWindow(display), info);
 printf("%.3f\n", ((double)info->idle)/1000);
 return 0;
}

