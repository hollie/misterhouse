package Net::Jabber;

#
# 09/04/00 winter :: modified to not require Unicode on pre 5.6 perl
#                    Could not find a 5.6 windows binary for Unicode::String xsub :(

=head1 NAME

Net::Jabber - Jabber Perl Library

=head1 SYNOPSIS

  Net::Jabber provides a Perl user with access to the Jabber
  Instant Messaging protocol.

  For more information about Jabber visit: 
 
    http://www.jabber.org

=head1 DESCRIPTION

  Net::Jabber is a convenient tool to use for any perl scripts
  that would like to utilize the Jabber Instant Messaging 
  protocol.  While not a client in and of itself, it provides 
  all of the necessary back-end functions to make a CGI client 
  or command-line perl client feasible and easy to use.  
  Net::Jabber is a wrapper around the rest of the official
  Net::Jabber::xxxxxx packages.  

  There is an example script, client.pl, that provides you with
  an example a very simple Jabber client that logs a user in and
  displays any messages they receive.  

  There is also an example transport script, transport.pl,
  that shows how to write a transport that gets a message,
  converts the entire message to uppercase, and send it back
  to the sender.

=head1 PACKAGES

  Net::Jabber::Client - this package contains the code needed to
  communicate with a Jabber server: login, wait for messages,
  send messages, and logout.  It uses XML::Stream to read the 
  stream from the server and based on what kind of tag it 
  encounters it calls a function to handle the tag.

  Net::Jabber::Transport - this package contains the code needed
  to write a transport.  A transport is a program tha handles
  the communication between a jabber server and some outside
  program or communications pacakge (IRC, talk, email, etc...)
  With this module you can write a full transport in just
  a few lines of Perl.  It uses XML::Stream to communicate with 
  its host server and based on what kind of tag it encounters it 
  calls a function to handle the tag.

  Net::Jabber::Protocol - a collection of high-level functions
  that Client and transport use to make their lives easier.
  These functions are included through AUTOLOAD and delegates.

  Net::Jabber::JID - the Jabber IDs consist of three parts:
  user id, server, and resource.  This module gives you access
  to those components without having to parse the string
  yourself.

  Net::Jabber::Message - everything needed to create and read
  a <message/> received from the server.

  Net::Jabber::Presence - everything needed to create and read
  a <presence/> received from the server.

  Net::Jabber::IQ - IQ is a wrapper around a number of modules
  that provide support for the various Info/Query namespaces that 
  Jabber recognizes.

  Net::Jabber::Query - this module uses delegates and autoloading
  to provide access to all of the Query modules listed below.

  Net::Jabber::Query::Agent - provides access to the information
  about an agent that the server supports.

  Net::Jabber::Query::Agents - the list of agents, see agent above,
  that the server supports.

  Net::Jabber::Query::Auth - everything needed to authenticate a
  session to the server.

  Net::Jabber::Query::Fneg - feature negoation between the client
  and server.

  Net::Jabber::Query::Oob - support for out of bandwidth file
  transfers.

  Net::Jabber::Query::Register - everything needed to create a new
  Jabber account on the server.

  Net::Jabber::Query::Roster - everything needed to manage and query
  the server side Rosters.

  Net::Jabber::Query::Roster::Item - access to an item from the
  roster.

  Net::Jabber::Query::Time - exchange time information with the
  target recipient (either server or client).

  Net::Jabber::Query::Version - exchange version information with 
  the target recipient (either server or client).

  Net::Jabber::X::Delay - specifies the delays that the message 
  went through before begin delivered.

  Net::Jabber::X::Oob - out of bandwidth file transers.

  Net::Jabber::X::Roster - support for embedded roster items.

  Net::Jabber::X::Roster::Item - access to the item in a roster.


=head1 AUTHOR

By Ryan Eatmon in May of 2000 for http://perl.jabber.org/

=head1 COPYRIGHT

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

require 5.003;
use strict;
use Time::Local;
use Carp;
use vars qw($VERSION %DELEGATES $UNICODE);

if ($] >= 5.006) {
    $UNICODE = 1;
} else {
    eval 'require Unicode::String';
                                # If Unicode::String is not installed, skip unicode processing
    if ($@) {
        $UNICODE = 0;
    }
    else {
        $UNICODE = 2;
    }
}


