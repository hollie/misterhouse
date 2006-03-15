@echo off
@rem Loop so we can have more than 9 arguments (not sure what happens after %9)
set pgmargs=
:getargs
set pgmargs=%pgmargs% %1
shift
if not '%1'=='' goto getargs

@mh -run get_tv_grid %pgmargs%
@rem perl -S get_tv_grid %1 %2 %3 %4 %5 %6 %7 %8 %9
