
# Compiles mh to mhe on Windows using the Par compiler

echo Compiling ...
@rem echo off

cd \mh\bin

set myM=
set myM=%myM% -M Win32::OLE  -M Win32::Process -M Win32::PerfLib  -M File::DosGlob
set myM=%myM% -M DB_File -M DBI -M DBD::mysql -M DBD::Sponge -M Math::Trig -M Net::Ping -M Digest::HMAC_MD5
set myM=%myM% -M Tk::Text -M Tk::Menubutton -M Tk::Radiobutton -M Tk::JPEG -M Tk::CursorControl -M Tk::Checkbutton
set myM=%myM% -M Net:::Jabber::Protocol -M XML::Stream::Node -M Net::Jabber -M Net::Jabber::Client -M CGI
set myM=%myM% -M Time::localtime -M XML::RSS -M XML::Parser -M Crypt::SSLeay -M IPC::Open2 -M Encode
set myM=%myM% -M Getopt::Long -M Text::Wrap -M Win32::Console -M Win32::WinError -M Win32::Sound -M GD 
set myM=%myM% -M Win32::Registry -M Sys::Hostname -M Tk::BrowseEntry -M Tk::ProgressBar -M Tk::ToolBar

@rem set myM=%myM% -M Audio::Mixer  -M Term::ReadKey -M Text::PhraseDistance

set myL=
set myL=%myL% -l c:/perl/perl/bin/ssleay32.dll -l c:/perl/perl/bin/libeay32.dll
@rem set myL=%myL% -l c:/perl/perl/bin/libeay32.dll
@rem set myL=%myL% -l c:/perl580/site/lib/auto/Win32/OLE/OLE.dll
@rem set myL=%myL% -l c:/perl580/site/lib/auto/Win32/setupsup/setupsup.dll
@rem set myL=%myL% -l libdb.dll
@rem set myL=-l /misterhouse/upload/libdb.dll

@rem set PATH=c:\perl\perl\bin;%PATH%

del mhc.errata
call pp.bat -v 3 -i ..\web\favicon.ico -L mhc.errata %myM% %myL% -o mhen.exe  mh

echo done
house speak done with compile

echo To review: unzip -l mhe.exe | more
