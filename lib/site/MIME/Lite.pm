package MIME::Lite;


=head1 NAME

MIME::Lite - low-calorie MIME generator


=head1 SYNOPSIS

    use MIME::Lite;
   
Create a single-part message:

    # Create a new single-part message, to send a GIF file:
    $msg = new MIME::Lite 
                From     =>'me@myhost.com',
                To       =>'you@yourhost.com',
                Cc       =>'some@other.com, some@more.com',
                Subject  =>'Helloooooo, nurse!',
                Type     =>'image/gif',
                Encoding =>'base64',
                Path     =>'hellonurse.gif';
    

Create a multipart message (i.e., one with attachments):

    # Create a new multipart message:
    $msg = new MIME::Lite 
                From    =>'me@myhost.com',
                To      =>'you@yourhost.com',
                Cc      =>'some@other.com, some@more.com',
                Subject =>'A message with 2 parts...',
                Type    =>'multipart/mixed';
    
    # Add parts (each "attach" has same arguments as "new"):
    attach $msg 
                Type     =>'TEXT',   
                Data     =>"Here's the GIF file you wanted";  
    attach $msg 
                Type     =>'image/gif',
                Path     =>'aaa000123.gif',
                Filename =>'logo.gif';


Output a message:

    # Format as a string:
    $str = $msg->as_string;
    
    # Print to a filehandle (say, a "sendmail" stream):
    $msg->print(\*SENDMAIL);


Send a message:

    # Send in the "best" way (the default is to use "sendmail"):
    $msg->send;
      


=head1 DESCRIPTION

In the never-ending quest for great taste with fewer calories,
we proudly present: I<MIME::Lite>.  

MIME::Lite is intended as a simple, standalone module for generating
(not parsing!) MIME messages... specifically, it allows you to
output a simple, decent single- or multi-part message with text or binary
attachments.  It does not require that you have the Mail:: or MIME::
modules installed.

You can specify each message part as either the literal data itself (in
a scalar or array), or as a string which can be given to open() to get
a readable filehandle (e.g., "<filename" or "somecommand|").

You don't need to worry about encoding your message data:
this module will do that for you.  It handles the 5 standard MIME encodings.

If you need more sophisticated behavior, please get the MIME-tools
package instead.  I will be more likely to add stuff to that toolkit
over this one.


=head1 MORE EXAMPLES

Create a multipart message exactly as above, but using the 
"attach to singlepart" hack:

    # Create a new multipart message:
    $msg = new MIME::Lite 
                From    =>'me@myhost.com',
                To      =>'you@yourhost.com',
                Cc      =>'some@other.com, some@more.com',
                Subject =>'A message with 2 parts...',
                Type    =>'TEXT',
                Data    =>"Here's the GIF file you wanted";  
    
    # Attach a part:
    attach $msg Type     =>'image/gif',
                Path     =>'aaa000123.gif',
                Filename =>'logo.gif';


Output a message to a filehandle:

    # Write it to a filehandle:
    $msg->print(\*STDOUT); 
     
    # Write just the header:
    $msg->print_header(\*STDOUT); 
     
    # Write just the encoded body:
    $msg->print_body(\*STDOUT); 


Get a message as a string:

    # Get entire message as a string:
    $str = $msg->as_string;
     
    # Get just the header:
    $str = $msg->header_as_string;
     
    # Get just the encoded body:
    $str = $msg->body_as_string;


Change how messages are sent:

    # Do something like this in your 'main':
    if ($I_DONT_HAVE_SENDMAIL) {
       MIME::Lite->send('smtp', "smtp.myisp.net", Timeout=>60);
    }
     
    # Now this will do the right thing:
    $msg->send;         # will now use Net::SMTP as shown above



=head1 PUBLIC INTERFACE

=cut


use Carp;
use FileHandle;

use strict;
use vars qw($VERSION $QUIET $PARANOID $VANILLA);



#==============================
#==============================
#
# GLOBALS, EXTERNAL/CONFIGURATION...

# The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision$, 10;

# Don't warn me about dangerous activities:
$QUIET = undef;

# Set this true if you don't want to use MIME::Base64/MIME::QuotedPrint:
$PARANOID = 0;

# Unsupported (for tester use): don't qualify boundary with time/pid:
$VANILLA = 0;


#==============================
#==============================
#
# GLOBALS, INTERNAL...

# Our sending facilities:
my $Sender     = "sendmail";
my %SenderArgs = (
    "sendmail" => ["/usr/lib/sendmail -t -oi -oem"],
    "smtp"     => [],
    "sub"      => [],
);

# Boundary counter:
my $BCount = 0;

# Known Mail/MIME fields... these, plus some general forms like 
# "x-*", are recognized by build():
my %KnownField = map {$_=>1} 
qw(
   bcc         cc          comments      date          encrypted 
   from        keywords    message-id    mime-version  organization
   received    references  reply-to      return-path   sender        
   subject     to
   );

# What external packages do we use for encoding?
my @Uses;


#==============================
#==============================
#
# PRIVATE UTILITY FUNCTIONS...

#------------------------------ 
#
# fold STRING
#
# Make STRING safe as a field value.  Remove leading/trailing whitespace,
# and make sure newlines are represented as newline+space

sub fold {
    my $str = shift;
    $str =~ s/^\s*|\s*$//g;    # trim
    $str =~ s/\n/\n /g;      
    $str;
}

#------------------------------
#
# gen_boundary
#
# Generate a new boundary to use.
# The unsupported $VANILLA is for test purposes only.

sub gen_boundary {
    return ("_----------=_".($VANILLA ? '' : int(time).$$).$BCount++);
}

#------------------------------
#
# known_field FIELDNAME
#
# Is this a recognized Mail/MIME field?

sub known_field {
    my $field = lc(shift);
    $KnownField{$field} or ($field =~ m{^(content|resent|x)-.});
}

#------------------------------
#
# is_mime_field FIELDNAME
#
# Is this a field I manage?

sub is_mime_field {
    $_[0] =~ /^(mime\-|content\-)/i;
}


#==============================
#==============================
#
# PRIVATE ENCODING FUNCTIONS...

#------------------------------
#
# encode_base64 STRING
#
# Encode the given string using BASE64.
# Unless paranoid, we try to load the real code before supplying our own.

