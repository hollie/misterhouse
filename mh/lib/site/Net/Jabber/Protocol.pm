package Net::Jabber::Protocol;

=head1 NAME

Net::Jabber::Protocol - Jabber Protocol Library

=head1 SYNOPSIS

  Net::Jabber::Protocol is a module that provides a developer easy access
  to the Jabber Instant Messaging protocol.  It provides high level functions
  to both Net::Jabber::Client and Net::Jabber::Transport.  These functions
  are automatically indluded in those modules through AUTOLOAD and delegates.

=head1 DESCRIPTION

  Protocol.pm seeks to provide enough high level APIs and automation of 
  the low level APIs that writing a Jabber Client/Transport in Perl is 
  trivial.  For those that wish to work with the low level you can do 
  that too, but those functions are covered in the documentation for 
  each module.

  Net::Jabber::Protocol provides functions to login, send and receive 
  messages, set personal information, create a new user account, manage
  the roster, and disconnect.  You can use all or none of the functions,
  there is no requirement.

  For more information on how the details for how Net::Jabber is written
  please see the help for Net::Jabber itself.

  For more information on writing a Client see Net::Jabber::Client.

  For more information on writing a Transport see Net::Jabber::Transport.

=head2 Basic Functions

    use Net::Jabber;

    $Con = new Net::Jabber::Client();            # From Net::Jabber::Client
    $status = $Con->Connect(name=>"jabber.org"); #

      or

    $Con = new Net::Jabber::Transport();         #
    $status = $Con->Connect(name=>"jabber.org",  # From Net::Jabber::Transport
			    secret=>"bob");      #


    $Con->SetCallBacks(message=>\&messageCallBack,
		       iq=>\&handleTheIQTag);

    $error = $Con->GetErrorCode();
    $Con->SetErrorCode("Timeout limit reached");

    $Con->Process();
    $Con->Process(5);

    $Con->Send($object);
    $Con->Send("<tag>XML</tag>");

    $Con->Disconnect();

=head2 ID Functions

    $id         = $Con->SendWithID($sendObj);
    $id         = $Con->SendWithID("<tag>XML</tag>");
    $receiveObj = $Con->SendAndReceiveWithID($sendObj);
    $receiveObj = $Con->SendAndReceiveWithID("<tag>XML</tag>");
    $yesno      = $Con->ReceivedID($id);
    $receiveObj = $Con->GetID($id);    
    $receiveObj = $Con->WaitForID($id);

=head2 Namespace Functions

    $Con->AddDelegate(namespace=>"foo::bar",
                      parent=>"Foo::Bar");

    $Con->AddDelegate(namespace=>"foo::bar::bob",
                      parent=>"Foo::Bar",
                      delegate=>"Foo::Bar::Bob");

=head2 Message Functions

    $Con->MessageSend(to=>"bob@jabber.org",
		      subject=>"Lunch",
		      body=>"Let's go grab some...\n";
		      thread=>"ABC123",
		      priority=>10);

=head2 Presence Functions

    $Con->PresenceSend();

=head2 Subscription Functions

    $Con->Subscription(type=>"subscribe",
		       to=>"bob@jabber.org");

    $Con->Subscription(type=>"unsubscribe",
		       to=>"bob@jabber.org");

    $Con->Subscription(type=>"subscribed",
		       to=>"bob@jabber.org");

    $Con->Subscription(type=>"unsubscribed",
		       to=>"bob@jabber.org");

=head2 PresenceDB Functions

    $Con->PresenceDBParse(Net::Jabber::Presence);

    $Con->PresenceDBDelete(Net::Jabber::"bob\@jabber.org");
    $Con->PresenceDBDelete(Net::Jabber::JID);

    $presence  = $Con->PresenceDBQuery("bob\@jabber.org");
    $presence  = $Con->PresenceDBQuery(Net::Jabber::JID);

    @resources = $Con->PresenceDBResources("bob\@jabber.org");
    @resources = $Con->PresenceDBResources(Net::Jabber::JID);

=head2 IQ  Functions

=head2 IQ::Agents Functions

    %agents = $Con->AgentsGet();
    %agents = $Con->AgentsGet(to=>"transport.jabber.org");

=head2 IQ::Auth Functions

    @result = $Con->AuthSend();
    @result = $Con->AuthSend(username=>"bob",
			     password=>"bobrulez",
			     resource=>"Bob");

=head2 IQ::Fneg Functions

    n/a

=head2 IQ::Info Functions

    n/a

=head2 IQ::Register Functions

    %fields = $Con->RegisterRequest();
    %fields = $Con->RegisterRequest(to=>"transport.jabber.org");

    @result = $Con->RegisterSend(usersname=>"newuser",
				 resource=>"New User",
				 password=>"imanewbie",
                                 email=>"newguy@new.com",
                                 key=>"some key");

=head2 IQ::Resource Functions

    n/a

=head2 IQ::Roster Functions

    %roster = $Con->RosterParse($iq);
    %roster = $Con->RosterGet();
    $Con->RosterAdd(jid=>"bob\@jabber.org",
		    name=>"Bob");
    $Con->RosterRemove(jid=>"bob@jabber.org");


=head2 IQ::Search Functions

    %fields = $Con->SearchRequest();
    %fields = $Con->SearchRequest(to=>"users.jabber.org");

    $Con->SearchSend(name=>"",
                     first=>"Bob",
                     last=>"",
                     nick=>"bob",
                     email=>"",
                     key=>"som key");

=head2 IQ::Time Functions

    %result = $Con->TimeQuery();
    %result = $Con->TimeQuery(to=>"bob@jabber.org");

    $Con->TimeSend(to=>"bob@jabber.org");

