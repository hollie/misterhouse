
# Return a tagline (used in web/ia5/menu.shtml)

# Authority: anyone

@ARGV = "$config_parms{data_dir}/remarks/1100tags.txt";

my $tagline;
rand($.) < 1 && ($tagline=$_) while <>;

return $tagline;


