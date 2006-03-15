use strict;

# -----------------------------------------------------------------------
# SMS module for Misterhouse
# Uses the form at www.smsboy.com to send an SMS message to your mobile.
# Written by Stuart Grimshaw <stuart@smgsystems.co.uk>
#
# v0.2 (17/12/2000)
#
# It's trivially simple to use, just add the .pm file to either your code
# directory, or the Misterhouse lib directory. Until the module is integrated
# into the next release (and until you upgrade to it) you need to add the
# line:
#
#	use SMS_Item;
#
# somewhere in your code.
#
# To create the object use:
#
#	new SMS_Item(<IntlCountryCode>, <MobileNumber>);
#
#	$SMS_StuMobile = new SMS_Item(44, "07976123456");
#
# and to send a message use the line:
#
#	$SMS_StuMobile->send("Mum called your home at 13:15");
#
# -----------------------------------------------------------------------

package SMS_Item;

use LWP::UserAgent;

my $smsurl = "http://www.smsboy.com/cgi-bin/sendsms9.pl";

sub new {
	
	my($class)=shift(@_);
	my($self) = {};
	
	$$self{country} = shift(@_);
	$$self{number} = shift(@_);

	bless $self, $class;
	return $self;
}

sub send {
	my($self, $message) = @_;
	
	my $ua = new LWP::UserAgent;
	my $req = new HTTP::Request POST => $smsurl;
	$req->content_type('application/x-www-form-urlencoded');
	$req->content("C=$$self{country}&N=$$self{number}&M=$message -- ");

	my $res = $ua->request($req);
}

sub set {
	my($self, $IntlCode, $Number) = @_;
	$$self{country}=$IntlCode;
	$$self{number}=$Number;
}