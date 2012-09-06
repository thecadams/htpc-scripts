mythrqcal
=========

**Unfinished:** This code is still not complete yet. The idea was to allow you to enter a Google Calendar appointment and the system woud search for a matching program which would be on during at least one point for which you set the calendar appointment.

So, if you know a show is going to be on between 3 and 4 PM, you might set an appointment for 3-4PM. The algorithm would look for a program matching your search query (it was going to use the same search algorithm as mythweb) for which any of the following is true:

- The program starts before and ends after the appointment's start time.
- The program starts before and ends after the appointment's end time.
- The program starts after the appointment's start time, and ends before the appointment's end time.

These 3 cases plus the fuzzy search logic to be borrowed from mythweb would allow you to be very approximate in your searches.

As it is, the search is partly implemented and calendar appointments are retrieved but not processed.