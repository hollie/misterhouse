@echo off

@rem This is a dos mh loop for restarting mh if mh had an unexpected exit
@rem If you want to use it, call it in the same way you would call mh.
@rem This will call mh.exe (if it exists) or 'perl mh'
@rem It checks exit codes so it can loop if a non-requested exit occured
@rem Note:  must be run from the mh\bin directory

@rem Should not need to set this
@rem set perl5lib=\mh\lib;\mh\lib\site;\mh\bin

@rem Gather up arguments into one var
set pgmargs=
:getargs
set pgmargs=%pgmargs% %1
shift
if not '%1'=='' goto getargs

:RERUN

@rem This file will be created if mh starts normally (i.e. does not die on startup)
del mh.started

if EXIST mh.exe goto COMPILED

echo Starting interpreted perl mh
perl -S mh %pgmargs%
if errorlevel 0 if not errorlevel 2 goto DONE
goto FAIL

:COMPILED
echo Starting compiled mh.exe
mh.exe %pgmargs%
if errorlevel 1 if not errorlevel 2 goto DONE

:FAIL

if not EXIST mh.started goto DONE2

echo 0 | date >> mh_restart.log
echo accidental exit on mh, restarting ... >> mh_restart.log
echo accidental exit on mh, restarting ...
@rem sleep 5
goto RERUN

:DONE2
echo mh had an error on startup, will not restart

:DONE
echo User exit of mh completed

