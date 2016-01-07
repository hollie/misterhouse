# Category = Photos

#@ This code reads directories of photos to create an index which is
#@ used by web browsers working as picture frames.
#@
#@ Review and update the html_alias_photos and photo_* parameters in your
#@ private.ini file, and run the command 'Reindex the photo album'.  Then point
#@ your web browser to
#@ <a href="/bin/photos.pl">http://localhost:8080/bin/photos.pl</a>
#@ or <a href="/slideshow">http://localhost:8080/slideshow</a>.
#@ You can also use <a href="SUB;photo_html">this link</a> to set the
#@ photo_dirs parm to a specific dir.
#@ If you have a slow browser (like the Audrey) you will want to resize your
#@ photos so they display quickly.  See mh/bin/mh.ini for more information.

# Example mh.ini parms
#  html_alias_photos     = c:/pictures_small
#  html_alias_photos_big = c:/pictures_big
#  photo_dirs            = /photos
#  photo_big_dirs        = /photos_big
#  photo_index           = /misterhouse/data/photo_index.txt
#  photo_viewer          = /slideshow

=begin comment

You can use mh/bin/image_resize to resize and pad your photos to fit
your browser screen (e.g. 640x480 for Audrey). 
    
=cut

#noloop=start

use vars '@photos';    # This will be persistent across code reloads

$v_photo_reindex = new Voice_Cmd 'Reindex the photo album [,name,date,random]';
$v_photo_reindex->set_info(
    "Re-creates a photo index for all the photos under $config_parms{photo_dirs} that match $config_parms{photo_filter}"
);

# Resize new photos using image_resize
$v_photo_resize = new Voice_Cmd 'Resize new photo album pictures';
$v_photo_resize->set_info(
    "Re-sizes any new photos in the photo album directories");
$p_photo_resize = new Process_Item;

my @subdirs;
$photo_subdir = new Generic_Item;
set_casesensitive $photo_subdir;

# Add form to Photos page
# The include will take too long if there are lots of files/dirs, so use a link instead
$Included_HTML{Photos} .=
  '<br><a href="SUB;photo_html" target=control>Pick a photo subdirectory to index</a>'
  . "\n";

# Just a reference to $config_parms{photo_viewer} so it shows up in the code_select list

#noloop=stop
# Search for photos from console
&tk_entry( 'Photo Search', \$Save{photo_search} ) if $Reload;

if ( said $v_photo_reindex) {
    $v_photo_reindex->respond('app=photos Indexing photos...');
    &photo_index( $v_photo_reindex->{state} );
}

sub photo_index {
    my ($sequence) = @_;
    $sequence = $config_parms{photo_sequence} unless $sequence;
    print_log
      "Reading photos that match photo_filter parm $config_parms{photo_filter} from photo_dirs parm $config_parms{photo_dirs}";
    &read_parms;    # Re-read parms, if they have changes
    undef @photos;
    for my $dir ( split ',', $config_parms{photo_dirs} ) {
        &photo_dir($dir);
    }

    # Do a fisher yates shuffle (Perl cookbook 4.17 pg 121)
    if ( $sequence eq 'random' ) {
        for ( my $i = @photos; --$i; ) {
            my $j = int rand( $i + 1 );
            @photos[ $i, $j ] = @photos[ $j, $i ];
        }
    }
    elsif ( $sequence eq 'date' ) {
        @photos = sort {
            my ($a1) = ( stat $a )[9];
            my ($a2) = ( stat $b )[9];
            $a1 <=> $a2
        } @photos;
    }
    my $count = @photos;
    speak "Indexed $count photos";
    print_log "Read a list of $count photos, sorted by $sequence";
    file_write $config_parms{photo_index}, join "\n", @photos;
}

sub photo_dir {
    my ($dir) = @_;

    my ($realdir);
    ($realdir) = &http_get_local_file($dir);
    unless ($realdir) {
        print_log
          "can't find real directory associated with web directory $dir, skipping";
        return;
    }

    print_log "  - Listing files from $dir -> $realdir";
    opendir( DIR, $realdir ) or print "Error in opening $realdir\n";
    for ( readdir(DIR) ) {
        next if /^\.+$/;
        &photo_dir("$dir/$_") if -d "$realdir/$_";    # Recurse through subdirs
        next unless /.+\.(jpg|jpeg|gif|png)$/i;
        next
          if $config_parms{photo_filter}
          and $_ !~ /$config_parms{photo_filter}/i;
        push @photos, "$dir/$_";
    }
    close DIR;
}

