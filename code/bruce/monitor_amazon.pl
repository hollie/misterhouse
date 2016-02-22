
# Category = Informational

#@ This one is for Laurie ... monitors the sales rank of her book at Amazon

$check_book_rank = new Voice_Cmd 'Check sales rank at Amazon';
$check_book_rank->set_info("Check how Laurie's Growing Wings book is selling");

#run_voice_cmd 'Check sales rank at Amazon' if time_cron '05 9,13,17,21 * * *';

if ( said $check_book_rank) {
    print_log "Retreiving data ...";
    my $url =
      'http://www.amazon.com/exec/obidos/ASIN/0618074058/o/qid%3D966011699/sr%3D8-1/ref%3Daps%5Fsr%5Fb%5F1%5F3/107-7654888-8042158';
    my $html = get $url;
    if ( $html =~ /Sales Rank:.+?([\d\,]+)/si ) {
        my $rank = round $1, 100;    # Round to nearest 100
        speak "Laurie, Amazon sales rank is $rank";
        logit "$config_parms{data_dir}/laurie_book_amazon.log", $rank;
    }
    else {
        speak "rooms=all Laurie, Amazon sales rank data not found";
    }
}

#<b>Amazon.com Sales Rank: </b>
#9,472
#</font><br>

