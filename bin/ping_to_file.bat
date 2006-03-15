@rem Used in internet_connect_check.pl
@echo Pinging %1 to file %2
@ping -n 1 %1 > %2