if ( my $string = quotemeta $Tk_results{'Photo Search'} )
{    # *** This is very odd (?)
    undef $Tk_results{'Photo Search'};
    print_log "Searching for photos that match $string";
    my @match   = grep /$string/i, @photos;
    my $count   = @match;
    my $results = "Found $count matches";
    print_log $results;
    $results .= "\n" . join "\n", @match;
    display $results, 60, 'Photo Search Results', 'fixed' if @match;
}

if ( said $v_photo_resize) {
    $v_photo_resize->respond('app=photos Resizing photos...');
    my $next;
    my @bigs = split /\s*,\s*/, $config_parms{photo_big_dirs};
    foreach my $webdir ( split /\s*,\s*/, $config_parms{photo_dirs} ) {
        my ( $realdir, $realdir2, $originals );
        ($realdir) = &http_get_local_file($webdir);
        unless ($realdir) {
            print_log
              "can't find real directory associated with web directory $webdir, skipping";
            next;
        }
        $originals = $bigs[$next];
        unless ( $originals or $config_parms{photo_prefix} ) {
            print_log
              "can't find webdir where your originals are located for $webdir, skipping";
            next;
        }
        ($realdir2) = &http_get_local_file($originals);
        $realdir2 = "" if $realdir eq $realdir2;
        unless ( $realdir2 or $config_parms{photo_prefix} ) {
            print_log
              "can't find real directory associated with web directory $originals, skipping";
            next;
        }
        $config_parms{photo_size} =~ m/(\d+)[x|X](\d+)/;
        my $width  = $1;
        my $height = $2;
        my $cmd    = "image_resize --size ";
        $cmd .= $width . "x" . $height . " -d ";
        $cmd .=
          $realdir2
          ? "$realdir2 -outdir $realdir -P ''"
          : "$realdir -P '$config_parms{photo_prefix}'";
        print_log "resize command is '$cmd'";
        $next ? add $p_photo_resize $cmd : set $p_photo_resize $cmd;
        $next++;
    }
    print_log "No photo directories found to resize" unless $next;
    start $p_photo_resize if $next;
}

$v_photo_resize->respond('app=photos connected=0 Photo resizing done')
  if done_now $p_photo_resize;

# Add a small form to the Photos category page to pick a subdirectory to index
sub photo_html {
    my $dir = '/photos';

    # TODO, Add support for multiple subdirectories
    my $selected = ( split ',', $config_parms{photo_dirs} )[0] || $dir;

    @subdirs = ();
    &photo_subdirs( $dir, '' );
    return '' unless @subdirs > 1;
    my $html;

    # Create a form to pick which photo subdirectories to index
    $html .=
      '<table border><tr><form action="SET;referer" target=control><td>Pick which photo subdirectory to index'
      . "\n";
    $html .= &html_form_select( '$photo_subdir', 1, $selected, @subdirs )
      . "</td></form></tr></table>\n";
    return $html;
}

# Process form submit
if ( my $state = state_now $photo_subdir) {
    &write_mh_opts( { 'photo_dirs' => $state }, undef, 1 );
    &photo_index;
}

# Recurse through subdirectories
sub photo_subdirs {
    my ( $dir, $subdir ) = @_;
    my ($dir2) = &http_get_local_file($dir);
    push @subdirs, "$dir$subdir";
    return unless $dir2;
    opendir( DIR, "$dir2/$subdir" ) or print "Error in opening $dir2/$subdir\n";
    for ( sort readdir(DIR) ) {
        next if /^\.+$/;
        next unless -d "$dir2/$subdir/$_";
        print "Reading photo dir $subdir/$_\n";
        &photo_subdirs( $dir, "$subdir/$_" );    # Recurse through subdirs
    }
    close DIR;
}

