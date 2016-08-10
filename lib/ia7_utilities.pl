package ia7_utilities;
use strict;
use Data::Dumper;

sub main::ia7_update_schedule {
	my ($object,@schedules) = @_;
	
	&main::print_log("updating Schedule for object $object");
	my $obj = &main::get_object_by_name($object);
	&main::print_log (Data::Dumper->Dump($obj->get_schedule));
	&main::print_log (join('|',@schedules));
}


if ($main::Startup) {

	my $ia7_coll_current_ver = 1.2;

	my @collection_files = ("$Pgm_Root/data/web/collections.json",
        					"$config_parms{data_dir}/web/collections.json",
       						"$config_parms{ia7_data_dir}/collections.json");      							
    for my $file (@collection_files) {
       	if (-e $file) {
       		&main::print_log("[IA7_Collection_Updater] : Checking $file to current version $ia7_coll_current_ver");
       		my $json_data;
       		my $file_data;
        	eval {
            	$file_data = &main::file_read($file);
            	$json_data = decode_json($file_data);    #HP, wrap this in eval to prevent MH crashes
        	};
        
            if ($@) {
            	&main::print_log("[IA7_Collection_Updater] : WARNING: decode_json failed for $file. Please check this file!");
        	} else {
 				my $updated = 0;
 				      		
        		if ((! defined $json_data->{meta}->{version}) or ($json_data->{meta}->{version} < 1.2)) { #IA7 v1.2 required change
        			$json_data->{700}->{user} = '$Authorized' unless (defined $json_data->{700}->{user});
        			my $found = 0;
        			foreach my $i (@{$json_data->{500}->{children}})	{
        				$found = 1 if ($i == 700);
        			}
        			push (@{$json_data->{500}->{children}},700) unless ($found);
        			$json_data->{meta}->{version} = "1.2";
       				&main::print_log("[IA7_Collection_Updater] : Updating $file to version 1.2");
       				$updated = 1; 			
        		}
        		if ($updated) {
        			my $json_newdata = to_json($json_data, {utf8 => 1, pretty => 1});
        			my $backup_file = $file . ".t" . int( ::get_tickcount() / 1000 ) . ".backup";
        			&main::file_write($backup_file,$file_data);
          			&main::print_log("[IA7_Collection_Updater] : Saved backup " . $file . ".t" . int( ::get_tickcount() / 1000 ) . ".backup");     			
        			&main::file_write($file,$json_newdata);
        		}
        	}
        }
    }  
}

1;