package Twarchiver::HTMLActions;
use Dancer ':syntax';

use feature ':5.10';

our $VERSION = '0.1';

use Net::Twitter;
use Twarchiver::DBActions ':main';
use HTML::EasyTags;
use DateTime::Format::Strptime;
use DateTime;
use List::MoreUtils qw(uniq);
use URI;
use Text::CSV;
use Carp qw/confess/;

use constant {
    CONS_KEY       => 'duo83UgzZ99BRPpf56pUnA',
    CONS_SEC       => '6Si7yg4S1USpVFFYpL6N8Bc3MftddMXEQYefbn9U3w',
    TWITTER_BASE   => 'http://twitter.com/',
    TWITTER_SEARCH => 'http://twitter.com/search',
    DATE_FORMAT    => "%d %b %Y %X",
};
use constant ACTIONS => qw/retweeted favorited/;

use Exporter 'import';

our @EXPORT_OK = qw/
  show_tweets_including authorise needs_authorisation
  make_user_home_link get_month_name_for get_tweets_as_textfile
  get_tweets_as_spreadsheet download_latest_tweets_for
  make_content ACTIONS DATE_FORMAT make_year_group
  make_mention_sidebar_item make_hashtag_sidebar_item
  make_url_sidebar_item make_tag_sidebar_item make_retweeted_sidebar
  linkify_text make_tweet_li request_tokens_for has_been_authorised
  make_retweet_link make_month_link tweet_to_text
  get_mention_url get_hashtag_url
  make_highlit_content
  make_url_report_link
  make_tag_link
  make_hashtag_link
  make_hashtag_report_link
  make_mention_link
  make_mention_report_link
  get_twitter
  /;

our %EXPORT_TAGS = (
    'routes' => [qw/
      show_tweets_including authorise needs_authorisation
      make_user_home_link get_month_name_for get_tweets_as_textfile
      get_tweets_as_spreadsheet download_latest_tweets_for
      make_content ACTIONS make_year_group
      make_mention_sidebar_item make_hashtag_sidebar_item
      make_url_sidebar_item make_tag_sidebar_item make_retweeted_sidebar
      /],
    'all' => [qw/
        show_tweets_including authorise needs_authorisation
        make_user_home_link get_month_name_for get_tweets_as_textfile
        get_tweets_as_spreadsheet download_latest_tweets_for
        make_content ACTIONS DATE_FORMAT make_year_group
        make_mention_sidebar_item make_hashtag_sidebar_item
        make_url_sidebar_item make_tag_sidebar_item make_retweeted_sidebar
        linkify_text make_tweet_li request_tokens_for has_been_authorised
        make_retweet_link make_month_link tweet_to_text
        get_mention_url get_hashtag_url
        make_highlit_content
        make_url_report_link
        make_tag_link
        make_hashtag_link
        make_hashtag_report_link
        make_mention_link
        make_mention_report_link
        get_twitter
    /]
);

my $html = HTML::EasyTags->new();

