use strict;

package Audrey_Play;

=head1 NAME

B<Audrey_Play> - This object can be used to play sound files on the Audrey.

=head1 SYNOPSIS


blah blah



=head1 DESCRIPTION

=head1 INHERITS

B<Generic_Item>

=head1 METHODS

=over

=cut

@Audrey_Play::ISA = ('Generic_Item');

my $address;

sub Init {
    #&::MainLoop_pre_add_hook(  \&Weather_Item::check_weather, 1 );
}

=item C<new($ip)>

$ip is the IP address of the Audrey.

=cut

sub new {
   my ($class, $ip) = @_;
   my $self = { };
   $self->{address}=$ip;
   
   if ($ip) {
      &::print_log("Creating Audrey_Play object...");
   } else {
      warn 'Empty expression is not allowed.';
   }

   bless $self, $class;
   return $self;         
}

sub play {
   my ($self,$web_file) = @_;
   &::print_log("Called 'play' in Audrey_Play object...");
   my $MHWeb = $::Info{IPAddress_local} . ":" . $::config_parms{http_port};
   &::print_log($MHWeb);
   &::run("get_url -quiet http://" . $self->{address} . "/mhspeak.shtml?http://" . $MHWeb . "/" . $web_file . " /dev/null");
}

1;