if (!$PARANOID and eval "require MIME::Base64") {
    import MIME::Base64 qw(encode_base64);
    push @Uses, "B$MIME::Base64::VERSION";
}
else {
    eval q{
sub encode_base64 {
    my $res = "";
    my $eol = "\n";

    pos($_[0]) = 0;        # thanks, Andreas!
    while ($_[0] =~ /(.{1,45})/gs) {
	$res .= substr(pack('u', $1), 1);
	chop($res);
    }
    $res =~ tr|` -_|AA-Za-z0-9+/|;

    # Fix padding at the end:
    my $padding = (3 - length($_[0]) % 3) % 3;
    $res =~ s/.{$padding}$/'=' x $padding/e if $padding;

    # Break encoded string into lines of no more than 76 characters each:
    $res =~ s/(.{1,76})/$1$eol/g if (length $eol);
    return $res;
} # sub
  } # q
} #if

#------------------------------
#
# encode_qp STRING
#
# Encode the given string, LINE BY LINE, using QUOTED-PRINTABLE.
# Stolen from MIME::QuotedPrint by Gisle Aas, with a slight bug fix: we
# break lines earlier.  Notice that this seems not to work unless
# encoding line by line.
#
# Unless paranoid, we try to load the real code before supplying our own.

if (!$PARANOID and eval "require MIME::QuotedPrint") {
    import MIME::QuotedPrint qw(encode_qp);
    push @Uses, "Q$MIME::QuotedPrint::VERSION";
}
else {
    eval q{
sub encode_qp {
    my $res = shift;
    $res =~ s/([^ \t\n!-<>-~])/sprintf("=%02X", ord($1))/eg;  # rule #2,#3
    $res =~ s/([ \t]+)$/
      join('', map { sprintf("=%02X", ord($_)) }
	           split('', $1)
      )/egm;                        # rule #3 (encode whitespace at eol)

    # rule #5 (lines shorter than 76 chars, but can't break =XX escapes:
    my $brokenlines = "";
    $brokenlines .= "$1=\n" while $res =~ s/^(.{70}([^=]{2})?)//; # 70 was 74
    $brokenlines =~ s/=\n$// unless length $res; 
    "$brokenlines$res";
} # sub
  } # q
} #if

#------------------------------
#
# encode_8bit STRING
#
# Encode the given string using 8BIT.
# This breaks long lines into shorter ones.

sub encode_8bit {
    my $str = shift;
    $str =~ s/^.{990}/$&\n/mg;
    $str;
}

#------------------------------
#
# encode_7bit STRING
#
# Encode the given string using 7BIT.
# This NO LONGER protects people through encoding.

sub encode_7bit {
    my $str = shift;
    $str =~ s/[\x80-\xFF]//eg; 
    $str =~ s/^.{990}/$&\n/mg;
    $str;
}

#==============================
#==============================

=head2 Construction

=over 4

=cut


#------------------------------

=item new [PARAMHASH]

I<Class method, constructor.>
Create a new message object.  

If any arguments are given, they are passed into C<build()>; otherwise,
just the empty object is created.

=cut

sub new {
    my $class = shift;

    # Create basic object:
    my $self = {
	Attrs => {},
	Header => [],    # message header
	Parts => [],     # array of parts
    };    
    bless $self, $class;

    # Build, if needed:
    return (@_ ? $self->build(@_) : $self);
}


#------------------------------

=item attach [OBJECT|PARAMHASH]

I<Instance method.>
Add a new part to this message, and return the new part.

You can attach a MIME::Lite OBJECT, or have it create one by specifying
a PARAMHASH that will be automatically given to C<new()>.

One of the possibly-quite-useful hacks thrown into this is the 
"attach-to-singlepart" hack: if you attempt to attach a part (let's
call it "part 1") to a message that I<isn't> a multipart message
(the "self" object in this case), the following happens:

=over 4

=item *

A new part (call it "part 0") is made.

=item *

The MIME attributes and data (but I<not> the other headers)
are cut from the "self" message, and pasted into "part 0".

=item *

The "self" is turned into a "multipart/mixed" message.

=item *

The new "part 0" is added to the "self", and I<then> "part 1" is added.

=back

One of the nice side-effects is that you can create a text message
and then add zero or more attachments to it, much in the same way
that a user agent like Netscape allows you to do.

=cut

sub attach {
    my $self = shift;

    # Create new part, if necessary:
    my $part1 = ((@_ == 1) ? shift : ref($self)->new(Top=>0, @_));

    # Do the "attach-to-singlepart" hack:
    if ($self->attr('content-type') !~ m{^multipart/}i) {

	# Create part zero:
	my $part0 = ref($self)->new;

	# Cut MIME stuff from self, and paste into part zero: 
	foreach (qw(Attrs Data Path FH)) {
	    $part0->{$_} = $self->{$_}; delete($self->{$_});
	}
	$part0->top_level(0);    # clear top-level attributes

	# Make self a top-level multipart:
	$self->{Attrs} ||= {};   # reset       
	$self->attr('content-type'              => 'multipart/mixed');
	$self->attr('content-type.boundary'     => gen_boundary());
	$self->attr('content-transfer-encoding' => '7bit');
	$self->top_level(1);     # activate top-level attributes

	# Add part 0:
	push @{$self->{Parts}}, $part0;
    }

    # Add the new part:
    push @{$self->{Parts}}, $part1;
    $part1;
}

#------------------------------

=item build [PARAMHASH]

I<Class/instance method, initiallizer.>
Create (or initiallize) a MIME message object.  
Normally, you'll use the following keys in PARAMHASH:

   * Data, FH, or Path      (either one of these, or none if multipart)
   * Type                   (e.g., "image/jpeg")
   * From, To, and Subject  (if this is the "top level" of a message)

The PARAMHASH can contain the following keys:

=over 4

=item (fieldname)

Any field you want placed in the message header, taken from the
standard list of header fields (you don't need to worry about case):

    Bcc           Encrypted     Received      Sender         
    Cc            From          References    Subject 
    Comments	  Keywords      Reply-To      To 
    Content-*	  Message-ID    Resent-*      X-*
    Date          MIME-Version  Return-Path   
                  Organization

To give experienced users some veto power, these fields will be set 
I<after> the ones I set... so be careful: I<don't set any MIME fields>
(like C<Content-type>) unless you know what you're doing!

To specify a fieldname that's I<not> in the above list, even one that's
identical to an option below, just give it with a trailing C<":">,
like C<"My-field:">.  When in doubt, that I<always> signals a mail 
field (and it sort of looks like one too).

=item Data

I<Alternative to "Path" or "FH".>
The actual message data.  This may be a scalar or a ref to an array of
strings; if the latter, the message consists of a simple concatenation 
of all the strings in the array.

=item Disposition

I<Optional.>
The content disposition, C<"inline"> or C<"attachment">.
The default is C<"inline">.

=item Encoding

I<Optional.>
The content transfer encoding that should be used to encode your data.  
The default is C<"binary">, which means "no encoding": this is generally
I<not> suitable for sending anything but ASCII text files with short
lines, so consider using one of the following values instead:

   Use encoding:     If your message contains:
   ------------------------------------------------------------
   7bit              Only 7-bit text, all lines <1000 characters
   8bit              8-bit text, all lines <1000 characters
   quoted-printable  8-bit text or long lines (MUCH more reliable than "8bit")
   base64            Largely binary data: a GIF, a tar file, etc.

Be sure to pick an appropriate encoding.  In the case of "7bit"/"8bit",
long lines are automatically chopped to legal length; in the case of "7bit", 
all 8-bit characters are automatically I<removed>.  This may not be
what you want, so pick your encoding well!
There's a L<"A MIME PRIMER"> in this document with more info.

=item FH

I<Alternative to "Data" or "Path".>
Filehandle containing the data, opened for reading.
See "ReadNow" also.

=item Filename

I<Optional.>
The name of the attachment.  You can use this to supply a filename
if the one in the Path is inadequate, or if you're using the Data argument.

=item Length

I<Optional.>
Set the content length explicitly.  Normally, this header is automatically
computed, but only under certain circumstances (see L<"Limitations">).

=item Path

I<Alternative to "Data" or "FH".>
Path to a file containing the data... actually, it can be any open()able
expression.  If it looks like a path, the last element will automatically 
be treated as the filename. 
See "ReadNow" also.

=item ReadNow

I<Optional, for use with "Path".>
If true, will open the path and slurp the contents into core now.
This is useful if the Path points to a command and you don't want 
to run the command over and over if outputting the message several
times.  B<Fatal exception> raised if the open fails.

=item Top

I<Optional.>
If defined, indicates whether or not this is a "top-level" MIME message.
The parts of a multipart message are I<not> top-level.
Default is true.

=item Type

I<Optional.>
The MIME content type, or one of these special values (case-sensitive):

     "TEXT"   means "text/plain"
     "BINARY" means "application/octet-stream"

The default is C<"TEXT">.

=back

A picture being worth 1000 words (which
is of course 2000 bytes, so it's probably more of an "icon" than a "picture",
but I digress...), here are some examples:

    $msg = build MIME::Lite 
               From     => 'yelling@inter.com',
               To       => 'stocking@fish.net',
               Subject  => "Hi there!",
               Type     => 'TEXT',
               Encoding => '7bit',
               Data     => "Just a quick note to say hi!";
 
    $msg = build MIME::Lite 
               From     => 'dorothy@emerald-city.oz',
               To       => 'gesundheit@edu.edu.edu',
               Subject  => "A gif for U"
               Type     => 'image/gif',
               Path     => "/home/httpd/logo.gif";
 
    $msg = build MIME::Lite 
               From     => 'laughing@all.of.us',
               To       => 'scarlett@fiddle.dee.de',
               Subject  => "A gzipp'ed tar file",
               Type     => 'x-gzip',
               Path     => "gzip < /usr/inc/somefile.tar |",
               ReadNow  => 1,
               Filename => "somefile.tgz";

To show you what's really going on, that last example could also 
have been written:

    $msg = new MIME::Lite;
    
    $msg->build(Type     => 'x-gzip',
                Path     => "gzip < /usr/inc/somefile.tar |",
                ReadNow  => 1,
                Filename => "somefile.tgz");
    
    $msg->add(From    => "laughing@all.of.us");
    $msg->add(To      => "scarlett@fiddle.dee.de");
    $msg->add(Subject => "A gzipp'ed tar file");  

=cut

sub build {
    my $self = shift;
    my %params = @_;
    my @params = @_;
    my $key;

    # Miko's note: reorganized to check for exactly one of Data, Path, or FH
    (defined($params{Data})+defined($params{Path})+defined($params{FH}) <= 1)
	or croak "supply exactly zero or one of (Data|Path|FH).\n";

    # Create new instance, if necessary:
    ref($self) or $self = $self->new;


    ### CONTENT-TYPE....
    ###

    # Get content-type:
    my $type = ($params{Type} || 'TEXT');
    ($type eq 'TEXT')   and $type = 'text/plain';
    ($type eq 'BINARY') and $type = 'application/octet-stream';
    $type = lc($type);
    $self->attr('content-type' => $type);
   
    # Get some basic attributes from the content type:
    my $is_multipart = ($type =~ m{^(multipart)/}i);

    # Add in the multipart boundary:
    if ($is_multipart) {
	my $boundary = gen_boundary();
	$self->attr('content-type.boundary' => $boundary);
    }


    ### DATA OR PATH...
    ###    Note that we must do this *after* we get the content type, 
    ###    in case read_now() is invoked, since it needs the binmode().

    # Get data, as...
    # ...either literal data:
    if (defined($params{Data})) {
	$self->data($params{Data});
    }
    # ...or a path to data:
    elsif (defined($params{Path})) {
	$self->path($params{Path});       # also sets filename
	$self->read_now if $params{ReadNow};
    }
    # ...or a filehandle to data:
    # Miko's note: this part works much like the path routine just above,
    elsif (defined($params{FH})) {
	$self->fh($params{FH});
	$self->read_now if $params{ReadNow};  # implement later
    }
    

    ### FILENAME... (added by Ian Smith <ian@safeway.dircon.co.uk> on 8/4/97)
    ###    Need this to make sure the filename is added.  The Filename
    ###    attribute is ignored, otherwise.
    if (defined($params{Filename})) {
	$self->filename($params{Filename});
    }
  

    ### CONTENT-TRANSFER-ENCODING...
    ###

    # Get it:
    my $enc = $params{Encoding} || 'binary';      # explicit value wins
    $self->attr('content-transfer-encoding' => lc($enc));
	
    # Sanity check:
    if ($type =~ m{^(multipart|message)/}) {
	($enc =~ m{^(7bit|8bit|binary)\Z}) or 
	    croak "illegal MIME: can't have encoding $enc with type $type!";
    }

    ### CONTENT-DISPOSITION...
    ###    Default is inline for single, none for multis:
    ###
    my $disp = ($params{Disposition} or ($is_multipart ? undef : 'inline'));
    $self->attr('content-disposition' => $disp);

    ### CONTENT-LENGTH...
    ###
    my $length;
    if (exists($params{Length})) {   # given by caller:
	$self->attr('content-length' => $params{Length});
    }
    else {                           # compute it ourselves
	$self->get_length;
    }

    
    # Init the top-level fields:
    $self->top_level(defined($params{Top}) ? $params{Top} : 1);

    # Set message headers:
    my @paramz = @params;
    my $field;
    while (@paramz) {
	my ($tag, $value) = (shift(@paramz), shift(@paramz));

	# Get tag, if a tag:
	if ($tag =~ /^\-/) {       # old style, backwards-compatibility
	    $field = lc($');
	}
	elsif ($tag =~ /:$/) {     # new style
	    $field = lc($`);
	}
	elsif (known_field($field = lc($tag))) {   # known field
	    # no-op
	}
	else {                     # not a field:
	    next;
	}
	
	# Add it:
	$self->add($field, $value);
    }

    # Done!
    $self;
}

