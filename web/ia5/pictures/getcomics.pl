#!/usr/bin/perl
# This came from [http://www.waider.ie/hacks/snorq.pl], adapted it to run with mh's
# perl libs (change lib path below). You need to have netpbm installed. Ron Klinkien.

BEGIN {
    push( @INC, "/mh/lib", "/mh/lib/site" );
}

use LWP::UserAgent;
use URI::URL;
use Date::Parse;
use HTML::Filter;

my $doc;
my $base;
my %pages;

$pages{'dilbert'} = [
    'http://www.dilbert.com/comics/dilbert/archive/',
    'img.*?src="(/comics/dilbert/archive/images/dilbert\d+.gif)"'
];

#$pages{'bobbins'} =
#  [
#   'http://www.bobbins.org/',
#   'img.*?src="(/comics/\d+.*?\.(png|gif))"'
#  ];

#$pages {'goats'} =
#  [
#   'http://www.goats.com/',
#   'img src="(/comix/\d+/goats\d+\.gif)"'
#  ];

#$pages{'redmeat'} =
#  [
#   'http://www.redmeat.com/redmeat/fresh.html',
#   'img src="(index\-\d+.gif)"'
#  ];

#$pages {'jerkcity'} =
#  [
#   'http://www.jerkcity.com/',
#   'frame src="(jerkcity\d+.html)"',
#   'img src="(jerkcity\d+.gif)"'
#  ];

# ----------------------------- page layout, such as it is --------------------
my $compilation = <<"COMP";
<html><body>
<base target ="output">
<table width=100% bgcolor="lightgrey">
<td><center>
<font size=3 color="black"><b>
Daily Comics
</b></font></center>
</td>
</table><br>
<table cellSpacing=0 cellPadding=0 width="100%" border=0>
 <h1>Dilbert</h1>
 <!-- feed me dilbert -->
 <h1>Goats</h1>
 <!-- feed me goats -->
 <h1>Bobbins</h1>
 <!-- feed me bobbins -->
 <!-- feed me pix -->
</table>
</body>
</html>
COMP

# ------------------------------- end of setup --------------------------------

my $ua = new LWP::UserAgent;
$ua->agent( "Snorq/0.1" . $ua->agent );
my ( $req, $res );

for my $page ( sort keys %pages ) {
    if ( $#ARGV != -1 ) {
        next unless grep /$page/i, @ARGV;
    }
    print "$page\n";

    # Figure out what we're getting!
    my $content     = "";
    my $contenttype = "";
    my $numrules    = $#{ $pages{$page} };
    my $n           = -1;                    # gack
    my $url;

    RULE:
    for my $rule ( @{ $pages{$page} } ) {

        # increment rule number
        $n++;

        print "   rule ", $n + 1, " of ", $numrules + 1, " : $rule\n";

        if ( !$content ) {

            # First rule is always a URL
            $url = $rule;
        }
        else {
            ($url) = $content =~ m/$rule/mi;
            if ( !defined($url) ) {
                print "   error extracting $rule\n";
                $content = undef;
                last RULE;
            }
        }

        # Patch in base and stuff
        if ( defined $base ) {
            $uri = new URI::URL($url);

            # Gack! relative URL!
            if ( $uri->path !~ m|^/| ) {
                local $URI::ABS_ALLOW_RELATIVE_SCHEME = 1;    # gack gack
                $uri = URI->new($url)->abs($base);
            }

            if ( !defined( $uri->host ) ) {
                $uri->scheme( $base->scheme );
                $uri->host( $base->host );
            }

            $url = $uri->as_string;
        }

        print "   fetching $url\n";

        $cached = 0;

        # if this is the terminal rule, try a HEAD instead of a GET
        if ( $n == $numrules ) {
            $req = new HTTP::Request HEAD => $url;

            $res = $ua->request($req);

            if ( $res->is_success ) {
                my $utime;

                # See if we get a datestamp
                $date = $res->headers->header('Last-Modified');
                if ( defined($date) ) {
                    print "   Last Mod: $date\n";
                    $utime = str2time($date);
                }
                else {
                    $utime = 0;
                }
                $contenttype = $res->content_type;

                # And this is what we call a "hack"
                $filename = "${page}_$contenttype";
                $filename =~ s|/|.|g;

                if ( -f $filename ) {
                    (
                        undef, undef, undef,  undef, undef, undef, undef,
                        undef, undef, $mtime, undef, undef, undef
                    ) = stat($filename);
                    if ( $mtime > $utime ) {
                        $cached = 1;
                    }
                    else {
                        $cached = 0;
                    }
                }
            }
            else {
                print "   head failed, for some reason.\n";
            }
        }

        # Screw caching, since it seems not to work.
        $cached = 0;

        if ($cached) {
            print "   cached, not fetching\n";
        }
        else {
            $req = new HTTP::Request GET => $url;

            $res = $ua->request($req);

            if ( $res->is_success ) {
                $content     = $res->content;
                $contenttype = $res->content_type;

                # And this is what we call a "hack"
                $filename = "${page}_$contenttype";
                $filename =~ s|/|.|g;

                $base = $res->base;
            }
            else {
                print "   error fetching data\n";
                $page = $res->as_string;
                undef $content;
                last RULE;
            }
        }

        next if !defined($content);
        next if $n < $numrules;

        print
          "   Item $page, content type $contenttype successfully fetched.\n";

        # Now, filter the page.
        if ( defined( $filters{$page} ) ) {
            print "   filtering it: ";

            print "start...";
            my @filters = reverse @{ $filters{$page} };

            my $filter = pop @filters;
            $content =~ s/^.*?$filter//si;

            print "end...";
            $filter = pop @filters;
            $content =~ s/$filter.*?$//si;

            if ( $#filters != -1 ) {
                print "body...";

                while ( $#filters != -1 ) {
                    my $search  = pop @filters;
                    my $replace = pop @filters;

                    $content =~ s/$search/$replace/sgie;
                }
            }
            print "done.\n";
        }

    }

    # Don't bother doing more if we couldn't get the page
    next unless $content;

    # Fix up URLs
    if ( $contenttype =~ /^text\/html/i ) {
        print "   Repatching URLs to $base\n";
        $doc = "";
        my $parser = HTML::Parser->new(
            api_version => 3,
            start_h     => [ \&p_start, "tagname, text, attr" ],
            default_h   => [ sub { $doc .= shift }, "text" ]
        );
        $parser->parse($content);
        $parser->eof;
        $content = $doc;
    }

    # Save the damn thing
    open( PAGE, ">$filename" );
    print PAGE $content;
    close(PAGE);

    # Figure out the link type, and add it.
    if ( $contenttype =~ /^image/i ) {
        print "   Slicing image... [$page/$contenttype]";
        $new = carve_image( $page, $contenttype );
        unlink($filename);    # don't leave the old image lying around
        print "done.\n";

        # See if it's got a place of its own to go into.
        if ( !( $compilation =~ s|(<!-- feed me $page -->)|$new\n| ) ) {
            $compilation =~ s|(<!-- feed me pix -->)|$new\n$1|;
        }
    }
    else {
        my $srcurl = "";
        $srcurl = " (<a href=\"$url\">from $url</a>)<br>";
        $srcurl .= " ($date)" if $date;
        if (
            !(
                $compilation =~
                s|(<!-- feed me $page -->)|<a href="$filename">$page</a>$srcurl\n|
            )
          )
        {
            $compilation =~
              s|(<!-- feed me text -->)|<a href="$filename">$page</a>$srcurl\n$1|;
        }
    }
}

