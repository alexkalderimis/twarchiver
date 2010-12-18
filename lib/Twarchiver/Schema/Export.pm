package Twarchiver::Schema::Export;

use strict;
use warnings;

=pod 

=head1 TITLE

Twarchiver::Schema::Export - functions for exporting the database to xml

=head1 SYNOPSIS

    use Twarchiver::Schema::Export ':all';
    use autodie qw(open close);

    open( my $output_fh, '>', 'some_file' );

    export_db_to_xml($output_fh);

    close $output_fh;

=head1 DESCRIPTION

Export the data to a human, and machine readable form. 

=head1 FUNCTIONS

=head2 export_db_to_xml( Handle )

Exports the whole db to the given filehandle.

=cut

1;


