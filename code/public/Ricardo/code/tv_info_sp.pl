# Category=TV

#@ This code will search for tv shows in the database created
#@ by tv_grid code.

$f_tv_file = new File_Item("$config_parms{data_dir}/tv_info1.txt");

$v_tv_movies1 =
  new Voice_Cmd('Qué {comedias,dramas,ciencia-ficción} hay hoy en televisión');
$v_tv_movies1->set_info(
    'Busca peliculas en todos los canales entre las 21 y las 23');

$v_tv_shows1 = new Voice_Cmd('Qué programas hay ahora en la televisión');
$v_tv_shows2 = new Voice_Cmd('Qué programas favoritos hay hoy en televisión');
$v_tv_shows1->set_info('Lista los programas que hay ahora mismo en cada canal');
$v_tv_shows2->set_info(
    "Comprueba si hay alguno de los siguientes programas hoy: $config_parms{favorite_tv_shows}"
);

if ( $state = said $v_tv_movies1) {
    run qq[get_tv_info_sp -times 21-23 -type $state];
    set_watch $f_tv_file;
}

if ( $state = said $v_tv_shows1) {
    run qq[get_tv_info_sp -times $Time_Now];
    set_watch $f_tv_file;
}
if ( said $v_tv_shows2) {
    print_log "Searching for favorite shows";
    run
      qq[get_tv_info_sp -times "$Time_Now-23.99" -keys "$config_parms{favorite_tv_shows}" -keyfile "$config_parms{favorite_tv_shows_file}" -title_only];
    set_watch $f_tv_file 'favorites today';
}

# Check for favorite shows now
#if (($New_Minute) or
if ( ( state $mode_mh eq 'normal' )
    and time_cron('0,5,10,15,20,25,30,35,40,45,50,55 * * * *') )
{
    run
      qq[get_tv_info_sp -quiet -times +0.085 -keys "$config_parms{favorite_tv_shows}"  -keyfile "$config_parms{favorite_tv_shows_file}"  -title_only];
    set_watch $f_tv_file 'favorites now';
}

# Speak/show the results for all of the above requests

$v_tv_results =
  new Voice_Cmd 'Cuáles son los resultados de buscar programas de televisión';
if ( $state = changed $f_tv_file or said $v_tv_results) {
    my $f_tv_info2 = "$config_parms{data_dir}/tv_info2.txt";

    my $summary      = read_head $f_tv_file 6;
    my ($show_count) = $summary =~ /Encontrados (\d+)/;
    my @data         = read_all $f_tv_file;
    shift @data;    # Drop summary;

    my $i = 0;
    foreach my $line (@data) {

        # 1|  C.S.I. Miami| Canal AXN| AXN| Dial 22|  De 19:30 hasta 20:30|
        my ( $title, $ch_name, $ch_key, $ch_num, $pgm_date, $start, $end );
        $title = '';
        if (
            (
                ( $title, $ch_name, $ch_key, $ch_num, $start, $end ) =
                $line =~
                /^\d+\|\s+(.+)\|\s*Canal (.+)\|\s*(.+)\|\s+Dial\s+(\d+)\|\s*De (\d+:\d+) hasta (\d+:\d+)\|/
            )
            or

            # 1|  El Ala Oeste| Canal AXN| AXN| Dial 22|  El 12/11/04| De 21:30 hasta 22:20|
            (
                ( $title, $ch_name, $ch_key, $ch_num, $pgm_date, $start, $end )
                = $line =~
                /^\d+\|\s+(.+)\|\s*Canal (.+)\|\s*(.+)\|\s+Dial\s+(\d+)\|\s*El (.+)\s*\|\s*De (\d+:\d+) hasta (\d+:\d+)\|/
            )
          )
        {
            $title =~ s/C\.S\.I\./C S I/gi;
            $ch_name =~ s/canal\+/Canal plus/gi;
            $start    = say_time($start);
            $end      = say_time($end);
            $pgm_date = say_date($pgm_date) if $pgm_date;
            my $aux = "$title, ";

            if ($pgm_date) {
                $aux .= "el $pgm_date ";
            }
            if ( $ch_num == 0 ) {
                $aux .= "a las $start hasta $end, en $ch_name";
            }
            else {
                $aux .=
                  "a las $start hasta $end, en $ch_name, diál $ch_num de digital plus";
            }
            $data[$i] = $aux;
        }
        $i++;
    }

    my $msg = "Hoy emiten ";
    $msg .= "$show_count"
      . ( $show_count > 1 ? ' programas favoritos' : ' programa favorito' );
    if ( $state eq 'favorites today' ) {
        if ( $show_count > 0 ) {
            respond "$msg\: @data";
        }
        else {
            respond "Hoy no emiten ningún programa favorito";
        }
    }
    elsif ( $state eq 'favorites now' ) {
        respond "app=tv Aviso, está empezando: @data" if $show_count > 0;
    }
    else {
        chomp $summary;    # Drop the cr
        respond "$summary @data ";
    }
    display $f_tv_info2 if $show_count;
}

sub set_events {
    my $tv_shows_e = "$Code_Dirs[0]/tv_shows_events.pl";
    my $display;

    open( MYCODE, ">$tv_shows_e" )
      or print_log "Error in writing to $tv_shows_e";
    print MYCODE "\n#@ Auto-generated from code/common/tv_info_sp.pl\n\n";

    print MYCODE<<eof;

    if (time_now '\$time') {
        my \$msg = "Aviso: va producir un destello de  magnitud en 2 minutos ";
        \$msg .= "a una altitud de , y azimut de .";
        speak "app=tv \$msg";
    }
eof

    close MYCODE;
    display $display, 0, 'TV shows list', 'fixed';
}

