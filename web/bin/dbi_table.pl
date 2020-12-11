
# Returns a list of all tables in the DBI database, pointed at with the mh.ini dbi_* parms.
# Call like this:  http://localhost:8080/bin/dbi_table.pl

return &html_page( '', 'No database connection' ) unless defined $DBI;

my $html = &html_header('List of all tables in the DBI database');

for my $table ( $DBI->func('_ListTables') ) {
    my $query = "select * from $table";
    my $sth   = $DBI->prepare($query);
    $sth->execute();
    $html .= "<br>error on $query: " . $DBI->errmsg unless defined $sth;

    $html .= "<br><h3>Table: $table</h3><table border=1>\n";

    my $names = $sth->{NAME};
    for my $field (@$names) {
        $html .= "<th>$field</th>\n";
    }

    while ( my $data = $sth->fetchrow_hashref ) {
        $html .= "<tr>\n";
        for my $field (@$names) {
            $html .= "<td>$data->{$field}</td>\n";
        }
        $html .= "</tr>\n";
    }
    $html .= "</table><hr>\n";
}

return &html_page( 'Database Listing', $html );