open( PAGE, ">main.html" );
print PAGE $compilation;
close(PAGE);

# This is ghastly, but noone seems to have a nice image processing
# module for Perl that I could use instead.
sub carve_image {
    my ( $name, $type ) = @_;
    my $html = "";

    my $filename = "${name}_$type";
    $filename =~ s|/|.|g;

    # Make directory FIXME nuke it if it exists
    mkdir $name, 0755 unless -d $name;

    # Convert to a pnm
    if ( $type eq "png" ) {
        `pngtopnm $filename > $name/$filename`;
    }
    else {
        `anytopnm $filename > $name/$filename`;
    }

    my $tijd = str2time($date);

    # Get dimensions (use Image::Info for this!)
    $pnmfile = `pnmfile $name/$filename`;
    ( $wide, $high ) = $pnmfile =~ m/:.*?,\s(\d+)\sby\s(\d+).*?/i;

    return qq( <pre>$pnmfile</pre>\n)
      if !defined($wide)
      or !defined($high);

    $html = qq(<table cellpadding="0" cellspacing="0" border="0">\n);

    for ( $y = 0; $y < $high; $y += 140 ) {
        if ( $y + 140 > $high ) {
            $h = $high - $y;
        }
        else {
            $h = 140;
        }

        $html .= "<tr>";

        for ( $x = 0; $x < $wide; $x += 150 ) {
            if ( $x + 150 > $wide ) {
                $w = $wide - $x;
            }
            else {
                $w = 150;
            }

            `pnmcut $x $y $w $h $name/$filename 2>/dev/null | ppmtogif 2>/dev/null > $name/$ {name}_$ {x}_$ {y}.gif`;
            $html .=
              qq(<td><img src="$name/$ {name}_$ {x}_$ {y}.gif" width="$w" height="$h"></td>);
        }
        $html .= "</tr>\n";
    }
    $html .= "</table>\n";

    # Cleanup
    unlink("$name/$filename");

    return $html;
}

sub patchurl {
    my $base = shift;
    my $url  = shift;

    my $uri = new URI $url;

    eval {
        if ( !defined( $uri->scheme ) or !$uri->scheme ) {
            $uri = new URI $url, ( $base->scheme || 'http' );   # what the hell?
        }

        # Gack! relative URL!
        if ( $uri->path !~ m|^/| ) {
            local $URI::ABS_ALLOW_RELATIVE_SCHEME = 1;          # gack gack
            $uri = URI->new($url)->abs($base);
        }

        if ( !defined( $uri->host ) ) {
            $uri->scheme( $base->scheme || 'http' );
            $uri->host( $base->host );
        }
    };

    $uri->scheme('http') unless $uri->scheme;    # thanks, slashdot

    return $url if $@;                           # bail out if there's an error.

    $uri->as_string;
}

sub p_start {
    my $tag = $_[1];
    if (   ( $_[0] eq "a" )
        || ( $_[0] eq "img" )
        || ( $_[0] eq "link" )
        || ( $_[0] eq "script" )
        || ( $_[0] eq "form" )
        || ( $_[0] eq "input" ) )
    {
        $tag = "<$_[0]";
        for my $a ( keys %{ $_[2] } ) {
            my $t = $_[2]->{$a};
            if ( $a =~ /^href|src|action$/i ) {
                $t = patchurl( $base, $t );
                $tag .= qq( $a="$t" );
            }
            else {
                $tag .= qq( $a="$t" );
            }
        }
        $tag =~ s/\s+$//;    # just in case
        $tag .= ">";
    }
    $doc .= $tag;
}
