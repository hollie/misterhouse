# Category=Internet

#
# get the local shabbat times for the current week.
# v1.0 max kelly <mxd@wilder.net> 7/02
# updates probably live at http://www.wilder.net/mxd/projects
#
# bit kludgy. whatever.
#
# you've read the GPL, right? it applies.
#
# requires HTML::FormatText and HTML::Parse. but you probably would have guessed that soon.

use HTML::FormatText;
use HTML::Parse;

my $f_shabbat_txt  = "$config_parms{data_dir}/web/shabbat.txt";
my $f_shabbat_html = "$config_parms{data_dir}/web/shabbat.html";

$v_shabbat = new Voice_Cmd '[Get,Show,Read] shabbat';
$v_shabbat->set_info('shabbat shalom');
$v_shabbat->set_authority('anyone');

$state = said $v_shabbat;

# todo, only do on monday
if ( $state eq 'Get' or time_now('6:30 AM') ) {

    # i suppose you oculd change this here, if you wanted someone elses shabbat
    # otherwise, its yours from mh.ini
    my $myzip = $config_parms{zip_code};
    print_log "Getting shabbat time for $myzip";

    my $htmp = get "http://www.hebcal.com/shabbat/?zip=$myzip;m=72";

    #chop top
    $htmp =~ s/.*\-\-\>//s;
    file_write $f_shabbat_html, $htmp;

    my $html      = parse_htmlfile($f_shabbat_html);
    my $formatter = HTML::FormatText->new();
    my $ascii     = $formatter->format($html);

    # ascii now contains raw ascii version of the page.

    #chop bottom
    $ascii =~ s/(\>.*)//s;

    # convert spaces
    $ascii =~ s/\ {5}/\n/g;

    # fix linefeeds
    # this puts a period as teh first line. i like that.
    $ascii =~ s/\n+/\.\n/g;

    file_write $f_shabbat_txt, $ascii;
    display $f_shabbat_txt;
}

display $f_shabbat_txt if $state eq 'Show';
speak $f_shabbat_txt   if $state eq 'Read';