=head2 IQ::Version Functions

    %result = $Con->VersionQuery();
    %result = $Con->VersionQuery(to=>"bob@jabber.org");

    $Con->VersionSend(to=>"bob@jabber.org",
                      name=>"Net::Jabber",
                      ver=>"1.0a",
                      os=>"Perl");

=head2 X Functions

=head1 METHODS

=head2 Basic Functions

    GetErrorCode() - returns a string that will hopefully contain some
                     useful information about why a function returned
                     an undef to you.

    SetErrorCode(string) - set a useful error message before you return
                           an undef to the caller.

    SetCallBacks(message=>function,  - sets the callback functions for
                 presence=>function,   the top level tags listed.  The
		 iq=>function)         available tags to look for are
                                       <message/>, <presence/>, and
                                       <iq/>.  If a packet is received
                                       with an ID then it is not sent
                                       to these functions, instead it
                                       is inserted into a LIST and can
                                       be retrieved by some functions
                                       we will mention later.

    Process(integer) - takes the timeout period as an argument.  If no
                       timeout is listed then the function blocks until
                       a packet is received.  Otherwise it waits that
                       number of seconds and then exits so your program
                       can continue doing useful things.  NOTE: This is
                       important for GUIs.  You need to leave time to
                       process GUI commands even if you are waiting for
                       packets.

                       IMPORTANT: You need to check the output of every
                       Process.  If you get an undef or "" then the 
                       connection died and you should behave accordingly.

    Send(object) - takes either a Net::Jabber::xxxxx object or an XML
    Send(string)   string as an argument and sends it to the server.

=head2 ID Functions

    SendWithID(object) - takes either a Net::Jabber::xxxxx object or an
    SendWithID(string)   XML string as an argument, adds the next
                         available ID number and sends that packet to
                         the server.  Returns the ID number assigned.
    
    SendAndReceiveWithID(object) - uses SendWithID and WaitForID to
    SendAndReceiveWithID(string)   provide a complete way to send and
                                   receive packets with IDs.  Can take
                                   either a Net::Jabber::xxxxx object
                                   or an XML string.  Returns the
                                   proper Net::Jabber::xxxxx object
                                   based on the type of packet received.

    ReceivedID(integer) - returns 1 if a packet has been received with
                          specified ID, 0 otherwise.

    GetID(integer) - returns the proper Net::Jabber::xxxxx object based
                     on the type of packet received with the specified
                     ID.  If the ID has been received the GetID returns
                     0.

    WaitForID(integer) - blocks until a packet with the ID is received.
                         Returns the proper Net::Jabber::xxxxx object
                         based on the type of packet received


    NOTE:  Only <iq/> officially support ids, so sending a <message/>, or 
           <presence/> with an id is a risk.  Both clients must support 
           this for these functions to work.

=head2 Namespace Functions

    AddNamespace(namespace=>string, - this tells the Net::Jabber modules
                 parent=>string,      about the new namespace.  The
                 delegate=>string)    namespaces determines how the xmlns
                                      looks in the tag.  The parent is
                                      the name of the module to create
                                      when you use this namespace.  The
                                      delegate is only needed if the
                                      parent module uses delegates to
                                      distinguish between namespaces
                                      (like the Net::Jabber::IQ and
                                      Net::Jabber::X modules do).  The
                                      delegate must be a valid Perl
                                      Module.

=head2 Message Functions

    MessageSend(hash) - takes the hash and passes it to SetMessage in
                        Net::Jabber::Message (refer there for valid
                        settings).  Then it sends the message to the
                        server.

=head2 Presence Functions

    PresenceSend() - sends an empty Presence to the server to tell it
                     that you are available

=head2 Subscription Functions

    Subscription(hash) - taks the hash and passes it to SetPresence in
                         Net::Jabber::Presence (refer there for valid
                         settings).  Then it sends the subscription to
                         server.

                         The valid types of subscription are:

                           subscribe    - subscribe to JID's presence
                           unsubscribe  - unsubscribe from JID's presence
                           subscribed   - response to a subscribe
                           unsubscribed - response to an unsubscribe

=head2 PresenceDB Functions

    PresenceDBParse(Net::Jabber::Presence) - for every presence that you 
                                             receive pass the Presence 
                                             object to the DB so that 
                                             it can track the resources 
                                             and priorities for you.

    PresenceDBDelete(string|Net::Jabber::JID) - delete thes JID entry
                                                from the DB.

    PresenceDBQuery(string|Net::Jabber::JID) - returns the NJ::Presence
                                               that was last received for
                                               the highest priority of this
                                               JID.  You can pass it a
                                               string or a NJ::JID object.

    PresenceDBResources(string|Net::Jabber::JID) - returns an array of 
                                                   resources in order
                                                   from highest priority 
                                                   to lowest.

=head2 IQ Functions

