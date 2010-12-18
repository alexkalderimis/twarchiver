use warnings;
use Test::Most 'bail';
use Test::Exception;
use Test::MockObject;
use Carp qw/confess/;

use lib 'lib';
use lib 't/lib';

use Test::Object (
    allow_setting => 1,
    confess_non_existant_fields => 0
);
use Twarchiver::Functions::DBAccess ':all';
my $test_data = do 't/etc/test_data';
if (my $err = $@) {
    BAIL_OUT("Error parsing test data: $err");
}
if (ref $test_data ne 'ARRAY' || @$test_data != 10) {
    diag explain $test_data;
    BAIL_OUT("Could not load test data") 
}
## Set up test database
Dancer::set(database => ':memory:');
{
    local $SIG{__WARN__} = sub {
    }; # Silence warnings here because Data::Dumper in 
       # SQL::Translator doesn't like code refs
    get_db()->deploy({
        show_warnings => 0,
    });
}
store_twitter_statuses(@$test_data);

BEGIN {
    use_ok('Twarchiver::Functions::Export' => ':all')
        or BAIL_OUT("Could not use module");
}

subtest 'Test tweet_to_text' => sub {
    my $tweet_1 = get_tweet_record('UserOne', 987654321);

    my $expected =
        'Time:   01 Feb 2010 12:00:00 AM' . "\n" .
        'This is the first #example tweet from the test' . "\n" . 
        'data set for @twarchiver';

    is tweet_to_text($tweet_1), $expected . "\n" x 2
        => "Can make a text representation of a tweet";

    $tweet_1->add_to_tags({
            tag_text => "An added example tag",
        });
    $tweet_1->add_to_tags({
            tag_text => "Eine zugefügte Bemerkung"
        });
    $expected .= "\n"
      . 'Tags: An added example tag, Eine zugefügte' . "\n" 
      . '      Bemerkung';

    is tweet_to_text($tweet_1), $expected .  "\n"
        => "Can make a text representation of a tweet with tags";
};


subtest 'Test get_tweets_as_textfile' => sub {
    my @tweets = get_all_tweets_for('UserOne');

    my $expected = qx{cat t/etc/tests_tweets.txt};
    chomp $expected;

    is get_tweets_as_textfile(@tweets), $expected
        => "Can get tweets as text file";
};

subtest 'Test get_tweets_as_spreadsheet' => sub {
    my @tweets = get_all_tweets_for('UserOne');

    my $expected = qx{cat t/etc/test_tweets.csv};
    chomp $expected;

    is get_tweets_as_spreadsheet(',', @tweets), $expected
        => "Can get tweets as csv";

    $expected = qx{cat t/etc/test_tweets.tsv};
    chomp $expected;


    is get_tweets_as_spreadsheet("\t", @tweets), $expected
        => "Can get tweets as tsv";
};

done_testing();
