package Twarchiver::Functions::DBAccess;

use strict;
use warnings;
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
    remove_tags_from_tweets restore_tokens save_tokens
    get_tweets_with_tag get_tweets_in_month get_retweeted_tweets
    get_months_in get_years_for get_retweet_summary
    get_tweets_with_mention get_tweets_with_hashtag get_tweets_with_url
    store_user_info
    get_most_recent_tweet_by
    get_tweets_from
/;
our %EXPORT_TAGS = (
    'all' => [qw/
    get_db get_all_tweets_for get_user_record get_since_id_for 
    get_tweet_record get_urls_for get_mentions_for get_hashtags_for
    get_tags_for store_twitter_statuses add_tags_to_tweets 
    remove_tags_from_tweets restore_tokens save_tokens
    get_tweets_with_tag get_tweets_in_month get_retweeted_tweets
    get_months_in get_years_for get_retweet_summary
    get_tweets_with_mention get_tweets_with_hashtag get_tweets_with_url
    store_user_info
    get_most_recent_tweet_by
    get_tweets_from
    /],
    'routes' => [qw/
    get_all_tweets_for get_tweets_with_tag get_retweeted_tweets 
    get_years_for get_mentions_for get_hashtags_for get_urls_for
    get_tags_for get_tweets_in_month get_user_record  
    add_tags_to_tweets remove_tags_from_tweets
    get_most_recent_tweet_by get_tweets_with_tag 
    get_tweets_with_mention get_tweets_with_hashtag get_tweets_with_url
    get_tweets_from
    /],
    'pagecontent' => [qw/
    get_user_record get_retweet_summary get_months_in 
    get_tweets_in_month 
    /],
    twitterapi => [qw/
    save_tokens restore_tokens store_twitter_statuses get_since_id_for
    store_user_info
    /]
);

