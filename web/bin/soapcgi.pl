
# --------------------------------------------------------------------------
#	soapcgi.pl
#
#	Requires: SoapServer.pm, WebServices.pm, SOAP::Lite
#
#	This is the cgi-like interface to the web services soap server
#   It transfers http requests to the SoapServer module.
#   The urn(s) for the web service is determined by the setting in this
#	file.  Eventually this file will also be used to do the authorization.
#
#	Created: 8/10/2006  Mike Wiebke mw65@yahoo.com
#
#---------------------------------------------------------------------------

# couple of global variables to retreive the information from the http request
use vars qw(%Http $HTTP_CONTENT %HTTP_ARGV);

# include the two modules for the server and the interfaces
use SoapServer;
use WebServices;

if ( $main::Debug{soap} ) {
    my ( $key, $header );
    while ( ( $key, $header ) = each %Http ) {
        logit "$config_parms{data_dir}/logs/soapdebug.log", "$key $header";
        logit "$config_parms{data_dir}/logs/soapdebug.log",
          "$ENV{HTTP_QUERY_STRING}";
    }
}

my $server = SoapServer->new();

# This call tells the server which module to pass the call to for each namespace.
# You can have multiple namespaces but it's a one to one relationship.  So you
# need a package for each namespace.  You can also specify that a namespace should
# go to any package in a particular directory or to a specific function in a package
# see the SOAP::Lite documentation for more info
$server->dispatch_with( { 'urn:mhsoap' => 'WebServices' } );
$server->objects_by_reference('WebServices');
my $results = $server->handle( $ENV{HTTP_QUERY_STRING}, \%Http );

logit "$config_parms{data_dir}/logs/soapdebug.log", $results
  if $main::Debug{soap};

return $results;
