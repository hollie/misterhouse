@echo off

@rem This is a dos mh loop for restarting mh if mh had an unexpected exit.
@rem This will call mhe.exe (if it exists) or 'perl mh' otherwise.
@rem It checks exit codes so it can loop if a non-requested exit occured
@rem Note:  This must be run from the mh\bin directory

@rem Gather up arguments into one var. to pass to mhe.exe or mh.pl file
@rem  shift drops first arg off and moves arg 2 to arg 1, arg 3 to arg 2
@rem  etc, on each pass of the loop until there are not more args,
@rem  then program continues from START

@rem CD into bin directory (where this script lives) so the mh.startup
@rem  file will be deleted correctly by mh when exiting normally.  
@rem  mh will only unlink the mh.startup file if it is in bin. This is
@rem  consistent with mhl on linux
cd %~p0


set pgmargs=
set noloop=0
:GETARGS
set pgmargs=%pgmargs% %1
if '%1' == '-run' set noloop=1
shift
if not '%1' == '' goto GETARGS
if %noloop% == 1  goto START

:RERUN
@rem This file will be deleted if mh starts normally (i.e. does not die on startup)
@rem if exist mh.started del mh.started
echo mh will delete on startup > mh.startup

:START
if EXIST mhe.exe goto COMPILED

echo Starting interpreted perl mh
perl -S mh %pgmargs%
@rem This test means exit=1 (normal exit) and not > 1
if errorlevel 1 if not errorlevel 2 goto DONE
@rem This only works from nt/2k/4dos
@rem if %errorlevel% == 1 goto DONE
if %noloop%     == 1 goto DONE
goto FAIL

:COMPILED
echo Starting compiled mhe.exe
mhe.exe %pgmargs%
if errorlevel 1 if not errorlevel 2 goto DONE
if %noloop%     == 1 goto DONE

:FAIL

@rem not EXIST mh.started goto DONE2
if       EXIST mh.startup goto DONE2

echo. | date >> mh_restart.log
echo accidental exit on mh, restarting ... >> mh_restart.log
echo accidental exit on mh, restarting ...
@rem sleep 5
goto RERUN

:DONE2
echo mh had an error on startup, will not restart

:DONE
@rem echo User exit of mh completed

