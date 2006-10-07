
@rem This is the dos version.  speak is the unix version

@echo off
@rem Loop so we can have more than 9 arguments (not sure what happens after %9)
set pgmargs=
:getargs
set pgmargs=%pgmargs% %1
shift
if not '%1'=='' goto getargs

@echo on
house speak  %pgmargs%
