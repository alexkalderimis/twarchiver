package Twarchiver::Functions::TwitterAPI;

use Dancer ':syntax';
use Math::BigInt;

use feature ':5.10';

our $VERSION = '0.1';

use Net::Twitter;
use Carp qw/confess/;
use DateTime;
use Scalar::Util qw/blessed/;

use Twarchiver::Functions::DBAccess ':twitterapi';

use constant {
    CONS_KEY       => 'duo83UgzZ99BRPpf56pUnA',
    CONS_SEC       => '6Si7yg4S1USpVFFYpL6N8Bc3MftddMXEQYefbn9U3w',
};

use Exporter 'import';

our @EXPORT_OK = qw/
  authorise 
  download_latest_tweets
  get_twitter
  has_been_authorised
  needs_authorisation
  request_tokens_for 
  download_tweets
  download_user_info
  /;

our %EXPORT_TAGS = (
    'all' => [qw/
        authorise 
        download_latest_tweets
        get_twitter
        has_been_authorised
        needs_authorisation
        request_tokens_for 
        download_tweets
        download_user_info
    /],
    'routes' => [qw/
    authorise needs_authorisation
    download_latest_tweets
    download_tweets
    download_user_info
    /]
);

=head2 [Bool] request_tokens_for(username, verifier)

Function:  Get access tokens from twitter, and store them in the database
Arguments: The username (string) and the OAuth verifier (String)
Returns:   Whether or not the request succeeded.
Throws:    An exception if the user authorises a different twitter user.

=cut

sub request_tokens_for {
    my ( $user, $verifier ) = @_;
    confess "No user" unless $user;
    confess "No verifier" unless $verifier;
    debug("Got verifier: $verifier");

    my $twitter = get_twitter();
    debug(to_dumper(cookies));
    my ($tok, $sec) = split(/___/, cookies->{tok_sec}->value);
    debug("tok: $tok, sec: $sec");
    $twitter->request_token( $tok );
    $twitter->request_token_secret( $sec );
    my @bits = $twitter->request_access_token( verifier => $verifier );

    if (@bits) {
        save_user_info( $user, @bits );
        return true;
    } else {
        return false;
    }
}

=head2 [Bool] needs_authorisation( username )

Function: Returns true if the user hasn't been authorised yet. Simple
          Negation of L<has_been_authorised>
Arguments: The twitter username
Returns:  A truth value

=cut

sub needs_authorisation {
    my $user = shift;
    return !has_been_authorised($user);
}

=head2 [Bool] has_been_authorised( username )

Function: Returns true if the user has been authorised.
Arguments: The twitter username
Returns:  A truth value

=cut

sub has_been_authorised {
    my $user = shift;

    if ( my $verifier = params->{oauth_verifier} ) {
        request_tokens_for( $user, $verifier );
    }
    return restore_tokens($user);
}

=head2 authorise()

Function: redirect the user to twitter to authorise us.

=cut

sub authorise {
    my $cb_url = request->uri_for( request->path );
    debug("callback url is $cb_url");
    eval {
        my $twitter = get_twitter();
        my $url = $twitter->get_authorization_url( callback => $cb_url );
        debug( "request token is " . $twitter->request_token );
        debug( "req tok secret is " .$twitter->request_token_secret );
        #set_cookie(secret => $twitter->request_token_secret);
        set_cookie(tok_sec  => $twitter->request_token . '___' . $twitter->request_token_secret);
        debug( to_dumper(cookies) );
        redirect($url);
        return false;
    };
    if ( my $err = $@ ) {
        error($err);
        send_error("Authorisation failed, $err");
    }
}

=head2 get_twitter([access_token, access_secret])

Function: Get a Net::Twitter object, using the access tokens if available
Returns:  A Net::Twitter instance

=cut

sub get_twitter {
    my @tokens = @_;
    my %args   = (
        traits          => [qw/OAuth API::REST InflateObjects/],
        consumer_key    => CONS_KEY,
        consumer_secret => CONS_SEC,
        decode_html_entities => 1,
    );
    if ( @tokens == 2 ) {
        @args{qw/access_token access_token_secret/} = @tokens;
    }
    my $twitter = eval { Net::Twitter->new(%args)};
    if (my $e = $@) {
        confess "Problem making twitter connection: $e";
    }
    return $twitter;
}

=head2 download_latest_tweets_for( screen_name )

Function:  Get the most up to date tweets by querying the twitter API
           and store them.
Arguments: The user's twitter screen name

