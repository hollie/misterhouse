package ia7_utilities;
use strict;
use JSON qw(decode_json to_json);

sub main::ia7_update_schedule {
    my ( $object, @schedules ) = @_;

    &main::print_log( "Updating Schedule for object $object, schedule size is " . scalar(@schedules) );

    my $obj = &main::get_object_by_name($object);
    my $s   = 0;
    my $index;
    my @curr_schedule = $obj->get_schedule;
    $obj->reset_schedule();
    for ( my $i = 1; $i <= ( scalar(@schedules) / 3 ); $i++ ) {
        my $jqCron = $schedules[ $i * 3 - 2 ];

        #jqCron uses 1-7 for Sat - Sunday, MH uses 0-6, so shift all the numbers
        &main::print_log(
            "Adding Schedule (id=" . $schedules[ $i * 3 - 3 ] . " cron=" . $schedules[ $i * 3 - 2 ] . " label=" . $schedules[ $i * 3 - 1 ] . ")" );
        $obj->set_schedule( $schedules[ $i * 3 - 3 ], $schedules[ $i * 3 - 2 ], $schedules[ $i * 3 - 1 ] );
    }
}

sub ia7_update_collection {
    &main::print_log("[IA7_Collection_Updater] : Starting");
    my $ia7_coll_current_ver = 1.2;

    my @collection_files = (
        "$main::Pgm_Root/data/web/collections.json",
        "$main::config_parms{data_dir}/web/collections.json",
        "$main::config_parms{ia7_data_dir}/collections.json"
    );
    for my $file (@collection_files) {
        if ( -e $file ) {
            &main::print_log("[IA7_Collection_Updater] : Reviewing $file to current version $ia7_coll_current_ver");
            my $json_data;
            my $file_data;
            eval {
                $file_data = &main::file_read($file);
                $json_data = decode_json($file_data);    #HP, wrap this in eval to prevent MH crashes
            };

            if ($@) {
                &main::print_log("[IA7_Collection_Updater] : WARNING: decode_json failed for $file. Please check this file!");
            }
            else {
                my $updated = 0;

                if (   ( !defined $json_data->{meta}->{version} )
                    or ( $json_data->{meta}->{version} < 1.2 ) )
                {                                        #IA7 v1.2 required change
                    $json_data->{700}->{user} = '$Authorized'
                      unless ( defined $json_data->{700}->{user} );
                    my $found = 0;
                    foreach my $i ( @{ $json_data->{500}->{children} } ) {
                        $found = 1 if ( $i == 700 );
                    }
                    push( @{ $json_data->{500}->{children} }, 700 )
                      unless ($found);
                    $json_data->{meta}->{version} = "1.2";
                    &main::print_log("[IA7_Collection_Updater] : Updating $file to version 1.2");
                    $updated = 1;
                }
                if ($updated) {
                    my $json_newdata = to_json( $json_data, { utf8 => 1, pretty => 1 } );
                    my $backup_file = $file . ".t" . int( ::get_tickcount() / 1000 ) . ".backup";
                    &main::file_write( $backup_file, $file_data );
                    &main::print_log( "[IA7_Collection_Updater] : Saved backup " . $file . ".t" . int( ::get_tickcount() / 1000 ) . ".backup" );
                    &main::file_write( $file, $json_newdata );
                }
            }
        }
    }
    &main::print_log("[IA7_Collection_Updater] : Finished");
}

1;
