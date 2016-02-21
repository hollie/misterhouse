
# Returns the current Authorisation. Being called from iphone/user_auth.shtml.

# Authority: anyone

return ( ($Authorized) ? "$Authorized" : 'none' );