=cut

sub download_tweets {
    my %args = @_;
    my $username = session('username');
    my $screen_name = $args{by} 
        || get_user_record($username)->twitter_account->screen_name;
    my $maxId = $args{from} 
        || get_oldest_id_for($screen_name);
    $maxId = Math::BigInt->new($maxId);
    $maxId->bsub(1);

    my $twitter_ac = get_twitter_account($screen_name);
    if (has_been_updated_recently($twitter_ac)) {
        return {
            isFinished => \1,
            got => $twitter_ac->tweets->count,
            total => $twitter_ac->tweet_total,
        };
    }

    my @tokens  = restore_tokens($username);
    my $twitter = get_twitter(@tokens);

    if ( $twitter->authorized ) {
        download_user_info(for => $twitter_ac, from => $twitter);
        my $args = { 
            id    => get_twitter_account($screen_name)->twitter_id,
            count => setting('downloadbatchsize') 
        };
        $args->{max_id} = "$maxId" if ($maxId && $maxId > 0);
        debug(to_dumper($args));
        my $response = {isFinished => \0};
        my $statuses = eval {$twitter->user_timeline($args)};
        if (my $e = $@) {
            error($e);
            $maxId->badd(1);
            $response->{nextBatchFromId} = "$maxId";
        } elsif (@$statuses) {
            store_twitter_statuses(@$statuses);
            $response->{nextBatchFromId} = $statuses->[-1]->id;
        } else {
            download_latest_tweets(by => $screen_name);
            $response->{isFinished} = \1;
            $response->{nextBatchFromId} = 0;
        }
        $response->{got} = $twitter_ac->tweets->count;
        $response->{total} = $twitter_ac->tweet_total;
        debug(to_dumper($response));
        return $response;
    } else {
        send_error("Not authorised");
    }

}
sub has_been_updated_recently {
    my $account = shift;
    my $last_update = $account->last_update();
    my $five_minutes_ago = DateTime->now()->subtract(minutes => 5);
    if ($last_update and $last_update > $five_minutes_ago) {
        debug("Has been updated recently " . $last_update->datetime());
        return true;
    } else {
        debug("Has not been updated recently");
        if ($last_update) {
            debug("Last update at " . $last_update->datetime());
        }
        return false;
    }
}

sub download_latest_tweets {
    my %args = @_;
    my $user = session('username');
    my $screen_name    = $args{by}
        || get_user_record($user)->twitter_account->screen_name;
    my $twitter_ac = get_twitter_account($screen_name);
    if (has_been_updated_recently($twitter_ac)) {
        return;
    }

    my @tokens  = restore_tokens($user);
    my $twitter = get_twitter(@tokens);
    my $since   = get_since_id_for($screen_name);

    if ( $twitter->authorized ) {
        download_user_info(for => $twitter_ac, from => $twitter);
        my %nt_args = ( 
            id => $twitter_ac->twitter_id,
            count => setting('downloadbatchsize'), 
        );
        $nt_args{since_id} = $since if $since;
        for ( $nt_args{page} = 1; ; $nt_args{page}++ ) {
            debug("Getting page $nt_args{page} of twitter statuses");
            debug(to_dumper({%nt_args}));
            my $statuses = $twitter->user_timeline(\%nt_args);
            last unless @$statuses;
            store_twitter_statuses(@$statuses);
            debug("Stored " . scalar(@$statuses) . " statuses");
        }
        my $now = DateTime->now();
        debug("Updated at " . $now->datetime());
        $twitter_ac->update({last_update => $now});
#        for my $new_mention (mentions_added_since($since)) {
#            download_user_info(for => $new_mention, from => $twitter);
#        }
    } else {
        die "Not authorised.";
    }
}

sub download_user_info {
    my %args = @_;
    my $twitter_account = $args{for};
    confess ("no twitter account" ) unless $twitter_account;
    unless (blessed $twitter_account) {
        $twitter_account = get_twitter_account($twitter_account);
    }
    my $twitter = $args{from};
    unless ($twitter) {
        my $user = session('username');
        my @tokens  = restore_tokens($user);
        $twitter = get_twitter(@tokens);
    }

    my $users = eval {$twitter->lookup_users({
            screen_name => $twitter_account->screen_name})};
    if (my $e = $@) {
        return;
    }
    confess "Couldn't get user info" 
        unless ($users && ref $users eq 'ARRAY');
    confess "More than one user found"
        if (@$users > 1);
    store_user_info($users->[0]);
}

true;
