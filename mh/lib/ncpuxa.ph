# This file was created by running h2ph on cpuxa.h in the xalib distribution 

# 8/12/05 dnorwood, the following line doesn't work on windows and isn't needed anyway 
#require '_h2ph_pre.ph';

unless(defined(&CMD_DELAY)) {
    sub CMD_DELAY () {	50000;}
}
unless(defined(&MSG_DELAY)) {
    sub MSG_DELAY () {	750000;}
}
unless(defined(&CMD_TRIES)) {
    sub CMD_TRIES () {	10;}
}
unless(defined(&READ_TRIES_ACK)) {
    sub READ_TRIES_ACK () {	2;}
}
unless(defined(&READ_TRIES)) {
    sub READ_TRIES () {	8;}
}
unless(defined(&NUM_TIMERS)) {
    sub NUM_TIMERS () {	64;}
}
unless(defined(&NUM_VARIABLES)) {
    sub NUM_VARIABLES () {	64;}
}
unless(defined(&NUM_PARAMS)) {
    sub NUM_PARAMS () {	128;}
}
unless(defined(&NUM_MODULES)) {
    sub NUM_MODULES () {	128;}
}
unless(defined(&NUM_POINTS)) {
    sub NUM_POINTS () {	16;}
}
unless(defined(&NUM_TYPES)) {
    sub NUM_TYPES () {	6;}
}
unless(defined(&MSG_BUF)) {
    sub MSG_BUF () {	32;}
}
unless(defined(&LEN_DATA)) {
    sub LEN_DATA () {	256;}
}
unless(defined(&LEN_CMD)) {
    sub LEN_CMD () {	8;}
}
unless(defined(&LEN_CRC)) {
    sub LEN_CRC () {	2;}
}
unless(defined(&LEN_DATE)) {
    sub LEN_DATE () {	50;}
}
unless(defined(&LEN_MSG)) {
    sub LEN_MSG () {	32;}
}
unless(defined(&LEN_PAG)) {
    sub LEN_PAG () {	64;}
}
unless(defined(&LEN_X10)) {
    sub LEN_X10 () {	16;}
}
unless(defined(&LEN_BUF)) {
    sub LEN_BUF () {	( &LEN_DATA+ &LEN_CMD);}
}
unless(defined(&IR_CLOCK)) {
    sub IR_CLOCK () {	4560;}
}
unless(defined(&X10_ACTIONS)) {
    sub X10_ACTIONS () {	16;}
}
unless(defined(&IOSTATES)) {
    sub IOSTATES () {	2;}
}
unless(defined(&WEEKDAYS)) {
    sub WEEKDAYS () {	7;}
}
unless(defined(&u_char)) {
    eval 'sub u_char () {\'unsigned char\';}' unless defined(&u_char);
}
unless(defined(&u_int)) {
    eval 'sub u_int () {\'unsigned int\';}' unless defined(&u_int);
}
unless(defined(&u_short)) {
    eval 'sub u_short () {\'unsigned short\';}' unless defined(&u_short);
}
unless(defined(&u_long)) {
    eval 'sub u_long () {\'unsigned long\';}' unless defined(&u_long);
}
eval("sub XA_UNKNOWN () { 0; }") unless defined(&XA_UNKNOWN);
eval("sub XA_LEARN_IR () { 1; }") unless defined(&XA_LEARN_IR);
eval("sub XA_LOCAL_IR () { 2; }") unless defined(&XA_LOCAL_IR);
eval("sub XA_REMOTE_IR () { 3; }") unless defined(&XA_REMOTE_IR);
eval("sub XA_GET_IR () { 4; }") unless defined(&XA_GET_IR);
eval("sub XA_SET_IR () { 5; }") unless defined(&XA_SET_IR);
eval("sub XA_SET_VARIABLE () { 6; }") unless defined(&XA_SET_VARIABLE);
eval("sub XA_SET_TIMER () { 7; }") unless defined(&XA_SET_TIMER);
eval("sub XA_GET_VARIABLES () { 8; }") unless defined(&XA_GET_VARIABLES);
eval("sub XA_GET_TIMERS () { 9; }") unless defined(&XA_GET_TIMERS);
eval("sub XA_SET_CPUXA_PARAM () { 10; }") unless defined(&XA_SET_CPUXA_PARAM);
eval("sub XA_SET_UNIT_PARAM () { 11; }") unless defined(&XA_SET_UNIT_PARAM);
eval("sub XA_GET_MEMORY () { 12; }") unless defined(&XA_GET_MEMORY);
eval("sub XA_SET_MEMORY () { 13; }") unless defined(&XA_SET_MEMORY);
eval("sub XA_GET_CPUXA_PARAMS () { 14; }") unless defined(&XA_GET_CPUXA_PARAMS);
eval("sub XA_GET_UNIT_PARAMS () { 15; }") unless defined(&XA_GET_UNIT_PARAMS);
eval("sub XA_GET_TYPES () { 16; }") unless defined(&XA_GET_TYPES);
eval("sub XA_GET_VERSIONS () { 17; }") unless defined(&XA_GET_VERSIONS);
eval("sub XA_IO_LATCHED () { 18; }") unless defined(&XA_IO_LATCHED);
eval("sub XA_IO_REALTIME () { 19; }") unless defined(&XA_IO_REALTIME);
eval("sub XA_SET_RELAY () { 20; }") unless defined(&XA_SET_RELAY);
eval("sub XA_GET_RTC () { 21; }") unless defined(&XA_GET_RTC);
eval("sub XA_SET_RTC () { 22; }") unless defined(&XA_SET_RTC);
eval("sub XA_SEND_X10 () { 23; }") unless defined(&XA_SEND_X10);
eval("sub XA_GET_X10 () { 24; }") unless defined(&XA_GET_X10);
eval("sub XA_X10STATES () { 25; }") unless defined(&XA_X10STATES);
eval("sub XA_X10_LEVEL () { 26; }") unless defined(&XA_X10_LEVEL);
eval("sub XA_X10_GROUP () { 27; }") unless defined(&XA_X10_GROUP);
eval("sub XA_RESCAN () { 28; }") unless defined(&XA_RESCAN);
eval("sub XA_RESTART () { 29; }") unless defined(&XA_RESTART);
eval("sub XA_INTERP_STOP () { 30; }") unless defined(&XA_INTERP_STOP);
eval("sub XA_INTERP_START () { 31; }") unless defined(&XA_INTERP_START);
eval("sub XA_INTERP_LOAD () { 32; }") unless defined(&XA_INTERP_LOAD);
eval("sub XA_ASCII_LOAD () { 33; }") unless defined(&XA_ASCII_LOAD);
eval("sub XA_PAGER_LOAD () { 34; }") unless defined(&XA_PAGER_LOAD);
eval("sub XA_EPHEM_LOAD () { 35; }") unless defined(&XA_EPHEM_LOAD);
eval("sub XA_GET_ADDRS () { 36; }") unless defined(&XA_GET_ADDRS);
eval("sub XA_MONITOR () { 37; }") unless defined(&XA_MONITOR);
eval("sub XA_HANGUP () { 38; }") unless defined(&XA_HANGUP);
eval("sub SERVER_REFUSED () { 0; }") unless defined(&SERVER_REFUSED);
eval("sub SERVER_FULL () { 1; }") unless defined(&SERVER_FULL);
eval("sub SERVER_INTERP () { 2; }") unless defined(&SERVER_INTERP);
eval("sub SERVER_OK () { 3; }") unless defined(&SERVER_OK);
eval("sub ERR_NONE () { 0; }") unless defined(&ERR_NONE);
eval("sub ERR_ACK () { 1; }") unless defined(&ERR_ACK);
eval("sub ERR_DATA () { 2; }") unless defined(&ERR_DATA);
eval("sub ERR_CRC_RX () { 3; }") unless defined(&ERR_CRC_RX);
eval("sub ERR_CRC_TX () { 4; }") unless defined(&ERR_CRC_TX);
eval("sub ERR_WRITE () { 5; }") unless defined(&ERR_WRITE);
eval("sub ERR_NOCMD () { 6; }") unless defined(&ERR_NOCMD);
eval("sub ERR_SOCKREAD () { 7; }") unless defined(&ERR_SOCKREAD);
eval("sub ERR_SOCKWRITE () { 8; }") unless defined(&ERR_SOCKWRITE);
eval("sub ERR_SHUTDOWN () { 9; }") unless defined(&ERR_SHUTDOWN);
eval("sub ERR_UNKNOWN () { 10; }") unless defined(&ERR_UNKNOWN);
1;
