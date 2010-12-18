package Twarchiver::Functions::TwitterAPI;

use Dancer ':syntax';

use feature ':5.10';

our $VERSION = '0.1';

use Net::Twitter;
use Carp qw/confess/;

use Twarchiver::Functions::DBAccess ':twitterapi';

use constant {
    CONS_KEY       => 'duo83UgzZ99BRPpf56pUnA',
    CONS_SEC       => '6Si7yg4S1USpVFFYpL6N8Bc3MftddMXEQYefbn9U3w',
};

use Exporter 'import';

our @EXPORT_OK = qw/
  authorise 
  download_latest_tweets_for
  get_twitter
  has_been_authorised
  needs_authorisation
  request_tokens_for 
  /;

our %EXPORT_TAGS = (
    'all' => [qw/
        authorise 
        download_latest_tweets_for
        get_twitter
        has_been_authorised
        needs_authorisation
        request_tokens_for 
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
    $twitter->request_token( cookies->{token}->value );
    $twitter->request_token_secret( cookies->{secret}->value );
    my @bits = $twitter->request_access_token( verifier => $verifier );

    confess("names don't match - got $bits[3]")
      unless ( $bits[3] eq $user );
    save_tokens( @bits[ 3, 0, 1 ] );
    return true;
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
        set_cookie(token  => $twitter->request_token);
        set_cookie(secret => $twitter->request_token_secret);
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

sub download_latest_tweets_for {
    my $user    = shift;
    my @tokens  = restore_tokens($user);
    my $twitter = get_twitter(@tokens);
    my $since   = get_since_id_for($user);

    if ( $twitter->authorized ) {
        for ( my $page = 1 ; ; ++$page ) {
            debug("Getting page $page of twitter statuses");
            my $args = { count => 100, page => $page };
            $args->{since_id} = $since if $since;
            my $statuses = $twitter->user_timeline($args);
            last unless @$statuses;
            store_twitter_statuses(@$statuses);
        }
    } else {
        die "Not authorised.";
    }
}

true;
