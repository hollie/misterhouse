
# Return a tagline (used in web/ia5/menu.shtml)

# Authority: anyone

if ( -e "$config_parms{data_dir}/remarks/1100tags.txt" ) {
    @ARGV = "$config_parms{data_dir}/remarks/1100tags.txt";
}
else {
    @ARGV = "$Pgm_Root/data/remarks/1100tags.txt";
}

my $tagline;
rand($.) < 1 && ( $tagline = $_ ) while <>;

return $tagline;

