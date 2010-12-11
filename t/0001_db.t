#!/usr/bin/perl

use Test::More;

use lib 'lib';

use strict;
use warnings;

use DateTime;
use Test::Exception;
use List::MoreUtils qw(uniq);

use Test::DBIx::Class {
    schema_class => 'Twarchiver::Schema',
    connect_info => ['dbi:SQLite:dbname=:memory:','',''],
    fixture_class => '::Populate',
}, 'User', 'Tweet', 'Mention', 'Tag', 'Hashtag', "Url";

## Your testing code below ##
fixtures_ok sub {
    my $schema = shift @_;
    my $user_rs = $schema->resultset('User');
    my $now = DateTime->now();
    $user_rs->create({
        screen_name => "User One",
        profile_image_url => 'Profile Image One',
        profile_bkg_url => 'Background Image One',
        access_token => 'Access Token One',
        access_token_secret => 'Access Secret One',
        tweets => [
                {
                    tweet_id=>1, 
                    text=>'Tweet One',
                    retweeted => 1,
                    retweeted_count => 100_000,
                    favorited => 1,
                    favorited_count => 50_000,
                    created_at => $now,
                    tweet_mentions => [
                        {mention => {screen_name => 'Mention One'}},
                        {mention => {screen_name => 'Mention Two'}},
                    ],
                    tweet_urls => [
                        {url => {address => 'Url One'}},
                        {url => {address => 'Url Two'}},
                    ],
                    tweet_hashtags => [
                        {hashtag => {topic => 'Topic One'}},
                        {hashtag => {topic => 'Topic Two'}},
                        {hashtag => {topic => 'Topic Three'}},
                    ],
                    tweet_tags => [
                        {tag => {text => 'Tag One'}},
                        {tag => {text => 'Tag Two'}},
                    ],

                },
                {
                    tweet_id=>2, 
                    text=>'Tweet Two',
                    retweeted => 1,
                    retweeted_count => 200_000,
                    favorited => 1,
                    favorited_count => 60_000,
                    created_at => DateTime->new(
                        year => $now->year - 1,
                        month => $now->month - 1,
                        day => $now->day,
                    ),
                    tweet_mentions => [
                        {mention => {screen_name => 'Mention Two'}},
                        {mention => {screen_name => 'Mention Three'}},
                        {mention => {screen_name => 'Mention Four'}},
                    ],
                    tweet_urls => [
                        {url => {address => 'Url Three'}},
                        {url => {address => 'Url Four'}},
                    ],
                    tweet_hashtags => [
                        {hashtag => {topic => 'Topic Two'}},
                        {hashtag => {topic => 'Topic Three'}},
                        {hashtag => {topic => 'Topic Four'}},
                    ],
                    tweet_tags => [
                        {tag => {text => 'Tag Three'}},
                        {tag => {text => 'Tag Four'}},
                        {tag => {text => 'Tag One'}},
                    ],

                },
                {
                    tweet_id=>3, text=>'Tweet Three',
                    created_at => DateTime->new(
                        year => 2010, month => 5, day => 6
                    ),
                    retweeted_count => 200_000,
                    tweet_hashtags => [
                        {hashtag => {topic => 'Topic Three'}},
                    ],
                },
        ],
    });
    $user_rs->create({
        screen_name => 'User Two',
        profile_image_url => 'Profile Image Two',
        profile_bkg_url => 'Background Image Two',
        access_token => 'Access Token Two',
        access_token_secret => 'Access Secret Two',
        tweets => [
                {
                    text=>'Tweet Five',
                    retweeted => 1,
                    retweeted_count => 300_000,
                    favorited => 1,
                    favorited_count => 70_000,
                    created_at => $now,
                    tweet_mentions => [
                        {mention => {screen_name => 'Mention Five'}},
                        {mention => {screen_name => 'Mention Six'}},
                    ],
                    tweet_urls => [
                        {url => {address => 'Url Five'}},
                        {url => {address => 'Url Six'}},
                    ],
                    tweet_hashtags => [
                        {hashtag => {topic => 'Topic Five'}},
                        {hashtag => {topic => 'Topic Six'}},
                    ],
                    tweet_tags => [
                        {tag => {text => 'Tag Five'}},
                        {tag => {text => 'Tag Six'}},
                    ],

                },
                {
                    text=>'Tweet Six',
                    retweeted => 1,
                    retweeted_count => 200_000,
                    favorited => 1,
                    favorited_count => 60_000,
                    created_at => DateTime->new(
                        year => $now->year - 1,
                        month => $now->month - 1,
                        day => $now->day,
                    ),
                    tweet_mentions => [
                        {mention => {screen_name => 'Mention Seven'}},
                        {mention => {screen_name => 'Mention Eight'}},
                        {mention => {screen_name => 'Mention One'}},
                    ],
                    tweet_urls => [
                        {url => {address => 'Url Seven'}},
                        {url => {address => 'Url Eight'}},
                    ],
                    tweet_hashtags => [
                        {hashtag => {topic => 'Topic Seven'}},
                        {hashtag => {topic => 'Topic Eight'}},
                    ],
                    tweet_tags => [
                        {tag => {text => 'Tag Seven'}},
                        {tag => {text => 'Tag Eight'}},
                        {tag => {text => 'Tag One'}},
                    ],

                },
                {
                    text=>'Tweet Seven',
                    created_at => DateTime->new(
                        year => 2010, month => 5, day => 17
                    )
                },
        ],
    });

    }, 'Installed fixtures';
