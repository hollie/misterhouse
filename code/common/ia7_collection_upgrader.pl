# Category = IA7

#@ IA7 v1.2 : This is a helper utility that can find and update collections.json files 
#@  if any structural changes are required.
#@
#@  v1.2 - add in new login system id 700

my $ia7_coll_current_ver = 1.2;

if ($Startup) {
	my $flag = 0;
	my $version = 0;
	if (-e "$Pgm_Root/data/web/ia7_collection_update") {
		$version = file_read("$Pgm_Root/data/web/ia7_collection_update");
		$flag = 1 if ($version < $ia7_coll_current_ver)
	} else {
		$flag = 1;
	}
	
	if ($flag) {
		my @collection_files = ("$Pgm_Root/data/web/collections.json",
        						"$config_parms{data_dir}/web/collections.json",
       							"$config_parms{ia7_data_dir}/collections.json");      							
       	for my $file (@collection_files) {
       		if (-e $file) {
       			print_log "[IA7_Collection_Updater] : Updating $file to version $ia7_coll_current_ver";
       			my $json_data;
       			my $file_data;
        		eval {
            		$file_data = file_read($file);
            		$json_data = decode_json($file_data);    #HP, wrap this in eval to prevent MH crashes
        		};
        
                if ($@) {
            		print_log "[IA7_Collection_Updater] : WARNING: decode_json failed for $file. Please check this file!";
        		} else {
        			if ($version < 1.2) { #IA7 v1.2 required change
        				$json_data->{700}->{user} = '$Authorized' unless (defined $json_data->{700}->{user});
        				my $found = 0;
        				foreach my $i (@{$json_data->{500}->{children}})	{
        					$found = 1 if ($i == 700);
        				}
        				push (@{$json_data->{500}->{children}},700) unless ($found);
        			}
        			my $json_newdata = to_json($json_data, {utf8 => 1, pretty => 1});
        			my $backup_file = $file . ".v" . $version . ".backup";
        			file_write($backup_file,$file_data);
          			print_log "[IA7_Collection_Updater] : Saved backup " . $file . ".v" . $version . ".backup";     			
        			file_write($file,$json_newdata);
        		}
        	}
        }
    file_write("$Pgm_Root/data/web/ia7_collection_update",$ia7_coll_current_ver);
  
    }
}