@echo off
@rem Gather up arguments into one var
set pgmargs=
:GETARGS
set pgmargs=%pgmargs% %1
shift
if not '%1' == '' goto GETARGS

perl -S backup_data %pgmargs%