## Your testing code above ##

ok my $user = User->find({screen_name => "User One"})
    => "We have a user";

is( $user->tweets->count, 3, => "Who has three tweets");

lives_ok( sub {$user->add_to_tweets({text => "Tweet Four"})}
    => "Can add tweet");

is( $user->tweets->count, 4 => "Who now has four tweets");

is_deeply(
    [ $user->tweets->get_column('text')->all ],
    ["Tweet One", "Tweet Two", "Tweet Three", "Tweet Four"],
    'The tweets have the right texts'
    );

is_deeply(
    [ Tweet->get_column('text')->all ],
    ["Tweet One", "Tweet Two", "Tweet Three", 
        "Tweet Five", "Tweet Six", "Tweet Seven", "Tweet Four"],
    'All tweets have the right texts'
);

ok my $tweet = Tweet->find(1)
    => "Found tweet 1";

is $tweet->text, "Tweet One"
    => "It has the right text";

is $tweet->mentions->count, 2
    => "It has the right number of mentions";

lives_ok( 
    sub {
        $tweet->add_to_mentions({screen_name => "Added One"})
    },
    "Can add mentions"
);

is $tweet->mentions->count, 3
    => "It has the right number of mentions";

is Mention->search()->count, 9
    => "The right number of mentions all round";

lives_ok( 
    sub {
        $tweet->add_to_mentions({screen_name => "Mention Three"})
    },
    "Can add mentions"
);

is Mention->search()->count, 9
    => "This doesn't add a new mention unnecessarily to the db";

my $user_one_mentions = Mention->search(
    {   
        'user.screen_name' => "User One"
    },
    {   
        join => {tweet_mentions => { tweet => 'user'}},
        distinct => 1,
    }
);

is $user_one_mentions->count, 5, "Can find mentions by user";

my $tweets_before_today = Tweet->search({
        created_at => {'<=', DateTime->now()},
    });

is $tweets_before_today->count, 6, "Can find tweets by date comparison";

my $start_of_may = DateTime->new(
    year => 2010,
    month => 5,
    day => 1,
);
my $start_of_june = DateTime->new(
    year => 2010,
    month => 6,
    day => 1,
);
my $tweets_in_may2010 = Tweet
    ->search({created_at => {'>' => $start_of_may}})
    ->search({created_at => {'<' => $start_of_june}});

is $tweets_in_may2010->count, 2, "Can find tweets in a particular month";

$tweet = Tweet->find({text => "Tweet Six"});

is $tweet->tags->count, 3, "Can find tags ok";
is_deeply(
    [$tweet->tags->get_column("text")->all],
    ["Tag Seven", "Tag Eight", "Tag One"],
    "And they have the right topics",
);
is Tag->count, 8, "We have the right total tag count";

lives_ok(
    sub {$tweet->add_to_tags({text => "Tag Two"})},
    "Can add a tag"
);
is $tweet->tags->count, 4, "Now have three tags";

is Tag->count, 8, "Adding an existing tag doesn't change the overall count";

ok my $tag = $tweet->tags->find({text => "Tag Two"})
    => "Can find the added tag";

ok my $link = $tag->tweet_tags->find({
        tweet => $tweet
    }) => "Can find the link";
$link->delete;

is Tag->count, 8, "Deleting a link doesn't delete the tag";

ok ! ($tag = $tweet->tags->find({text => "Tag Two"}))
    => "The tweet is no longer tagged with the unlinked tag";

is $tweet->tags->count, 3, "Back to two tags";

is Tweet->search({retweeted_count => {'>=' => 1}})->count, 5
    => "There are the right number of retweets";

my @retweet_counts = grep {defined}
        map {$_->retweeted_count} 
        Tweet->search(
            undef, 
            {
                select => ['retweeted_count'],
                distinct => 1,
            }
        );

is_deeply(
    [ @retweet_counts ],
    [ 100_000, 200_000, 300_000 ],
    "Can summarise the retweet counts"
) or diag(explain(\@retweet_counts));

is Tweet->search({retweeted_count => 200_000})->count, 3
    => "And we can get the right number of retweets by count";

ok my $user_one = User->find({screen_name => "User One"})
    => "Can find user one";

