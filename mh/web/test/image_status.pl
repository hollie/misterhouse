
# Return an image file that reflects the current status

my $file = "$config_parms{html_dir}/graphics/$Save{mode}.jpg";

print "image_status.pl will return file=$file\n";

return &file_read($file);
