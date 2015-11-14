# Category = Time
#  Original by Douglas J. Nakakihara

#@ This module allows you to easily add timed reminders. These can be
#@ used for TV show reminders, birthdays, etc.
#@ Copy mh/data/alarmclock.txt into your data_dir and modify.
#@ You can use the mh.ini alarm_function parm to point to a customize alarm
#@ function to do things like like sending yourself an im or email reminder.

my (@alarmdata);

# If alarm data file changed read new data
if ( ( $New_Minute and file_changed("$config_parms{data_dir}/alarmclock.txt") )
    or $Reload )
{
    print "Reading alarm clock data ($Date_Now $Time_Now):\n";
    @alarmdata = ();
    open( ALARMDATA, "$config_parms{data_dir}/alarmclock.txt" );
    while (<ALARMDATA>) {
        unless ( /^#/ or /^\s+$/ ) {
            print " - $_";
            chomp $_;
            push @alarmdata, $_;
        }
    }
    close(ALARMDATA);
    my $alarmcount = @alarmdata;
    print "  $alarmcount alarms set.\n";
}

if ($New_Minute) {
    for my $data (@alarmdata) {
        my ( $alarm_time, $alarm_msg ) = split '\|', $data, 2;

        #       print "test alrm: time=$alarm_time msg=$alarm_msg d=$data\n";

        my @a = split ' ', $alarm_time;
        if (   ( @a == 5 and &time_cron($alarm_time) )
            or ( @a != 5 and &time_now($alarm_time) ) )
        {
            # Use eval to eval $Time_Now ect in msg
            eval qq|speak "$alarm_msg"|;
            eval qq|$config_parms{alarm_function}("$alarm_msg")|
              if $config_parms{alarm_function};
        }
    }
}

# Here is an example alarm function
sub alarm_function_default {
    my ($alarm_msg) = @_;

    # Only send msgs flagged with a trailing !
    if ( $alarm_msg =~ /\!$/ ) {
        net_mail_send(
            subject => "mh alarm: $alarm_msg",
            text    => "Alarm at $Date_Now  $Time_Now\n\n$alarm_msg"
        );
        net_im_send( text => "mh alarm $Time_Now: $alarm_msg" );
    }
}
