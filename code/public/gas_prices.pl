#Category=News

# gas_prices.pl
# Author: Dan Hoffard
# Gets and reads the lowest gas prices in the western Fort Worth, TX area.
# Easily modifiable for other areas
# Based on news_starnews

my $f_gas_summary = "$config_parms{data_dir}/web/gas_summary.txt";
my $f_gas_html    = "$config_parms{data_dir}/web/gas.html";

# 1. Go to GasBuddy.com and execute a search for your area
# 2. Replace the URL below with the generated URL for your search
# 3. Change $v_gas to your desired voice command

my $Gas_URL =
  'http://www.fortworthgasprices.com/index.aspx?s=Y\&fuel=A\&area=Fort%20Worth%20-%20West\&tme_limit=84';

$p_gas = new Process_Item("perl get_url  $Gas_URL $f_gas_html");
$v_gas =
  new Voice_Cmd('[Get,Read,Show] the Lowest West Fort Worth Gas Stations');

speak($f_gas_summary) if said $v_gas eq 'Read';

display($f_gas_summary) if said $v_gas eq 'Show';

if ( said $v_gas eq 'Get' or $New_Hour ) {

    if (&net_connect_check) {

        print_log "Retrieving gas prices from the net ...";

        # Use start instead of run so we can detect when it is done
        start $p_gas;
    }
}

# Because of my limited parsing skills, this is somewhat of a kludge
# You will more than likely need to change the gas station names
# or better yet, make it smarter!

if ( done_now $p_gas) {

    my ( $summary, $i );

    for ( file_read "$f_gas_html" ) {

        # Set the 9 below to (the number of stations to report * 3)
        if ( $i < 9 ) {
            if (/\'\>2.(.+)\<\/a\>\<\/td\>/) {
                $i++;
                $summary .= "\$2.$1 ";
            }
            elsif (/\'\>1.(.+)\<\/a\>\<\/td\>/) {
                $i++;
                $summary .= "\$1.$1 ";
            }
            elsif (/\'\>3.(.+)\<\/a\>\<\/td\>/) {
                $i++;
                $summary .= "\$3.$1 ";
            }
            elsif (/\'\>4.(.+)\<\/a\>\<\/td\>/) {
                $i++;
                $summary .= "\$4.$1 ";
            }
            elsif (/\'\>0.(.+)\<\/a\>\<\/td\>/) {
                $i++;
                $summary .= "\$0.$1 ";
            }
            elsif (/					Albertsons/) {
                $i++;
                $summary .= "Albertsons at ";
            }
            elsif (/					Diamond Shamrock/) {
                $i++;
                $summary .= " Diamond Shamrock at ";
            }
            elsif (/					Citgo/) {
                $i++;
                $summary .= "Citgo at ";
            }
            elsif (/					Diamond Shamrock/) {
                $i++;
                $summary .= "Diamond Shamrock at ";
            }
            elsif (/					FinaServe/) {
                $i++;
                $summary .= "FinaServe at ";
            }
            elsif (/					Sams Club/) {
                $i++;
                $summary .= "Sams Club at ";
            }
            elsif (/					crows/) {
                $i++;
                $summary .= "crows at ";
            }
            elsif (/					bee zee \(texaco\)/) {
                $i++;
                $summary .= "bee zee (texaco) at ";
            }
            elsif (/					Conoco/) {
                $i++;
                $summary .= "Conoco at ";
            }
            elsif (/					highway oil/) {
                $i++;
                $summary .= "highway oil at ";
            }
            elsif (/					Chevron/) {
                $i++;
                $summary .= "Chevron at ";
            }
            elsif (/colspan\=\"2\"\>(.+)\<\/td\>/) {
                $i++;
                $summary .= "$1.\n";
            }
        }
    }
    file_write "$f_gas_summary", $summary;
}