$VERSION = "1.0013";

use Net::Jabber::Debug;
($Net::Jabber::JID::VERSION < $VERSION) &&
  die("Net::Jabber::JID $VERSION required--this is only version $Net::Jabber::JID::VERSION");

use Net::Jabber::JID;
($Net::Jabber::JID::VERSION < $VERSION) &&
  die("Net::Jabber::JID $VERSION required--this is only version $Net::Jabber::JID::VERSION");

use Net::Jabber::X;
($Net::Jabber::X::VERSION < $VERSION) &&
  die("Net::Jabber::X $VERSION required--this is only version $Net::Jabber::X::VERSION");

use Net::Jabber::Query;
($Net::Jabber::Query::VERSION < $VERSION) &&
  die("Net::Jabber::Query $VERSION required--this is only version $Net::Jabber::Query::VERSION");

use Net::Jabber::Message;
($Net::Jabber::Message::VERSION < $VERSION) &&
  die("Net::Jabber::Message $VERSION required--this is only version $Net::Jabber::Message::VERSION");

use Net::Jabber::IQ;
($Net::Jabber::IQ::VERSION < $VERSION) &&
  die("Net::Jabber::IQ $VERSION required--this is only version $Net::Jabber::IQ::VERSION");

use Net::Jabber::Presence;
($Net::Jabber::Presence::VERSION < $VERSION) &&
  die("Net::Jabber::Presence $VERSION required--this is only version $Net::Jabber::Presence::VERSION");

use Net::Jabber::Client;
($Net::Jabber::Client::VERSION < $VERSION) &&
  die("Net::Jabber::Client $VERSION required--this is only version $Net::Jabber::Client::VERSION");

use Net::Jabber::Transport;
($Net::Jabber::Transport::VERSION < $VERSION) &&
  die("Net::Jabber::Transport $VERSION required--this is only version $Net::Jabber::Transport::VERSION");


##############################################################################
#
# NameSpace delegates
#
##############################################################################
$DELEGATES{'jabber:iq:agent'}->{parent} = "Net::Jabber::Query";
$DELEGATES{'jabber:iq:agent'}->{delegate} = "Net::Jabber::Query::Agent";
$DELEGATES{'jabber:iq:agents'}->{parent} = "Net::Jabber::Query";
$DELEGATES{'jabber:iq:agents'}->{delegate} = "Net::Jabber::Query::Agents";
$DELEGATES{'jabber:iq:auth'}->{parent} = "Net::Jabber::Query";
$DELEGATES{'jabber:iq:auth'}->{delegate} = "Net::Jabber::Query::Auth";
$DELEGATES{'jabber:iq:autoupdate'}->{parent} = "Net::Jabber::Query";
$DELEGATES{'jabber:iq:autoupdate'}->{delegate} = "Net::Jabber::Query::AutoUpdate";
$DELEGATES{'jabber:iq:filter'}->{parent} = "Net::Jabber::Query";
$DELEGATES{'jabber:iq:filter'}->{delegate} = "Net::Jabber::Query::Filter";
$DELEGATES{'jabber:iq:fneg'}->{parent} = "Net::Jabber::Query";
$DELEGATES{'jabber:iq:fneg'}->{delegate} = "Net::Jabber::Query::Fneg";
$DELEGATES{'jabber:iq:oob'}->{parent} = "Net::Jabber::Query";
$DELEGATES{'jabber:iq:oob'}->{delegate} = "Net::Jabber::Query::Oob";
$DELEGATES{'jabber:iq:register'}->{parent} = "Net::Jabber::Query";
$DELEGATES{'jabber:iq:register'}->{delegate} = "Net::Jabber::Query::Register";
$DELEGATES{'jabber:iq:roster'}->{parent} = "Net::Jabber::Query";
$DELEGATES{'jabber:iq:roster'}->{delegate} = "Net::Jabber::Query::Roster";
$DELEGATES{'jabber:iq:search'}->{parent} = "Net::Jabber::Query";
$DELEGATES{'jabber:iq:search'}->{delegate} = "Net::Jabber::Query::Search";
$DELEGATES{'jabber:iq:time'}->{parent} = "Net::Jabber::Query";
$DELEGATES{'jabber:iq:time'}->{delegate} = "Net::Jabber::Query::Time";
$DELEGATES{'jabber:iq:version'}->{parent} = "Net::Jabber::Query";
$DELEGATES{'jabber:iq:version'}->{delegate} = "Net::Jabber::Query::Version";

