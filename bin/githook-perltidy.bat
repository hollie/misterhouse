
@echo off
set dir=%~p0
@rem Loop so we can have more than 9 arguments (not sure what happens after %9)
set pgmargs=
:getargs
set pgmargs=%pgmargs% %1
shift
if not '%1'=='' goto getargs

@echo on

perl -S "%dir%githook-perltidy" %pgmargs%