my $userOnes_200_000er_tweets = $user_one->tweets->search(
    {retweeted_count => 200_000}
);

my @occurances_of_topics = 
    map {[$_->topic() => $_->get_column('count')]}
    sort {$b->get_column('count') <=> $a->get_column('count')}
    Hashtag->search(
    {   
        'user.screen_name' => "User One"
    },
    {   
        select => [
            'topic',
            {count => 'topic'}
        ],
        as => [qw/topic count/],
        join => {tweet_hashtags => { tweet => 'user'}},
        distinct => 1,
    }
);
is_deeply(
    [@occurances_of_topics],
    [
        ['Topic Three' => '3'],
        ['Topic Two' => '2'],
        ['Topic Four' => '1'],
        ['Topic One' => '1'],
    ],
    "Can summarise hashtags properly"
) or diag(explain \@occurances_of_topics);

is $user_one->tweets->get_column('tweet_id')->max, 7
    => "get_since_id_for logic test";

is $user_one->tweets->find(7)->text, "Tweet Four"
    => "The since id points to the right record";

is User->find_or_create({screen_name => "User One"})->id, 
    $user_one->id(),
    "get_user_record logic test";
    
is_deeply(
    [$user_one->access_token, $user_one->access_token_secret],
    ['Access Token One', 'Access Secret One'],
    "restore_tokens logic test"
);

lives_ok(
    sub {$user_one->update({
        access_token => "Token One - Updated",
        access_token_secret => "Secret One - Updated",
    });},
    "Can update tokens"
);

is_deeply(
    [$user_one->access_token, $user_one->access_token_secret],
    ['Token One - Updated', 'Secret One - Updated'],
    "save_tokens logic test"
);

my $user_tweets_rs = $user_one->tweets->search(
    undef,
    {order_by => {-desc => 'tweet_id'}},
);
is $user_tweets_rs->count, 4
    => "restore_statuses_for count test";

is_deeply(
    [$user_tweets_rs->get_column('text')->all],
    ["Tweet Four", "Tweet Three", "Tweet Two", "Tweet One"],
    "restore_statuses_for content test"
);

ok my $tweet_7 = Tweet->find({text => "Tweet Seven"})
    => "Can find tweet 7";

is $tweet_7->tags->count, 0
    => "Starts with 0 tags";


is $tweet_7->urls->count, 0
    => "Starts with 0 urls";

lives_ok(
    sub {$tweet_7->add_to_urls({address => "Added Url"})},
    "Can add a url"
);

is $tweet_7->urls->count, 1
    => "Now has 1 url";

ok my $added_url = Url->find({address => "Added Url"})
    => "Can find the added url";

is $added_url->tweets->count, 1
    => "The added url has one tweet";

is Url->count, 9
    => "The number of urls overall is right";

lives_ok(
    sub {$tweet_7->add_to_urls({address => "Url One"})},
    "Can add an existing url"
);

is $tweet_7->urls->count, 2
    => "The count of urls for the tweet has gone up";

is Url->count, 9
    => "The number of urls overall hasn't gone up";

my @user_one_tweets = $user_one->tweets;
is scalar(@user_one_tweets), 4
    => "Make content logic test: get tweets by user";

my $first_tweet = shift @user_one_tweets;

is $first_tweet->text, "Tweet One"
    => "Make content logic test: get attributes of tweet";

is $first_tweet->mentions->count, 4
    => "Make content logic test: get references of tweets";

is $first_tweet->mentions->first->screen_name, "Mention One"
    => "Make content logic test: get attributes of references";

is_deeply(
    [$first_tweet->tags->get_column("text")->all],
    ["Tag One", "Tag Two"],
    "Make content logic test: get tags as a list"
);

my @years = uniq map {$_->created_at->year} 
                    $user_one->search_related('tweets',
                        { created_at => {'!=' => undef}})->all;
is_deeply(
    \@years,
    [2010, 2009],
    "get_years_for logic test"
) or diag explain \@years;

my $year_start = DateTime->new(year => 2010, month => 1, day => 1);
my $year_end =  DateTime->new(year => 2010, month => 12, day => 31);

my @months = uniq map {$_->created_at->month} 
                    $user_one->search_related('tweets',
                        {created_at => {'!=' => undef}})
                    ->search({created_at => {'>=' => $year_start}})
                    ->search({created_at => {'<=' => $year_end}})
                    ->all;
is_deeply(
    \@months,
    [12, 5],
    "get_months_in logic test"
) or diag explain \@months;

my @statuses = map {$_->text}
               $user_one->tweets
                        ->search(
                            {'tag.text' => "Tag One"},
                            {'join' => {tweet_tags => 'tag'}}
                        )->all;

is_deeply(
    \@statuses,
    ["Tweet One", "Tweet Two"],
    "Can find tweets by user and tag text",
) or diag explain \@statuses;
done_testing;
