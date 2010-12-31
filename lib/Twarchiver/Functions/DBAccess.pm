package Twarchiver::Functions::DBAccess;

use strict;
use warnings;
use Carp qw/confess/;
require Dancer;
use Twarchiver::Schema;
use List::MoreUtils qw(uniq);
use Data::Dumper;

use feature qw( :5.10 );

=head1 NAME

Twarchiver::DBActions - Functions for interacting with the database

=head1 SYNOPSIS

  use Twarchiver::DBAccess qw(:all);

  my @tweets = get_all_tweets_for($user);

This module contains functions primarily used for interacting with the 
database, either for data retrieval or data storage.

=head1 Functions

=cut

use Exporter 'import';
our @EXPORT_OK = qw/
    get_db get_all_tweets_for get_user_record get_since_id_for 
    get_tweet_record get_urls_for get_mentions_for get_hashtags_for
    get_tags_for store_twitter_statuses add_tags_to_tweets 
    remove_tags_from_tweets restore_tokens save_user_info
    get_tweets_with_tag get_tweets_in_month get_retweeted_tweets
    get_months_in get_years_for get_retweet_summary
    get_tweets_with_mention get_tweets_with_hashtag get_tweets_with_url
    store_user_info
    get_most_recent_tweet_by
    get_tweets_from
    exists_user
    validate_user
    get_tweet_count
    get_retweet_count
    mentions_added_since
    get_oldest_id_for
    get_twitter_account
/;
our %EXPORT_TAGS = (
    'all' => [qw/
    get_db get_all_tweets_for get_user_record get_since_id_for 
    get_tweet_record get_urls_for get_mentions_for get_hashtags_for
    get_tags_for store_twitter_statuses add_tags_to_tweets 
    remove_tags_from_tweets restore_tokens save_user_info
    get_tweets_with_tag get_tweets_in_month get_retweeted_tweets
    get_months_in get_years_for get_retweet_summary
    get_tweets_with_mention get_tweets_with_hashtag get_tweets_with_url
    store_user_info
    get_most_recent_tweet_by
    get_tweets_from
    get_twitter_account
    /],
    'routes' => [qw/
    get_all_tweets_for get_tweets_with_tag get_retweeted_tweets 
    get_years_for get_mentions_for get_hashtags_for get_urls_for
    get_tags_for get_tweets_in_month get_user_record  
    add_tags_to_tweets remove_tags_from_tweets
    get_most_recent_tweet_by get_tweets_with_tag 
    get_tweets_with_mention get_tweets_with_hashtag get_tweets_with_url
    get_tweets_from
    get_tweet_count
    get_retweet_count
    get_twitter_account
    /],
    'pagecontent' => [qw/
    get_user_record get_retweet_summary get_months_in 
    get_tweets_in_month 
    get_twitter_account
    /],
    twitterapi => [qw/
    save_user_info restore_tokens store_twitter_statuses get_since_id_for
    store_user_info get_user_record
    mentions_added_since
    get_all_tweets_for
    get_oldest_id_for
    get_twitter_account
    /],
    login => [qw/
    exists_user validate_user get_user_record
    /],
);