my $span_re     = qr/<.?span.*?>/;
my $mentions_re = qr/(\@(?:$span_re|\w+)+\b)/;
my $hashtags_re = qr/(\#(?:$span_re|[\w-]+)+)/;
my $urls_re     = qr{(http://(?:$span_re|[\w\./]+)+\b)};

my %re_for = (
    urls     => $urls_re,
    mentions => $mentions_re,
    hashtags => $hashtags_re,
);

my %urliser_for = (
    urls     => sub { return shift },
    mentions => sub { return get_mention_url(shift) },
    hashtags => sub { return get_hashtag_url(shift) },
);

=head2 make_highlit_content( searchterm, @tweets )

Function:  return the content for a set of tweets with the searchterms
           highlit in the text. 
Arguments: (Str|Re) The searchterm
           (@ResultRows) The tweets to display
Returns: The html page, with terms surrounded by a span tag set:
         'text text<span class="key-term">key term</span>text text'

=cut

sub make_highlit_content {
    my ($searchterm, @tweets) = @_;
    for (0 .. $#tweets) {
        my $tweet = $tweets[$_];
        ( $tweet->{highlighted_text} = $tweet->text ) 
            =~ s{$searchterm}{<span class="key-term">$&</span>}g;
    }
    return make_content(@tweets);
}

=head2 [String] make_content( tweets )

Function:  Orchestrate the construction of content. 
Arguments: A list of DBIx::Class Tweet result rows
Returns:   A <ol > li> list of tweets, or <p>apology</p> if no tweets found

=cut

sub make_content {
    my @tweets = @_;
    if (@tweets) {
        return $html->ol( $html->li_group( [ map { make_tweet_li($_) } @tweets ] ) );
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
    my ( $type, $text ) = @_;
    my $re      = $re_for{$type};
    my $urliser = $urliser_for{$type};
    my @things  = $text =~ /$re/g;
    if (@things) {
        @things = uniq(@things);
        debug(
            sprintf(
                "Found %d things of interest: %s",
                scalar(@things), join( ', ', @things )
            )
        );
        my %link_for;
        for my $thing (@things) {
            ( my $cleaned_thing = $thing ) =~ s/$span_re//g;
            $link_for{$thing} = $html->a(
                href => $urliser->($cleaned_thing),
                text => $thing,
            );
        }
        while ( my ( $lhs, $rhs ) = each %link_for ) {
            $text =~ s/$lhs/$rhs/g;
        }
    }
    return $text;
}

=head2 [String] get_linkified_text( text )

Function:  Put links in the given text for any found urls, mentions
           or hashtags. 
Arguments: the text string to put links into.
Returns:   The linkified text

=cut

sub get_linkified_text {
    my $text = shift;
    # Triple filtered for extra purity
    $text = linkify_text( 'urls',     $text );
    $text = linkify_text( 'mentions', $text );
    $text = linkify_text( 'hashtags', $text );
    return $text;
}

=head2 [String] make_tweet_li( tweet )

Function: Return the inner html of the li element that 
displays the tweet. This element is made up of:

    # The display box

          div > h2            -timestamp
              > p             -text
              > div > ul > li -tags

    # The tagger form

          form > p > input    -textbox
                   > input    -add button
                   > input    -remove button

Arguments: A DBIx::Class Tweet result row object
Returns:   An html string with the above structure.

=cut

sub make_tweet_li {
    my $tweet = shift;
    return '' unless $tweet;

    my $tweet_box    = make_tweet_display_box($tweet);
    my $tagging_form = make_tweet_tagger_form($tweet);

    return $tweet_box . $tagging_form;
}


=head2 [String] make_tweet_display_box( tweet )

Function: Return the div element that displays the tweet. This element is
          made up of:

          div > h2            -Heading: timestamp
              > p             -Body:    text - with links
              > div > ul > li -Tag Box: list of tags

Arguments: A DBIx::Class Tweet result row object
Returns:   An html string with the above structure.

=cut

sub make_tweet_display_box {
    my $tweet     = shift;

    my $id        = $tweet->tweet_id;
    my $text      = get_linkified_text(
        $tweet->{highlighted_text} || $tweet->text
    );
    
    my $div_start = $html->div_start( 
        onclick => "toggleForm('$id');" 
    );
    my $heading   = $html->h2( 
        $tweet->created_at->strftime(DATE_FORMAT) 
    );
    my $body      = $html->p($text);
    my $tag_box   = make_tag_list_box($tweet);
    my $div_end   = $html->div_end;
    return $div_start . $heading . $body . $tag_box . $div_end;
}

=head2 [String] make_tag_list_box( tweet )

Function: Return the div element that displays the list
          of tags. The element is made up of:

            div > ul > li -list of tags

Arguments: A DBIx::Class Tweet result row object
Returns:   An html string with the above structure.

=cut

sub make_tag_list_box {
    my $tweet = shift;
    my $id = $tweet->tweet_id;
    my $div_start = $html->div_start(
        id    => $id . '-tags',
        class => 'tags-list'
    );
    my $tags_list = $html->ul(
        { id => "tagList-$id" },
        make_tags_list($tweet)
    );
    my $div_end = $html->div_end;
    return $div_start . $tags_list . $div_end;
}

=head2 [String] make_tags_list( tweet )

Function: Return the group of li elements containing the tweets tags.
          The string is a set of '<li></li>' tag pairs with content.

          li

Arguments: A DBIx::Class Tweet result row object
Returns:   An html string with the above structure.

=cut

sub make_tags_list {
    my $tweet = shift;
    if ($tweet->tags->count) {
        my @tags = $tweet->tags->get_column("tag_text")->all;
        return $html->li_group([@tags]);
    } else {
        return '';
    }
}

=head2 [String] make_tweet_tagger_form( tweet )

Function: Return the form element used to add and remove tags
          from the tweet. The element has the following structure:

          form > p > input    -textbox
                   > input    -add button
                   > input    -remove button

Arguments: A DBIx::Class Tweet result row object
Returns:   An html string with the above structure.

=cut

sub make_tweet_tagger_form {
    my $tweet = shift;
    my $id    = $tweet->tweet_id;

    my $form_start = $html->form_start(
        style  => 'display: none;',
        class  => 'tag-form',
        method => 'post',
        id     => $id
    );
    my $form_body = make_tagger_form_body($tweet);

    my $form_end = $html->form_end;

    return $form_start . $form_body . $form_end;
}

=head2 [String] make_tagger_form_body( tweet )

Function: Return the input elements that make up the 
          working part of the tagger form.
          The element has the following structure:

          p > input    -textbox
            > input    -add button
            > input    -remove button

Arguments: A DBIx::Class Tweet result row object
Returns:   An html string with the above structure.

=cut

sub make_tagger_form_body {
    my $tweet = shift;
    my $user = $tweet->user->screen_name;
    my $id = $tweet->tweet_id;

    my $text_box = $html->input( 
        type    => 'text', 
        id      => "tag-$id" 
    );
    my $add_button = $html->input(
        value   => 'Add',
        type    => 'button',
        onclick => "javascript:addTags('$user', '$id');",
    );
    my $remove_button = $html->input(
        value   => 'Remove',
        type    => 'button',
        onclick => "javascript:removeTags('$user', '$id');",
    );

    my $form_body = $html->p(
        "Tag:" . $text_box . $add_button . $remove_button
    );
    return $form_body;
}

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
        set_cookie token  => $twitter->request_token;
        set_cookie secret => $twitter->request_token_secret;
        redirect($url);
        return false;
    };
    if ( my $err = $@ ) {
        error($err);
        send_error("Authorisation failed, $err");
    }
}

=head2 get_month_name_for(month_number)

Function:  Get the name of the month given as a number
Arguments: A number from 1 - 12
Returns:   A string with the corresponding month name

=cut

sub get_month_name_for {
    state %name_of_month;
    my $month_number = shift;
    confess "No month number provided to get_month_name_for" 
        unless $month_number;
    confess "Bad argument to get_month_name_for: expected a number from 1 - 12, but got '$month_number'" 
        unless (grep {$month_number eq $_} 1 .. 12);
    
    unless (%name_of_month) {
        %name_of_month =
          map { $_ => DateTime->new( year => 2010, month => $_ )->month_name } 1 .. 12;
    }
    return $name_of_month{$month_number};
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

sub download_latest_tweets {
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

=head2 make_popular_sidebar( username, action )

Function: Make a sidebar summarising retweeted and favourited tweets

=cut

sub make_retweeted_sidebar {
    my $username = shift;
    my $column   = 'retweeted_count';
    my $user     = get_user_record($username);
    my $total    = $user->tweets
                        ->search( { $column => { '>' => 0 } } )
                        ->count;
    my $list     = $html->li_group(
        [
            $html->a(
                href => request->uri_for( 
                    join('/', 'show', params->{username}, 'retweeted')),
                text => "All Retweeted Statuses ($total)",
            )
        ]
    );
    if ($total) {
        my @rows = get_retweet_summary( $username );
        $list .= $html->li_group(
            [
                map { make_retweet_link( 
                        $_->$column, $_->get_column("occurs")) }
                  @rows
            ]
        );
    }
    return $list;
}

=head2 make_retweet_link( no_times_done, occurances )

Function: Make a link for the popular sidebar. 
Returns:  '<a href="/show/user/retweeted?count=2">Retweeted twice (7)</a>'

=cut 

sub make_retweet_link {
    my $retweet_count   = shift;
    my $number_of_tweets = shift;
    confess "retweet count '$retweet_count' is not a number" 
        unless $retweet_count =~ /^\d+$/;
    confess "number of tweets '$number_of_tweets' is not a number"
        unless $number_of_tweets =~ /^\d+$/;

    my $text = 'Retweeted ';
    if ( $retweet_count == 1 ) {
        $text .= "once";
    } elsif ( $retweet_count == 2 ) {
        $text .= "twice";
    } else {
        $text .= "$retweet_count times";
    }
    $text .= " ($number_of_tweets)";

    my $uri = URI->new( request->uri_for( join( '/', 'show', params->{username}, 'retweeted' ) ) );
    $uri->query_form( count => $retweet_count );
    return $html->a(
        href => $uri,
        text => $text,
    );
}

=head2 make_year_group( username, year )

Function: Make a html list section for each year of the form:
          h3      - Year heading
          ul > li - List of month links

=cut

sub make_year_group {
    my ( $username, $year ) = @_;
    my @months = get_months_in( $username, $year );
    my $month_group =
      $html->li_group( [ map { make_month_link( $username, $year, $_ ) } @months ] );
    my $list_item = $html->h3($year) . "\n" . $html->ul($month_group);
    return $list_item;
}

=head2 make_user_home_link

Function: get the link to the user's home status list
Returns:  '<a href="/show/username">username</a>'

=cut

sub make_user_home_link {
    my $user = shift || params->{username};
    confess "No username provided" unless $user;
    my $link = $html->a(
        href => request->uri_for( join( '/', 'show', $user ) ),
        text => $user,
    );
    return $link;
}

=head2 make_month_link(username, year, month) 

Function: make the link for each month in the timeline summary
Returns:  '<a href="/show/username/2010/12">December (7 tweets)</a>'

=cut

sub make_month_link {
    my ( $user, $y, $m ) = @_;
    my $number_of_tweets = get_tweets_in_month( $user, $y, $m )->count;
    return $html->a(
        href => request->uri_for( join( '/', 'show', $user, $y, $m ) ),
        text => sprintf( "%s (%s tweets)", get_month_name_for($m), $number_of_tweets ),
    );
}

=head2 make_url_sidebar_item( UrlResultRow )

Function: make the li item in the sidebar
Returns:  <a href="this">this</a><a href="/show/user/url?address=this">(linked to 7 times)</a>

=cut

sub make_url_sidebar_item {
    my $url = shift;
    my $result = eval { sprintf( "%s %s",
        $html->a( href => $url->address, text => $url->address ),
        make_url_report_link( $url->address, $url->get_column("count"), )
        );
    };
    if (my $e = $@) {
        confess "Problem making url sidebar: $e";
    }
    return $result;
}

=head2 make_url_report_link( address, count )

Function: make a link for the given url
Returns:  '<a href="/show/user/url?address=this">(linked to 7 times)</a>'

=cut

sub make_url_report_link {
    my ( $address, $count ) = @_;
    confess "no address" unless $address;
    confess "no count" unless defined $count;
    my $uri = URI->new( request->uri_for( join( '/', 'show', params->{username}, 'url' ) ) );
    $uri->query_form( address => $address );

    return $html->a(
        href  => "$uri",
        text  => "(linked to $count times)",
        class => 'sidebarinternallink',
    );
}

=head2 make_tag_sidebar_item( TagResultRow ) 

Function: make the list item for the sidebar tag list
Returns:  '<a href="show/user/tag/tagtext">tagtext (7)</a>'

=cut 

sub make_tag_sidebar_item {
    my $tag      = shift;
    my $result = eval { make_tag_link( 
        params->{username}, $tag->text, $tag->get_column('count') );
    };
    if (my $e = $@) {
        confess "Problem making tag sidebar item: $e";
    }
    return $result;
}

=head2 make_tag_link( user, tagtext, count )

Function: Make the link for the given tag
Returns: '<a href="show/user/tag/tagtext">tagtext (7)</a>'

=cut

sub make_tag_link {
    my ( $username, $tag, $count ) = @_;
    for ([0, 'username'], [1, 'tag'], [2, 'count']) {
        confess "No ", $_->[1] unless $_[$_->[0]];
    };
    return $html->a(
        href => request->uri_for(
            join(
                '/',
                show => $username,
                tag  => $tag
            )
        ),
        text => "$tag ($count)",
    );
}

=head2 make_hashtag_sidebar_item( HashtagResultRow )

Function: Make the list item for the hashtag sidebar
Returns:  '<a href="http://twitter.com/search?q=topic">topic</a><a href="/show/user/on/hashtag">(7 hashtags)</a>'

=cut

sub make_hashtag_sidebar_item {
    my $hashtag = shift;
    my $elements = eval{ sprintf( "%s %s",
        make_hashtag_link( $hashtag->topic ),
        make_hashtag_report_link( 
            $hashtag->topic, $hashtag->get_column("count"), ) );
    };
    if (my $e = $@) {
        confess "Problem making hashtag sidebar item: $e";
    }
    return $elements;
}

=head2 get_hashtag_url( topic )

Function: get the link to a twitter search on the given topic
Returns:  'http://twitter.com/search?q=topic'

=cut

sub get_hashtag_url {
    my $topic = shift;
    confess "Topic is undefined" unless (defined $topic);
    my $uri   = URI->new(TWITTER_SEARCH);
    $uri->query_form( q => $topic );
    return "$uri";
}

=head2 make_hashtag_link( topic )

Function: make a link for this topic to the appropriate twitter url
Returns:  '<a href="http://twitter.com/search?q=topic">topic</a>'

=cut

sub make_hashtag_link {
    my $topic = shift;
    confess "No topic" unless $topic;
    $topic =~ s/$span_re//g;

    return $html->a(
        href => get_hashtag_url($topic),
        text => $topic,
    );
}

=head2 make_hashtag_report_link( hashtag, count )

Function: make a link for the given mention
Returns:  '<a href="show/user/on/hashtag">(7 hashtags)</a>'

=cut

sub make_hashtag_report_link {
    my ( $topic, $count ) = @_;
    for ([0, 'topic'], [1, 'count']) {
        confess "No ", $_->[1] unless $_[$_->[0]];
    }
    confess "Topic is not a hashtag: got $topic"
        unless ($topic =~ /^#/);
    return $html->a(
        href => URI->new(
            request->uri_for(
            join( '/', 'show', params->{username}, 'on', substr( $topic, 1 ) ) )
        ),
        text  => "($count hashtags)",
        class => 'sidebarinternallink',
    );
}

=head2 make_mention_sidebar_item( MentionResultRow )

Function: make the li item for the sidebar
Returns:  '<a href="http://twitter.com/mention">@mention</a> <a href="show/user/to/mention" class="sidebarinternallink">(7 mentions)</a>'

=cut

sub make_mention_sidebar_item {
    my $mention = shift;
    my $result = eval {
        sprintf( "%s %s",
            make_mention_link( $mention->mention_name ),
            make_mention_report_link( 
                $mention->mention_name, 
                $mention->get_column("count"), 
            ) 
        );
    };
    if (my $e = $@) {
        confess "Problem making mention sidebar item: $e";
    }
    return $result;
}

=head2 get_mention_url( screen_name )

Function: construct a url pointing to the twitter profile of user
Return:   'http://twitter.com/mention'

=cut 

sub get_mention_url {
    my $mention = shift;
    confess "Mention is undefined" unless (defined $mention);
    $mention = substr( $mention, 1 ) if ($mention =~ /^\@/);
    return TWITTER_BASE . $mention;
}

=head2 make_mention_link( mentioned_name )

Function: make a link to the twitter profile of the mentioned user
Return:   '<a href="http://twitter.com/mention">@mention</a>'

=cut

sub make_mention_link {
    my $screen_name = shift;
    confess "No mention" unless $screen_name;
    $screen_name =~ s/$span_re//g;
    return $html->a(
        href => get_mention_url($screen_name),
        text => $screen_name,
    );
    select;
}

=head2 make_mention_report_link( mentioned_name, count )

Function: make a link for the given mention
Returns:  '<a href="show/user/to/mentioned_name" class="sidebarinternallink">(7 mentions)</a>'

=cut

sub make_mention_report_link {
    my ( $screen_name, $count ) = @_;
    for ([0, 'mention'], [1, 'count']) {
        confess "No ", $_->[1] unless $_[$_->[0]];
    }
    return $html->a(
        href => request->uri_for(
            join( '/', 
                'show', params->{username}, 'to', 
                substr( $screen_name, 1 ) 
            )
        ),
        text  => "($count mentions)",
        class => 'sidebarinternallink',
    );
}

=head2 get_tweets_as_textfile( @tweets )

Function: Transform a list of tweets into a text string for downloading
Returns:  A text string

=cut

sub get_tweets_as_textfile {
    my @tweets = @_;

    content_type 'text/plain';

    return join( "\n\n", map { tweet_to_text($_) } @tweets );
}

=head2 get_tweets_as_spreadsheet( separator, tweets )

Function: Transform a list of tweets into csv, or tsv file format
Returns:  A text string

=cut

sub get_tweets_as_spreadsheet {
    my ( $separator, @tweets ) = @_;

    content_type "text/tab-separated-values";

    my $csv = Text::CSV->new(
        {
            sep_char     => $separator,
            binary       => 1,
            always_quote => 1,
        }
    );
    return join(
        "\n",
        map {
            $csv->combine(
                $_->created_at->strftime(DATE_FORMAT), 
                $_->text,
                $_->retweeted_count,
                join(':', $_->tags->get_column('tag_text')->all),
            );
            $csv->string()
          } @tweets
    );
}

=head2 tweet_to_text( tweet )

Function: Transform a tweet into a text string, with date, text and tags

=cut

sub tweet_to_text {
    my $tweet = shift;
    my $created_at  = $tweet->created_at->strftime(DATE_FORMAT);
    my $text  = $tweet->text;
    my @tags  = $tweet->tags->get_column('tag_text')->all;
    my $tags =
      (@tags)
      ? 'Tags: ' . join( ', ', @tags )
      : '';
    my $result;
    eval {
        local $SIG{__WARN__};
        open( TEMP, '>', \$result );
        format TEMP = 
Time:   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        $created_at
^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ~~
$text
^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< 
$tags
      ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ~~
      $tags
.
        write TEMP;
    };
    if ( my $e = $@ ) {
        error( "Problem with " . $tweet->text . $e );
    }
    return $result;
}

true;
