
my $member = shift;
my $file   = "$main::config_parms{html_root}/mh_brian/$member";

return &file_read($file);