my $mentions_re  = qr/(\@\w+\b)/;
my $hashtags_re  = qr/(\#[\w-]+)/;
my $urls_re      = qr{(http://[\w\./]+\b|[\w\.]+(?:com|co\.uk|org|ly)[\w\&\?/]*)};

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
    my $id   = shift;
    my $condition  = {
        screen_name => $user,
    };
    my $db = get_db();
    my $user_rec = $db->resultset('User')->find_or_create(
        $condition,
        {
            prefetch => 'tweets'
        }
    );
    if ($id) {
        $user_rec->update({user_id => $id});
    }
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
    return $user_rec->tweets->search( $condition,
                        {order_by => {-desc => 'created_at'}},
                    );
}

=head2 get_since_id_for( screen_name )

Function:  get the id of the most recent tweet for this user
Arguments: The user's twitter screen name
Returns:   The id (scalar)

=cut

sub get_since_id_for {
    my $user = shift;
    my $most_recent_tweet = get_most_recent_tweet_by($user);
    if ($most_recent_tweet) {
        return $most_recent_tweet->tweet_id;
    } else {
        return;
    }
}

sub get_most_recent_tweet_by {
    my $user = shift;
    my $user_rec = get_user_record($user);
    if ($user_rec->tweets->count) {
        my $since = $user_rec->tweets->get_column('created_at')->max;
        my $most_recent = $user_rec->tweets
                                ->find({created_at => $since});
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
    my $user_rec = get_user_record($screen_name);
    my $tweet_rec = $user_rec->tweets->find(
        {'tweet_id' => $id,}
    );
    unless ($tweet_rec) {
        $tweet_rec = $user_rec->add_to_tweets({
                tweet_id => $id,
                text     => $text,
        });
    }
    return $tweet_rec;
}

=head2 store_twitter_statuses( list_of_tweets )

Function:  Store the tweets in the database
Arguments: The list of twitter statuses returned from the Twitter API

=cut

sub store_twitter_statuses {
    my @statuses = @_;
    for (@statuses) {
        my $tweet_rec = get_tweet_record(
            $_->user->screen_name, $_->id, $_->text);
        $tweet_rec->update({
            retweeted_count => $_->retweet_count,
            favorited       => $_->favorited,
            created_at      => $_->created_at,
        });
        my $text = $_->text;

        my @mentions = $text =~ /$mentions_re/g;
        for my $mention (@mentions) {
            $tweet_rec->add_to_mentions({mention_name => $mention});
        }
        my @hashtags = $text =~ /$hashtags_re/g;
        for my $hashtag (@hashtags) {
            $tweet_rec->add_to_hashtags({topic => $hashtag});
        }
        my @urls = $text =~ /$urls_re/g;
        for my $url (@urls) {
            $tweet_rec->add_to_urls({address => $url});
        }
        $tweet_rec->update;
    }
}

sub store_user_info {
    my $user = shift;
    my $user_rec = get_user_record($user->screen_name, $user->id);
    $user_rec->update({
            created_at => $user->created_at,
            profile_image_url => $user->profile_image_url,
            profile_bkg_url   => $user->profile_background_image_url,
        });
}

=head2 save_tokens( username, access_token, access_token_secret)

Function: Store the given tokens in the database in the given
          user's record

=cut

sub save_tokens {
    my ( $user, $token, $secret ) = @_;
    my $user_rec = get_user_record($user);

    $user_rec->update({
            access_token => $token,
            access_token_secret => $secret,
    });
}

=head2 restore_tokens( username)

Function: Get the tokens for this user back from the database
Returns:  The access tokens

=cut

sub restore_tokens {
    my $user = shift;
    my $user_rec = get_user_record($user);

    my @tokens = (
        $user_rec->access_token,
        $user_rec->access_token_secret,
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
    my $user = shift;
    return get_tweet_features_for_user($user, 
        'Url', 'address', 'tweet_urls');
}

=head2 [ResultsRow(s)] get_mentions_for( screen_name )

Function:  Get mention records associated with a particular user.
Arguments: (String) a twitter screen name
Returns:   <List Context> A list of result row objects
           <Scalar|Void> A result set object

=cut

sub get_mentions_for {
    my $user = shift;
    return get_tweet_features_for_user($user, 
        'Mention', 'mention_name', 'tweet_mentions');
}

=head2 [ResultsRow(s)] get_hashtags_for( screen_name )

Function:  Get mention records associated with a particular user.
Arguments: (String) a twitter screen name
Returns:   <List Context> A list of result row objects
           <Scalar|Void> A result set object

=cut

sub get_hashtags_for {
    my $user = shift;
    return get_tweet_features_for_user($user, 
        'Hashtag', 'topic', 'tweet_hashtags');
}

=head2 [ResultsRow(s)] get_tags_for( screen_name )

Function:  Get tag records associated with a particular user.
Arguments: (String) a twitter screen name
Returns:   <List Context> A list of result row objects
           <Scalar|Void> A result set object

=cut

sub get_tags_for {
    my $user = shift;
    return get_tweet_features_for_user($user, 
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
    my ($user, $source, $main_col, $bridge_table) = @_;
    my $search = get_db()->resultset($source)->search(
        {   
            'user.screen_name' => $user
        },
        {   
            'select' => [
                $main_col, 
                {count => $main_col, -as => 'number'}
            ],
            'as' => [$main_col, 'count'],
            join => {$bridge_table => { tweet => 'user'}},
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
    my $response = {};
    for my $tweet_id (@tweets) {
        my $tweet = get_db()->resultset('Tweet')
                            ->find({tweet_id => $tweet_id});
        if ($tweet) {
            for my $tag (@tags) {
                if ($tweet->tags->search({tag_text => $tag})->count) {
                    push @{$response->{errors}}, 
                        "Tweet $tweet_id is already tagged with $tag";
                } else {
                    $tweet->add_to_tags({tag_text => $tag});
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
    my $response = {};
    for my $tweet_id (@tweets) {
        my $tweet = get_db()->resultset('Tweet')
                            ->find({tweet_id => $tweet_id});
        if ($tweet) {
            for my $tag_str (@tags) {
                if ($tweet->tags->search({tag_text => $tag_str})->count) {
                    my $tag = $tweet->tags->find({tag_text => $tag_str});
                    my $link = $tag->tweet_tags->find({tweet => $tweet});
                    $link->delete;
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

=head2 [Results] get_tweets_with_tag( screen_name, tag )

Function:  Get all the tweets tagged with a particular tag by a given user
Arguments: (String) The user's twitter screen name
           (String) The tag we are searching by
Returns:   <List Context> DBIx::Class result rows
           <Scalar Context> A DBIx::Class result set

=cut

sub get_tweets_with_tag {
    my ($username, $tag) = @_;
    return get_all_tweets_for($username)->search(
        {'tag.tag_text' => $tag},
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
    my ($username, $mention) = @_;
    return get_all_tweets_for($username)->search(
        {'mention.mention_name'    => $mention },
        {'join' => {tweet_mentions => 'mention'}}
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
    my ($username, $hashtag) = @_;
    my $user = get_user_record($username);
    return get_all_tweets_for($username)->search(
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
    my ($username, $address) = @_;
    my $user = get_user_record($username);
    return get_all_tweets_for($username)->search(
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
    my ($username, $count) = @_;
    my $column = 'retweeted_count';
    my $condition = ($count) 
        ? {$column => $count}
        : {$column => {'>' => 0}};
    return get_all_tweets_for($username)->search($condition);
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
    my $username = shift;
    my $col = 'retweeted_count';
    return get_user_record($username)->tweets->search(
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
    my $username = shift;
    my $user = get_user_record($username);
    my @years = uniq( 
                    map( {$_->created_at->year} 
                        $user->search_related('tweets',
                            { created_at => {'!=' => undef}},
                            { order_by => {-desc => 'created_at'}}
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
    my $username = shift;
    my $year = shift;
    my $user = get_user_record($username);
    my $year_start = DateTime->new(year => $year, month => 1, day => 1);
    my $year_end =  DateTime->new(year => ++$year, month => 1, day => 1);

    my @months = uniq(
                map  {$_->created_at->month} 
                $user->search_related('tweets',
                        { created_at => {'!='    => undef            }},
                        { order_by   => {'-desc' => 'created_at'     }})
                ->search({created_at => {'>='    => $year_start->ymd }})
                ->search({created_at => {'<'     => $year_end->ymd   }})
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
    my ($username, $year, $month) = @_;
    my $user = get_user_record($username);
    my $start_of_month = DateTime->new(
        year => $year, month => $month, day => 1);
    my $end_of_month = DateTime->new(
        year => $year, month => $month, day => 1
    )->add( months => 1 );

    return  $user->tweets->search(
                { created_at => {'!='  => undef                }},
                { order_by   => {-desc => 'created_at'         }})
        ->search({created_at => {'>='  => $start_of_month->ymd }})
        ->search({created_at => {'<'   => $end_of_month->ymd   }});
}

sub get_tweets_from {
    my ($username, $epoch, $days) = @_;
    my $from = DateTime->from_epoch( epoch => $epoch);
    my $to = ($days)
        ? DateTime->from_epoch( epoch => $epoch)
                        ->add( days => $days)
        : DateTime->now();
    return get_user_record($username)->tweets
                        ->search({created_at => {'>=', $from->ymd}})
                        ->search({created_at => {'<', $to->ymd}});
}

sub validate_user {
    my $username = shift;
    my $password = shift;
    
    my $user_rec = get_user_record($user);
    my $passhash = $user_rec->passhash;

    if (Crypt::SaltedHash->validate($passhash, $password)) {
        return 1;
    } else {
        return 0;
    }
}


1;
