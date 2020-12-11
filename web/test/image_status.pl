
# Return an image file that reflects the current status

my $file = "$config_parms{html_dir}/graphics/";

#$file .= "$Save{mode}.jpg";
if ( $Save{mode} eq 'normal' ) {
    $file .= 'funny_face.gif';
}
else {
    $file .= 'goofy.gif';
}

print "image_status.pl will return file=$file\n";

return &file_read($file);
