
@rem This is the dos version.  house is the unix version

@rem Use this run mh commands from a command prompt or other programs
@rem For example:
@rem    house speak hi there
@rem    house display c:\autoexec.bat
@rem    house Turn the backyard light on
@rem    house XAJAK


@rem Make sure xcmd_file matches with the mh.ini parm

@rem cmd_file=%TEMP%\house_cmd.txt
set xcmd_file=\temp\house_cmd.txt

@echo off
@rem Loop so we can have more than 9 arguments (not sure what happens after %9)
set pgmargs=
:getargs
set pgmargs=%pgmargs% %1
shift
if not '%1'=='' goto getargs

@echo on
echo %pgmargs% > %xcmd_file%



