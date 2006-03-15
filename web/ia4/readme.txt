
The following is a brief explanation of how I have put together my Audrey
pages.  This is not a one-size-fits-all solution, but rather an example
that anyone else can take and customize to their own environment.  Several
of the web pages below make extensive use of includes as well as calling
subroutines to get status information as well as control various MH functions.

My audrey's are configured to call the page directly, hence no index.html
in its present format.  You could easily change this by simply renaming 
audrey.html and changing the one link on the mh_logo image that reloads
the entire opening frame.

The calendar pages were inspired by info on the homeseer site regarding the
work that some users had done on similar Audrey pages.  You will need to edit
them and provide your username and password for your Yahoo Calendar.

I hope these are of benefit to some of you.  I have enjoyed working on them.
Audrey was the piece my MH setup needed to become truly useful.

--Ron Wright
  ron@wright-house.d2g.com


mh_web/audrey

audrey.html           Main Audrey Page:  Creates initial frames
mainmenu.html         Generates main audrey menu
title.html            Creates title on top of main page
datetime.shtml        includes current date and time as well as a save temperature variable
empty.html            used to pad the screen size so pages keep there shape in other browsers
statuspanel.pl        Perl script usedto generate opening status page.
statuspanel.shtml     <include> to call above perl script
off.gif               red led
on.gif                blinking green led
mh_logo.gif           The Misterhouse Logo

lights.shtml          Generates to Lights control page

modes.shtml           Creates the mode set page also containing motion status
motion.pl             perl file to check status of all motion detectors

phone.shtml           Reads temporary log created by calllog.pl and display recent callers.

music.html            Creates link to two Internet Radio sites

calendar.html         Creates Calendar screen
calendarmenu.html     Provides menu on bottom to select calendar view
caltoday.html         Displays todays calendar
calweek.html          Display this weeks calendar
calmonth.html         Displays monthly calendar
calyear.html          Displays annual calendar
caladd.html           Add events to your calendar

localwx.html          Display local weather radar image.  
wxoutlook.html        Displays 6 day outlook graphic from local TV Station
wxforecast.shtml      Display forecast from get_internet_data
weather.shtml         display the local weather conditions as collected by get_Internet_data



mh_web/graphics

big_on.gif
big_off.gif



mh_code

web_sub.pl            Subroutines used by the Audrey web pages.