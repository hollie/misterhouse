@echo off

@rem Should not need to set this
@rem set perl5lib=\mh\lib;\mh\lib\site;\mh\bin

set pgmargs=
:getargs
set pgmargs=%pgmargs% %1
shift
if not '%1'=='' goto getargs

perl -S mh %pgmargs%
