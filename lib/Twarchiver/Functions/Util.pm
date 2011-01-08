package Twarchiver::Functions::Util;

use feature ':5.10';
use DateTime;
use Carp qw/confess/;

=head1 CONSTANTS

=head2 DATE_FORMAT

The standard date format we use for displaying date times:
    12 Nov 2010 12:53 PM

=cut

use constant {
    DATE_FORMAT    => "%d %b %Y %X",
    LONG_MONTH_FORMAT => "%e %B %Y",
};

our $VERSION = '0.1';

use Exporter 'import';

our @EXPORT_OK = qw/
    get_month_name_for
    DATE_FORMAT
    LONG_MONTH_FORMAT
    /;

our %EXPORT_TAGS = (
    'all' => [qw/
        get_month_name_for
        DATE_FORMAT
        LONG_MONTH_FORMAT
    /],
    'routes' => [qw/
        get_month_name_for
        DATE_FORMAT
    /]
);

=head1 FUNCTIONS

=head2 get_month_name_for(month_number)

Function:  Get the name of the month given as a number
Arguments: A number from 1 - 12
Returns:   A string with the corresponding month name

=cut

sub get_month_name_for {
    state %name_of_month;
    my $month_number = shift;
    confess "No month number provided to get_month_name_for" 
        unless $month_number;
    confess "Bad argument to get_month_name_for: expected a number from 1 - 12, but got '$month_number'" 
        unless (grep {$month_number eq $_} 1 .. 12);
    
    unless (%name_of_month) {
        %name_of_month =
          map { $_ => DateTime->new( year => 2010, month => $_ )->month_name } 1 .. 12;
    }
    return $name_of_month{$month_number};
}

1;
