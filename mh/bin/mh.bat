@echo off

@rem This is a dos mh loop for restarting mh if mh had an unexpected exit.
@rem This will call mh.exe (if it exists) or 'perl mh' otherwise.
@rem It checks exit codes so it can loop if a non-requested exit occured
@rem Note:  This must be run from the mh\bin directory

@rem Gather up arguments into one var
set pgmargs=
set noloop=0
:GETARGS
set pgmargs=%pgmargs% %1
if '%1' == '-run' set noloop=1
shift
if not '%1' == '' goto GETARGS
if %noloop% == 1  goto START

:RERUN
@rem This file will be created if mh starts normally (i.e. does not die on startup)
if exist mh.started del mh.started

:START
if EXIST mh.exe goto COMPILED

echo Starting interpreted perl mh
perl -S mh %pgmargs%
@rem This test means exit=1 (normal exit) and not > 1
if errorlevel 1 if not errorlevel 2 goto DONE
@rem This only works from nt/2k/4dos
@rem if %errorlevel% == 1 goto DONE
if %noloop%     == 1 goto DONE
goto FAIL

:COMPILED
echo Starting compiled mh.exe
mh.exe %pgmargs%
if errorlevel 1 if not errorlevel 2 goto DONE
if %noloop%     == 1 goto DONE

:FAIL

if not EXIST mh.started goto DONE2

echo. | date >> mh_restart.log
echo accidental exit on mh, restarting ... >> mh_restart.log
echo accidental exit on mh, restarting ...
@rem sleep 5
goto RERUN

:DONE2
echo mh had an error on startup, will not restart

:DONE
@rem echo User exit of mh completed

