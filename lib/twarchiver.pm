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
my $dt_parser = DateTime::Format::Strptime->new( 
    pattern => '%a %b %d %T %z %Y' );

my %cookies;
my $schema;

my $span_re           = qr/<.?span.*?>/;
my $mentions_re       = qr/(\@(?:$span_re|\w+)+\b)/;
my $hashtags_re       = qr/(\#(?:$span_re|[\w-]+)+)/;
my $urls_re           = qr{(http://(?:$span_re|[\w\./]+)+\b)};

my $re_for = (
    urls     => $urls_re,
    mentions => $mentions_re,
    hashtags => $hashtags_re,
);

my %urliser_for = (
    urls     => sub {return shift},
    mentions => sub {return get_mention_url(shift)},
    hashtags => sub {return get_hashtag_url(shift)},
);

=head2 show_statuses_for

Function: return a page loading all the statuses from a user

=cut

sub show_statuses_for {
    my $user = params->{username};

    return authorise($user) if needs_authorisation($user);

    my $title       = "Status Archive for $user";
    my $content_url = $user;

    template 'statuses' => {
        content_url => $content_url,
        title => $title,
        username => $user,
    };
}

=head2 show_tweets_including

Function: return a page loading tweets with a particular search term.

=cut

sub show_tweets_including {
    my ( $user, $searchterm, $is_case_insensitive ) = @_;

    return authorise($user) if needs_authorisation($user);

    my $title = 'Statuses from '
      . $html->a(
        href => request->uri_for( join( '/', 'show', $user ) ),
        text => $user,
      ) . " mentioning $searchterm";
    my $content_url = join('/', $user, 'search', $searchterm);
    $content_url .= '?i=1' if $is_case_insensitive;

    template 'statuses' => {
        content_url => $content_url,
        title => $title,
        username => $user,
    };
}

=head2 [String] get_search_username_content 

Function: Called by ajax to populate the page with content for all tweets
          matching a particular search term
Returns:  The content html string

=cut

sub get_search_username_content {
    my $user = params->{username};
    my $searchterm = params->{searchterm};
    my $is_case_insensitive = params->{i};

    if (needs_authorisation($user)) {
        return $html->p("Not Authorised");
    }

    eval { $re = ($is_case_insensitive) 
            ? qr/$searchterm/i 
            : qr/$searchterm/; 
    };
    if ($@) {
        $re = ($is_case_insensitive)
          ? qr/\Q$searchterm\E/i
          : qr/\Q$searchterm\E/;
    }
    download_latest_tweets_for($user);
    my $rs = restore_statuses_for($user);
    my @tweets;
    while (my $tweet = $rs->next()) {
        if ($tweet->text =~ $re) {
            my $x = $_->text; 
            $x =~ s{$re}{<span class="key-term">$&</span>}g;
            $_->{highlighted_text} = $x;
            push @tweets, $tweet;
        }
    }
    debug( "Got " . scalar(@tweets) . " tweets with searchterm" );

    my $content = make_content(@tweets);
    return $content;
}

=head2 [String] get_username_content 

Function: Called by ajax to populate the page with content for all tweets
Returns:  The content html string

=cut

sub get_username_content {
    my $user = params->{username};
    if (needs_authorisation($user)) {
        return $html->p("Not Authorised");
    }
    download_latest_tweets_for($user);
    my @tweets = restore_statuses_for($user);
    my $content = make_content(@tweets);
    return $content;
}

=head2 [String] make_content( tweets )

Function:  Orchestrate the construction of content. 
Arguments: A list of DBIx::Class Tweet result rows
Returns:   A ol > li list of tweets, or a p apology if no tweets found

=cut

sub make_content {
    my @tweets = @_;
    if (@tweets) {
        return $html->ol( 
            $html->li_group( [ map { make_tweet_li($_) } @tweets ] ) );
    } else {
        return $html->p("No tweets found");
    }
}

=head2 linkify_text( Str type, Str text )

Function:  Replace the type of thing in the text with links as 
           appropriate, respecting any highlighting in the text.
Arguments: The type of thing ("urls", "mentions" or "hashtags"), and
           the text string to put links into.
Returns:   The munged text

=cut

sub linkify_text {
    my ($type, $text) = @_;
    my $re      = $re_for{$type};
    my $urliser = $urliser_for{$type};
    my @things  = $text =~ /$re/g;
    if (@things) {
        @things = uniq(@things);
        debug( sprintf( "Found %d things of interest: %s", 
                scalar(@things), join( ', ', @things ) ) );
        my %link_for;
        for my $thing (@things) {
            (my $cleaned_thing = $thing) =~ s/$span_re//g;
            $link_for{$thing} = $html->a(
                href => urliser->($cleaned_thing),
                text => $thing,
            );
        }
        while ( my ( $lhs, $rhs ) = each %link_for ) {
            $text =~ s/$lhs/$rhs/g;
        }
    }
    return $text;
}

=head2 [String] make_tweet_li( tweet )

Function: Return the li element that displays the tweet. This element is
          made up of:

          div > h2            -timestamp
              > p             -text
              > div > ul > li -tags
          form > p > input    -textbox
                   > input    -add button
                   > input    -remove button

Arguments: A DBIx::Class Tweet result row object
Returns:   An html string with the above structure.

=cut

sub make_tweet_li {
    my $status = shift;
    return '' unless $status;
    my $text = $status->{highlighted_text} || $status->text;
    # Triple filtered for extra purity
    $text = linkify_text('urls', $text);
    $text = linkify_text('mentions', $text);
    $text = linkify_text('hashtags', $text);

    my $id = $status->tweet_id;

    my $list_item = join( "\n",
        $html->div_start( onclick => "toggleForm('$id');", ),
        $html->h2($status->created_at->strftime("%d %b %Y %X")),
        $html->p($text),
        $html->div_start( 
            id => $id . '-tags', 
            class => 'tags-list' 
        ),
        $html->ul(
            { id => "tagList-$id" },
            (
                ( $status->tags->count )
                    ? $html->li_group( 
                        [$status->tags->get_column("text")->all])
                    : ''
            )
        ),
        $html->div_end,
        $html->div_end,
        $html->form_start(
            style  => 'display: none;',
            class  => 'tag-form',
            method => 'post',
            id     => $id
        ),
        $html->p(
            "Tag:" 
          . $html->input( type => 'text', id => "tag-$id" )
          . $html->input(
                value   => 'Add',
                type    => 'button',
                onclick => sprintf( "javascript:addNewTag('%s', '%s');", 
                    $status->user->screen_name, $id ),
          )
          . $html->input(
                value   => 'Remove',
                type    => 'button',
                onclick => sprintf( "javascript:deleteTag('%s', '%s');", 
                    $status->user->screen_name, $id ),
          ),
        ),
        $html->form_end(),
    );

    return $list_item;
}

=head2 [Bool] request_tokens_for(username, verifier)

Function:  Get access tokens from twitter, and store them in the database
Arguments: The username (string) and the OAuth verifier (String)
Returns:   Whether or not the request succeeded.
Throws:    An exception if the user authorises a different twitter user.

=cut

sub request_tokens_for {
    my ( $user, $verifier ) = @_;
    debug("Got verifier: $verifier");

    my $twitter = get_twitter();
    $twitter->request_token( cookies->{token}->value );
    $twitter->request_token_secret( cookies->{secret}->value );
    my @bits = $twitter->request_access_token( verifier => $verifier );

    send_error("names don't match - got $bits[3]"
        unless ( $bits[3] eq $user);
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
    return ! has_been_authorised($user);
}

=head2 [Bool] has_been_authorised( username )

Function: Returns true if the user has been authorised.
Arguments: The twitter username
Returns:  A truth value

=cut

sub has_been_authorised {
    my $user = shift;

    if (my $verifier = params->{oauth_verifier}) {
        request_tokens_for($user, $verifier);
    }
    return restore_tokens($user)) {
}

=head2 authorise( username )

Function: redirect the user to twitter to authorise us.
Arguments: The twitter username

=cut

sub authorise {
    my $user   = shift;
    my $cb_url = request->uri_for( request->path );
    debug("callback url is $cb_url");
    try {
        my $twitter = get_twitter();
        my $url = $twitter->get_authorization_url( callback => $cb_url );
        debug( "request token is " . $twitter->request_token );
        set_cookie token => $twitter->request_token;
        set_cookie secret => $twitter->request_token_secret;
        redirect($url);
        return false;
    }
    catch {
        error($_);
        send_error("Authorisation failed, $_");
    };
}

=head2 get_db

Function: Get a connection to the database
Returns:  A DBIx::Class::Schema instance

=cut

sub get_db {
    unless ($schema) {
        $schema = Twarchiver::Schema->connect(
            "dbi:SQLite:dbname=".setting('database'));
    }

    return $schema;
}

=head2 get_month_name_for(month_number)

Function:  Get the name of the month given as a number
Arguments: A number from 1 - 12
Returns:   A string with the corresponding month name

=cut

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

=head2 get_twitter([access_token, access_secret])

Function: Get a Net::Twitter object, using the access tokens if available
Returns:  A Net::Twitter instance

=cut

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

=head2 restore_statuses_for( screen_name, [condition] )

Function:  get tweets from database for a specific user
Arguments: the user's twitter screen name
           (optionally) a condition to search by
Returns:   <List Context> A list of the users statuses (Row objects) 
           <Scalar|Void> A result set of the same.

=cut
    
sub restore_statuses_for {
    my $user      = shift;
    my $condition = shift;
    my $user_rec = get_user_record($user);
    return $user_rec->tweets->search( $condition,
                        {order_by => {-desc => 'tweet_id'}},
                    );
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

=head2 download_latest_tweets_for( screen_name )

Function:  Get the most up to date tweets by querying the twitter API
           and store them.
Arguments: The user's twitter screen name

=cut

sub download_latest_tweets {
    my $user = shift;
    my @tokens = restore_tokens($user);
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

=head2 store_twitter_statuses( list_of_tweets )

Function:  Store the tweets in the database
Arguments: The list of twitter statuses returned from the Twitter API

=cut

sub store_twitter_statuses {
    my @statuses = @_;
    my $db = get_db;
    for (@statuses) {
        my $tweet_rec = get_tweet_record(
            $_->{id}, $_->{user}{screen_name});
        $tweet_rec->update({
            text            => $_->{text},
            retweeted_count => $_->{retweeted_count},
            favorited_count => $_->{favorited_count},
            created_at => $dt_parser->parse_datetime($_->{created_at}),
        });
        my $text = $_->{text};

        my @mentions = $text =~ /$mentions_re/g;
        for my $mention (@mentions) {
            $tweet_rec->add_to_mentions({screen_name => $mention});
        }
        my @hashtags = $text =~ /$hashtags_re/g;
        for my $hashtag (@hashtags) {
            $tweet_rec->add_to_hashtags({topic => $hashtag});
        }
        my @urls = $tweet_text =~ /$urls_re/g;
        for my $url (@urls) {
            $tweet_rec->add_to_urls({$address => $url});
        }
        $tweet_rec->update;
    }
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

    return unless (@tokens == 2);
    return @tokens;
}

=head2 [ResultRow] get_user_record( screen_name )

Function:  Get the db record for the given user
Arguments: The user's twitter screen name
Returns:   A DBIx::Class User result row object

=cut

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

=head2 [ResultRow] get_tweet_record( tweet_id, screen_name )

Function:  Get the tweet with the given id by the given user, or add
           one to the user's list of tweets.
Arguments: The tweet id, and the screen name of the tweeter
Returns:   A DBIx::Class Tweet row object

=cut 

sub get_tweet_record {
    my ($id, $screen_name) = @_;
    my $db = get_db();
    my $user_rec = get_user_record($screen_name);
    my $tweet_rec = $user_rec->tweets->find(
        {'tweet_id' => $id,}
    );
    unless ($tweet_rec) {
        $tweet_rec = $user_rec->add_to_tweets({
                tweet_id => $id,
        });
    }
    return $tweet_rec;
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

true;
