print "Starting mh_perl2exe_list.pl ...";

# We need to include this in the perl2exe compile list until it can recognize eval "use module";

# Note: use lib really messes up perl2exe ... see sent note to Indy dated 11/14/98
#  - my_lib.pm is an copy of lib.pm.  Don't ask me why perl2exe has problems with lib.mh and not my_lib.pm!
# This means code called from mh (e.g. get_tv_grid) must use my_lib instead of lib till this is fixed :(

# Naw, lets use  "eval 'use lib...'" instead

use CGI;    # Used in mh/web/organizer scripts
use GD;     # Used by web on-the-fly buttons

#use lib;
use lib '.';

#use my_lib;

use Tk;
use Tk::Entry;          # Needed for perl2exe
use Tk::Event;          # Needed for perl2exe
use Tk::Button;         # Needed for perl2exe
use Tk::Radiobutton;    # Needed for perl2exe
use Tk::Text;           # Needed for perl2exe
use Tk::Scrollbar;      # Needed for perl2exe
use Tk::Menubutton;     # Needed for perl2exe
use Tk::Checkbutton;    # Needed for perl2exe
use Tk::Listbox;        # Needed for perl2exe
use Tk::Photo;          # Needed for perl2exe
use Tk::JPEG;           # Needed for perl2exe

use Math::Trig;         # Used in internet_earthquakes.pl
use Net::DNS::Resolver; # Needed find_domain_name

use Net::AIM;
use Net::Jabber;
use Net::Jabber::Client;
use Net::SNPP;
use XML::XPath::XMLParser;    # Used by read_xml_A
use XML::Stream;              # Used by Jabber
use XML::Stream::Hash;        # Used by Jabber
use File::Spec;               # Used by Jabber
use File::Spec::Unix;         # Used by Jabber
use File::Spec::Win32;        # Used by Jabber

# Note: 'use lib' will causes us not to find AddScroolbars, even with the following!
#use Tk::AddScrollbars; # Needed for perl2exe
#use Tk::Scrollbars;	# Needed for perl2exe

use Win32;         # So we can call extentions like shutdown
use Win32::API;    # To keep perl2exe happy
use Win32::Console;

#se Win32::DUN;		# Interface to rasdial
use Win32::DriveInfo;    # For disk space free/total
use Win32::OLE;

#se Win32::OLE::lite;
use Win32::Process;
use Win32::PerfLib;
use Win32::Setupsup
  qw(WaitForAnyWindow SendKeys EnumChildWindows SetFocus SetWindowText GetWindowText);

#use Win32::Setupsup;    # For sending keystrokes
use Win32::Sound;        # So we can play wave files
use Win32::SoundEx;      # So we can play wave files
use Win32::Registry;

use Win32::SerialPort;     # To keep perl2exe happy
use Device::SerialPort;    # To keep perl2exe happy
use Geo::WeatherNOAA;      # Used from get_weather call

#use Text::Wrap;              # Used in GEO::weather

use DB_File;

use File::DosGlob;
use re;                    # Used by File::Copy File::Basename

use URI::URL::http;        # Used by get_url
use MIME::Lite;            # Used by get_tv_grid, etc
use HTML::Parse;           # Used by get_tv_grid, etc
use HTTP::Cookies;         # Used by get_tv_grid, etc
use HTTP::Request::Common; # Used by get_tv_grid, etc

use Display;

# These are new with 5.6
#use File::Glob;

print " done\n";

1;
