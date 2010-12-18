use warnings;
use Test::Most 'bail';
use Test::Exception;

use lib 'lib';
use lib 't/lib';

BEGIN {
    use_ok('Twarchiver::Functions::Util' => ':all');
}

subtest 'Test DATE_FORMAT' => sub {
    is DATE_FORMAT, '%d %b %Y %X', "Can get the date format";
};

subtest 'Test get_month_name_for' => sub {
    my @month_names = (qw/
        January February March April May June July
        August September October November December
    /);
    for (0 .. $#month_names) {
        is get_month_name_for($_ + 1), $month_names[$_]
            => "Can get month name for month " . ($_ + 1);
    }
    for ('', undef, 0) {
        throws_ok(sub {get_month_name_for($_)}, qr/No month number/
            => "Catches no month number");
    }
    for (-1, 13, 1_000_000, 'not a number') {
        throws_ok(sub {get_month_name_for($_)}, qr/expected a number/
            => "Catches number of of bounds: $_"
        );
    }
};

done_testing();