my $mentions_re  = qr/\@(\w+\b)/;
my $hashtags_re  = qr/(\#[\w-]+)/;
my $urls_re      = qr{
    (
        http://[\w\./]+\b
    |   
        [\w\.]+\.[\w\.]*
        (?:com|co\.uk|org|ly)
        [\w\&\?/]*
    )
}x;

#my $dt_parser = DateTime::Format::Strptime->new( pattern => '%a %b %d %T %z %Y' );

=head2 get_db

Function: Get a connection to the database
Returns:  A DBIx::Class::Schema instance

=cut

sub get_db {
    state $schema;
    unless ($schema) {
        Dancer::debug( "Connecting to " . Dancer::setting('database') );
        $schema = Twarchiver::Schema->connect(
            "dbi:SQLite:dbname=". Dancer::setting('database'),
            undef, undef,
            {AutoCommit => 1}
        );
    }

    return $schema;
}

=head2 [ResultRow] get_user_record( screen_name )

Function:  Get the db record for the given user
Arguments: The user's twitter screen name
Returns:   A DBIx::Class User result row object

=cut

sub get_user_record {
    my $user = shift;
    my $condition  = {
        username => $user,
    };
    my $db = get_db();
    my $user_rec = $db->resultset('User')->find_or_create(
        $condition,
    );
    return $user_rec;
}

=head2 get_all_tweets_for( screen_name, [condition] )

Function:  get tweets from database for a specific user
Arguments: the user's twitter screen name
           (optionally) a condition to search by
Returns:   <List Context> A list of the users statuses (Row objects) 
           <Scalar|Void> A result set of the same.

=cut
    
sub get_all_tweets_for {
    my $user      = shift;
    my $condition = shift;
    my $user_rec = get_user_record($user);
    if ($user_rec->has_twitter_account) {
        return $user_rec->twitter_account->tweets->search( $condition,
                            {order_by => {-desc => 'tweeted_at'}},
                        );
    } else {
        return;
    }
}

=head2 get_since_id_for( screen_name )

Function:  get the id of the most recent tweet for this user
Arguments: The user's twitter screen name
Returns:   The id (scalar)

=cut

sub get_since_id_for {
    my $screen_name = shift;
    if (my $most_recent_tweet = get_most_recent_tweet_by($screen_name)) {
        return $most_recent_tweet->tweet_id;
    } else {
        return;
    }
}
sub get_oldest_id_for {
    my $screen_name = shift;
    my $oldest_tweet = get_oldest_tweet_by($screen_name);
    if ($oldest_tweet) {
        return $oldest_tweet->tweet_id;
    } else {
        return;
    }
}

sub get_most_recent_tweet_by {
    my $screen_name = shift;
    if (my $twitter_account = get_twitter_account($screen_name)) {
        my $since = $twitter_account->tweets
                             ->get_column('tweeted_at')->max;
        my $most_recent = $twitter_account->tweets
                                ->find({tweeted_at => $since});
        return $most_recent;
    } else {
        return;
    }
}
sub get_twitter_account {
    my $screen_name = shift;
    my $search = get_db()->resultset('TwitterAccount')
                         ->search({screen_name => $screen_name});
    unless ($search->count) {
        confess ("No twitter ac found for '$screen_name'");
    }
    return $search->single;
}

sub get_oldest_tweet_by {
    my $screen_name = shift;
    my $twitter_account = get_twitter_account($screen_name);
    if ($twitter_account and $twitter_account->has_tweets) {
        my $first = $twitter_account->tweets
                             ->get_column('tweeted_at')->min;
        my $oldest = $twitter_account->tweets
                                ->find({tweeted_at => $first});
        return $oldest;
    } else {
        return;
    }
}

=head2 [ResultRow] get_tweet_record( tweet_id, screen_name )

Function:  Get the tweet with the given id by the given user, or add
           one to the user's list of tweets.
Arguments: The tweet id, and the screen name of the tweeter
Returns:   A DBIx::Class Tweet row object

=cut 

sub get_tweet_record {
    my ($screen_name, $id, $text) = @_;
    my $db = get_db();
    my $twitter_ac = get_twitter_account($screen_name);
    confess("no twitter account") unless $twitter_ac;
    my $tweet = $twitter_ac->tweets->find(
        {'tweet_id' => $id,}
    );
    unless ($tweet) {
        $tweet = $twitter_ac->add_to_tweets({
                tweet_id => $id,
                text     => $text,
        });
    }
    return $tweet;
}

=head2 store_twitter_statuses( list_of_tweets )

Function:  Store the tweets in the database
Arguments: The list of twitter statuses returned from the Twitter API

=cut

sub store_twitter_statuses {
    my (@statuses) = @_;
    for (@statuses) {
        my $tweet_rec = get_tweet_record(
            $_->user->screen_name, $_->id, $_->text);
        $tweet_rec->update({
            retweeted_count => $_->retweet_count,
            favorited       => $_->favorited,
            tweeted_at      => $_->created_at,
        });
        my $text = $_->text;

        my @mentions = $text =~ /$mentions_re/g;
        for my $mention (@mentions) {
            $tweet_rec->add_to_mentions({screen_name => $mention})
                unless ($tweet_rec->mentions->search({screen_name => $mention})->count);
        }
        my @hashtags = $text =~ /$hashtags_re/g;
        for my $hashtag (@hashtags) {
            $tweet_rec->add_to_hashtags({topic => $hashtag})
                unless $tweet_rec->hashtags->search({topic => $hashtag})->count;
        }
        my @urls = $text =~ /$urls_re/g;
        for my $url (@urls) {
            $tweet_rec->add_to_urls({address => $url})
                unless $tweet_rec->urls->search({address => $url})->count;
        }
        $tweet_rec->update;
    }
}

sub store_user_info {
    my $user = shift;

    my $twitter_account = get_db()->resultset('TwitterAccount')
                                  ->find_or_create({
                                screen_name => $user->screen_name
                            });
    $twitter_account->update({
            twitter_id        => $user->id,
            created_at        => $user->created_at,
            profile_image_url => $user->profile_image_url,
            profile_bkg_url   => $user->profile_background_image_url,
            tweet_total       => $user->statuses_count,
        });
}

sub mentions_added_since {
    my $since = my $since_id = shift || 0;
    if ($since_id) {
        my $since_tweet = get_db()->resultset('Tweet')->find(
                            {tweet_id => $since_id});
        $since = $since_tweet->tweeted_at->ymd;
    }

    my @mentions = eval {
        local $SIG{__WARN__};        
        get_db()->resultset('TwitterAccount')
                           ->search(
                        {
                            "tweet.tweeted_at" => {'>' => $since},
                        },
                        {
                            'join' => {'tweet_mentions' => 'tweet'},
                        }
        )->all();
    };
    if (my $e = $@) {
        return;
    }

    return @mentions;
}

=head2 save_tokens( username, access_token, access_token_secret)

Function: Store the given tokens in the database in the given
          user's record

=cut

sub save_user_info {
    my ( $username, $token, $secret, $twitter_id, $screen_name ) = @_;
    my $user_rec = get_user_record($username);

    my $twitter_account = get_db()->resultset('TwitterAccount')
                                  ->find_or_create(
        { screen_name => $screen_name }
    );
    $user_rec->update({
            twitter_account => $twitter_account
        });
    Dancer::debug("Updated users twitter_account");
    $twitter_account->update({
            twitter_id => $twitter_id,
            access_token => $token,
            access_token_secret => $secret,
            user => $user_rec,
    });
}

=head2 restore_tokens( username)

Function: Get the tokens for this user back from the database
Returns:  The access tokens

=cut

sub restore_tokens {
    my $user = shift;
    my $user_rec = get_user_record($user);

    return unless ($user_rec->twitter_account);

    my @tokens = (
        $user_rec->twitter_account->access_token,
        $user_rec->twitter_account->access_token_secret,
    );

    return unless (grep({defined} @tokens) == 2);
    return @tokens;
}

=head2 [ResultsRow(s)] get_urls_for( screen_name )

Function:  Get url records associated with a particular user.
Arguments: (String) a twitter screen name
Returns:   <List Context> A list of result row objects
           <Scalar|Void> A result set object

=cut

sub get_urls_for {
    my $screen_name = shift;
    return get_tweet_features_for_user($screen_name, 
        'Url', 'address', 'tweet_urls');
}

=head2 [ResultsRow(s)] get_mentions_for( screen_name )

Function:  Get mention records associated with a particular user.
Arguments: (String) a twitter screen name
Returns:   <List Context> A list of result row objects
           <Scalar|Void> A result set object

=cut

sub get_mentions_for {
    my $screen_name = shift;
    return get_tweet_features_for_user($screen_name, 
        'TwitterAccount', 'screen_name', 'tweet_mentions');
}

=head2 [ResultsRow(s)] get_hashtags_for( screen_name )

Function:  Get mention records associated with a particular user.
Arguments: (String) a twitter screen name
Returns:   <List Context> A list of result row objects
           <Scalar|Void> A result set object

=cut

sub get_hashtags_for {
    my $screen_name = shift;
    return get_tweet_features_for_user($screen_name, 
        'Hashtag', 'topic', 'tweet_hashtags');
}

=head2 [ResultsRow(s)] get_tags_for( screen_name )

Function:  Get tag records associated with a particular user.
Arguments: (String) a twitter screen name
Returns:   <List Context> A list of result row objects
           <Scalar|Void> A result set object

=cut

sub get_tags_for {
    my $screen_name = shift;
    return get_tweet_features_for_user($screen_name, 
        'Tag', 'tag_text', 'tweet_tags');
}

=head2 [ResultsRow(s)] get_tweet_features_for_user( screen_name, source main_column bridge_table )

Function:  Get sub features of tweets associated with a particular user.
Arguments: (String) a twitter screen name
           (String) the name of the result source
           (String) the name of the main column of the object
           (String) the bridge table used in the many-many relationship
Returns:   <List Context> A list of result row objects
           <Scalar|Void> A result set object

This function is used by get_mentions_for et. al. to query the db.

=cut

sub get_tweet_features_for_user {
    my ($screen_name, $source, $main_col, $bridge_table) = @_;
    Dancer::debug(Dancer::to_dumper(\@_));
    my $search = get_db()->resultset($source)->search(
        {   
            'tweet.twitter_account' => $screen_name
        },
        {   
            'select' => [
                $main_col, 
                {count => $main_col, -as => 'number'}
            ],
            'as' => [$main_col, 'count'],
            'join' => {$bridge_table => 'tweet'},
            distinct => 1,
            'order_by' => {-desc => 'number'},
        }
    );
    return $search;
}

=head2 [HashRef] add_tags_to_tweets([tags], [tweet_ids])

Function:  Add the given tag list to the tweets with the given ids
Arguments: (ArrayRef[Str]) a list of tags
           (ArrayRef[Str]) a list of tweet ids
Returns:   (HashRef) a response detailing success/failure for each
           tag/tweet combination

=cut

sub add_tags_to_tweets {
    my @tags = @{(shift)};
    my @tweets = @{(shift)};
    my $username = Dancer::session('username');
    my $response = {};
    for my $tweet_id (@tweets) {
        my $tweet = get_db()->resultset('Tweet')
                            ->find({tweet_id => $tweet_id});
        if ($tweet) {
            for my $tag (@tags) {
                my $is_private = ($tag =~ s/^_//);
                if (tweet_has_tag($tweet, $tag)) {
                    push @{$response->{errors}}, 
                        "Tweet $tweet_id is already tagged with $tag";
                } else {
                    $tweet->add_to_tags({tag_text => $tag});
                    if ($is_private) {
                        my $link = $tweet->tweet_tags->find(
                            {'tag.tag_text' => $tag},
                            {'join' => 'tag'});
                        $link->update(
                            {private_to => get_user_record($username)}
                        );
                    }
                    push @{$response->{$tweet_id}{added}}, $tag;
                }
            }
            $tweet->update;
        } else {
            push @{$response->{errors}}, "Could not find tweet $tweet_id";
        }
    }
    return $response;
}
=head2 [Bool] tweet_has_tag(tweet, tag_text)

Returns true if the tweet is tagged with the given tag, and that 
tag is visible to the current user.

=cut

sub tweet_has_tag {
    my ($tweet, $tag) = @_;
    my $username = Dancer::session('username');
    return $tweet->tags->search(
        {
            tag_text => $tag,
                -or => [
            'tweet_tags.private_to.username' => $username,
            'tweet_tags.private_to' => undef,
            ],
        },
        {
            'join' => {'tweet_tags' => 'private_to'},
        }
    )->count;
}

=head2 [HashRef] remove_tags_from_tweets([tags], [tweet_ids])

Function:  Remove the given tag list from the tweets with the given ids
Arguments: (ArrayRef[Str]) a list of tags
           (ArrayRef[Str]) a list of tweet ids
Returns:   (HashRef) a response detailing success/failure for each
           tag/tweet combination

=cut

sub remove_tags_from_tweets {
    my @tags = @{(shift)};
    my @tweets = @{(shift)};
    my $username = Dancer::session('username');
    my $response = {};
    for my $tweet_id (@tweets) {
        my $tweet = get_db()->resultset('Tweet')
                            ->find({tweet_id => $tweet_id});
        if ($tweet) {
            for my $tag_str (@tags) {
                if (tweet_has_tag($tweet, $tag_str)) {
                    unlink_tag_from_tweet($tweet, $tag_str);
                    push @{$response->{$tweet_id}{removed}}, $tag_str;
                } else {
                    push @{$response->{errors}}, 
                        "Could not find tag '$tag_str' on tweet $tweet_id";
                }
            }
            $tweet->update;
        } else {
            push @{$response->{errors}}, "Could not find tweet $tweet_id";
        }
    }
    return $response;
}

=head2 unlink_tag_from_tweet(tweet, tag_text) 

Performs the deletion of a tag from a tweet

=cut

sub unlink_tag_from_tweet {
    my ($tweet, $tag_text) = @_;
    my $tag = $tweet->tags->find({tag_text => $tag_text});
    my $link = $tag->tweet_tags->find({tweet => $tweet});
    $link->delete;
}

=head2 [Results] get_tweets_with_tag( screen_name, tag )

Function:  Get all the tweets tagged with a particular tag by a given user
Arguments: (String) The user's twitter screen name
           (String) The tag we are searching by
Returns:   <List Context> DBIx::Class result rows
           <Scalar Context> A DBIx::Class result set

=cut

sub get_tweets_with_tag {
    my ($screen_name, $tag) = @_;
    my $username = Dancer::session('username');
    return get_twitter_account($screen_name)->tweets->search(
        {
            'tag.tag_text' => $tag,
            'tweet_tags.private_to' => [undef, $username],
        },
        {'join' => {tweet_tags => 'tag'}}
    );
}

=head2 [Results] get_tweets_with_mention( screen_name, mention )

Function:  Get all the tweets tagged with a particular mention by a given user
Arguments: (String) The user's twitter screen name
           (String) The mention we are searching by
Returns:   <List Context> DBIx::Class result rows
           <Scalar Context> A DBIx::Class result set

=cut

sub get_tweets_with_mention {
    my ($screen_name, $mention) = @_;
    return get_twitter_account($screen_name)->tweets->search(
        {'tweet_mentions.mention'    => $mention },
        {
            'join' => 'tweet_mentions',
        }
    );
}

=head2 [Results] get_tweets_with_hashtag( screen_name, hashtag )

Function:  Get all the tweets tagged with a particular hashtag by a given user
Arguments: (String) The user's twitter screen name
           (String) The hashtag we are searching by
Returns:   <List Context> DBIx::Class result rows
           <Scalar Context> A DBIx::Class result set

=cut

sub get_tweets_with_hashtag {
    my ($screen_name, $hashtag) = @_;
    return get_twitter_account($screen_name)->tweets->search(
        {'hashtag.topic'           => $hashtag },
        {'join' => {tweet_hashtags => 'hashtag'}}
    );
}

=head2 [Results] get_tweets_with_url( screen_name, url )

Function:  Get all the tweets tagged with a particular url by a given user
Arguments: (String) The user's twitter screen name
           (String) The url we are searching by
Returns:   <List Context> DBIx::Class result rows
           <Scalar Context> A DBIx::Class result set

=cut

sub get_tweets_with_url {
    my ($screen_name, $address) = @_;
    return get_twitter_account($screen_name)->tweets->search(
        {'url.address'           => $address },
        {'join' => {tweet_urls => 'url'}}
    );
}

=head2 [Results] get_retweeted_tweets( screen_name, count? )

Function:  Get the tweets by a given user retweeted by 
           other users (optionally: at least count times)
Arguments: (String)  The user's twitter screen name
           (Number)? The count required 
Returns:   <List Context> DBIx::Class result rows
           <Scalar Context> A DBIx::Class result set

=cut

sub get_retweeted_tweets {
    my ($screen_name, $count) = @_;
    my $column = 'retweeted_count';
    my $condition = ($count) 
        ? {$column => $count}
        : {$column => {'>' => 0}};
    return get_twitter_account($screen_name)->tweets->search($condition);
}

=pod 

=head2 [Results] get_retweet_summary( screen_name )

Function:  Get results summarising information about popular tweets, 
           gets the number of times tweets were retweeted/fav'ed
           and the number of tweets this applies to
Arguments: (String) The user's twitter screen name
           (String)  Either "retweeted" or "favorited"
Returns:   <List Context> DBIx::Class result rows
           <Scalar Context> A DBIx::Class result set

=cut

sub get_retweet_summary {
    my $screen_name = shift;
    my $col = 'retweeted_count';
    return get_twitter_account($screen_name)->tweets->search(
                    {
                        $col => {'>' =>  0},
                    },
                    {
                        'select' => [
                            $col,
                            {count => $col,
                            -as   => 'occurs'},
                        ],
                        as => [$col, 'occurs'],
                        distinct => 1,
                        'order_by' => {-desc => 'occurs'},
                    });
}

=head2 [@years] get_years_for( screen_name )

Function:  Get a list of years that a user has tweeted in
Arguments: (String) The user's twitter screen name
Returns:   (List[Str]) A list of years

=cut

sub get_years_for {
    my $screen_name = shift;
    my @years = uniq( 
                    map( {$_->tweeted_at->year} 
                    get_twitter_account($screen_name)->tweets->search(
                            { tweeted_at => {'!=' => undef}},
                            { order_by => {-desc => 'tweeted_at'}}
                        )->all)
                );
    return @years;
}

=head2 [@months] get_months_in( screen_name, year )

Function:  Get a list of months a user has tweeted in in a particular
           year.
Arguments: (String) The user's twitter screen name
           (String) A year (4 digits)
Returns:   (List[Str]) A list of months

=cut

sub get_months_in {
    my $screen_name = shift;
    my $year = shift;
    my $year_start = DateTime->new(year => $year, month => 1, day => 1);
    my $year_end =  DateTime->new(year => ++$year, month => 1, day => 1);

    my @months = uniq(
                map  {$_->tweeted_at->month} 
                get_twitter_account($screen_name)->tweets->search(
                        { tweeted_at => {'!='    => undef            }},
                        { order_by   => {'-desc' => 'tweeted_at'     }})
                ->search({tweeted_at => {'>='    => $year_start->ymd }})
                ->search({tweeted_at => {'<'     => $year_end->ymd   }})
                ->all
                );
    return @months;
}

=head2 [Results] get_tweets_in_month( screen_name, year, month )

Function:  Get the tweets by a given user from a given month
Arguments: (String) The user's twitter screen name
           (Number) The year (4 digit)
           (Number) The month (1 - 12)
Returns:   <List Context> DBIx::Class result rows
           <Scalar Context> A DBIx::Class result set

=cut

sub get_tweets_in_month {
    my ($screen_name, $year, $month) = @_;
    my $start_of_month = DateTime->new(
        year => $year, month => $month, day => 1);
    my $end_of_month = DateTime->new(
        year => $year, month => $month, day => 1
    )->add( months => 1 );

    return get_twitter_account($screen_name)->tweets->search(
                { tweeted_at => {'!='  => undef                }},
                { order_by   => {-desc => 'tweeted_at'         }})
        ->search({tweeted_at => {'>='  => $start_of_month->ymd }})
        ->search({tweeted_at => {'<'   => $end_of_month->ymd   }});
}

sub get_tweets_from {
    my ($screen_name, $epoch, $days) = @_;
    my $from = DateTime->from_epoch( epoch => $epoch);
    my $to = ($days)
        ? DateTime->from_epoch( epoch => $epoch)
                        ->add( days => $days)
        : DateTime->now();
    return get_twitter_account($screen_name)->tweets
                        ->search({tweeted_at => {'>=', $from->ymd}})
                        ->search({tweeted_at => {'<', $to->ymd}});
}

sub validate_user {
    my $username = shift;
    my $password = shift;
    
    my $user_rec = get_user_record($username);
    my $passhash = $user_rec->passhash;

    if (Crypt::SaltedHash->validate($passhash, $password)) {
        return 1;
    } else {
        return 0;
    }
}

sub exists_user {
    my $username = shift;
    return get_db()->resultset('User')
                   ->search({username => $username})
                   ->count;
}

sub get_tweet_count {
    my $screen_name = shift;
    if (my $ta = get_twitter_account($screen_name)) {
        return $ta->tweets->count;
    } else {
        return 0;
    }
}

sub get_retweet_count {
    my $screen_name = shift;
    if (my $ta = get_twitter_account($screen_name)) {
        return $ta->tweets
                  ->search({retweeted_count => {'>' => 0}})
                  ->count;
    } else {
        return 0;
    }
}

1;
