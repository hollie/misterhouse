# Category = Entertainment

#@ This code reads directories of photos to create an index which is 
#@ used by web browsers working as picture frames.
#@
#@ Review and update the photo_* parameters in your mh.private.ini 
#@ file, then run the command 'Reindex the photo album'.  Then point 
#@ your web browser to
#@  
#@  http://localhost:8080/bin/photos.pl


# Example mh.ini parms
#  html_alias_photos     = c:/pictures_small
#  html_alias_photos_dad = c:/pictures_small/dad/Slides
#  photo_dirs   = /photos,/photos_dad
#  photo_index  = /misterhouse/data/photo_index.txt


=begin comment

You can use mh/bin/image_resize to resize and pad your photos to fit
your browser screen (e.g. 640x480 for Audrey). 
    
=cut

use vars '@photos';             # This will be persistent across passes and code reloads

  
$photo_reindex = new Voice_Cmd 'Reindex the photo album [,name,date,random]';
$photo_reindex->set_info("Re-creates a photo index for all the photos under $config_parms{photo_dirs} that match $config_parms{photo_filter}");

&photo_index($temp) if $temp = said $photo_reindex;

sub photo_index {
    my ($sequence) = @_;
    $sequence = $config_parms{photo_sequence} unless $sequence;

    print_log "Reading photos that match photo_filer parm $config_parms{photo_filter} from photo_dirs parm $config_parms{photo_dirs}";
    &read_parms;                # Re-read parms, if they have changes
    undef @photos;
    for my $dir (split ',', $config_parms{photo_dirs}) {
        &photo_dir($dir);
    }
    
                                # Do a fisher yates shuffle (Perl cookbook 4.17 pg 121)
    if ($sequence eq 'random') {
        for (my $i = @photos; --$i; ) {
            my $j = int rand($i + 1);
            @photos[$i, $j] = @photos[$j, $i];
        }
    }
    elsif ($sequence eq 'date') {
        @photos = sort {my ($a1) = (stat $a)[9]; my ($a2) = (stat $b)[9];  $a1 <=> $a2} @photos;
    }
    print_log "Read a list of " . scalar(@photos) . " photos, sorted by $sequence";
    file_write $config_parms{photo_index}, join "\n", @photos;
}

sub photo_dir {
    my ($dir) = @_;
    my ($dir2) = &http_get_local_file($dir);
    print "  - Listing files from $dir -> $dir2\n";
    opendir(DIR, $dir2) or print "Error in opening $dir2\n";
    for (readdir(DIR)) {
        next if /^\.+$/;
        &photo_dir("$dir/$_") if -d "$dir2/$_"; # Recurse through subdirs
        next unless /.+\.(jpg|jpeg|gif|png)$/i;
        next if $config_parms{photo_filter} and $_ !~ /$config_parms{photo_filter}/i;
        push @photos, "$dir/$_";
    }
    close DIR;
}


                                # Search for strings in user code
#&tk_entry('Photo Search', \$Save{photo_search});

if (my $string = quotemeta $Tk_results{'Photo Search'}) {
    undef $Tk_results{'Photo Search'};
    print "Searching for photos that match $string";
    my @match = grep /$string/i, @photos;
    my $count = @match;
    my $results = "Found $count matches";
    print_log $results;
    $results .= "\n" . join "\n", @match;
    display $results, 60, 'Photo Search Results', 'fixed' if @match;
}

                                # Resize new photos using image_resize
$photo_resize  = new Voice_Cmd 'Resize new photo album pictures';
$photo_resize  ->set_info("Re-sizes any new photos in the photo album directories");
$photo_resizep = new Process_Item '/pictures/resize_images.bat';
start $photo_resizep if said $photo_resize;
speak 'Photo resizing done' if done_now $photo_resizep;

# My resize_images.bat file has entries like this:
#   call image_resize -r 0 -p sm2 --size 800x600 -d school
#   call image_resize -r 0 -p sm2 --size 800x600 -d home


