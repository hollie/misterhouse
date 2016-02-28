# Category=TV

#@ This code will download TV schedules from the Internet and
#@ optionally create events to remind you or your vcr to watch shows
#@ edit your mh.ini file, to set the mh.ini tv_channels parm.

# Note: This $tv_grid is a special name, used by the get_tv_grid program.
#       Do not change it.
# This is what downloads tv data.  This needs to be forked/detatched, as it can take a while
$v_get_tv_grid_data = new Voice_Cmd('Leer rejilla de televisión');
$v_get_tv_grid_data->set_info(
    'Lee la rejilla de TV para los canales seleccionados y genera la base de datos de TV.'
);
if ( ( said $v_get_tv_grid_data) or time_now('6:35') ) {
    if (&net_connect_check) {

        # Use mh_run so we can find mh libs and/or compiled mh.exe/mhe
        #	my $pgm = "mh_run get_tv_grid_sp -db tv";
        my $pgm = "get_tv_grid_sp -db tv";
        if ( $config_parms{tv_channels} ) {
            $pgm .= qq[ -channels "$config_parms{tv_channels}"];
        }

        # Allow data to be stored wherever the alias points to
        my $tvdir = &html_alias('tv');
        $pgm .= qq[ -outdir "$tvdir"] if $tvdir;

        run $pgm;
        print_log "TV grid update started";
    }
    else {
        speak "Sorry, you must be logged onto the net";
    }
}

