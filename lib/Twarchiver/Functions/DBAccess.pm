package Twarchiver::Functions::DBAccess;

use strict;
use warnings;
use Carp qw/confess/;
use Dancer;
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
    get_tags_for store_timeline_statuses store_search_statuses 
    add_tags_to_tweets remove_tags_from_tweets 
    restore_tokens save_user_info get_tweets_with_tag 
    get_tweets_in_month get_retweeted_tweets get_months_in 
    get_years_for get_retweet_summary
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
    get_tweets_by
    get_user_count_summary 
    beta_key_is_valid_and_unused
    assign_beta_key
    get_tags_from_tweet
    get_tweets_matching
    get_hashtag
    get_since_id_on
    get_tweets_on
    get_screen_name_list
    get_hashtags_list
/;
our %EXPORT_TAGS = (
    'all' => [qw/
    get_db get_all_tweets_for get_user_record get_since_id_for 
    get_tweet_record get_urls_for get_mentions_for get_hashtags_for
    get_tags_for store_timeline_statuses add_tags_to_tweets 
    remove_tags_from_tweets restore_tokens save_user_info
    get_tweets_with_tag get_tweets_in_month get_retweeted_tweets
    get_months_in get_years_for get_retweet_summary
    get_tweets_with_mention get_tweets_with_hashtag get_tweets_with_url
    store_search_statuses
    store_user_info
    get_most_recent_tweet_by
    get_tweets_from
    get_twitter_account
    get_tweets_by
    get_user_count_summary 
    beta_key_is_valid_and_unused
    assign_beta_key
    get_tags_from_tweet
    get_tweets_matching
    get_hashtag
    get_since_id_on
    get_tweets_on
    get_screen_name_list
    get_hashtags_list
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
    get_tweets_by
    get_user_count_summary 
    get_tags_from_tweet
    get_tweets_matching
    get_tweets_on
    get_screen_name_list
    get_hashtags_list
    /],
    'pagecontent' => [qw/
    get_user_record get_retweet_summary get_months_in 
    get_tweets_in_month 
    get_twitter_account
    get_hashtag
    /],
    twitterapi => [qw/
    save_user_info restore_tokens 
    store_timeline_statuses 
    store_search_statuses
    get_since_id_for
    store_user_info get_user_record
    mentions_added_since
    get_all_tweets_for
    get_oldest_id_for
    get_twitter_account
    get_hashtag
    get_since_id_on
    /],
    login => [qw/
    exists_user validate_user get_user_record
    beta_key_is_valid_and_unused
    assign_beta_key
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
            {
                AutoCommit => 1,
                sqlite_unicode => 1,
            }
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

sub get_oldest_id_with_hashtag {
    my $topic = shift;
    my $oldest_tweet = get_oldest_tweet_with_hashtag($topic);
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

sub get_since_id_on {
    my $topic = shift;
    if (my $most_recent_tweet = get_most_recent_tweet_on($topic)) {
        return $most_recent_tweet->tweet_id;
    } else {
        return;
    }
}

sub get_most_recent_tweet_on {
    my $topic = shift;
    my $hashtag = get_hashtag($topic);
    if ($hashtag and $hashtag->tweets->count) {
        my $since = $hashtag->tweets->get_column('tweeted_at')->max;
        my $most_recent = $hashtag->tweets->find({tweeted_at => $since});
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

sub get_oldest_tweet_with_hashtag {
    my $topic = shift;
    my $hashtag = get_hashtag($topic);
    if ($hashtag and $hashtag->has_tweets) {
        my $first = $hashtag->tweets->get_column('tweeted_at')->min;
        my $oldest = $hashtag->tweets->find({tweeted_at => $first});
        return $oldest;
    } else {
        return;
    }
}

sub get_hashtag {
    my $topic = shift;
    my $hashtag = get_db->resultset('Hashtag')
                        ->find_or_create({topic => $topic});
    return $hashtag;
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

=head2 store_search_statuses( list_of_tweets )

Function:  Store the tweets in the database
Arguments: The list of twitter statuses returned from the Twitter API

=cut

sub store_search_statuses {
    my (@statuses) = @_;
    for (@statuses) {
        store_user_info_from_search($_);
        my $tweet_rec = get_tweet_record(
            $_->from_user, $_->id, $_->text);
        $tweet_rec->update({
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

sub store_timeline_statuses {
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

sub store_user_info_from_search {
    my $user = shift;

    my $twitter_account = get_db()->resultset('TwitterAccount')
                                  ->find_or_create({
                                screen_name => $user->from_user
                            });
    $twitter_account->update({
            twitter_id        => $user->from_user_id,
            profile_image_url => $user->profile_image_url,
        });
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
    my %args = @_;
    if (my $screen_name = $args{screen_name}) {
        return get_tweet_features_for_user($screen_name, 
            'Url', 'address', 'tweet_urls');
    } elsif (my $topic = $args{topic}) {
        return get_tweet_features_for_topic($topic, 
            'Url', 'address', 'tweet_urls');
    } else {
        confess "Bad Arguments";
    }

}

=head2 [ResultsRow(s)] get_mentions_for( screen_name )

Function:  Get mention records associated with a particular user.
Arguments: (String) a twitter screen name
Returns:   <List Context> A list of result row objects
           <Scalar|Void> A result set object

=cut

sub get_mentions_for {
    my %args = @_;
    if (my $screen_name = $args{screen_name}) {
        return get_tweet_features_for_user($screen_name, 
            'TwitterAccount', 'screen_name', 'tweet_mentions');
    } elsif (my $topic = $args{topic}) {
        return get_tweet_features_for_topic($topic, 
            'TwitterAccount', 'screen_name', 'tweet_mentions');
    } else {
        confess "Bad Arguments";
    }
}


=head2 [ResultsRow(s)] get_hashtags_for( screen_name )

Function:  Get mention records associated with a particular user.
Arguments: (String) a twitter screen name
Returns:   <List Context> A list of result row objects
           <Scalar|Void> A result set object

=cut

sub get_hashtags_for {
    my %args = @_;
    if (my $screen_name = $args{screen_name}) {
        return get_tweet_features_for_user($screen_name, 
            'Hashtag', 'topic', 'tweet_hashtags');
    } elsif (my $topic = $args{topic}) {
        return get_tweet_features_for_topic($topic, 
            'Hashtag', 'topic', 'tweet_hashtags');
    } else {
        confess "Bad Arguments";
    }

}

=head2 [ResultsRow(s)] get_tags_for( screen_name )

Function:  Get tag records associated with a particular user.
Arguments: (String) a twitter screen name
Returns:   <List Context> A list of result row objects
           <Scalar|Void> A result set object

=cut

sub get_tags_for {
    my %args = @_;
    if (my $screen_name = $args{screen_name}) {
        return get_tweet_features_for_user($screen_name, 
            'Tag', 'tag_text', 'tweet_tags');
    } elsif (my $topic = $args{topic}) {
        return get_tweet_features_for_topic($topic, 
            'Tag', 'tag_text', 'tweet_tags');
    } else {
        confess "Bad Arguments";
    }
}

sub get_authors_for_topic {
    my $topic = shift;

    return get_db()->resultset('TwitterAccount')->search(
        {
            'hashtag.topic' => $topic,
        },
        {   
            'select' => [
                'screen_name',
                {count => 'screen_name', -as => 'number'}
            ],
            'as' => ['screen_name', 'count'],
            'join' => {
                tweets => {
                    tweet_hashtags => 
                        'hashtag'}},
            distinct => 1,
            'order_by' => {-desc => 'number'},
        }
    );
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
    debug(Dancer::to_dumper(\@_));
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

sub get_tweet_features_for_topic {
    my ($topic, $source, $main_column, $bridge_table) = @_;
    return get_db()->resultset($source)->search(
        {
            'hashtag.topic' => $topic,
        },
        {   
            'select' => [
                $main_column, 
                {count => $main_column, -as => 'number'}
            ],
            'as' => [$main_column, 'count'],
            'join' => {
                $bridge_table => {
                    tweet => {
                        tweet_hashtags => 
                            'hashtag'}}},
            distinct => 1,
            'order_by' => {-desc => 'number'},
        }
    );
}
sub get_hashtag_count_query {
    my %args = @_;
    my %count_args;
    if (my $screen_name = $args{screen_name}) {
        $count_args{constraint_path}  = 'tweet.twitter_account';
        $count_args{constraint_value} = $screen_name;
        $count_args{join}             = {tweet_hashtags => 'tweet'};
    } elsif (my $topic = $args{topic}) {
        $count_args{constraint_path}  = 'hashtag.topic';
        $count_args{constraint_value} = $topic;
        $count_args{join}             = 
            {tweet_hashtags => {tweet => {tweet_hashtags => 'hashtag'}}};
    } else {
        confess "Bad Arguments";
    }

    $count_args{main_column}      = 'hashtag_id';
    $count_args{source}           = 'Hashtag';
    $count_args{as_column}        = 'hashtag_count';
    my $query = get_count_query(%count_args);
    return $query;
}

sub get_mention_count_query {
    my %args = @_;
    my %count_args;
    if (my $screen_name = $args{screen_name}) {
        $count_args{constraint_path}  = 'tweet.twitter_account';
        $count_args{constraint_value} = $screen_name;
        $count_args{join}             = {tweet_mentions => 'tweet'};
    } elsif (my $topic = $args{topic}) {
        $count_args{constraint_path}  = 'hashtag.topic';
        $count_args{constraint_value} = $topic;
        $count_args{join}             = 
            {tweet_mentions => {tweet => {tweet_hashtags => 'hashtag'}}};
    } else {
        confess "Bad Arguments";
    }

    $count_args{main_column}      = 'screen_name';
    $count_args{source}           = 'TwitterAccount';
    $count_args{as_column}        = 'mention_count';
    my $mention_count_query = get_count_query(%count_args);
    return $mention_count_query;
}

sub get_url_count_query {
    my %args = @_;
    my %count_args;
    if (my $screen_name = $args{screen_name}) {
        $count_args{constraint_path}  = 'tweet.twitter_account';
        $count_args{constraint_value} = $screen_name;
        $count_args{join}             = {tweet_urls => 'tweet'};
    } elsif (my $topic = $args{topic}) {
        $count_args{constraint_path}  = 'hashtag.topic';
        $count_args{constraint_value} = $topic;
        $count_args{join}             = 
            {tweet_urls => {tweet => {tweet_hashtags => 'hashtag'}}};
    } else {
        confess "Bad Arguments";
    }

    $count_args{main_column}      = 'url_id';
    $count_args{source}           = 'Url';
    $count_args{as_column}        = 'url_count';
    my $query = get_count_query(%count_args);
    return $query;
}

sub get_tag_count_query {
    my %args = @_;
    my %count_args;
    if (my $screen_name = $args{screen_name}) {
        $count_args{constraint_path}  = 'tweet.twitter_account';
        $count_args{constraint_value} = $screen_name;
        $count_args{join}             = {tweet_tags => 'tweet'};
    } elsif (my $topic = $args{topic}) {
        $count_args{constraint_path}  = 'hashtag.topic';
        $count_args{constraint_value} = $topic;
        $count_args{join}             = 
            {tweet_tags => {tweet => {tweet_hashtags => 'hashtag'}}};
    } else {
        confess "Bad Arguments";
    }

    $count_args{main_column}      = 'tag_id';
    $count_args{source}           = 'Tag';
    $count_args{as_column}        = 'tag_count';
    my $query = get_count_query(%count_args);
    return $query;
}

sub get_tweets_count_query {
    my %args = @_;
    my %count_args;
    if (my $screen_name = $args{screen_name}) {
        $count_args{constraint_path}  = 'twitter_account.screen_name';
        $count_args{constraint_value} = $screen_name;
        $count_args{join}             = 'twitter_account';
    } elsif (my $topic = $args{topic}) {
        $count_args{constraint_path}  = 'hashtag.topic';
        $count_args{constraint_value} = $topic;
        $count_args{join}             = {tweet_hashtags => 'hashtag'};
    } else {
        confess "Bad Arguments";
    }

    $count_args{main_column}      = 'tweet_id';
    $count_args{source}           = 'Tweet';
    $count_args{as_column}        = 'tweet_count';
    my $query = get_count_query(%count_args);
    return $query;
}

sub get_retweet_count_query {
    my %args = @_;
    my %count_args;
    if (my $screen_name = $args{screen_name}) {
        $count_args{constraint_path}  = 'twitter_account.screen_name';
        $count_args{constraint_value} = $screen_name;
        $count_args{join}             = 'twitter_account';
    } elsif (my $topic = $args{topic}) {
        $count_args{constraint_path}  = 'hashtag.topic';
        $count_args{constraint_value} = $topic;
        $count_args{join}             = {tweet_hashtags => 'hashtag'};
    } else {
        confess "Bad Arguments";
    }

    $count_args{extra_constraint} = {'me.retweeted_count' => {'>' => 0}},
    $count_args{main_column}      = 'tweet_id';
    $count_args{source}           = 'Tweet';
    $count_args{as_column}        = 'retweet_count';
    my $query = get_count_query(%count_args);
    return $query;
}

sub get_tweeter_count_query {
    my %args = @_;
    return unless ($args{topic});
    my %count_args = (
        source           => 'TwitterAccount',
        constraint_path  => 'hashtag.topic',
        constraint_value => $args{topic},
        main_column      => 'screen_name',
        as_column        => 'tweeter_count',
        join             => {tweets => {tweet_hashtags => 'hashtag'}},
    );
    return get_count_query(%count_args);
}

sub get_count_query {
    my %args = @_;
    my %constraint = (
        $args{constraint_path} => $args{constraint_value},
    );
    @constraint{keys %{$args{extra_constraint}}} 
        = values(%{$args{extra_constraint}}) if $args{extra_constraint};
    return get_db()->resultset($args{source})->search(\%constraint,
        {
            'select' => {count => $args{main_column}},
            'as'     => [$args{as_column}],
            'join'   => $args{join},
        }
    )->as_query;
}

sub get_user_count_summary {
    my %args = @_;

    my $mention_count_query  = get_mention_count_query(%args);
    my $hashtags_count_query = get_hashtag_count_query(%args);
    my $urls_count_query     = get_url_count_query(%args);
    my $tag_count_query      = get_tag_count_query(%args);
    my $tweet_count_query    = get_tweets_count_query(%args);
    my $retweet_count_query  = get_retweet_count_query(%args);
    my $tweeter_count_query  = get_tweeter_count_query(%args);

    my $source;
    my $constraint;
    my $select = [
                $tweet_count_query,
                $retweet_count_query,
                $hashtags_count_query,
                $tag_count_query,
                $mention_count_query,
                $urls_count_query,
    ];
    my $as = [qw/tweet_count retweet_count hashtag_count tag_count 
                mention_count urls_total/];
    if (my $screen_name = $args{screen_name}) {
        $source = 'TwitterAccount';
        $constraint = {screen_name => $screen_name};
        push @$select, 'created_at';
        push @$as,'created_at';
    } elsif (my $topic = $args{topic}) {
        $source = 'Hashtag';
        $constraint = {topic => $topic},
        push @$select, $tweeter_count_query;
        push @$as,'tweeter_count';
    } else {
        confess "Bad Arguments";
    }

    my $rs = get_db()->resultset($source);
    # for speed
    $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    my $data = $rs->find($constraint,{'select' => $select, 'as' => $as});

    if (my $screen_name = $args{screen_name}) {
        $data->{beginning}   = DateTime::Format::SQLite->parse_datetime(
                                $data->{created_at})->dmy;
        $data->{most_recent} = get_most_recent_tweet_by($screen_name)
                                ->tweeted_at->dmy();
    } elsif (my $topic = $args{topic}) {
        $data->{beginning}   = get_oldest_tweet_with_hashtag($topic)
                                ->tweeted_at->dmy();
        $data->{most_recent} = get_most_recent_tweet_on($topic)
                                ->tweeted_at->dmy();
    }
    return $data;
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
                    $tweet->add_to_tags({
                        tag_text => $tag,
                        tagger => get_user_record($username),
                    });
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

=head2 [Results] get_tweets_with_tag( screen_name, tag, [max_id] )
Function:  Get all the tweets tagged with a particular tag by a given user
Arguments: (String) The user's twitter screen name
           (String) The tag we are searching by
Returns:   <List Context> DBIx::Class result rows
           <Scalar Context> A DBIx::Class result set

=cut

sub get_tweets_with_tag {
    my ($screen_name, $tag, $max_id) = @_;
    my $username = Dancer::session('username');
    my $rs = get_tweets_by($screen_name, $max_id)->search(
        {
            'tag.tag_text' => $tag,
            'tweet_tags.private_to' => [undef, $username],
        },
        {'join' => {tweet_tags => 'tag'}}
    );
    if (wantarray) {
        return tweet_page_from_rs($rs, $max_id);
    } else {
        return $rs;
    }
}

=head2 [Results] get_tweets_with_mention( screen_name, mention, [max_id] )

Function:  Get all the tweets tagged with a particular mention by a given user
Arguments: (String) The user's twitter screen name
           (String) The mention we are searching by
Returns:   <List Context> DBIx::Class result rows
           <Scalar Context> A DBIx::Class result set

=cut

sub get_tweets_with_mention {
    my ($screen_name, $mention, $max_id) = @_;
    my $rs = get_tweets_by($screen_name, $max_id)->search(
        {'tweet_mentions.mention'    => $mention },
        {
            'join' => 'tweet_mentions',
        }
    );
    if (wantarray) {
        return tweet_page_from_rs($rs, $max_id);
    } else {
        return $rs;
    }
}

=head2 [Results] get_tweets_with_hashtag( screen_name, hashtag, [max_id])

Function:  Get all the tweets tagged with a particular hashtag by a given user
Arguments: (String) The user's twitter screen name
           (String) The hashtag we are searching by
Returns:   <List Context> DBIx::Class result rows
           <Scalar Context> A DBIx::Class result set

=cut

sub get_tweets_with_hashtag {
    my ($screen_name, $hashtag, $max_id) = @_;
    my $rs = get_tweets_by($screen_name, $max_id)->search(
        {'hashtag.topic'           => $hashtag },
        {'join' => {tweet_hashtags => 'hashtag'}}
    );
    return $rs;
}

=head2 [Results] get_tweets_with_url( screen_name, url, [max_id] )

Function:  Get all the tweets tagged with a particular url by a given user
Arguments: (String) The user's twitter screen name
           (String) The url we are searching by
Returns:   <List Context> DBIx::Class result rows
           <Scalar Context> A DBIx::Class result set

=cut

sub get_tweets_with_url {
    my ($screen_name, $address, $max_id) = @_;
    my $rs = get_tweets_by($screen_name, $max_id)->search(
        {'url.address'           => $address },
        {'join' => {tweet_urls => 'url'}}
    );
    if (wantarray) {
        return tweet_page_from_rs($rs, $max_id);
    } else {
        return $rs;
    }
}

=head2 [Results] get_retweeted_tweets( screen_name, [count], [max_id] )

Function:  Get the tweets by a given user retweeted by 
           other users (optionally: at least count times)
Arguments: (String)  The user's twitter screen name
           (Number)? The count required 
Returns:   <List Context> DBIx::Class result rows
           <Scalar Context> A DBIx::Class result set

=cut

sub get_retweeted_tweets {
    my ($screen_name, $count, $max_id) = @_;
    my $column = 'retweeted_count';
    my $condition = ($count) 
        ? {$column => $count}
        : {$column => {'>' => 0}};
    my $rs = get_tweets_by($screen_name, $max_id)->search($condition);
    if (wantarray) {
        return tweet_page_from_rs($rs, $max_id);
    } else {
        return $rs;
    }
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
    my %args = @_;
    my $thing;
    if (my $screen_name = $args{screen_name}) {
        $thing = get_twitter_account($screen_name);
    } elsif (my $topic = $args{topic}) {
        $thing = get_hashtag($topic);
    } else {
        confess "Bad Arguments:", @_;
    }
    my $col = 'retweeted_count';
    return $thing->tweets->search(
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
    my %args = @_;
    my $thing;
    if (my $screen_name = $args{screen_name}) {
        $thing = get_twitter_account($screen_name);
    } elsif (my $topic = $args{topic}) {
        $thing = get_hashtag($topic);
    } else {
        confess "Bad Arguments:", @_;
    }
    my @years = uniq( 
        map( {$_->tweeted_at->year} 
                $thing->tweets->search(
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
    my %args = @_;
    my $thing;
    if (my $screen_name = $args{screen_name}) {
        $thing = get_twitter_account($screen_name);
    } elsif (my $topic = $args{topic}) {
        $thing = get_hashtag($topic);
    } else {
        confess "Bad Arguments:", @_;
    }
    my $year = $args{year};
    my $year_start = DateTime->new(year => $year, month => 1, day => 1);
    my $year_end =  DateTime->new(year => ++$year, month => 1, day => 1);

    my @months = uniq(
        map  {$_->tweeted_at->month} 
        $thing->tweets->search(
                { tweeted_at => {'!='    => undef            }},
                { order_by   => {'-desc' => 'tweeted_at'     }})
        ->search({tweeted_at => {'>='    => $year_start->ymd }})
        ->search({tweeted_at => {'<'     => $year_end->ymd   }})
        ->all
        );
    return @months;
}

=head2 [Results] get_tweets_in_month( screen_name, year, month, [max_id] )

Function:  Get the tweets by a given user from a given month
Arguments: (String) The user's twitter screen name
           (Number) The year (4 digit)
           (Number) The month (1 - 12)
Returns:   List of DBIx::Class result rows

=cut

sub get_tweets_in_month {
    my %args = @_;
    my $superset;
    if (my $screen_name = $args{screen_name}) {
        $superset = get_tweets_by($screen_name, $args{max_id});
    } elsif (my $topic = $args{topic}) {
        $superset = get_tweets_on($topic, $args{max_id});
    } else {
        confess "Bad Arguments:", @_;
    }
    my $start_of_month = DateTime->new(
        year => $args{year}, month => $args{month}, day => 1);
    my $end_of_month = DateTime->new(
        year => $args{year}, month => $args{month}, day => 1
    )->add( months => 1 );

    my $rs = $superset->search({ tweeted_at => {'!='  => undef                }},
                         { order_by   => {-desc => 'tweeted_at'         }})
                ->search({tweeted_at => {'>='  => $start_of_month->ymd }})
                ->search({tweeted_at => {'<'   => $end_of_month->ymd   }});

    return $rs;
}

sub tweet_page_from_rs {
    my ($rs, $max) = @_;
    if ($max) {
        $rs = $rs->search({tweeted_at => {'<' => $max}});
    } 
    my @returners;
    while (my $tweet = $rs->next()) {
        last if (@returners >= Dancer::setting('pageSize'));
        push @returners, $tweet;
    }
    return @returners;
}


sub get_tweets_from {
    my ($screen_name, $epoch, $days, $max_id) = @_;
    my $from = DateTime->from_epoch( epoch => $epoch);
    my $to = ($days)
        ? DateTime->from_epoch( epoch => $epoch)
                        ->add( days => $days)
        : DateTime->now();
    my $rs = get_tweets_by($screen_name, $max_id)
                    ->search({tweeted_at => {'>=', $from->ymd}})
                    ->search({tweeted_at => {'<', $to->ymd}});
    if (wantarray) {
        return tweet_page_from_rs($rs, $max_id);
    } else {
        return $rs;
    };
}

sub get_tweets_on {
    my ($topic, $max_id) = @_;
    my $condition = ($max_id)
        ? { tweeted_at => { '<' => $max_id }}
        : {};
    return get_hashtag($topic)->tweets->search(
        $condition,
        {
            order_by => {-desc => 'tweeted_at'},
            prefetch => 'twitter_account',
        },
    );
}

sub get_tweets_by {
    my ($screen_name, $max_id) = @_;
    my $condition = ($max_id)
        ? { tweeted_at => { '<' => $max_id }}
        : {};
        
    my $rs = get_twitter_account($screen_name)->tweets->search(
        $condition,
        {order_by => {-desc => 'tweeted_at'}},
    );
    if (wantarray) {
        return tweet_page_from_rs($rs, $max_id);
    } else {
        return $rs;
    };
}

sub get_tweets_matching { 
    my ($screen_name, $searchterm, $max_id) = @_;
    return get_tweets_by($screen_name, $max_id)->search(
                {text => {like => '%' . $searchterm . '%'}});
}
    

sub validate_user {
    my $username = shift;
    my $password = shift;
    
    my $user_rec = get_user_record($username);
    my $passhash = $user_rec->passhash;

    if (eval{Crypt::SaltedHash->validate($passhash, $password)}) {
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

sub beta_key_is_valid_and_unused {
    my $key = shift;
    my $key_rec = get_db->resultset('Betakey')->find({key => $key});
    unless ($key_rec) {
        return false;
    }
    if ($key_rec->has_user) {
        return false;
    }
    return true;
}

sub assign_beta_key {
    my %args = @_;
    confess "No key" unless $args{key};
    my $key_rec = get_db->resultset('Betakey')->find({key => $args{key}});
    confess "Key not valid: $args{key}" unless $key_rec;
    $key_rec->update({user => $args{user}});
}

sub get_tags_from_tweet {
    my ($tweet, $username) = @_;
    my @tags = $tweet->tags->search(
        {
            '-or' => [
            'tweet_tags.private_to' => undef,
            'tweet_tags.private_to.username' => $username
            ]
        },
        {
            'join' => {'tweet_tags' => 'private_to'},
            distinct => 1,
        }
    )->get_column("tag_text")->all;
    return @tags;
}

sub get_screen_name_list {
    my $db = get_db();
    my @names = $db->resultset("TwitterAccount")
                   ->get_column("screen_name")
                   ->all;
    if (wantarray) {
        return @names;
    } else {
        return join(',', map {'"' . $_ . '"'} @names);
    }
}

sub get_hashtags_list {
    my $db = get_db();
    my @topics = $db->resultset("Hashtag")
                   ->get_column("topic")
                   ->all;
    if (wantarray) {
        return @topics;
    } else {
        return join(',', map {'"' . substr($_, 1) . '"'} @topics);
    }
}

1;
