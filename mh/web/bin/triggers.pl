
=begin comment

This code is used to list and manipulate triggers.  See mh/doc/mh.* set_trigger for more info.

  http://localhost:8080/bin/triggers.pl

=cut

use strict;
$^W = 0;                        # Avoid redefined sub msgs

my ($function, @parms) = @ARGV;

#print "dbx a=@ARGV.\n";

if ($function eq 'add') {
    return &web_trigger_add();
}
else {
    return &web_trigger_list();
}

sub web_trigger_list {

    &triggers_save;             # Check for changes to write out


                                # Create header and 'add a trigger' form
    my $html = &html_header('Triggers Menu');

    my $form_trigger = &html_form_select('trigger1', 0, 'time_now', '',
          qw(time_now time_cron time_random new_second new_minute new_hour $New_Hour $New_Day $New_Week $New_Month $New_Year));

    my $form_code    = &html_form_select('code1', 0, 'speak', '',
          qw(speak play display print_log set run run_voice_cmd net_im_send net_mail_send get));

    $html = qq|
<HTML><HEAD><TITLE>Triggers Menu</TITLE></HEAD>
<BODY>
<br><a name='Top'></a>
$html
To set a time and/or date based alarm, use time_now with any valid time/date spec (e.g. 12/25 7 am).  
OneShot triggers will expire after they run once.  Change to NoExpire to run every time without expiring.
Expired items will be pruned to data_dir/triggers.expired one week after they expire.
The trigger name can be any unique string.

<form action='/bin/triggers.pl?add' method=post>
<input type=submit value='Create'>
<input type=input name=name     size=10 value="Test">
$form_trigger
<input type=input name=trigger2 size=18 value="12 pm">
$form_code
<input type=input name=code2    size=30 value="hi">
</form>

<TABLE BORDER>
|;

                                # Add an index
    $html .= "<tr><td colspan=7>";
    $html .="<a href=/bin/triggers.pl>Refresh</a>\n";
    $html .= "<B>Trigger Index: <B>\n";
    for my $category ('OneShot', 'NoExpire', 'Disabled', 'Expired') {
        $html .= "<a href='#$category'>$category</a>\n";
    }
    $html .= "</td></tr>\n";

    my $type_prev;
                                # Sort in indexed order
    for my $name (sort {my $t1 = $triggers{$a}{type};  my $t2 = $triggers{$b}{type};
                        $t1 = 0 if $t1 eq 'OneShot';  $t2 = 0 if $t2 eq 'OneShot';
                        $t1 = 1 if $t1 eq 'NoExpire'; $t2 = 1 if $t2 eq 'NoExpire';
                        $t1 cmp $t2 or $a cmp $b} keys %triggers) {

        my ($trigger, $code, $type, $triggered) = &trigger_get($name);

        if ($type_prev ne $type) {
            $type_prev =  $type;
            $html .= "<tr><td colspan=7><B>$type</B> (<a name='$type' href='#Top'>back to top</a>)</td></tr>\n";
        }
        
        my $name2 = $name;
        $name2 =~ s/ /\%20/g;
        $html .= "<tr>\n";

        $html .= "<td><a href=/SUB;/bin/triggers.pl?trigger_copy('$name2')>Copy</a>\n";
        $html .= "    <a href=/SUB;/bin/triggers.pl?trigger_delete('$name2')>Delete</a>\n";
        $html .= "    <a href=/SUB;/bin/triggers.pl?trigger_run('$name2')>Run</a></td>\n";

        $html .= &html_form_input_set_func('trigger_rename', '/bin/triggers.pl', $name, $name);

#       $html .= "<td><a href=/bin/set_var.pl?\$triggers{'$name2'}{trigger}&/bin/triggers.pl>$trigger</a></td>\n";
        $html .= &html_form_input_set_var("\$triggers{'$name'}{trigger}", '/bin/triggers.pl', $trigger);

        $code = substr($code, 0, 30) . '...' if length($code) > 30;
        $html .= "<td><a href=/bin/set_var.pl?\$triggers{'$name2'}{code}&/bin/triggers.pl>$code</a></td>\n";

        $html .= &html_form_select_set_var("\$triggers{'$name'}{type}", $type,
                                  'OneShot', 'NoExpire', 'Disabled', 'Expired');
        

        if ($triggered) {
            my $triggered_date = &time_date_stamp(7, $triggered) if $triggered;
            $html .= "<td>$triggered_date</td>\n";
        }

        $html .= "</tr>\n\n";

    }
    $html .= "</table>\n";
    return &html_page('', $html);
}


sub web_trigger_add {

                                # Allow un-authorized users to browse only (if listed in password_allow)
#   return 'Not authorized to make updates' unless $Authorized eq 'admin';
    return 'Not authorized to make updates' unless $Authorized;

                                # Process form
    if (@parms) {
#       print "db p=@parms\n";
        my %p;
        for my $p (@parms) {
            $p{$1} = $2 if $p =~ /(.+?)=(.+)/;
        }
        my $trigger = ($p{trigger1}) ? "$p{trigger1} '$p{trigger2}'" : $p{trigger2};
        my $code;
        if ($p{code1}) {
#           $p{code2} = "qq~$p{code2}~" unless $p{code1} eq 'set';
	    unless ($p{code1} eq 'set') {
		$p{code2} =~ s/\'/\\'/g;
		$p{code2} = "'$p{code2}'";
	    }
            $code = "$p{code1} $p{code2}";
        }
        else {
            $code = $p{code2};
        }
#       print "db t=$trigger c=$code\n";
        &trigger_set($trigger, $code, 'OneShot', $p{name});
        return &http_redirect('/bin/triggers.pl');
    }
                                # Create form
    else {
        my $html = "Add a trigger:<form action='/bin/triggers.pl?add' method=post>\n";
        $html .= qq|<br>Name   <input type=input name=name    value="Test">\n|;
        $html .= qq|<br>Trigger<input type=input name=trigger value="time_now '12 pm'">\n|;
        $html .= qq|<br>Event  <input type=input name=code    value="speak 'hi'">\n|;
        $html .= qq|<br><input type=submit value='Create'></form>\n|;
        return &html_page('', $html);
    }
}
