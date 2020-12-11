#
# List recent images in a given dir.  Pick images 10 minutes apart.
#
# Call like this:  http://localhost:8080/bin/list_images.pl?/web/motion
# or this from an .shtml file:  <!--#include file="/bin/list_images.pl?/web/motion" -->
#

my ($url) = @ARGV;

my ($dir) = &http_get_local_file($url);

#print "db u=$url d=$dir\n";

my ( %file_data, $html, $i );

opendir DIR, $dir or print "list_images.pl: Could not open dir for $dir: $!\n";
for my $file ( readdir DIR ) {
    next unless $file =~ /jpg$/i;
    ( $file_data{$file}{date} ) = ( stat("$dir/$file") )[9];
}
close DIR;

my %files_picked;
for my $file (
    sort { $file_data{$b}{date} <=> $file_data{$a}{date} }
    keys %file_data
  )
{
    my ($root) = $file =~ /(\S+?)_/;
    if (  !$files_picked{$root}
        or $files_picked{$root} > ( $file_data{$file}{date} + 60 * 10 ) )
    {
        $files_picked{$root} = $file_data{$file}{date};

        #	print "r=$root f=$file d=$file_data{$file}{date}\n";
        $html .= qq|<img src="$url/$file">\n|;
        last if ++$i >= 12;
    }
}

return &html_page( 'Recent Images', $html );

