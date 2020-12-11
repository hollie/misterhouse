##########################
#  Klier Home Automation #
##########################

####################>>>  Timed Events
# TIME_CRON EVENTS - 1st digit = Minute(s) separated by commas
#                    2nd digit = Hour(s) separated by commas
#                    3rd digit = Day(s) separated by commas
#                    4th digit = Month(s) separated by commas
#                    5th digit = Day of week(s) 0=Sun 1=Mon 2=Tue, etc.
#                            * = Ignore this field

if ( time_cron('20 8 1 1 *') )    { speak "Notice: Please put the flag out." }
if ( time_cron('20 17 1 1 *') )   { speak "Notice: Please take the flag in." }
if ( time_cron('20 6 12 2 *') )   { speak "Notice: Please put the flag out." }
if ( time_cron('20 17 12 2 *') )  { speak "Notice: Please take the flag in." }
if ( time_cron('20 6 22 2 *') )   { speak "Notice: Please put the flag out." }
if ( time_cron('20 17 22 2 *') )  { speak "Notice: Please take the flag in." }
if ( time_cron('20 6 15 5 *') )   { speak "Notice: Please put the flag out." }
if ( time_cron('20 20 15 5 *') )  { speak "Notice: Please take the flag in." }
if ( time_cron('20 6 15 5 *') )   { speak "Notice: Please put the flag out." }
if ( time_cron('20 20 15 5 *') )  { speak "Notice: Please take the flag in." }
if ( time_cron('20 6 14 6 *') )   { speak "Notice: Please put the flag out." }
if ( time_cron('20 20 14 6 *') )  { speak "Notice: Please take the flag in." }
if ( time_cron('20 6 4 7 *') )    { speak "Notice: Please put the flag out." }
if ( time_cron('20 20 4 7 *') )   { speak "Notice: Please take the flag in." }
if ( time_cron('20 6 27 7 *') )   { speak "Notice: Please put the flag out." }
if ( time_cron('20 20 27 7 *') )  { speak "Notice: Please take the flag in." }
if ( time_cron('20 6 11 9 *') )   { speak "Notice: Please put the flag out." }
if ( time_cron('20 20 11 9 *') )  { speak "Notice: Please take the flag in." }
if ( time_cron('20 6 17 9 *') )   { speak "Notice: Please put the flag out." }
if ( time_cron('20 20 17 9 *') )  { speak "Notice: Please take the flag in." }
if ( time_cron('20 6 27 10 *') )  { speak "Notice: Please put the flag out." }
if ( time_cron('20 18 27 10 *') ) { speak "Notice: Please take the flag in." }
if ( time_cron('20 6 11 11 *') )  { speak "Notice: Please put the flag out." }
if ( time_cron('20 17 11 11 *') ) { speak "Notice: Please take the flag in." }
if ( time_cron('20 6 7 12 *') )   { speak "Notice: Please put the flag out." }
if ( time_cron('20 17 7 12 *') )  { speak "Notice: Please take the flag in." }
if ( time_cron('20 8 25 12 *') )  { speak "Notice: Please put the flag out." }
if ( time_cron('20 17 25 12 *') ) { speak "Notice: Please take the flag in." }

#                                                   Week 1 > 0 < 7
#                                                   Week 2 > 7 < 14
#                                                   Week 3 > 14 < 21
#                                                   Week 4 > 21 < 32

# First Week of the month Events
if ( $Day > 0 and $Day < 7 ) {
    if ( time_cron('20 6 * 9 1') )  { speak "Notice: Please put the flag out." }
    if ( time_cron('20 20 * 9 1') ) { speak "Notice: Please take the flag in." }
    if ( time_cron('20 6 * 11 2') ) { speak "Notice: Please put the flag out." }
    if ( time_cron('20 17 * 11 2') ) {
        speak "Notice: Please take the flag in.";
    }
}

# 2nd Week of the month Events
if ( $Day > 7 and $Day < 14 ) {
    if ( time_cron('20 6 * 5 0') )  { speak "Notice: Please put the flag out." }
    if ( time_cron('20 20 * 5 0') ) { speak "Notice: Please take the flag in." }
    if ( time_cron('20 6 * 10 1') ) { speak "Notice: Please put the flag out." }
    if ( time_cron('20 17 * 10 1') ) {
        speak "Notice: Please take the flag in.";
    }
}

# 3rd Week of the month Events
if ( $Day > 14 and $Day < 21 ) {
    if ( time_cron('20 6 * 4 1') )  { speak "Notice: Please put the flag out." }
    if ( time_cron('20 20 * 4 1') ) { speak "Notice: Please take the flag in." }
    if ( time_cron('20 6 * 5 6') )  { speak "Notice: Please put the flag out." }
    if ( time_cron('20 20 * 5 6') ) { speak "Notice: Please take the flag in." }
    if ( time_cron('20 6 * 6 0') )  { speak "Notice: Please put the flag out." }
    if ( time_cron('20 20 * 6 0') ) { speak "Notice: Please take the flag in." }
}

# 4th Week of the month Events
if ( $Day > 21 and $Day < 28 ) {
    if ( time_cron('20 6 * 11 4') ) { speak "Notice: Please put the flag out." }
    if ( time_cron('20 17 * 11 4') ) {
        speak "Notice: Please take the flag in.";
    }
}
