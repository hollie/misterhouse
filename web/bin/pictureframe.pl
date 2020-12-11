# pictureframe.pl
# by douglas j. nakakihara (doug@dougworld.com)
#
# This Perl script, used in conjunction with misc/pictureframe.shtml,
# will create an picture frame web page. It reads all of the
# files in the defined picture directory.
#
# Do not use filenames with spaces!
#
# Point to the web directory that has your pictures with this mh.ini parm:
#   pictureframe_dir = /pictures
#
# You may want this mh.ini parm to create a web pictures dirctory:
#   html_alias_pictures = /pictures  c:/pictures
#
# View with:
#   http://localhost:8080/misc/pictureframe.shtml
#
# The images are loaded as a page background in order to totally
# fill the screen. If you don't want the image to repeat (ie tile),
# you'll have to make all images the size of your screen (e.g.
# for Audrey, 640 x 480). Just fill in
# the empty areas with black. (I originally made a version
# that just displayed a standard image, but could not elimiate
# the borders. argh!)
#
# Audrey tips:
#
# If you press the Browser button while the browser is
# already visible, the menu will slide away! The maximum visible
# size is 640 x 480.
#
# Since Audrey's image display is not so great, you might want
# to use low JPEG compression. This will speed up image loading too.
#
# To keep Audrey from sleeping:
#
#   echo 0 > /config/SYSTEM_ScreenSaveSecs
#
#   You can just hit power button to turn off
#

my ( $html, @picnames );

my $webpath = $config_parms{pictureframe_dir};
my ($picdir) = &http_get_local_file($webpath);

# Open the directory and read files
opendir( DIR, $picdir ) or print "Error in opening $picdir\n";
for ( readdir(DIR) ) {
    next unless /.+\.(jpg|jpeg|gif|png)$/;
    s/ /%20/g;
    push @picnames, $_;
}

# Get random record
my $index = 1 + int( (@picnames) * rand );
my $showpic = $picnames[ $index - 1 ];

$config_parms{pictureframe_url} = '/ia5' unless $config_parms{pictureframe_url};

# Create image tag
return "
<body background='$webpath\/$showpic'>
<table><tr>
<td><a href='$config_parms{pictureframe_url}'>
<img src='/graphics/1pixel.gif' width='600' height='400' border=0></td>
</a>
";
