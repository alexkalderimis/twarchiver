package twarchiver;
use Dancer ':syntax';

our $VERSION = '0.1';

use Net::Twitter;
use Try::Tiny;
use File::Basename;
use File::Path qw(make_path);
use File::Spec::Functions;
use Scalar::Util 'blessed';
use Twarchiver::DB::Schema;

use constant CONS_KEY      => 'duo83UgzZ99BRPpf56pUnA';
use constant CONS_SEC      => '6Si7yg4S1USpVFFYpL6N8Bc3MftddMXEQYefbn9U3w';
use constant STORAGE_PATHS => ( dirname($0), 'data', 'auth-tokens' );
use constant STATUS_STORAGE => (dirname($0), 'data', 'statuses');

use constant TWITTER_BASE   => 'http://twitter.com/';
use constant TWITTER_SEARCH => 'http://twitter.com/search';
use constant ACTIONS => qw/retweeted favorited/;

use Exporter 'import';
our @EXPORT = qw/get_twitter restore_tokens save_tokens store_statuses restore_statuses_for get_db get_user_record/;

my $html = HTML::EasyTags->new();
my $datetime_parser = DateTime::Format::Strptime->new( 
    pattern => '%a %b %d %T %z %Y' );

my %cookies;
my $schema;

my $span_re           = qr/<.?span.*?>/;
my $mentions_re       = qr/(\@(?:$span_re|\w+)+\b)/;
my $hashtags_re       = qr/(\#(?:$span_re|[\w-]+)+)/;
my $urls_re           = qr{(http://(?:$span_re|[\w\./]+)+\b)};

sub get_db {
    unless ($schema) {
        $schema = Twarchiver::Schema->connect(
            "dbi:SQLite:dbname=".setting('database'));
    }

    return $schema;
}

my %name_of_month;
sub get_month_name_for {
    my $month_number = shift;
    unless (%name_of_month) {
        %name_of_month = map 
            {$_ => DateTime->new(year => 2010, month => $_)->month_name} 
                1 .. 12;
    }
    return $name_of_month{$month_number};
}

sub get_twitter {
    my @tokens = @_;
    my %args = (
        traits          => [qw/OAuth API::REST/],
        consumer_key    => CONS_KEY,
        consumer_secret => CONS_SEC,
    );
    if (@tokens == 2) {
        @args{qw/access_token access_token_secret/} = @tokens;
    }

    return Net::Twitter->new(%args);
}

=head2 restore_statuses_for( screen_name )

Function:  get tweets from database
Arguments: the user's twitter screen name
Returns:   A list of the users statuses (Row objects).

=cut
    
sub restore_statuses_for {
    my $user = shift;
    my $user_rec = get_user_record($user);
    my @statuses = sort {$b->created_at->epoch <=> $a->created_at->epoch}
                    $user_rec->search_related('tweets')->all;
    return @statuses;
}

=head2 get_since_id_for( screen_name )

Function:  get the id of the most recent tweet for this user
Arguments: The user's twitter screen name
Returns:   The id (scalar)

=cut

sub get_since_id_for {
    my $user = shift;
    my $user_rec = get_user_record($user);
    my $since_id = $user_rec->tweets->get_column('tweet_id')->max;
    return $since_id;
}

=head2 retrieve_statuses( screen_name, access_token, access_token_secret)

Function:  Get the most up to date tweets by querying the twitter API
Arguments: The user's twitter screen name
           The user's OAuth access token
           The user's OAuth access token secret
Returns:   A list of the users statuses as database row objects.

=cut

sub retrieve_statuses {
    my ( $user, @tokens ) = @_;
    my %no_of_st;

    if (@tokens) {
        my $twitter = get_twitter(@tokens);

        my $since = get_since_for($user);

        if ( $twitter->authorized ) {

            for ( my $page = 1 ; ; ++$page ) {
                debug("Getting page $page of twitter statuses");
                my $args = { count => 100, page => $page };
                $args->{since_id} = $since if $since;
                my $statuses = $twitter->user_timeline($args);
                last unless @$statuses;
                store_twitter_statuses(@stats);
            }
        } else {
            die "Not authorised.";
        }
    } 
    return restore_statuses_for($user);
}

=head2 store_twitter_statuses( list_of_tweets )

Function:  Store the tweets in the database
Arguments: The list of twitter statuses returned from the Twitter API

=cut

sub store_twitter_statuses {
    my @statuses = @_;
    my $db = get_db;
    for (@statuses) {
        my $tweet_rec = get_tweet_record($_->{id}, $_->{screen_name});
        my ($text, $retw, $retw_no, $fav, $fav_no) 
            = @{$_}{qw/text retweeted retweeted_count 
                favorited favorited_count/};
        }
        $tweet_rec->text($text);
        $tweet_rec->retweeted($retweeted);
        $tweet_rec->retweeted_count($retweeted_no);
        $tweet_rec->favorited($favorited);
        $tweet_rec->favorited_count($favorited_no);

        my $dt = $datetime_parser->parse_datetime($_->{created_at});
        $tweet_rec->created_at($dt);
        $tweet_rec->year($dt->year);
        $tweet_rec->month($dt->month);

        my @mentions = $text =~ /$mentions_re/g;
        for my $mention (@mentions) {
            my $mention_rec = $db->resultset('Mention')->find_or_create({
                screen_name => $mention
            });
            $mention_rec->add_to_tweets($tweet_rec);
            $tweet_rec->add_to_mentions($mention_rec);
            $mention_rec->update;
        }
        my @hashtags = $text =~ /$hashtags_re/g;
        for my $hashtag (@hashtags) {
            my $hashtag_rec = $db->resultset('Hashtag')->find_or_create({
                topic => $hashtag
            });
            $hashtag_rec->add_to_tweets($tweet_rec);
            $tweet_rec->add_to_hashtags($hashtag_rec);
            $hashtag_rec->update;
        }
        my @urls = $tweet_text =~ /$urls_re/g;
        for my $url (@urls) {
            my $url_rec = $db->resultset('Url')->find_or_create({
                address => $url
            });
            $url_rec->add_to_tweets($tweet_rec);
            $tweet_rec->add_to_urls($url_rec);
            $url_rec->update;
        }
        $tweet_rec->update;
    }
}

sub restore_tokens {
    my $user = shift;
    my $user_rec = get_user_record($user);

    my @tokens = (
        $user_rec->access_token,
        $user_rec->access_token_secret,
    );

    return unless (@tokens == 2);
    return @tokens;
}

sub get_user_record {
    my $user = shift;
    my $db = get_db();
    my $user_rec = $db->resultset('User')->find_or_create(
        {
            screen_name => $user,
        },
    );
    return $user_rec;
}

sub get_tweet_record {
    my ($id, $screen_name) = @_;
    my $db = get_db();
    my $user_rec = get_user_record($screen_name);
    my $tweet_rec = $user_rec->tweets->find(
        {'tweet_id' = > $id,}
    );
    unless ($tweet_rec) {
        $tweet_rec = $user_rec->add_to_tweets({
                tweet_id => $id,
        });
    }
    return $tweet_rec;
}

    

sub save_tokens {
    my ( $user, $token, $secret ) = @_;
    my $user_rec = get_user_record($user);

    $user_rec->update({
            access_token => $token,
            access_token_secret => $secret,
    });
}



get '/' => sub {
    template 'index';
};

true;
