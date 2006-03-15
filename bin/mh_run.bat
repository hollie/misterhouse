@echo off

@rem This calls mh to run mh bin scripts, so we can use the perl libs in the mh distro.
@rem Since it calls mh.bat, the compiled mh.exe will be used if found. 

@rem Loop so we can have more than 9 arguments (not sure what happens after %9)
set pgmargs=
:getargs
set pgmargs=%pgmargs% %1
shift
if not '%1'=='' goto getargs

@mh -run %pgmargs%

