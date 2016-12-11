# Category = News

#@ This module checks the http://actualidad.wanadoo.es/home.html
#@ web site to get the most recent news in Spain and international
#@
#@ You can check several sections: Hoy, nacional, Internacional,
#@ Deportes, Sociedad, Finanzas, Tecnología, Ciencia and Cultura.
#@

# Sections names
my %Sections_names = (
    'Hoy',           'Hoy es noticia',
    'Nacional',      'Nacional',
    'Internacional', 'Internacional',
    'Deportes',      "Deportes \/ Segundosfuera",
    'Sociedad',      'Sociedad',
    'Finanzas',      "Finanzas \/ Basefinanciera",
    'Tecnología',    'Tecnología',
    'Ciencia',       'Ciencia',
    'Cultura',       'Cultura',
);

# Maximum number of news by section to show
my $News_count = 10;

my $f_news_data = "$config_parms{data_dir}/news_data";
$f_news_file = new File_Item($f_news_data);

$v_news = new Voice_Cmd('[Comprueba,Dime,Borra] las últimas noticias');
$v_news->set_info(
    "Muestra las últimas noticias de las categorias: $config_parms{news_sections}"
);
$v_news->set_authority('anyone');
set_icon $v_news 'news';

$state = said $v_news;

if (   ( $state eq 'Comprueba' )
    or ( ( state $mode_mh eq 'normal' ) and time_cron("15 * * * *") ) )
{
    if (&net_connect_check) {

        #print_log "comprobando las últimas noticias ...";

        &get_news;
    }
}

if ( $state eq 'Borra' ) {
    $Save{news} = '';
}

if ( $state eq 'Dime' ) {
    &say_news('Hoy');
}

if ( changed $f_news_file) {
    my $new_news = "";
    my ( $news, $search, $section );
    my $inside_section = 0;

    my $text = file_read $f_news_data;

    #print "File: $f_news_data\n";
    #print "Noticias: text ---------->>>>\n$text\n";

    foreach ( split /\n/, $text ) {

        #look for news sectons
        if (/^\[(.*)\]/) {
            $section = $1;

            #    print "News Section: $section\n";
            if ( $section = &valid_section($section) ) {
                $inside_section = 1;
            }
            else {
                $inside_section = 0;
            }
            next;
        }

        if ($inside_section) {
            $news = $search = $_;
            $search =~ s/\./\\\./g;
            $search =~ s/\(/\\\(/g;
            $search =~ s/\)/\\\)/g;
            $search =~ s/\*/\\\*/g;
            if ( $search =~ m!^Videotitulares\:! ) { }    #do nothing
            elsif ( $Save{news} !~ /$search/ ) {
                $new_news = $new_news . "$section\: " . $news . "\t";
            }
        }
    }
    if ($new_news) {
        $Save{news} = $new_news . $Save{news};
        $Save{news} =~ s/^(([^\t]*\t){1,25}).*/$1/;       # Save last 25 news
        foreach ( split /\t/, $new_news ) {
            $news = $_;
            &speak_news($news);
        }
    }
}

sub valid_section {
    my $section = shift;

    my $sec;
    for $sec ( split( ',', $config_parms{news_sections} ) ) {
        $sec =~ s/^\s+//;

        #  foreach $sec (keys(%Sections_names)) {
        if ( $section =~ m!$Sections_names{$sec}! ) {
            return $sec;
        }
    }
    return '';
}

sub say_news {
    my $section = shift;

    foreach ( split /\t/, $Save{news} ) {
        if (m!^$section\:!) {
            my $news = $_;
            &speak_news($news);
        }
    }
}

sub speak_news {
    s/^Hoy\: /Hoy es noticia\: /;

    #   print "Speak_news: $_\n";
    speak $_;
}

# Fetch the news page and parse it
# update the parsed data file.
sub get_news {

    my $pgm = "get_news_sp";

    #print_log "running $pgm";
    run $pgm;

    #print_log "News update started";

    set_watch $f_news_file;
}

