
# Return a login/logout button depending on the current
# Authorisation. Being called from ia5/top.shtml.

# Authority: anyone

my $icon = '/ia5/images/login.gif';

# Return a user specific icon, or default logout icon if not found.
if ($Authorized) {
    $icon = "/ia5/images/logout_$Authorized.gif";
    $icon = '/ia5/images/logout.gif' unless &http_get_local_file($icon);
}

my $action =
  ($Authorized)
  ? "/UNSET_PASSWORD?user=$Authorized"
  : "/SET_PASSWORD?user=$Authorized";

#print "\ndbx a=$Authorized i=$icon a=$action\n";
return
    "<a href='$action'><img src='$icon' alt='"
  . ( ($Authorized) ? 'Logout' : 'Login' )
  . "' border=0></a>";
