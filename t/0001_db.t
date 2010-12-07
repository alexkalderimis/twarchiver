#!/usr/bin/perl

use Test::More;

use lib 'lib';

use strict;
use warnings;

use DateTime;
use Test::Exception;

use Test::DBIx::Class {
    schema_class => 'Twarchiver::Schema',
    connect_info => ['dbi:SQLite:dbname=:memory:','',''],
    fixture_class => '::Populate',
}, 'User', 'Tweet', 'Mention';

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
                        {mention => {screen_name => 'Mention Three'}},
                        {mention => {screen_name => 'Mention Four'}},
                    ],
                    tweet_urls => [
                        {url => {address => 'Url Three'}},
                        {url => {address => 'Url Four'}},
                    ],
                    tweet_hashtags => [
                        {hashtag => {topic => 'Topic Three'}},
                        {hashtag => {topic => 'Topic Four'}},
                    ],
                    tweet_tags => [
                        {tag => {text => 'Tag Three'}},
                        {tag => {text => 'Tag Four'}},
                    ],

                },
                {tweet_id=>3, text=>'Tweet Three'},
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
                    ],

                },
                {text=>'Tweet Seven'},
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
done_testing;