=head2 IQ::Agents Functions

    AgentsGet(to=>string, - takes all of the information and
    AgentsGet()             builds a Net::Jabber::IQ::Agents packet.
                            It then sends that packet either to the
                            server, or to the specified transport,
                            with an ID and waits for that ID to return.
                            Then it looks in the resulting packet and 
                            builds a hash that contains the values
                            of the agent list.  The hash is layed out
                            like this:  (NOTE: the jid is the key to
                            distinguish the various agents)

                              $hash{<JID>}->{order} = 4
                                          ->{name} = "ICQ Transport"
                                          ->{transport} = "ICQ #"
                                          ->{description} = "ICQ...blah..."
                                          ->{service} = "icq"
                                          ->{register} = 1
                                          ->{search} = 1
                                        etc...

                            The order field determines the order that
                            it came from the server in... in case you
                            care.  For more info on the valid fields 
                            see the Net::Jabber::Query::Agent module.

=head2 IQ::Auth Functions

    AuthSend(username=>string, - takes all of the information and
             password=>string,   builds a Net::Jabber::IQ::Auth packet.
             resource=>string)   It then sends that packet to the
    AuthSend()                   server with an ID and waits for that
                                 ID to return.  Then it looks in
                                 resulting packet and determines if
                                 authentication was successful for not.
                                 If no hash is passed then it tries
                                 to open an anonymous session.  The
                                 array returned from AuthSend looks
                                 like this:
                                   [ type , message ]
                                 If type is "ok" then authentication
                                 was successful, otherwise message
                                 contains a little more detail about the
                                 error.

=head2 IQ::Fneg Functions

    n/a

=head2 IQ::Info Functions

    n/a

=head2 IQ::Register Functions

    RegisterRequest(to=>string) - send an <iq/> request to the specified
    RegisterRequest()             server/transport, if not specified it
                                  sends to the current active server.
                                  The function returns a hash that
                                  contains the required fields.   Here
                                  is an example of the hash:

	                             $fields{intructions} = "do this..."
                                     $fields{key} = "some key"
                                     $fields{username} = ""
                                     ...

                                  The fields that are present are the
                                  required fields the server needs.

    RegisterSend(hash) - takes the contents of the hash and passes it
	                 to the SetRegister function in the module
                         Net::Jabber::Query::Register.  This function
	                 returns an array that looks like this:
  
                            [ type , message ]

                         If type is "ok" then registration was 
                         successful, otherwise message contains a 
                         little more detail about the error.

=head2 IQ::Resource Functions

    n/a

=head2 IQ::Roster Functions

    RosterParse(IQ object) - returns a hash that contains the roster
                             parsed into the following data structure:

                  $roster{'bob@jabber.org'}->{name}         
                                      - Name you stored in the roster

                  $roster{'bob@jabber.org'}->{subscription} 
                                      - Subscription status 
                                        (to, from, both, none)

		  $roster{'bob@jabber.org'}->{ask}
                                      - The ask status from this user 
                                        (subscribe, unsubscribe)

		  $roster{'bob@jabber.org'}->{groups}
                                      - Array of groups that 
                                        bob@jabber.org is in

    RosterGet() - sends an empty Net::Jabber::IQ::Roster tag to the
                  server so the server will send the Roster to the
                  client.  Returns the above hash from RosterParse.
			  
    RosterAdd(hash) - sends a packet asking that the jid be
                      added to the roster.  The hash format
	              is defined in the SetItem function
                      in the Net::Jabber::Query::Roster::Item
                      module.

    RosterRemove(hash) - sends a packet asking that the jid be
                         removed from the roster.  The hash
	                 format is defined in the SetItem function
                         in the Net::Jabber::Query::Roster::Item
                         module.

=head2 IQ::Search Functions

    SearchRequest(to=>string) - send an <iq/> request to the specified
    SearchRequest()             server/transport, if not specified it
                                sends to the current active server.
                                The function returns a hash that
                                contains the required fields.   Here
                                is an example of the hash:

	                           $fields{intructions} = "do this..."
                                   $fields{key} = "some key"
                                   $fields{name} = ""
                                   ...

                                The fields that are present are the
                                required fields the server needs.  If
                                the hash is undefined then there was
                                an error with the request.

    SearchSend(to=>string|JID, - takes the contents of the hash and 
	       hash)             passes it to the SetSearch function
                                 in the module Net::Jabber::Query::Search.
                                 And then send the packet.

=head2 IQ::Time Functions

    TimeQuery(to=>string) - asks the jid specified for its local time.
    TimeQuery()             If the to is blank, then it queries the
                            server.  Returns a hash with the various 
                            items set:

                              $time{utc}     - Time in UTC
                              $time{tz}      - Timezone
                              $time{display} - Display string

    TimeSend(to=>string) - sends the current UTC time to the specified
                           jid.

=head2 IQ::Version Functions

    VersionQuery(to=>string) - asks the jid specified for its client
    VersionQuery()             version information.  If the to is blank,
                               then it queries the server.  Returns a
                               hash with the various items set:

                                 $version{name} - Name
                                 $version{ver}  - Version
                                 $version{os}   - Operating System/Platform

    VersionSend(to=>string,   - sends the specified version information
                name=>string,   to the jid specified in the to.
                ver=>string,
                os=>string)

=head2 X Functions

=head1 AUTHOR

Revised by Ryan Eatmon in December 1999.

By Thomas Charron in July of 1999 for http://jabber.org..

Based on a screenplay by Jeremie Miller in May of 1999
for http://jabber.org/

=head1 COPYRIGHT

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use vars qw($VERSION);

$VERSION = "1.0013";

sub new {
  my $proto = shift;
  my $self = { };

  $self->{VERSION} = $VERSION;
  
  bless($self, $proto);
  return $self;
}


##############################################################################
#
# GetErrorCode - if you are returned an undef, you can call this function
#                and hopefully learn more information about the problem.
#
##############################################################################
sub GetErrorCode {
  shift;
  my $self = shift;
  return ((exists($self->{ERRORCODE}) && ($self->{ERRORCODE} ne "")) ? 
	  $self->{ERRORCODE} : 
	  $!
	 );
}


##############################################################################
#
# SetErrorCode - sets the error code so that the caller can find out more
#                information about the problem
#
##############################################################################
sub SetErrorCode {
  shift;
  my $self = shift;
  my ($errorcode) = @_;
  $self->{ERRORCODE} = $errorcode;
}


###########################################################################
#
# CallBack - Central callback function.  If a packet comes back with an ID
#            and the tag and ID have been registered then the packet is not
#            returned as normal, instead it is inserted in the LIST and
#            stored until the user wants to fetch it.  If the tag and ID
#            are not registered the function checks if a callback exists 
#            for this tag, if it does then that callback is called, 
#            otherwise the function drops the packet since it does not know
#            how to handle it.
#
###########################################################################
sub CallBack {
  shift;
  my $self = shift;
  my (@object) = @_;

  $self->{DEBUG}->Log1("CallBack: received(",&Net::Jabber::BuildXML(@object),")");

  my $tag = $object[0];
  my $id = "";
  $id = $object[1]->[0]->{id} if (exists($object[1]->[0]->{id}));

  $self->{DEBUG}->Log1("CallBack: tag($tag)");
  $self->{DEBUG}->Log1("CallBack: id($id)") if ($id ne "");

  if ($self->CheckID($tag,$id)) {
    $self->{DEBUG}->Log1("CallBack: found registry entry: tag($tag) id($id)");
    $self->DeregisterID($tag,$id);
    my $NJObject;
    $NJObject = new Net::Jabber::IQ(@object) 
      if ($tag eq "iq");
    $NJObject = new Net::Jabber::Presence(@object) 
      if ($tag eq "presence");
    $NJObject = new Net::Jabber::Message(@object) 
      if ($tag eq "message");
    $self->GotID($object[1]->[0]->{id},$NJObject);
  } else {
    $self->{DEBUG}->Log1("CallBack: no registry entry");  
    if (exists($self->{CB}->{$tag})) {
      $self->{DEBUG}->Log1("CallBack: goto user function($self->{CB}->{$tag})");
      &{$self->{CB}->{$tag}}(@object);
    } else {
      $self->{DEBUG}->Log1("CallBack: no defined function.  Dropping packet.");
    }
  }
}


###########################################################################
#
# SetCallBacks - Takes a hash with top level tags to look for as the keys
#                and pointers to functions as the values.  The functions
#                are called and passed the XML::Parser::Tree objects
#                generated by XML::Stream.
#
###########################################################################
sub SetCallBacks {
  shift;
  my $self = shift;
  while($#_ >= 0) {
    my $func = pop(@_);
    my $tag = pop(@_);
    $self->{DEBUG}->Log1("SetCallBacks: tag($tag) func($func)");
    $self->{CB}{$tag} = $func;
  }
}


###########################################################################
#
#  Process - If a timeout value is specified then the function will wait
#            that long before returning.  This is useful for apps that
#            need to handle other processing while still waiting for
#            packets.  If no timeout is listed then the function waits
#            until a packet is returned.  Either way the function exits 
#            as soon as a packet is returned.
#
###########################################################################
sub Process {
  shift;
  my $self = shift;
  my ($timeout) = @_;
  my ($status);

  $self->{DEBUG}->Log1("Process: timeout($timeout)");

  if (!defined($timeout) || ($timeout eq "")) {
    while(1) {
      $status = $self->{STREAM}->Process();
      last if (($status != 0) || ($status eq ""));
      select(undef,undef,undef,.25);
    }
    $self->{DEBUG}->Log1("Process: return($status)");
    return $status;
  } else {
    return $self->{STREAM}->Process($timeout);
  }
}


###########################################################################
#
# Send - Takes either XML or a Net::Jabber::xxxx object and sends that
#        packet to the server.
#
###########################################################################
sub Send {
  shift;
  my $self = shift;
  my $object = shift;

  if (ref($object) eq "") {
    $self->SendXML($object);
  } else {
    $self->SendXML($object->GetXML());
  }
}


###########################################################################
#
# SendXML - Sends the XML packet to the server
#
###########################################################################
sub SendXML {
  shift;
  my $self = shift;
  my($xml) = @_;
  $self->{DEBUG}->Log1("SendXML: sent($xml)");
  $self->{STREAM}->Send($xml);
}


###########################################################################
#
# SendWithID - Take either XML or a Net::Jabber::xxxx object and send it
#              with the next available ID number.  Then return that ID so
#              the client can track it.
#
###########################################################################
sub SendWithID {
  shift;
  my $self = shift;
  my ($object) = @_;

  #------------------------------------------------------------------------
  # Take the current XML stream and insert an id attrib at the top level.
  #------------------------------------------------------------------------
  my $currentID = $self->{LIST}->{currentID};

  my $xml;
  if (ref($object) eq "") {
    $xml = $object;
    $xml =~ s/^(\<[^\>]+)(\>)/$1 id\=\'$currentID\'$2/;
    my ($tag) = ($xml =~ /^\<(\S+)\s/);
    $self->RegisterID($tag,$currentID);
  } else {
    $object->SetID($currentID);
    $xml = $object->GetXML();
    $self->RegisterID($object->GetTag(),$currentID);
  }

  #------------------------------------------------------------------------
  # Send the new XML string.
  #------------------------------------------------------------------------
  $self->SendXML($xml);

  #------------------------------------------------------------------------
  # Increment the currentID and return the ID number we just assigned.
  #------------------------------------------------------------------------
  $self->{LIST}->{currentID}++;
  return $currentID;
}


###########################################################################
#
# SendAndReceiveWithID - Take either XML or a Net::Jabber::xxxxx object and
#                        send it with the next ID.  Then wait for that ID
#                        to come back and return the response in a
#                        Net::Jabber::xxxx object.
#
###########################################################################
sub SendAndReceiveWithID {
  shift;
  my $self = shift;
  my ($object) = @_;

  my $id = $self->SendWithID($object);
  return $self->WaitForID($id);
}


###########################################################################
#
# ReceivedID - returns 1 if a packet with the ID has been received, or 0
#              if it has not.
#
###########################################################################
sub ReceivedID {
  shift;
  my $self = shift;
  my ($id) = @_;

  return 1 if exists($self->{LIST}->{$id});
  return 0;
}


###########################################################################
#
# GetID - Return the Net::Jabber::xxxxx object that is stored in the LIST
#         that matches the ID if that ID exists.  Otherwise return 0.
#
###########################################################################
sub GetID {
  shift;
  my $self = shift;
  my ($id) = @_;

  return $self->{LIST}->{$id} if $self->ReceivedID($id);
  return 0;
}


###########################################################################
#
# WaitForID - Keep looping and calling Process(1) to poll every second
#             until the response from the server occurs.
#
###########################################################################
sub WaitForID {
  shift;
  my $self = shift;
  my ($id) = @_;
  
  while(!$self->ReceivedID($id)) {
    return undef unless (defined($self->Process(0)));
  }
  return $self->GetID($id);
}


###########################################################################
#
# GotID - Callback to store the Net::Jabber::xxxxx object in the LIST at
#         the ID index.  This is a private helper function.
#
###########################################################################
sub GotID {
  shift;
  my $self = shift;
  my ($id,$object) = @_;

  $self->{LIST}->{$id} = $object;
}


###########################################################################
#
# CheckID - Checks the ID registry if this tag and ID have been registered.
#           0 = no, 1 = yes
#
###########################################################################
sub CheckID {
  shift;
  my $self = shift;
  my ($tag,$id) = @_;
  $id = "" unless defined($id);
  return 0 if ($id eq "");
  return exists($self->{IDRegistry}->{$tag}->{$id});
}


###########################################################################
#
# RegisterID - Register the tag and ID in the registry so that the CallBack
#              can know what to put in the ID list and what to pass on.
#
###########################################################################
sub RegisterID {
  shift;
  my $self = shift;
  my ($tag,$id) = @_;

  $self->{IDRegistry}->{$tag}->{$id} = 1;
}


###########################################################################
#
# DeregisterID - Delete the tag and ID in the registry so that the CallBack
#                can knows that it has been received.
#
###########################################################################
sub DeregisterID {
  shift;
  my $self = shift;
  my ($tag,$id) = @_;

  delete($self->{IDRegistry}->{$tag}->{$id});
}


##############################################################################
#
# AddDelegate - adds the namespace and corresponding pacakge onto the list
#               of availbale delegates based on the namespace.
#
##############################################################################
sub AddDelegate {
  my $self = shift;
  my %delegates;
  while($#_ >= 0) { $delegates{ lc pop(@_) } = pop(@_); }

  $Net::Jabber::DELEGATES{$delegates{namespace}}->{parent} = $delegates{parent};
  $Net::Jabber::DELEGATES{$delegates{namespace}}->{delegate} = $delegates{delegate};
}



###########################################################################
#
# MessageSend - Takes the same hash that Net::Jabber::Message->SetMessage
#               takes and sends the message to the server.
#
###########################################################################
sub MessageSend {
  shift;
  my $self = shift;

  my $mess = new Net::Jabber::Message();
  $mess->SetMessage(@_);
  $self->Send($mess);
}


###########################################################################
#
# PresenceDBParse - adds the presence information to the Presence DB so
#                   you can keep track of the current state of the JID and
#                   all of it's resources.
#
###########################################################################
sub PresenceDBParse {
  shift;
  my $self = shift;
  my ($presence) = @_;

  my $type = $presence->GetType();
  return unless (($type eq "") || 
		 ($type eq "available") || 
		 ($type eq "unavailable"));

  my $fromJID = $presence->GetFrom("jid");
  my $fromID = $fromJID->GetJID();
  my $resource = $fromJID->GetResource();
  $resource = " " unless ($resource ne "");
  my $priority = $presence->GetPriority();

  $self->{DEBUG}->Log1("PresenceDBParse: fromJID(",$fromJID->GetJID("full"),") resource($resource) priority($priority) type($type)"); 
  $self->{DEBUG}->Log2("PresenceDBParse: xml(",$presence->GetXML(),")");

  if (exists($self->{PRESENCEDB}->{$fromID})) {

    my $oldPriority = $self->{PRESENCEDB}->{$fromID}->{resources}->{$resource};


    my $loc;
    my $index;
    foreach $index (0..$#{$self->{PRESENCEDB}->{$fromID}->{priorities}->{$oldPriority}}) {
      $loc = $index
	if ($self->{PRESENCEDB}->{$fromID}->{priorities}->{$oldPriority}->[$index]->{resource} eq $resource);
    }
    splice(@{$self->{PRESENCEDB}->{$fromID}->{priorities}->{$oldPriority}},$loc,1);
    delete($self->{PRESENCEDB}->{$fromID}->{resources}->{$resource});
    delete($self->{PRESENCEDB}->{$fromID}->{priorities}->{$oldPriority})
      if ($#{$self->{PRESENCEDB}->{$fromID}->{priorities}->{$oldPriority}} == -1);
    delete($self->{PRESENCEDB}->{$fromID})
      if (scalar(keys(%{$self->{PRESENCEDB}->{$fromID}})) == 0);

    $self->{DEBUG}->Log1("PresenceDBParse: remove ",$fromJID->GetJID("full")," from the DB"); 
  }


  if (($type eq "") || ($type eq "available")) {
    my $loc = -1;
    my $index;
    foreach $index (0..$#{$self->{PRESENCEDB}->{$fromID}->{priorities}->{$priority}}) {
      $loc = $index
	if ($self->{PRESENCEDB}->{$fromID}->{priorities}->{$priority}->[$index]->{resource} eq $resource);
    }
    $loc = $#{$self->{PRESENCEDB}->{$fromID}->{priorities}->{$priority}}+1
      if ($loc == -1);
    $self->{PRESENCEDB}->{$fromID}->{resources}->{$resource} = $priority;
    $self->{PRESENCEDB}->{$fromID}->{priorities}->{$priority}->[$loc]->{presence} = 
      $presence;
    $self->{PRESENCEDB}->{$fromID}->{priorities}->{$priority}->[$loc]->{resource} = 
      $resource;

    $self->{DEBUG}->Log1("PresenceDBParse: add ",$fromJID->GetJID("full")," to the DB"); 
  }
}


###########################################################################
#
# PresenceDBDelete - delete the JID from the DB completely.
#
###########################################################################
sub PresenceDBDelete {
  shift;
  my $self = shift;
  my ($jid) = @_;
  
  if (ref($jid) eq "Net::Jabber::JID") {
    return if !exists($self->{PRESENCEDB}->{$jid->GetJID()});
    delete($self->{PRESENCEDB}->{$jid->GetJID()});
    $self->{DEBUG}->Log1("PresenceDBDelete: delete ",$jid->GetJID()," from the DB"); 
  } else {
    return if !exists($self->{PRESENCEDB}->{$jid});
    delete($self->{PRESENCEDB}->{$jid});
    $self->{DEBUG}->Log1("PresenceDBDelete: delete ",$jid," from the DB"); 
  }
}


###########################################################################
#
# PresenceDBQuery - retrieve the last Net::Jabber::Presence received with
#                  the highest priority.
#
###########################################################################
sub PresenceDBQuery {
  shift;
  my $self = shift;
  my ($jid) = @_;

  if (ref($jid) eq "Net::Jabber::JID") {
    return if !exists($self->{PRESENCEDB}->{$jid->GetJID()});

    my $highPriority = 
      (sort {$b cmp $a} keys(%{$self->{PRESENCEDB}->{$jid->GetJID()}->{priorities}}))[0];
    
    return $self->{PRESENCEDB}->{$jid->GetJID()}->{priorities}->{$highPriority}->[0]->{presence};
  } else {
    return if !exists($self->{PRESENCEDB}->{$jid});

    my $highPriority = 
      (sort {$b cmp $a} keys(%{$self->{PRESENCEDB}->{$jid}->{priorities}}))[0];
    
    return $self->{PRESENCEDB}->{$jid}->{priorities}->{$highPriority}->[0]->{presence};
  }
}


###########################################################################
#
# PresenceDBResources - returns a list of the resources from highest
#                       priority to lowest.
#
###########################################################################
sub PresenceDBResources {
  shift;
  my $self = shift;
  my ($jid) = @_;

  my @resources;

  if (ref($jid) eq "Net::Jabber::JID") {
    return if !exists($self->{PRESENCEDB}->{$jid->GetJID()});

    my $priority;
    foreach $priority (sort {$b cmp $a} keys(%{$self->{PRESENCEDB}->{$jid->GetJID()}->{priorities}})) {
      my $index;
      foreach $index (0..$#{$self->{PRESENCEDB}->{$jid->GetJID()}->{priorities}->{$priority}}) {
	next if ($self->{PRESENCEDB}->{$jid->GetJID()}->{priorities}->{$priority}->[$index]->{resource} eq " ");
	push(@resources,$self->{PRESENCEDB}->{$jid->GetJID()}->{priorities}->{$priority}->[$index]->{resource});
      }	
    }
  } else {
    return if !exists($self->{PRESENCEDB}->{$jid});

    my $priority;
    foreach $priority (sort {$b cmp $a} keys(%{$self->{PRESENCEDB}->{$jid}->{priorities}})) {
      my $index;
      foreach $index (0..$#{$self->{PRESENCEDB}->{$jid}->{priorities}->{$priority}}) {
	next if ($self->{PRESENCEDB}->{$jid}->{priorities}->{$priority}->[$index]->{resource} eq " ");
	push(@resources,$self->{PRESENCEDB}->{$jid}->{priorities}->{$priority}->[$index]->{resource});
      }	
    }
  }
  return @resources;
}


###########################################################################
#
# PresenceSend - Sends a presence tag to announce your availability
#
###########################################################################
sub PresenceSend {
  shift;
  my $self = shift;
  my $presence = new Net::Jabber::Presence();
  $presence->SetPresence(@_);
  $self->Send($presence);
}


###########################################################################
#
# PresenceProbe - Sends a presence probe to the server
#
###########################################################################
sub PresenceProbe {
  shift;
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }
  delete($args{type});

  my $presence = new Net::Jabber::Presence();
  $presence->SetPresence(type=>"probe",
			 %args);
  $self->Send($presence);
}


###########################################################################
#
# Subscription - Sends a presence tag to perform the subscription on the
#                specified JID.
#
###########################################################################
sub Subscription {
  shift;
  my $self = shift;

  my $presence = new Net::Jabber::Presence();
  $presence->SetPresence(@_);
  $self->Send($presence);
}


###########################################################################
#
# AgentsGet - Sends an empty IQ to the server/transport to request that the
#             list of supported Agents be sent to them.  Returns a hash
#             containing the values for the agents.
#
###########################################################################
sub AgentsGet {
  shift;
  my $self = shift;

  my $iq = new Net::Jabber::IQ;
  $iq->SetIQ(@_);
  $iq->SetIQ(type=>"get");
  my $query = $iq->NewQuery("jabber:iq:agents");

  $iq = $self->SendAndReceiveWithID($iq);

  $query = $iq->GetQuery();
  my @agents = $query->GetAgents();

  my %agents;
  my $agent;
  my $count = 0;
  foreach $agent (@agents) {
    my $jid = $agent->GetJID();
    $agents{$jid}->{name} = $agent->GetName();
    $agents{$jid}->{description} = $agent->GetDescription();
    $agents{$jid}->{transport} = $agent->GetTransport();
    $agents{$jid}->{service} = $agent->GetService();
    $agents{$jid}->{register} = $agent->GetRegister();
    $agents{$jid}->{search} = $agent->GetSearch();
    $agents{$jid}->{groupchat} = $agent->GetGroupChat();
    $agents{$jid}->{agents} = $agent->GetAgents();
    $agents{$jid}->{order} = $count++;
  }

  return %agents;
}


###########################################################################
#
# AuthSend - This is a self contained function to send a login iq tag with
#            an id.  Then wait for a reply what the same id to come back 
#            and tell the caller what the result was.
#
###########################################################################
sub AuthSend {
  shift;
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  #------------------------------------------------------------------------
  # If we have access to the SHA-1 digest algorithm then let's use it.
  # Remove the password fro the hash, create the digest, and put the
  # digest in the hash instead.
  #
  # Note: Concat the Session ID and the password and then digest that
  # string to get the server to accept the digest.
  #------------------------------------------------------------------------
  if ($self->{DIGEST} == 1) {
    if (exists($args{password})) {
      my $password = delete($args{password});
      my $digest = Digest::SHA1::sha1_hex($self->{SESSION}->{id}.$password);
      $args{digest} = $digest;
    }
  }

  #------------------------------------------------------------------------
  # Create a Net::Jabber::IQ object to send to the server
  #------------------------------------------------------------------------
  my $IQLogin = new Net::Jabber::IQ();
  my $IQAuth = $IQLogin->NewQuery("jabber:iq:auth");
  $IQAuth->SetAuth(%args);

  #------------------------------------------------------------------------
  # Send the IQ with the next available ID and wait for a reply with that 
  # id to be received.  Then grab the IQ reply.
  #------------------------------------------------------------------------
  $IQLogin = $self->SendAndReceiveWithID($IQLogin);

  #------------------------------------------------------------------------
  # From the reply IQ determine if we were successful or not.  If yes then 
  # return "".  If no then return error string from the reply.
  #------------------------------------------------------------------------
  return ( $IQLogin->GetErrorCode() , $IQLogin->GetError() )
    if ($IQLogin->GetType() eq "error");
  return ("ok","");
}


###########################################################################
#
# RegisterRequest - This is a self contained function to send an iq tag
#                   an id that requests the target address to send back
#                   the required fields.  It waits for a reply what the
#                   same id to come back and tell the caller what the 
#                   fields are.
#
###########################################################################
sub RegisterRequest {
  shift;
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  #------------------------------------------------------------------------
  # Create a Net::Jabber::IQ object to send to the server
  #------------------------------------------------------------------------
  my $IQ = new Net::Jabber::IQ();
  $IQ->SetIQ(to=>delete($args{to})) if exists($args{to});
  $IQ->SetIQ(type=>"get");
  my $IQRegister = $IQ->NewQuery("jabber:iq:register");

  #------------------------------------------------------------------------
  # Send the IQ with the next available ID and wait for a reply with that 
  # id to be received.  Then grab the IQ reply.
  #------------------------------------------------------------------------
  $IQ = $self->SendAndReceiveWithID($IQ);
  
  #------------------------------------------------------------------------
  # Check if there was an error.
  #------------------------------------------------------------------------
  if ($IQ->GetType() eq "error") {
    $self->SetErrorCode($IQ->GetErrorCode().": ".$IQ->GetError());
    return;
  }

  #------------------------------------------------------------------------
  # From the reply IQ determine what fields are required and send a hash
  # back with the fields and any values that are already defined (like key)
  #------------------------------------------------------------------------
  $IQRegister = $IQ->GetQuery();
  return %{$IQRegister->GetFields()};
}


###########################################################################
#
# RegisterSend - This is a self contained function to send a registration
#                iq tag with an id.  Then wait for a reply what the same
#                id to come back and tell the caller what the result was.
#
###########################################################################
sub RegisterSend {
  shift;
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  #------------------------------------------------------------------------
  # Create a Net::Jabber::IQ object to send to the server
  #------------------------------------------------------------------------
  my $IQ = new Net::Jabber::IQ();
  $IQ->SetIQ(to=>delete($args{to})) if exists($args{to});
  $IQ->SetIQ(type=>"set");
  my $IQRegister = $IQ->NewQuery("jabber:iq:register");
  $IQRegister->SetRegister(%args);

  #------------------------------------------------------------------------
  # Send the IQ with the next available ID and wait for a reply with that 
  # id to be received.  Then grab the IQ reply.
  #------------------------------------------------------------------------
  $IQ = $self->SendAndReceiveWithID($IQ);
  
  #------------------------------------------------------------------------
  # From the reply IQ determine if we were successful or not.  If yes then 
  # return "".  If no then return error string from the reply.
  #------------------------------------------------------------------------
  return ( $IQ->GetErrorCode() , $IQ->GetError() )
    if ($IQ->GetType() eq "error");
  return ("ok","");
}


###########################################################################
#
# RosterAdd - Takes the Jabber ID of the user to add to their Roster and
#             sends the IQ packet to the server.
#
###########################################################################
sub RosterAdd {
  shift;
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  my $iq = new Net::Jabber::IQ();
  $iq->SetIQ(type=>"set");
  my $roster = $iq->NewQuery("jabber:iq:roster");
  my $item = $roster->AddItem();
  $item->SetItem(%args);

  $self->{DEBUG}->Log1("RosterAdd: xml(",$iq->GetXML(),")");
  $self->Send($iq);
}


###########################################################################
#
# RosterAdd - Takes the Jabber ID of the user to remove from their Roster
#             and sends the IQ packet to the server.
#
###########################################################################
sub RosterRemove {
  shift;
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }
  delete($args{subscription});

  my $iq = new Net::Jabber::IQ();
  $iq->SetIQ(type=>"set");
  my $roster = $iq->NewQuery("jabber:iq:roster");
  my $item = $roster->AddItem();
  $item->SetItem(%args,
		 subscription=>"remove");
  $self->Send($iq);
}


###########################################################################
#
# RosterParse - Returns a hash of roster items.
#
###########################################################################
sub RosterParse {
  shift;
  my $self = shift;
  my($iq) = @_;

  my $query = $iq->GetQuery();
  my @items = $query->GetItems();

  my %roster;
  my $item;
  foreach $item (@items) {
    my $jid = $item->GetJID();
    $roster{$jid}->{name} = $item->GetName();
    $roster{$jid}->{subscription} = $item->GetSubscription();
    $roster{$jid}->{ask} = $item->GetAsk();
    $roster{$jid}->{groups} = [ $item->GetGroups() ];
  }

  return %roster;
}


###########################################################################
#
# RosterGet - Sends an empty IQ to the server to request that the user's
#             Roster be sent to them.  Returns a hash of roster items.
#
###########################################################################
sub RosterGet {
  shift;
  my $self = shift;

  my $iq = new Net::Jabber::IQ;
  $iq->SetIQ(type=>"get");
  my $query = $iq->NewQuery("jabber:iq:roster");

  $iq = $self->SendAndReceiveWithID($iq);

  return $self->RosterParse($iq);
}


###########################################################################
#
# SearchRequest - This is a self contained function to send an iq tag
#                 an id that requests the target address to send back
#                 the required fields.  It waits for a reply what the
#                 same id to come back and tell the caller what the 
#                 fields are.
#
###########################################################################
sub SearchRequest {
  shift;
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  #------------------------------------------------------------------------
  # Create a Net::Jabber::IQ object to send to the server
  #------------------------------------------------------------------------
  my $IQ = new Net::Jabber::IQ();
  $IQ->SetIQ(to=>delete($args{to})) if exists($args{to});
  $IQ->SetIQ(type=>"get");
  my $IQSearch = $IQ->NewQuery("jabber:iq:search");

  $self->{DEBUG}->Log1("SearchRequest: sent(",$IQ->GetXML(),")");

  #------------------------------------------------------------------------
  # Send the IQ with the next available ID and wait for a reply with that 
  # id to be received.  Then grab the IQ reply.
  #------------------------------------------------------------------------
  $IQ = $self->SendAndReceiveWithID($IQ);
  
  $self->{DEBUG}->Log1("SearchRequest: received(",$IQ->GetXML(),")");

  #------------------------------------------------------------------------
  # Check if there was an error.
  #------------------------------------------------------------------------
  if ($IQ->GetType() eq "error") {
    $self->SetErrorCode($IQ->GetErrorCode().": ".$IQ->GetError());
    $self->{DEBUG}->Log1("SearchRequest: error(",$self->GetErrorCode(),")");
    return;
  }

  #------------------------------------------------------------------------
  # From the reply IQ determine what fields are required and send a hash
  # back with the fields and any values that are already defined (like key)
  #------------------------------------------------------------------------
  $IQSearch = $IQ->GetQuery();
  $self->{DEBUG}->Log1("SearchRequest: return(",\%{$IQSearch->GetFields()},")");
  return %{$IQSearch->GetFields()};
}


###########################################################################
#
# SearchSend - This is a self contained function to send a search
#              iq tag with an id.  Then wait for a reply what the same
#              id to come back and tell the caller what the result was.
#
###########################################################################
sub SearchSend {
  shift;
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  #------------------------------------------------------------------------
  # Create a Net::Jabber::IQ object to send to the server
  #------------------------------------------------------------------------
  my $IQ = new Net::Jabber::IQ();
  $IQ->SetIQ(to=>delete($args{to})) if exists($args{to});
  $IQ->SetIQ(type=>"set");
  my $IQSearch = $IQ->NewQuery("jabber:iq:search");
  $IQSearch->SetSearch(%args);

  #------------------------------------------------------------------------
  # Send the IQ with the next available ID and wait for a reply with that 
  # id to be received.  Then grab the IQ reply.
  #------------------------------------------------------------------------
  $self->Send($IQ);
}


###########################################################################
#
# TimeQuery - Sends an iq:time query to either the server or the specified
#             JID.
#
###########################################################################
sub TimeQuery {
  shift;
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  my $iq = new Net::Jabber::IQ();
  $iq->SetIQ(to=>delete($args{to})) if exists($args{to});
  $iq->SetIQ(type=>'get');
  my $time = $iq->NewQuery("jabber:iq:time");

  $self->Send($iq);
}


###########################################################################
#
# TimeSend - sends an iq:time packet to the specified user.
#
###########################################################################
sub TimeSend {
  shift;
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  my $iq = new Net::Jabber::IQ();
  $iq->SetIQ(to=>delete($args{to}),
	     type=>'result');
  my $time = $iq->NewQuery("jabber:iq:time");
  $time->SetTime(%args);

  $self->Send($iq);
}



###########################################################################
#
# VersionQuery - Sends an iq:version query to either the server or the 
#                specified JID.
#
###########################################################################
sub VersionQuery {
  shift;
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  my $iq = new Net::Jabber::IQ();
  $iq->SetIQ(to=>delete($args{to})) if exists($args{to});
  $iq->SetIQ(type=>'get');
  my $version = $iq->NewQuery("jabber:iq:version");

  $self->Send($iq);
}


###########################################################################
#
# VersionSend - sends an iq:version packet to the specified user.
#
###########################################################################
sub VersionSend {
  shift;
  my $self = shift;
  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }

  my $iq = new Net::Jabber::IQ();
  $iq->SetIQ(to=>delete($args{to}),
	     type=>'result');
  my $version = $iq->NewQuery("jabber:iq:version");
  $version->SetVersion(%args);

  $self->Send($iq);
}


1;
