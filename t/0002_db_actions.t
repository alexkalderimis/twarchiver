use strict;
use warnings;
use Carp qw/cluck/;

use Test::More tests => 59;
use Test::Exception;
use Scalar::Util 'refaddr';
use List::Util qw(sum);

require Dancer;
use lib 'lib';
use lib 't/lib';

Dancer::set(database => ':memory:');

BEGIN {
    use_ok( 'Twarchiver::DBActions' => ':all')
        or BAIL_OUT("Could not use module");
}

my $test_data = do 't/etc/test_data';
if (my $err = $@) {
    BAIL_OUT("Error parsing test data: $err");
}
if (ref $test_data ne 'ARRAY' || @$test_data != 10) {
    diag explain $test_data;
    BAIL_OUT("Could not load test data") 
}

my $db;
lives_ok(
    sub {$db = get_db()},
    "Can call get_db",
);

isa_ok($db, 'Twarchiver::Schema', "And it is a Twarchiver::Schema");

is(refaddr($db), refaddr(get_db()), "And it is a singleton");

{
    local $SIG{__WARN__} = sub {
    }; # Silence warnings here because Data::Dumper in 
       # SQL::Translator doesn't like code refs
    $db->deploy({
        show_warnings => 0,
    });
}

is $db->resultset("User")->count, 0
    => "Starts with 0 users";

my $user;
lives_ok(
    sub {$user = get_user_record('TestUser');},
    "Can call get_user_record",
) or BAIL_OUT("Cannot fetch a user - no point continuing");

can_ok($user, qw/screen_name id tweets/)
    or diag explain $db->deployment_statements;

is $user->screen_name, 'TestUser'
    => "The user has the right name";

is $db->resultset("User")->count, 1
    => "Now has 1 user";

my $same_user = get_user_record('TestUser');

is $db->resultset("User")->count, 1
    => "Calling for the same user again does not create a new one";

my $tweet;
lives_ok(
    sub {$tweet = get_tweet_record('TestUser', 1, "Foo");},
    "Can call get_tweet_record",
) or BAIL_OUT("Cannot fetch a tweet - no point continuing");

can_ok(
    $tweet, 
    qw/text tweet_id user mentions urls hashtags tags created_at/,
) or diag explain $db->deployment_statements;

is $tweet->text, 'Foo'
    => "The tweet has the right text";

is $tweet->user->screen_name, 'TestUser'
    => "Is associated with the right user";

is $db->resultset('Tweet')->count, 1 
    => "Only has one tweet at this point";

my $same_tweet = get_tweet_record('TestUser', 1);

is $tweet->text, $same_tweet->text
    => "And it can be fetched again";

is $db->resultset('Tweet')->count, 1 
    => "Without making any extraneous tweets";

lives_ok(
    sub { store_twitter_statuses(@$test_data) },
    "Can call store_twitter_statuses",
);

is $db->resultset("User")->count, 2
    => "Now we have a new user";

is $db->resultset("Tweet")->count, 11
    => "All ten tweets were loaded ok";

is $db->resultset("Mention")->count, 9
    => "All nine mentions were loaded ok";

is $db->resultset("Hashtag")->count, 7
    => "All seven hashtags were loaded ok";

is $db->resultset("Url")->count, 7
    => "All seven urls were loaded ok";

is get_since_id_for('UserOne'), 987654321,
    => "Gets the correct since id";

is_deeply(
    [map {$_->tweet_id} get_all_tweets_for('UserOne')->all],
    [reverse(987654312 .. 987654321)],
    "Gets all tweets in the right order",
);

is restore_tokens('UserOne'), undef
    => "UserOne doesn't have any tokens yet";

lives_ok(
    sub {save_tokens('UserOne', 'access_test', 'secret_test')},
    "Can call save tokens",
);

is_deeply(
    [restore_tokens('UserOne')],
    ['access_test', 'secret_test'],
    "Can restore stored tokens",
);

$db->resultset('Url')->create({address => 'decoy url'});

is get_urls_for('UserOne')->count, 7
    => "get_urls_for test: number is correct (ignores decoy)";

$db->resultset('Mention')->create({mention_name => 'decoy'});

is get_mentions_for('UserOne')->count, 9,
    => "get_mentions_for test: number is correct (ignores decoy)";

$db->resultset('Hashtag')->create({topic => 'decoy'});

is get_hashtags_for('UserOne')->count, 7
    => "get_hashtags_for test: number is correct (ignores decoy)";

$db->resultset('Tag')->create({tag_text => 'decoy'});

is get_tags_for('UserOne')->count, 0
    => "get_tags_for test: number is correct (ignores decoy)";

my $response;
lives_ok(
    sub {$response = add_tags_to_tweets(
            ['Testing1', 'Testing2'],
            [987654312 .. 987654320],
        );},
    "Can call add_tags_to_tweets",
);

is $db->resultset("Tag")->count, 3
    => "Only added two tags";