=back

=cut


#==============================
#==============================

=head2 Setting/getting headers and attributes

=over 4

=cut

#------------------------------
#
# top_level ONOFF
#
# Set/unset the top-level attributes and headers.
# This affects "MIME-Version" and "X-Mailer".

sub top_level {
    my ($self, $onoff) = @_;	
    if ($onoff) {
	$self->attr('MIME-Version' => '1.0');
	my $uses = (@Uses ? ("(" . join("; ", @Uses) . ")") : '');
	$self->replace('X-Mailer' => "MIME::Lite $VERSION $uses")
	    unless $VANILLA;
    }
    else {
	$self->attr('MIME-Version' => undef);
	$self->delete('X-Mailer');
    }
}

#------------------------------

=item add TAG,VALUE

Add field TAG with the given VALUE to the end of the header. 
The TAG will be converted to all-lowercase, and the VALUE 
will be made "safe" (returns will be given a trailing space).

B<Beware:> any MIME fields you "add" will override any MIME
attributes I have when it comes time to output those fields.
Normally, you will use this method to add I<non-MIME> fields:

    $msg->add("Subject" => "Hi there!");

Giving VALUE an arrayref will cause all those values to be added:

    $msg->add("Received" => ["here", "there", "everywhere"]

I<Note:> add() is probably going to be more efficient than C<replace()>,
so you're better off using it for most applications.

I<Note:> the name comes from Mail::Header.

=cut

sub add {
    my $self = shift;
    my $tag = lc(shift);
    my $value = shift;

    # If a dangerous option, warn them:
    carp "Explicitly setting a MIME header field ($tag) is dangerous:\n".
	 "use the attr() method instead.\n"
	if (is_mime_field($tag) && !$QUIET);

    # Get array of clean values:
    my @vals = ref($value) ? @{$value} : ($value);
    map { s/\n/\n /g } @vals;

    # Add them:
    foreach (@vals) {
	push @{$self->{Header}}, [$tag, $_];
    }
}

#------------------------------

=item attr ATTR,[VALUE]

Set MIME attribute ATTR to the string VALUE.  
ATTR is converted to all-lowercase.
This method is normally used to set/get MIME attributes:

    $msg->attr("content-type"         => "text/html");
    $msg->attr("content-type.charset" => "US-ASCII");
    $msg->attr("content-type.name"    => "homepage.html");

This would cause the final output to look something like this:

    Content-type: text/html; charset=US-ASCII; name="homepage.html"

Note that the special empty sub-field tag indicates the anonymous 
first sub-field.

Giving VALUE as undefined will cause the contents of the named
subfield to be deleted.

Supplying no VALUE argument just returns the attribute's value:

    $type = $msg->attr("content-type");        # returns "text/html"
    $name = $msg->attr("content-type.name");   # returns "homepage.html"

=cut

sub attr {
    my ($self, $attr, $value) = @_;
    $attr = lc($attr);

    # Break attribute name up:
    my ($tag, $subtag) = split /\./, $attr;
    defined($subtag) or $subtag = '';

    # Set or get?
    if (@_ > 2) {   # set:
	$self->{Attrs}{$tag} ||= {};            # force hash
	delete $self->{Attrs}{$tag}{$subtag};   # delete first
	if (defined($value)) {                  # set...
	    $value =~ s/[\r\n]//g;                   # make clean
	    $self->{Attrs}{$tag}{$subtag} = $value;
	}
    }
	
    # Return current value:
    $self->{Attrs}{$tag}{$subtag};
}

#------------------------------

=item delete TAG

Delete field TAG with the given VALUE to the end of the header.  
The TAG will be converted to all-lowercase.

    $msg->delete("Subject");

I<Note:> the name comes from Mail::Header.

=cut

sub delete {
    my $self = shift;
    my $tag = lc(shift);

    # Delete from the header:
    my $hdr = [];
    my $field;
    foreach $field (@{$self->{Header}}) {
	push @$hdr, $field if ($field->[0] ne $tag);
    }
    $self->{Header} = $hdr;
    $self;
}

#------------------------------

=item fields

Return the full header for the object, as a ref to an array
of C<[TAG, VALUE]> pairs.

Any fields that the user has explicitly set will override the
corresponding MIME fields that we would generate.  So: I<don't> say:

    $msg->set("Content-type" => "text/html; charset=US-ASCII");

unless you I<mean it>!

I<Note:> I called this "fields" because the header() method of
Mail::Header returns something different, but similar enough to 
be confusing.

=cut

sub fields {
    my $self = shift;
    my @fields;
    
    # Get a lookup-hash of all *explicitly-given* fields:
    my %explicit = map { $_->[0] => 1 } @{$self->{Header}};
    
    # Start with any MIME attributes not given explicitly:
    my $tag;
    foreach $tag (sort keys %{$self->{Attrs}}) {	

	# Skip if explicit:
	next if ($explicit{$tag});         

	# Skip if no subtags:
	my @subtags = keys %{$self->{Attrs}{$tag}}; 
	@subtags or next;

	# Create string:
	my $value;
	defined($value = $self->{Attrs}{$tag}{''}) or next; # need default tag!
	foreach (sort @subtags) {
	    next if ($_ eq '');
	    $value .= qq{; $_="$self->{Attrs}{$tag}{$_}"};
	}
	
	# Add to running fields;
	push @fields, [$tag, $value];
    }
    
    # Add remaining fields (note that we duplicate the array for safety):
    foreach (@{$self->{Header}}) {
	push @fields, [@{$_}];
    }

    # Done!
    return \@fields;
}

#------------------------------

=item filename [FILENAME]

Set the filename which this data will be reported as.
This actually sets both "standard" attributes.

With no argument, returns the filename as dictated by the 
content-disposition.

=cut

sub filename {
    my ($self, $filename) = @_;
    if (@_ > 1) {
	$self->attr('content-type.name' => $filename);
	$self->attr('content-disposition.filename' => $filename);
    }
    $self->attr('content-disposition.filename');
}

#------------------------------

=item get TAG,[INDEX]

Get the contents of field TAG, which might have been set 
with set() or replace().  Returns the text of the field.

    $ml->get('Subject', 0);

If the optional 0-based INDEX is given, then we return the INDEX'th
occurence of field TAG.  Otherwise, we look at the context:
In a scalar context, only the first (0th) occurence of the 
field is returned; in an array context, I<all> occurences are returned.  

I<Warning:> this should only be used with non-MIME fields.
Behavior with MIME fields is TBD, and will raise an exception for now.

=cut

sub get {
    my ($self, $tag, $index) = @_;
    $tag = lc($tag); 
    croak "get: can't be used with MIME fields\n" if is_mime_field($tag);
    
    my @all = map { ($_->[0] eq $tag) ? $_->[1] : ()} @{$self->{Header}};
    (defined($index) ? $all[$index] : (wantarray ? @all : $all[0]));
}

#------------------------------

=item get_length

Recompute the content length for the message I<if the process is trivial>, 
setting the "content-length" attribute as a side-effect:

    $msg->get_length;

Returns the length, or undefined if not set.

I<Note:> the content length can be difficult to compute, since it 
involves assembling the entire encoded body and taking the length
of it (which, in the case of multipart messages, means freezing
all the sub-parts, etc.).  

This method only sets the content length to a defined value if the
message is a singlepart with C<"binary"> encoding, I<and> the body is
available either in-core or as a simple file.  Otherwise, the content
length is set to the undefined value.

Since content-length is not a standard MIME field anyway (that's right, kids:
it's not in the MIME RFCs, it's an HTTP thing), this seems pretty fair.

=cut

#----
# Miko's note: I wasn't quite sure how to handle this, so I waited to hear 
# what you think.  Given that the content-length isn't always required, 
# and given the performance cost of calculating it from a file handle,
# I thought it might make more sense to add some some sort of computelength 
# property. If computelength is false, then the length simply isn't 
# computed.  What do you think?
#
# Eryq's reply:  I agree; for now, we can silently leave out the content-type.

sub get_length {
    my $self = shift;

    my $is_multipart = ($self->attr('content-type') =~ m{^multipart/}i);
    my $enc = lc($self->attr('content-transfer-encoding') || 'binary');
    my $length;
    if (!$is_multipart && ($enc eq "binary")){  # might figure it out cheap:
	if    (defined($self->{Data})) {               # it's in core
	    $length = length($self->{Data});
	}
	elsif (defined($self->{FH})) {                 # it's in a filehandle
	    # no-op: it's expensive, so don't bother
	}
	elsif (-e $self->{Path}) {                     # it's a simple file!
	    $length = (-s $self->{Path});
	}
    }
    $self->attr('content-length' => $length);
    return $length;
}

#------------------------------

=item replace TAG,VALUE

Delete all occurences of fields named TAG, and add a new
field with the given VALUE.  TAG is converted to all-lowercase.

B<Beware:> any MIME fields you "replace" will override any MIME
attributes I have when it comes time to output those fields.
Normally, you will use this method to set I<non-MIME> fields:

    $msg->replace("Subject" => "Hi there!");

Giving VALUE as undefined will simply cause the contents of the named
field to be deleted.  Giving VALUE as an arrayref will cause all the values
in the array to be added.

I<Note:> the name comes from Mail::Header.

=cut

sub replace {
    my ($self, $tag, $value) = @_;
    $self->delete($tag);
    $self->add($tag, $value) if defined($value);
}

=back

=cut


#==============================
#==============================

=head2 Setting/getting message data

=over 4

=cut

#------------------------------

=item binmode [OVERRIDE]

With no argument, returns whether or not it thinks that the data 
(as given by the "Path" argument of C<build()>) should be read using 
binmode() (for example, when C<read_now()> is invoked).

The default behavior is that any content type other than 
C<text/*> or C<message/*> is binmode'd; this should in general work fine.

With a defined argument, this method sets an explicit "override"
value.  An undefined argument unsets the override.
The new current value is returned.

=cut

sub binmode {
    my $self = shift;
    $self->{Binmode} = shift if (@_);       # argument? set override
    return (defined($self->{Binmode}) 
	    ? $self->{Binmode}
	    : ($self->attr("content-type") !~ m{^(text|message)/}i));
}

#------------------------------

=item data [DATA]

Get/set the literal DATA of the message.  The DATA may be
either a scalar, or a reference to an array of scalars (which
will simply be joined).    

I<Warning:> setting the data causes the "content-length" attribute
to be recomputed (possibly to nothing).

=cut

sub data {
    my $self = shift;
    if (@_) {
	$self->{Data} = ((ref($_[0]) eq 'ARRAY') ? join('', @{$_[0]}) : $_[0]);
	$self->get_length;
    }
    $self->{Data};
}


#------------------------------

=item path [PATH]

Get/set the PATH to the message data.

I<Warning:> setting the path recomputes any existing "content-length" field,
and re-sets the "filename" (to the last element of the path if it
looks like a simple path, and to nothing if not).

=cut

sub path {
    my $self = shift;
    if (@_) {

	# Set the path, and invalidate the content length:
	$self->{Path} = shift;

	# Re-set filename, extracting it from path if possible:
	my $filename;
	if ($self->{Path} and ($self->{Path} !~ /\|$/)) {  # non-shell path:
	    ($filename = $self->{Path}) =~ s/^<//;    
	    ($filename) = ($filename =~ m{([^\/]+)\Z});
	}
	$self->filename($filename);

	# Reset the length:
	$self->get_length;
    }
    $self->{Path};
}

#------------------------------

=item fh [FILEHANDLE]

Get/set the FILEHANDLE which contains the message data.

Takes a filehandle as an input and stores it in the object.
This routine is similar to path(); one important difference is that 
no attempt is made to set the content length.  

=cut

sub fh {
    my $self = shift;
    $self->{FH} = shift if @_;
    $self->{FH};
}

#------------------------------

=item resetfh [FILEHANDLE]

Set the current position of the filehandle back to the beginning. 
Only applies if you used "FH" in build() or attach() for this message.

Returns false if unable to reset the filehandle (since not all filehandles
are seekable).

=cut

#----
# Miko's note: With the Data and Path, the same data could theoretically 
# be reused.  However, file handles need to be reset to be reused, 
# so I added this routine.
#
# Eryq reply: beware... not all filehandles are seekable (think about STDIN)!

sub resetfh {
    my $self = shift;
    seek($self->{FH},0,0);
}

#------------------------------

=item read_now 

Forces data from the path/filehandle (as specified by C<build()>)
to be read into core immediately, just as though you had given it
literally with the C<Data> keyword.  

Note that the in-core data will always be used if available.

Be aware that everything is slurped into a giant scalar: you may not want 
to use this if sending tar files!  The benefit of I<not> reading in the data 
is that very large files can be handled by this module if left on disk
until the message is output via C<print()> or C<print_body()>.

=cut

sub read_now {
    my $self = shift;
    local $/ = undef;
    
    if    ($self->{FH}) {       # data from a filehandle:
	my $chunk;
	$self->{Data} = '';
	CORE::binmode($self->{FH}) if $self->binmode;
	while (read($self->{FH}, $chunk, 1024)) {$self->{Data} .= $chunk}
    }
    elsif ($self->{Path}) {     # data from a path:
	open SLURP, $self->{Path} or croak "open $self->{Path}: $!";
	CORE::binmode(SLURP) if $self->binmode;
	$self->{Data} = <SLURP>;        # sssssssssssssslurp...
	close SLURP;                    # ...aaaaaaaaahhh!
    }
}

#------------------------------

=item sign PARAMHASH

Sign the message.  This forces the message to be read into core,
after which the signature is appended to it.

=over 4

=item Data

As in C<build()>: the literal signature data.
Can be either a scalar or a ref to an array of scalars.

=item Path

As in C<build()>: the path to the file.

=back

If no arguments are given, the default is:

    Path => "$ENV{HOME}/.signature"

The content-length is recomputed.

=cut

sub sign {
    my $self = shift;
    my %params = @_;

    # Default:
    @_ or $params{Path} = "$ENV{HOME}/.signature";

    # Force message in-core:
    defined($self->{Data}) or $self->read_now;

    # Load signature:
    my $sig;
    if (!defined($sig = $params{Data})) {      # not given explicitly:
	local $/ = undef;
	open SIG, $params{Path} or croak "open sig $params{Path}: $!";
	$sig = <SIG>;                  # sssssssssssssslurp...
	close SIG;                     # ...aaaaaaaaahhh!
    }    
    $sig = join('',@$sig) if (ref($sig) and (ref($sig) eq 'ARRAY'));

    # Append, following Internet conventions:
    $self->{Data} .= "\n-- \n$sig";

    # Re-compute length:
    $self->get_length;
    1;
}

=back

=cut


#==============================
#==============================

=head2 Output

=over 4

=cut

#------------------------------

=item print [OUTHANDLE]

I<Instance method.> 
Print the message to the given output handle, or to the currently-selected
filehandle if none was given.

All OUTHANDLE has to be is a filehandle (possibly a glob ref), or 
any object that responds to a print() message.

=cut

sub print {
    my ($self, $out) = @_;

    # Coerce into a printable output handle:
    $out = wrap MIME::Lite::IO_Handle $out;

    # Output the head and its terminating blank line:
    $self->print_header($out);
    $out->print("\n");

    # Output either the body or the parts.
    #   Notice that we key off of the content-type!  We expect fewer 
    #   accidents that way, since the syntax will always match the MIME type.
    if ($self->attr('content-type') !~ m{^multipart/}i) {	
	$self->print_body($out);  # Single part
    }
    else {                        # Multipart...
	my $boundary = $self->attr('content-type.boundary');

	# Preamble:
	$out->print("This is a multi-part message in MIME format.\n");
	
	# Parts:
	my $part;
	foreach $part (@{$self->{Parts}}) {
	    $out->print("\n--$boundary\n");
	    $part->print($out);
	}
	$out->print("\n--$boundary--\n\n");
    }
    1;
}

#------------------------------

=item print_body [OUTHANDLE]

I<Instance method.> 
Print the body of the message to the given output handle, 
or to the currently-selected filehandle if none was given.

All OUTHANDLE has to be is a filehandle (possibly a glob ref), or 
any object that responds to a print() message.

B<Fatal exception> raised if unable to open any of the input files,
or if a part contains no data, or if an unsupported encoding is 
encountered.

=cut

sub print_body {
    my ($self, $out) = @_;

    # Coerce into a printable output handle:
    $out = wrap MIME::Lite::IO_Handle $out;

    # Get content-transfer-encoding:
    my $encoding = uc($self->attr('content-transfer-encoding'));

    # Notice that we don't just attempt to slurp the data in from a file:
    # by processing files piecemeal, we still enable ourselves to prepare
    # very large MIME messages...

    # Is the data in-core?  If so, blit it out...
    if (defined($self->{Data})) {
      DATA: 
	{ $_ = $encoding;

	  /^BINARY$/ and do {
	      $out->print($self->{Data}); 
	      last DATA;
	  };
	  /^8BIT$/ and do {
	      $out->print(encode_8bit($self->{Data})); 
	      last DATA;
	  };
	  /^7BIT$/ and do {
	      $out->print(encode_7bit($self->{Data})); 
	      last DATA;
	  };
	  /^QUOTED-PRINTABLE$/ and do {
	      while ($self->{Data}=~ m{^.*[\r\n]*}mg) {
		  $out->print(encode_qp($&));   # have to do it line by line...
	      }
	      last DATA;	 
	  };
	  /^BASE64/ and do {
	      $out->print(encode_base64($self->{Data})); 
	      last DATA;
	  };
	  croak "unsupported encoding: `$_'";
        }
    }

    # Else, is the data in a file?  If so, output piecemeal...
    #    Miko's note: this routine pretty much works the same with a path 
    #    or a filehandle. the only difference in behaviour is that it does 
    #    not attempt to open anything if it already has a filehandle
    elsif (defined($self->{Path}) || defined($self->{FH})) {
	no strict 'refs';          # in case FH is not an object
	my $DATA;
	
	# Open file if necessary:
	if (defined($self->{Path})) {
	    $DATA = new FileHandle || croak "can't get new filehandle!";
	    $DATA->open("$self->{Path}") or croak "open $self->{Path}: $!";
	}
	else {
	    $DATA=$self->{FH};
	}
	CORE::binmode($DATA) if $self->binmode;
		
	# Encode piece by piece:
      PATH: 
	{   $_ = $encoding;
	    
	    /^BINARY$/ and do {
		$out->print($_)                while read($DATA, $_, 2048); 
		last PATH;
	    };      
	    /^8BIT$/ and do {
		$out->print(encode_8bit($_))   while (<$DATA>); 
		last PATH;
	    };
	    /^7BIT$/ and do {
		$out->print(encode_7bit($_))   while (<$DATA>); 
		last PATH;
	    };
	    /^QUOTED-PRINTABLE$/ and do {
		$out->print(encode_qp($_))     while (<$DATA>); 
		last PATH;
	    };
	    /^BASE64$/ and do {
		$out->print(encode_base64($_)) while (read($DATA, $_, 45));
		last PATH;
	    };
	    croak "unsupported encoding: `$_'";
	}
	
	# Close file:
	close $DATA if defined($self->{Path});
    }
    
    else {
	croak "no data in this part!";
    }
    1;
}

#------------------------------

=item print_header [OUTHANDLE]

I<Instance method.> 
Print the header of the message to the given output handle, 
or to the currently-selected filehandle if none was given.

All OUTHANDLE has to be is a filehandle (possibly a glob ref), or 
any object that responds to a print() message.

=cut

sub print_header {
    my ($self, $out) = @_;

    # Coerce into a printable output handle:
    $out = wrap MIME::Lite::IO_Handle $out;

    # Output the header:
    $out->print($self->header_as_string);
    1;
}

#------------------------------

=item as_string

I<Instance method.> 
Return the entire message as a string, with a header and an encoded body.

=cut

sub as_string {
    my $self = shift;
    my $str = "";
    my $io = (wrap MIME::Lite::IO_Scalar \$str);
    $self->print($io);
    $str;
}
*stringify = \&as_string;    # backwards compatibility

#------------------------------

=item body_as_string

I<Instance method.> 
Return the encoded body as a string.

I<Note:> actually prepares the body by "printing" to a scalar.
Proof that you can hand the C<print*()> methods any blessed object 
that responds to a C<print()> message.

=cut

sub body_as_string {
    my $self = shift;
    my $str = "";
    my $io = (wrap MIME::Lite::IO_Scalar \$str);
    $self->print_body($io);
    $str;
}
*stringify_body = \&body_as_string;    # backwards compatibility

#------------------------------

=item header_as_string

I<Instance method.> 
Return the header as a string.

=cut

sub header_as_string {
    my $self = shift;
    my $str = '';
    foreach (@{$self->fields}) {
	my ($tag, $value) = @$_;
	$tag =~ s/\b([a-z])/uc($1)/ge;   # make pretty
	$tag =~ s/^mime-/MIME-/ig;       # even prettier
	$str .= "$tag: $value\n";
    }
    $str;
}
*stringify_header = \&header_as_string;    # backwards compatibility

=back

=cut



#==============================
#==============================

=head2 Sending

=over 4

=cut

#------------------------------

=item send

=item send HOW, HOWARGS...

I<Class/instance method.>  
This is the principle method for sending mail, and for configuring
how mail will be sent.

I<As an instance method> (with no arguments), sends the message by whatever 
means has been set up (the default is to use the Unix "sendmail" program).
Returns whatever the mail-handling routine returns: this should be true 
on success, false/exception on error:

    $msg = MIME::Lite->new(From=>...);
    $msg->send || die "you DON'T have mail!";

I<As a class method> (with a HOW argument and optional HOWARGS), sets up 
how the instance method will work for all objects until further notice.
It treats HOW as a facility name, with optional HOWARGS handled by
the facility.   There are three facilities:

=over 4

=item "sendmail", SENDMAILCMD

Send a message by piping it into the "sendmail" command.
Uses the C<send_by_sendmail()> method, giving it the SENDMAILCMD.
This usage implements (and deprecates) the C<sendmail()> method.
 
=item "smtp", [HOSTNAME]

Send a message by SMTP, using optional HOSTNAME as SMTP-sending host.
Uses the C<send_by_smtp()> method.

=item "sub", \&SUBREF, ARGS...

Sends a message MSG by invoking the subroutine SUBREF of your choosing,
with MSG as the first argument, and ARGS following.

=back

I<For example:> let's say you're on an OS which lacks the usual Unix
"sendmail" facility, but you've installed something a lot like it, and
you need to configure your Perl script to use this "sendmail.exe" program.
Do this following in your script's setup:

    MIME::Lite->send('sendmail', "d:\\programs\\sendmail.exe");

Then, whenever you need to send a message $msg, just say:

    $msg->send;

That's it.  Now, if you ever move your script to a Unix box, all you
need to do is change that line in the setup and you're done.
All of your $msg-E<gt>send invocations will work as expected.

=cut

sub send {
    my $self = shift;
    if (ref($self)) {              # instance method:
	my $method = "send_by_$Sender";
	my @args   = @{$SenderArgs{$Sender} || []};
	return $self->$method(@args);
    }
    else {                         # class method:
	$Sender = shift;
	$SenderArgs{$Sender} = [@_];    # remaining args
	return 1;
    }
}

#------------------------------

=item send_by_sendmail SENDMAILCMD

I<Instance method.>
Send message via the external "sendmail" program, SENDMAILCMD.
Returns true on success, false or exception on error.

I<Note:> this facility will probably only work on Unix systems.
The SENDMAILCMD for this facility must get all its message-specific 
information from the standard input.

=cut

sub send_by_sendmail {
    my ($self, $sendmailcmd) = @_;

    # Do it:
    my $pid;
    open SENDMAIL, "|$sendmailcmd" or croak "open |$sendmailcmd: $!";
    $self->print(\*SENDMAIL);
    close SENDMAIL;
    return (($? >> 8) ? undef : 1);
}

#------------------------------

=item send_by_smtp [ARGS...]

I<Instance method.>
Send message via SMTP, using Net::SMTP.  
The ARGS are sent into Net::SMTP::new(): usually, these are

    MAILHOST, OPTION=>VALUE, ...

Returns true on success, false or exception on error.

=cut

# Provided by Andrew McRae. Version 0.2  anm  09Sep97
# Copyright 1997 Optimation New Zealand Ltd.
# May be modified/redistributed under the same terms as Perl.
#
sub send_by_smtp {
    my ($self, @args) = @_;

    # We need the "From:" and "To:" headers to pass to the SMTP mailer:
    my $hdr = $self->fields();   
    my $from = $self->get('From');
    my @to   = $self->get('To');

    # Create SMTP client:
    require Net::SMTP;
    my $smtp = MIME::Lite::SMTP->new(@args)
        or croak "Failed to connect to mail server: $!";
    $smtp->mail($from)
        or croak "SMTP MAIL command failed: $!";
    $smtp->to(@to)
        or croak "SMTP RCPT command failed: $!";
    $smtp->data()
        or croak "SMTP DATA command failed: $!";

    # MIME::Lite can print() to anything with a print() method:
    $self->print($smtp);
    $smtp->dataend();
    $smtp->quit;
    1;
}

#------------------------------
#
# send_by_sub [\&SUBREF, [ARGS...]]
#
# I<Instance method, private.>
# Send the message via an anonymous subroutine.
#
sub send_by_sub {
    my ($self, $subref, @args) = @_;
    &$subref($self, @args);
}

#------------------------------

=item sendmail COMMAND...

I<Class method, DEPRECATED.>  
Declare the sender to be "sendmail", and set up the "sendmail" command.
I<You should use send() instead.>

=cut

sub sendmail {
    my $self = shift;
    $self->send('sendmail', join(' ', @_));
}

=back

=cut



#==============================
#==============================

=head2 Miscellaneous

=over 4

=cut

#------------------------------

=item quiet ONOFF

I<Class method.>  
Suppress/unsuppress all warnings coming from this module.

    quiet MIME::Lite 1;       # I know what I'm doing

I recommend that you include that comment as well.  And while
you type it, say it out loud: if it doesn't feel right, then maybe
you should reconsider the whole line.  C<;-)>

=cut

sub quiet {
    my $class = shift;
    $QUIET = shift if @_;
    $QUIET;
}

=back

=cut



#============================================================

package MIME::Lite::SMTP;

#============================================================
# This class just adds a print() method to Net::SMTP.
# Notice that we don't use/require it until it's needed!

use strict;
use vars qw( @ISA );
@ISA = qw(Net::SMTP);

sub print { shift->datasend(@_) }



#============================================================

package MIME::Lite::IO_Handle;

#============================================================

# Wrap a non-object filehandle inside a blessed, printable interface:
# Does nothing if the given $fh is already a blessed object.
sub wrap {
    my ($class, $fh) = @_;
    no strict 'refs';

    # Get default, if necessary:
    $fh or $fh = select;        # no filehandle means selected one
    ref($fh) or $fh = \*$fh;    # scalar becomes a globref
    
    # Stop right away if already a printable object:
    return $fh if (ref($fh) and (ref($fh) ne 'GLOB'));

    # Get and return a printable interface:
    bless \$fh, $class;         # wrap it in a printable interface
}

# Print:
sub print {
    my $self = shift;
    print {$$self} @_;
}


#============================================================

package MIME::Lite::IO_Scalar;

#============================================================

# Wrap a scalar inside a blessed, printable interface:
sub wrap {
    my ($class, $scalarref) = @_;
    defined($scalarref) or $scalarref = \"";
    bless $scalarref, $class;
}

# Print:
sub print {
    my $self = shift;
    $$self .= join('', @_);
    1;
}

1;
__END__


#============================================================

=head1 NOTES

=head2 Limitations

This is "lite", after all...

=over 4

=item *

There's no parsing.  Get MIME-tools if you need to parse MIME messages.

=item *

MIME::Lite messages are currently I<not> interchangeable with 
either Mail::Internet or MIME::Entity objects.  This is a completely 
separate module.

=item *

A content-length field is only inserted if the encoding is binary,
the message is a singlepart, and all the document data is available
at C<build()> time by virtue of residing in a simple path, or in-core.
Since content-length is not a standard MIME field anyway (that's right, kids:
it's not in the MIME RFCs, it's an HTTP thing), this seems pretty fair.

=item *

MIME::Lite alone cannot help you lose weight.  You must supplement
your use of MIME::Lite with a healthy diet and exercise. 

=back


=head2 Cheap and easy mailing

I thought putting in a default "sendmail" invocation wasn't too bad an 
idea, since a lot of Perlers are on UNIX systems.  The default arguments
to sendmail (which you can change) are:

     -t      Scan message for To:, Cc:, Bcc:, etc.
              
     -oi     Do NOT treat a single "." on a line as a message terminator.
             As in, "-oi vey, it truncated my message... why?!"
                
     -oem    On error, mail back the message (I assume to the
             appropriate address, given in the header).
             When mail returns, circle is complete.  Jai guru deva -oem.

If you're not on a Unix system, or if you'd just rather send mail
some other way, check out the C<send()> method.  There's built in
support for SMTP delivery, or you can slip in your own hooks. 


=head2 Under the hood

This class treats a MIME header in the most abstract sense,
as being a collection of high-level attributes.  The actual
RFC-822-style header fields are not constructed until it's time
to actually print the darn thing.



=head1 WARNINGS

B<Important:> the MIME attributes are stored and manipulated separately 
from the message header fields; when it comes time to print the 
header out, I<any explicitly-given header fields override the ones that
would be created from the MIME attributes.>  That means that this:

    ### DANGER ### DANGER ### DANGER ### DANGER ### DANGER ###
    $msg->add("Content-type", "text/html; charset=US-ASCII");

will set the exact C<"Content-type"> field in the header I write, 
I<regardless of what the actual MIME attributes are.>

I<This feature is for experienced users only,> as an escape hatch in case
the code that normally formats MIME header fields isn't doing what 
you need.  And, like any escape hatch, it's got an alarm on it:
MIME::Lite will warn you if you attempt to C<set()> or C<replace()>
any MIME header field.  Use C<attr()> instead.



=head1 A MIME PRIMER

=head2 Content types

The "Type" parameter of C<build()> is a I<content type>. 
This is the actual type of data you are sending.  
Generally this is a string of the form C<"majortype/minortype">.

Here are the major MIME types.
A more-comprehensive listing may be found in RFC-2046.

=over 4

=item application

Data which does not fit in any of the other categories, particularly 
data to be processed by some type of application program. 
C<application/octet-stream>, C<application/gzip>, C<application/postscript>...

=item audio

Audio data.
C<audio/basic>...

=item image

Graphics data.
C<image/gif>, C<image/jpeg>...

=item message

A message, usually another mail or MIME message.
C<message/rfc822>...

=item multipart

A message containing other messages.
C<multipart/mixed>, C<multipart/alternative>...

=item text

Textual data, meant for humans to read.
C<text/plain>, C<text/html>...

=item video

Video or video+audio data.
C<video/mpeg>...

=back


=head2 Content transfer encodings

The "Encoding" parameter of C<build()>.
This is how the message body is packaged up for safe transit.

Here are the 5 major MIME encodings.
A more-comprehensive listing may be found in RFC-2045.

=over 4

=item 7bit

Basically, no I<real> encoding is done.  However, this label guarantees that no
8-bit characters are present, and that lines do not exceed 1000 characters 
in length.

=item 8bit

Basically, no I<real> encoding is done.  The message might contain 8-bit 
characters, but this encoding guarantees that lines do not exceed 1000 
characters in length.

=item binary

No encoding is done at all.  Message might contain 8-bit characters,
and lines might be longer than 1000 characters long.

The most liberal, and the least likely to get through mail gateways.  
Use sparingly, or (better yet) not at all.

=item base64

Like "uuencode", but very well-defined.  This is how you should send
essentially binary information (tar files, GIFs, JPEGs, etc.). 

=item quoted-printable

Useful for encoding messages which are textual in nature, yet which contain 
non-ASCII characters (e.g., Latin-1, Latin-2, or any other 8-bit alphabet).

=back



=head1 CHANGE LOG

B<Current version:>
$Id$

=over 4


=item Version 1.133

Fixed bug in "Data" handling: arrayrefs were not being handled
properly.


=item Version 1.130

Added much larger and more-flexible send() facility.
I<Thanks to Andrew McRae (and Optimation New Zealand Ltd) 
for the Net::SMTP interface.  Additional thanks to the many folks
who requested this feature.>

Added get() method for extracting basic attributes.

New... "t" tests!


=item Version 1.124

Folded in filehandle (FH) support in build/attach.
I<Thanks to Miko O'Sullivan for the code.>


=item Version 1.122

MIME::Base64 and MIME::QuotedPrint are used if available.

The 7bit encoding no longer does "escapes"; it merely strips 8-bit characters.


=item Version 1.121

Filename attribute is now no longer ignored by build().
I<Thanks to Ian Smith for finding and patching this bug.>


=item Version 1.120

Efficiency hack to speed up MIME::Lite::IO_Scalar.
I<Thanks to David Aspinwall for the patch.>


=item Version 1.116

Small bug in our private copy of encode_base64() was patched.
I<Thanks to Andreas Koenig for pointing this out.>

New, prettier way of specifying mail message headers in C<build()>.

New quiet method to turn off warnings.

Changed "stringify" methods to more-standard "as_string" methods.


=item Version 1.112

Added C<read_now()>, and C<binmode()> method for our non-Unix-using brethren: 
file data is now read using binmode() if appropriate.
I<Thanks to Xiangzhou Wang for pointing out this bug.>


=item Version 1.110

Fixed bug in opening the data filehandle.


=item Version 1.102

Initial release.


=item Version 1.101

Baseline code.

=back


=head1 TERMS AND CONDITIONS

Copyright (c) 1997 by Eryq.  
Copyright (c) 1998 by ZeeGee Software Inc.
All rights reserved.  This program is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.  

This software comes with B<NO WARRANTY> of any kind.
See the COPYING file in the distribution for details.


=head1 NUTRITIONAL INFORMATION

For some reason, the US FDA says that this is now required by law
on any products that bear the name "Lite"...

    Serving size:             1 module
    Servings per container:   1
    Calories:                 0
    Fat:                      0g
      Saturated Fat:          0g

    Warning: for consumption by hardware only!  May produce 
    indigestion in humans if taken internally.


=head1 AUTHOR

Eryq (F<eryq@zeegee.com>).
President, ZeeGee Software Inc. (F<http://www.zeegee.com>).

Created: 11 December 1996.  Ho ho ho.

=cut