$DELEGATES{'jabber:x:autoupdate'}->{parent} = "Net::Jabber::X";
$DELEGATES{'jabber:x:autoupdate'}->{delegate} = "Net::Jabber::X::AutoUpdate";
$DELEGATES{'jabber:x:delay'}->{parent} = "Net::Jabber::X";
$DELEGATES{'jabber:x:delay'}->{delegate} = "Net::Jabber::X::Delay";
$DELEGATES{'jabber:x:gc'}->{parent} = "Net::Jabber::X";
$DELEGATES{'jabber:x:gc'}->{delegate} = "Net::Jabber::X::GC";
#$DELEGATES{'jabber:x:ident'}->{parent} = "Net::Jabber::X";
#$DELEGATES{'jabber:x:ident'}->{delegate} = "Net::Jabber::X::Ident";
$DELEGATES{'jabber:x:oob'}->{parent}   = "Net::Jabber::X";
$DELEGATES{'jabber:x:oob'}->{delegate}   = "Net::Jabber::X::Oob";
$DELEGATES{'jabber:x:roster'}->{parent}   = "Net::Jabber::X";
$DELEGATES{'jabber:x:roster'} ->{delegate}  = "Net::Jabber::X::Roster";


##############################################################################
#
# SetXMLData - takes a host of arguments and sets a portion of the specified
#              XML::Parser::Tree object with that data.  The function works
#              in two modes "single" or "multiple".  "single" denotes that 
#              the function should locate the current tag that matches this 
#              data and overwrite it's contents with data passed in.  
#              "multiple" denotes that a new tag should be created even if 
#              others exist.
#
#              type    - single or multiple
#              XMLTree - pointer to XML::Parser::Tree
#              tag     - name of tag to create/modify (if blank assumes
#                        working with top level tag)
#              data    - CDATA to set for tag
#              attribs - attributes to ADD to tag
#
##############################################################################
sub SetXMLData {
  my ($type,$XMLTree,$tag,$data,$attribs) = @_;
  my ($key);

  if ($tag ne "") {
    if ($type eq "single") {
      my ($child);
      foreach $child (1..$#{$$XMLTree[1]}) {
	if ($$XMLTree[1]->[$child] eq $tag) {
	  if ($data ne "") {
	    #todo: add code to handle writing the cdata again and appending it.
	    $$XMLTree[1]->[$child+1]->[1] = 0;
	    $$XMLTree[1]->[$child+1]->[2] = &EscapeXML($data);
	  }
	  foreach $key (keys(%{$attribs})) {
	    $$XMLTree[1]->[$child+1]->[0]->{$key} = &EscapeXML($$attribs{$key});
	  }
	  return;
	}
      }
    }
    $$XMLTree[1]->[($#{$$XMLTree[1]}+1)] = $tag;
    $$XMLTree[1]->[($#{$$XMLTree[1]}+1)]->[0] = {};
    foreach $key (keys(%{$attribs})) {
      $$XMLTree[1]->[$#{$$XMLTree[1]}]->[0]->{$key} = &EscapeXML($$attribs{$key});
    }
    if ($data ne "") {
      $$XMLTree[1]->[$#{$$XMLTree[1]}]->[1] = 0;
      $$XMLTree[1]->[$#{$$XMLTree[1]}]->[2] = &EscapeXML($data);
    }
  } else {
    foreach $key (keys(%{$attribs})) {
      $$XMLTree[1]->[0]->{$key} = &EscapeXML($$attribs{$key});
    }
    if ($data ne "") {
      if (($#{$$XMLTree[1]} > 0) &&
	  ($$XMLTree[1]->[($#{$$XMLTree[1]}-1)] eq "0")) {
	$$XMLTree[1]->[$#{$$XMLTree[1]}] .= &EscapeXML($data);
      } else {
	$$XMLTree[1]->[($#{$$XMLTree[1]}+1)] = 0;
	$$XMLTree[1]->[($#{$$XMLTree[1]}+1)] = &EscapeXML($data);
      }
    }
  }
}


##############################################################################
#
# GetXMLData - takes a host of arguments and returns various data structures
#              that match them.
#
#              type - "existence" - returns 1 or 0 if the tag exists in the
#                                   top level.
#                     "value" - returns either the CDATA of the tag, or the
#                               value of the attribute depending on which is
#                               sought.  This ignores any mark ups to the data
#                               and just returns the raw CDATA.
#                     "value array" - returns an array of strings representing
#                                     all of the CDATA in the specified tag.
#                                     This ignores any mark ups to the data
#                                     and just returns the raw CDATA.
#                     "tree" - returns an XML::Parser::Tree object with the
#                              specified tag as the root tag.
#                     "tree array" - returns an array of XML::Parser::Tree 
#                                    objects each with the specified tag as
#                                    the root tag.
#              XMLTree - pointer to XML::Parser::Tree object
#              tag     - tag to pull data from.  If blank then the top level
#                        tag is accessed.
#              attrib  - attribute value to retrieve.  Ignored for types
#                        "value array", "tree", "tree array".  If paired
#                        with value can be used to filter tags based on
#                        attributes and values.
#              value   - only valid if an attribute is supplied.  Used to
#                        filter for tags that only contain this attribute.
#                        Useful to search through multiple tags that all
#                        reference different name spaces.
#
##############################################################################
sub GetXMLData {
  my ($type,$XMLTree,$tag,$attrib,$value) = @_;

  $attrib = "" if !defined($attrib);
  $value = "" if !defined($value);

  #---------------------------------------------------------------------------
  # Check if a child tag in the root tag is being requested.
  #---------------------------------------------------------------------------
  if ($tag ne "") {
    my (@array);
    my ($child);
    foreach $child (1..$#{$$XMLTree[1]}) {
      if (($$XMLTree[1]->[$child] eq $tag) || ($tag eq "*")) {
	next if (ref($$XMLTree[1]->[$child]) eq "ARRAY");

        #---------------------------------------------------------------------
        # Filter out tags that do not contain the attribute and value.
        #---------------------------------------------------------------------
	next if (($value ne "") && ($attrib ne "") && exists($$XMLTree[1]->[$child+1]->[0]->{$attrib}) && ($$XMLTree[1]->[$child+1]->[0]->{$attrib} ne $value));
	next if (($attrib ne "") && ((ref($$XMLTree[1]->[$child+1]) ne "ARRAY") || !exists($$XMLTree[1]->[$child+1]->[0]->{$attrib})));

        #---------------------------------------------------------------------
	# Check for existence
        #---------------------------------------------------------------------
	if ($type eq "existence") {
	  return 1;
	}
        #---------------------------------------------------------------------
	# Return the raw CDATA value without mark ups, or the value of the
        # requested attribute.
        #---------------------------------------------------------------------
	if ($type eq "value") {
	  if ($attrib eq "") {
	    my $str = "";
	    my $next = 0;
	    my $index;
	    foreach $index (1..$#{$$XMLTree[1]->[$child+1]}) {
	      if ($next == 1) { $next = 0; next; }
	      if ($$XMLTree[1]->[$child+1]->[$index] eq "0") {
		$str .= $$XMLTree[1]->[$child+1]->[$index+1];
		$next = 1;
	      }
	    }
	    return &UnescapeXML($str);
	  }
	  return &UnescapeXML($$XMLTree[1]->[$child+1]->[0]->{$attrib})
	    if (exists $$XMLTree[1]->[$child+1]->[0]->{$attrib});
	}
        #---------------------------------------------------------------------
	# Return an array of values that represent the raw CDATA without
        # mark up tags for the requested tags.
        #---------------------------------------------------------------------
	if ($type eq "value array") {
	  my $str = "";
	  my $next = 0;
	  my $index;
	  foreach $index (1..$#{$$XMLTree[1]->[$child+1]}) {
	    if ($next == 1) { $next = 0; next; }
	    if ($$XMLTree[1]->[$child+1]->[$index] eq "0") {
	      $str .= $$XMLTree[1]->[$child+1]->[$index+1];
	      $next = 1;
	    }
	  }
	  push(@array,&UnescapeXML($str));
	}
        #---------------------------------------------------------------------
	# Return a pointer to a new XML::Parser::Tree object that has the
        # requested tag as the root tag.
        #---------------------------------------------------------------------
	if ($type eq "tree") {
	  my @tree = ( $$XMLTree[1]->[$child] , $$XMLTree[1]->[$child+1] );
	  return @tree;
	}
        #---------------------------------------------------------------------
	# Return an array of pointers to XML::Parser::Tree objects that have
        # the requested tag as the root tags.
        #---------------------------------------------------------------------
	if ($type eq "tree array") {
	  my @tree = ( $$XMLTree[1]->[$child] , $$XMLTree[1]->[$child+1] );
	  push(@array,\@tree);
	}
      }
    }
    #-------------------------------------------------------------------------
    # If we are returning arrays then return array.
    #-------------------------------------------------------------------------
    if (($type eq "tree array") || ($type eq "value array")) {
      return @array;
    }
  } else {
    #---------------------------------------------------------------------
    # This is the root tag, so handle things a level up.
    #---------------------------------------------------------------------

    #---------------------------------------------------------------------
    # Return the raw CDATA value without mark ups, or the value of the
    # requested attribute.
    #---------------------------------------------------------------------
    if ($type eq "value") {
      if ($attrib eq "") {
	my $str = "";
	my $next = 0;
	my $index;
	foreach $index (1..$#{$$XMLTree[1]}) {
	  if ($next == 1) { $next = 0; next; }
	  if ($$XMLTree[1]->[$index] eq "0") {
	    $str .= $$XMLTree[1]->[$index+1];
	    $next = 1;
	  }
	}
	return &UnescapeXML($str);
      }
      return &UnescapeXML($$XMLTree[1]->[0]->{$attrib})
        if (exists $$XMLTree[1]->[0]->{$attrib});
    }
    #---------------------------------------------------------------------
    # Return a pointer to a new XML::Parser::Tree object that has the
    # requested tag as the root tag.
    #---------------------------------------------------------------------
    if ($type eq "tree") {
      my @tree =  @{$$XMLTree};
      return @tree;
    }
  }
  #---------------------------------------------------------------------------
  # Return 0 if this was a request for existence, or "" if a request for
  # a "value", or [] for "tree", "value array", and "tree array".
  #---------------------------------------------------------------------------
  return 0 if ($type eq "existence");
  return "" if ($type eq "value");
  return [];
}


##############################################################################
#
# EscapeXML - Simple function to make sure that no bad characters make it into
#             in the XML string that might cause the string to be 
#             misinterpreted.
#
##############################################################################
sub EscapeXML {
  my $data = shift;

  $data =~ s/&/&amp;/g;
  $data =~ s/</&lt;/g;
  $data =~ s/>/&gt;/g;
  $data =~ s/\"/&quot;/g;
  $data =~ s/\'/&apos;/g;

  if ($UNICODE == 1) {
    eval("{  no warnings;  \$data =~ tr/\0-\xff//CU;  };")
  }
  elsif ($UNICODE == 2) {
      my $unicode = new Unicode::String();
      $unicode->latin1($data);
      $data = $unicode->utf8;
      eval ("{  no warnings;  \$data =~ tr/\0-\xff//CU;  };")
  }

  return $data;
}


##############################################################################
#
# UnescapeXML - Simple function to unecnode the bad characters from the XML
#              string.
#
##############################################################################
sub UnescapeXML {
  my $data = shift;

  $data =~ s/&apos;/\'/g;
  $data =~ s/&quot;/\"/g;
  $data =~ s/&gt;/>/g;
  $data =~ s/&lt;/</g;
  $data =~ s/&amp;/&/g;
  
  if ($UNICODE == 1) {
    eval("{  no warnings;  \$data =~ tr/\0-\x{ff}//UC;  };")
  }
  elsif ($UNICODE == 2) {
      my $unicode = new Unicode::String();
      $unicode->utf8($data);
      $data = $unicode->latin1;
  }

  return $data;
}


##############################################################################
#
# BuildXML - takes an XML::Parser::Tree object and builds the XML string that
#            it represents.
#
##############################################################################
sub BuildXML {
  my (@parseTree) = @_;
  my ($str,$att,$child);

  return "" if $#parseTree eq -1;

  if (ref($parseTree[0]) eq "") {

    if ($parseTree[0] eq "0") {
      return $parseTree[1];
    }

    $str = "<".$parseTree[0];
    foreach $att (keys(%{$parseTree[1]->[0]})) {
      $str .= " ".$att."='".$parseTree[1]->[0]->{$att}."'";
    }
    
    my $tempStr = &Net::Jabber::BuildXML(@{$parseTree[1]});

    if (!defined($tempStr) || ($tempStr eq "")) {
      $str .= "/>";
    } else {
      $str .= ">";
      $str .= $tempStr;
      $str .= "</".$parseTree[0].">";
    }

  } else {
    shift(@parseTree);
    while("@parseTree" ne "") {
      $str .= &Net::Jabber::BuildXML(@parseTree);
      shift(@parseTree);
      shift(@parseTree);
    }
  }

  return $str;
}


##############################################################################
#
# printData - debugging function to print out any data structure in an 
#             organized manner.  Very useful for debugging XML::Parser::Tree
#             objects.  This is a private function that will only exist in
#             in the development version.
#
##############################################################################
sub printData {
  my ($preString,$data) = @_;

  if (ref($data) eq "HASH") {
    my $key;
    foreach $key (sort { $a cmp $b } keys(%{$data})) {
      if (ref($$data{$key}) eq "") {
	print $preString,"{\'",$key,"\'} = \"",$$data{$key},"\"\n";
      } else {
	print $preString,"{\'",$key,"\'}\n";
	&printData($preString."{'".$key."'}->",$$data{$key});
      }
    }
  }
  if (ref($data) eq "ARRAY") {
    my $index;
    foreach $index (0..$#{$data}) {
      if (ref($$data[$index]) eq "") {
	print $preString,"[",$index,"] = \"",$$data[$index],"\"\n";
      } else {
	print $preString,"[",$index,"]\n";
	&printData($preString."[".$index."]->",$$data[$index]);
      }
    }
  }
  if (ref($data) eq "REF") {
    &printData($preString."->",$$data);
  }
  if (ref($data) eq "") {
    print $preString," = \"",$data,"\"\n";
  }
}


##############################################################################
#
# GetTimeStamp - generic funcion for getting a timestamp.
#
##############################################################################
sub GetTimeStamp {
  my($type,$time,$length) = @_;

  return "" if (($type ne "local") && ($type ne "utc") && !($type =~ /^(local|utc)delay(local|utc)$/));

  $length = "long" unless defined($length);

  my ($sec,$min,$hour,$mday,$mon,$year,$wday);
  if ($type =~ /utcdelay/) {
    ($year,$mon,$mday,$hour,$min,$sec) = ($time =~ /^(\d\d\d\d)(\d\d)(\d\d)T(\d\d)\:(\d\d)\:(\d\d)$/);
    $mon--;
    ($type) = ($type =~ /^utcdelay(.*)$/);
    $time = timegm($sec,$min,$hour,$mday,$mon,$year);
  }
  if ($type =~ /localdelay/) {
    ($year,$mon,$mday,$hour,$min,$sec) = ($time =~ /^(\d\d\d\d)(\d\d)(\d\d)T(\d\d)\:(\d\d)\:(\d\d)$/);
    $mon--;
    ($type) = ($type =~ /^localdelay(.*)$/);
    $time = timelocal($sec,$min,$hour,$mday,$mon,$year);
  }

  ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime(((defined($time) && ($time ne "")) ? $time : time)) if ($type eq "local");
  ($sec,$min,$hour,$mday,$mon,$year,$wday) = gmtime(((defined($time) && ($time ne "")) ? $time : time)) if ($type eq "utc");
  $wday = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat')[$wday];
  $mon = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec')[$mon];
  return sprintf("%3s %3s %02d, %d %02d:%02d:%02d",$wday,$mon,$mday,($year + 1900),$hour,$min,$sec) if ($length eq "long");
  return sprintf("%02d:%02d:%02d",$hour,$min,$sec) if ($length eq "short");
  return sprintf("%02d:%02d",$hour,$min) if ($length eq "shortest");
}


1;