is_deeply(
    $response,
    { 
        987654312 => {
            added => ['Testing1', 'Testing2'],
        },
        987654313 => {
            added => ['Testing1', 'Testing2'],
        },
        987654314 => {
            added => ['Testing1', 'Testing2'],
        },
        987654315 => {
            added => ['Testing1', 'Testing2'],
        },
        987654316 => {
            added => ['Testing1', 'Testing2'],
        },
        987654317 => {
            added => ['Testing1', 'Testing2'],
        },
        987654318 => {
            added => ['Testing1', 'Testing2'],
        },
        987654319 => {
            added => ['Testing1', 'Testing2'],
        },
        987654320 => {
            added => ['Testing1', 'Testing2'],
        },
    },
    "Got the expected response"
) or diag explain $response;


lives_ok(
    sub {$response = add_tags_to_tweets(
            ['Testing3', 'Testing4'],
            [987654320 .. 987654323],
        );},
    "Can call add_tags_to_tweets even when the ids don't exist",
);

is $db->resultset("Tag")->count, 5
    => "Only added two tags";

is_deeply(
    $response,
    { 
        987654320 => {
            added => ['Testing3', 'Testing4'],
        },
        987654321 => {
            added => ['Testing3', 'Testing4'],
        },
        errors => [
            "Could not find tweet 987654322",
            "Could not find tweet 987654323",
        ],
    },
    "Got the expected response - with errors"
) or diag explain $response;

is get_tags_for('UserOne')->count, 4
    => "get_tags_for test: number is correct after adding";

is get_tweets_with_tag('UserOne', 'Testing1')->count, 9
    => "get_tweets_with_tag test 1";

is get_tweets_with_tag('UserOne', 'Testing3')->count, 2
    => "get_tweets_with_tag test 2";

lives_ok(
    sub {$response = remove_tags_from_tweets(
            [qw/Testing1 Testing4/],
            [987654321, 987654312, 10],
        )},
    "Can call remove_tags_from_tweets"
);

is_deeply(
    $response,
    { 
        987654312 => {
            removed => ['Testing1'],
        },
        987654321 => {
            removed => ['Testing4'],
        },
        errors => [
            "Could not find tag 'Testing1' on tweet 987654321",
            "Could not find tag 'Testing4' on tweet 987654312",
            "Could not find tweet 10",
        ],
    },
    "Got the expected response - with errors"
) or diag explain $response;


is get_tweets_with_tag('UserOne', 'Testing1')->count, 8
    => "get_tweets_with_tag test 3";

is get_tweets_with_tag('UserOne', 'Testing4')->count, 1
    => "get_tweets_with_tag test 4";

is get_tweets_with_mention('UserOne', '@twarchiver')->count, 8
    => "get_tweets_with_mention test 1";

is get_tweets_with_mention('UserOne', '@elephants')->count, 2
    => "get_tweets_with_mention test 2";

is get_tweets_with_hashtag('UserOne', '#example')->count, 10
    => "get_tweets_with_hashtag test 1";

is get_tweets_with_hashtag('UserOne', '#test-data')->count, 7
    => "get_tweets_with_hashtag test 2";

is get_tweets_with_url('UserOne', 'http://animals.com')->count, 3
    => "get_tweets_with_url test 1";

is get_tweets_with_url('UserOne', 'http://elephants.com')->count, 2
    => "get_tweets_with_url test 2";

is get_retweeted_tweets('UserOne')->count, 8,
    => "Can get all retweeted tweets";

is get_retweeted_tweets('UserOne', 2)->count, 3,
    => "Can get retweeted tweets with a count";

my $retweeted_summary = [
    map {[$_->retweeted_count, $_->get_column('occurs')]}
        get_retweet_summary('UserOne')->all];

is_deeply(
    $retweeted_summary, 
    [
        ['2','3'],
        ['1','2'],
        ['4','2'],
        ['3','1']
    ],
    "Can get a summary of retweets ok",
) or diag explain $retweeted_summary;

is sum(map {$_->[1]} @$retweeted_summary), 
   get_retweeted_tweets('UserOne')->count,
   "The number of tweets on each case sums to the total number of retweeted tweets";

is_deeply(
    [get_years_for('UserOne')],
    [reverse(2008 .. 2010)],
    "get_years_for ok",
);

my $months = [get_months_in('UserOne', 2009)];
is_deeply(
    $months,
    [12, 6, 1],
    "get_months_in ok",
) or diag explain $months;

is get_tweets_in_month('UserOne', 2010, 1)->count, 3
    => "get_tweets_in_month test - check count"
    or diag explain [map {[$_->created_at->ymd, $_->created_at->epoch]} 
            get_tweets_in_month('UserOne', 2010, 1)->all];

is grep( {$_->created_at->month == 1} 
    get_tweets_in_month('UserOne', 2010, 1)->all),
   3, "get_tweets_in_month test - check month values"
    or diag explain [map {[$_->created_at->ymd, $_->created_at->epoch]} 
            get_tweets_in_month('UserOne', 2010, 1)->all];


