#
# Asterisk.pl by Robert Mann robert@easyway.com
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the <ORGANIZATION> nor the names of its
#       contributors may be used to endorse or promote products derived from
#       this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# USAGE:
#
# Add these to your mh.ini
# This port may be what ever you want just make sure your MisterHouse.agi matches the following.
# server_astersisk_port = 8090
# asterisk_server_username = yourusername
# asterisk_server_password = yourpassword
#
# Here you want to tell MisterHouse what your interface to meaningful name is.
# Interface numbers just need to be in order but can be as high as you need
# them and need not be in any specific order.
# My incoming X100P telco lines
# asterisk_interface1=Zap/1-1:Work Phone
# asterisk_interface2=Zap/2-1:Home Phone
# My TDM40B 4 port analog phone adapter
# asterisk_interface3=Zap/3-1:Cordless Line 1
# asterisk_interface4=Zap/4-1:Cordless Line 2
# asterisk_interface5=Zap/5-1:Fax
# Some SIP clients that connect and make calls through my system.
# asterisk_interface6=SIP/2002:Robert Mann Laptop
# asterisk_interface7=SIP/2003:Charles Mann Home
# asterisk_interface8=SIP/2004:Joe Mann Home
# asterisk_interface9=SIP/2005:Cheryl Mann Home

my ( %ast_to_name, %ast_callerid_extensions );
my ( $auth, $username, $password );

# Create the asterisk server on MisterHouse to accept incoming connections from Asterisk
$asterisk_server = new Socket_Item( undef, undef, 'server_asterisk' );

# On startup of MisterHouse initialize some variables from entries in the mh.ini file.
if ($Startup) {
    my ($ace);
    #
    # Get the name to channel from the config file.  This way it can announce from Home Phone instead of Zap/1-1
    #
    my ( $astint, $astname, $astconfig );
    my ($count);
    $count = 1;
    while (1) {
        $astconfig = "asterisk_interface" . $count;
        if ( $::config_parms{$astconfig} ) {
            ( $astint, $astname ) = split( /:/, $::config_parms{$astconfig} );
            $ast_to_name{$astint} = $astname;
        }
        else {
            last;
        }
        $count++;
    }
}

# Here we find data sent from Asterisk and parse it out and do what needs to be done with it.
# I am not good with MisterHouse as of yet to know the best way to handle certain things but this
# works for me and may need to be changed around to work for you.  One of the things I changed is
# CallerID stuff so that I can keep better track of the line that the call came in on.  I just copied
# some of the code from other files in MisterHouse to do what I needed done but there is definetly
# better ways to do this and I am hoping that someone will help guide me in the right direction
# or take it upon themselves to fix it and redistribute it back out for all to use.
if ( my $data = said $asterisk_server) {
    print_log("DATA: $data") if $Debug{asterisk};

    # First check for the login and password before letting them do anything.
    if ( !$auth ) {
        if ( $data =~ /Login: (.*)/ ) {
            $username = $1;
        }
        elsif ( $username && $data =~ /Secret: (.*)/ ) {
            $password = $1;
            if (   $::config_parms{asterisk_server_username} eq $username
                && $::config_parms{asterisk_server_password} eq $password )
            {
                $auth = 1;
            }
            else {
                set $asterisk_server "Incorrect login information\n\n";
                $username = '';
                $password = '';
            }
        }
    }
    else {
        if ( $data =~ /CallerID:/ ) {
            $data =~ /CallerID: \"(.*)\" \<(.*)\> Line: (.*)/;
            my $callername   = $1;
            my $callernumber = $2;
            my $astline      = $3;
            &asterisk_logit( "in", $callernumber, &make_bettername($callername),
                $ast_to_name{$astline} );
            stop $asterisk_server;
            respond(
                "mode=unmuted Call from "
                  . &make_speakable(
                    $callername, $callernumber, $ast_to_name{$astline}
                  )
            );

        }
        elsif ( $data =~ /DTMF:/ ) {
            $data =~ /DTMF: (.*) CallFrom: (.*)/;
            my $dtmf     = $1;
            my $callfrom = $2;
            &asterisk_logit( "out", $dtmf, '', $ast_to_name{$callfrom} );
            &::print_log("out $dtmf $ast_to_name{$callfrom}");
            stop $asterisk_server;

        }
        elsif ( $data =~ /Command:/ ) {
            $data =~ /Command:(.*) Response=(.*)/;
            my $cmd      = $1;
            my $response = lc($2);
            my $respond  = "asterisk" if $response =~ /^y/;
            print_log("Asterisk Command: $cmd with response code: $response")
              if $Debug{asterisk};
            &process_external_command( $cmd, 0, 'asterisk', $respond );
            if ( $response !~ /^y/ ) {
                stop $asterisk_server;
            }
        }
        $auth = '';
    }
}

# Here is were I got really confused.  Unfortunatly the documentation for MisterHouse and Asterisk are not
# quite up to par and this took a lot of digging through code and trying to understand how MisterHouse
# handles responses from different things.  I think this is what the respond_??? was designed to do but
# had a really hard time making it work the way I needed it to.  I will work to better this as I can
# or as I learn more.
sub respond_asterisk {
    my %parms = @_;
    set $asterisk_server "$parms{text}";
    stop $asterisk_server;
}

# This formats the name and number in to a more speakable format.
sub make_speakable {
    my ( $name, $number, $line ) = @_;
    my ( $first, $middle, $last );
    if ( $name =~ /wireless caller/i ) {
        return "Wireless Caller from $number on $line";
    }
    elsif ( $name =~ /privacy manager/i ) {
        return "Privacy Manager from $number on $line";
    }
    else {
        ( $last, $first, $middle ) = split( ' ', $name );
        $first = ucfirst( lc($first) );
        $first = ucfirst( lc($middle) )
          if length($first) == 1 and $middle;    # Last M First format
        $last = ucfirst( lc($last) );
        return "$first $middle $last on $line";
    }
    return "Unknown Caller on $line";
}

# This formats the name for a better viewable format for the database.
sub make_bettername {
    my ($name) = @_;
    my ( $first, $middle, $last );
    if ( $name =~ /wireless caller/i ) {
        return "Wireless Caller";
    }
    elsif ( $name =~ /privacy manager/i ) {
        return "Privacy Manager";
    }
    else {
        ( $last, $first, $middle ) = split( ' ', $name );
        $first = ucfirst( lc($first) );
        $first = ucfirst( lc($middle) )
          if length($first) == 1 and $middle;    # Last M First format
        $last = ucfirst( lc($last) );
        return "$first $middle $last";
    }
    return "Unknown Caller";
}

# Simply uses the logit function to send the DTMF and CallerID to the database.  This is where
# I really could have used better documentation to figure out exactly how the database wanted this
# information and how to make it work better for displaying what line they were calling on or from.
sub asterisk_logit {
    my ( $type, $number, $name, $line ) = @_;
    my ($filename);
    if ( $type eq "in" ) {
        $filename = 'callerid';
    }
    else {
        $filename = 'phone';
    }
    &::logit(
        "$::config_parms{data_dir}/phone/logs/$filename.$::Year_Month_Now.log",
        "number=$number name=$name line=$line type=$type"
    );
}
