package Twarchiver::Functions::PageContent;

our $VERSION = '0.1';

use Dancer ':syntax';
use Dancer::Plugin::ProxyPath;

use HTML::EasyTags;
use List::MoreUtils qw(uniq);
use URI;
use Carp qw/confess/;
use Encode;
use DateTime::Format::SQLite;

use Twarchiver::Functions::DBAccess ':pagecontent';
use Twarchiver::Functions::Util ':all';

use constant {
    TWITTER_BASE   => 'http://twitter.com/',
    TWITTER_SEARCH => 'http://twitter.com/search',
};

use Exporter 'import';

our @EXPORT_OK = qw/
  get_hashtag_url
  get_mention_url 
  get_normal_login_message_box
  get_failed_login_message_box
  linkify_text make_tweet_li 
  make_content 
  make_hashtag_link
  make_hashtag_report_link
  make_hashtag_sidebar_item
  make_highlit_content
  make_mention_link
  make_mention_report_link
  make_mention_sidebar_item 
  make_month_link 
  make_retweeted_sidebar
  make_retweet_link 
  make_tagger_form_body
  make_tag_link
  make_tag_list_box
  make_tag_sidebar_item 
  make_tags_list
  make_tweet_display_box
  make_tweet_tagger_form
  make_url_report_link
  make_url_sidebar_item 
  make_user_home_link 
  make_year_group
  highlight
  get_linkified_text
  /;

our %EXPORT_TAGS = (
    'routes' => [qw/
        make_user_home_link
        make_content
        make_highlit_content
        make_year_group
        make_mention_sidebar_item
        make_hashtag_sidebar_item
        make_tag_sidebar_item 
        make_url_sidebar_item 
        make_retweeted_sidebar
        get_linkified_text
        highlight
        get_linkified_text
      /],
    'all' => [qw/
        get_hashtag_url
        get_mention_url 
        get_normal_login_message_box
        get_failed_login_message_box
        linkify_text make_tweet_li 
        make_content 
        make_hashtag_link
        make_hashtag_report_link
        make_hashtag_sidebar_item
        make_highlit_content
        make_mention_link
        make_mention_report_link
        make_mention_sidebar_item 
        make_month_link 
        make_retweeted_sidebar
        make_retweet_link 
        make_tagger_form_body
        make_tag_link
        make_tag_list_box
        make_tag_sidebar_item 
        make_tags_list
        make_tweet_display_box
        make_tweet_tagger_form
        make_url_report_link
        make_url_sidebar_item 
        make_user_home_link 
        make_year_group
        highlight
        get_linkified_text
    /],
    'login' => [qw/
        get_normal_login_message_box
        get_failed_login_message_box
    /]
);

my $html = HTML::EasyTags->new();

my $span_re     = qr{</?span(?: class=\S+>|>)};
my $mentions_re = qr/(\@(?:$span_re|\w+)+\b)/;
my $hashtags_re = qr/(\#(?:$span_re|[\w-]+)+)/;
my $urls_re     = qr{(
                            http://
                            (?:$span_re|[^\s<>]+)+
                            \b
                        |
                            \b
                            (?:$span_re|\w|\.)+
                            \.
                            (?:$span_re|\w|\.)*
                            (?:com|org|co\.uk|ly)
                            (?:$span_re|[\w\&\?/])*
                            \b
                    )}x;

my %re_for = (
    urls     => $urls_re,
    mentions => $mentions_re,
    hashtags => $hashtags_re,
);

my %urliser_for = (
    urls     => sub { return get_url_url(shift) },
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
        $tweet->{highlighted_text} = highlight($tweet->text, $searchterm);
    }
    return make_content(@tweets);
}

sub highlight {
    my ($text, $re) = @_;
    return $text unless $re;
    $text =~  s{$re}{<span class="key-term">$&</span>}g;
    return $text;
}

=head2 [String] make_diverse_user_content( tweets )

Function:  Orchestrate the construction of content for tweets from
           more than one user. 
Arguments: A list of DBIx::Class Tweet result rows
Returns:   A <ol > li> list of tweets, or <p>apology</p> if no tweets found

=cut

sub make_diverse_user_content {
    my @tweets = @_;
    if (@tweets) {
        return $html->ol( $html->li_group( {class => "tweet"}, [ map { make_tweet_li_with_pic($_) } @tweets ] ) );
    } else {
        return no_tweets_found();
    }
}

=head2 [String] make_content( tweets )

Function:  Orchestrate the construction of content. 
Arguments: A list of DBIx::Class Tweet result rows
Returns:   A <ol > li> list of tweets, or <p>apology</p> if no tweets found

=cut

sub make_content {
    my @tweets = @_;

    if (@tweets) {
        my $dt = $tweets[-1]->tweeted_at;
        my $time_stamp = DateTime::Format::SQLite->format_datetime($dt);
        my $no_of_tweets = @tweets;
        my $more_button = make_more_button($time_stamp, $no_of_tweets);
        my $list_items = $html->li_group( 
            {class => "tweet"}, 
            [ map { make_tweet_li($_) } @tweets ] 
        );
        return $list_items . $more_button;
    } else {
        return no_tweets_found();
    }
}

sub make_more_button {
    my ($id, $page_size) = @_;
    if ($page_size < setting('pageSize')) {
        return ''; # There aren't any more
    }
    my $url = URI->new(request->path());
    my $params = params();
    delete $params->{from};
    $url->query_form(from => $id, %{(params)});
    my $button = $html->input(
        type => "button",
        onclick => "getMore(this, '$url')",
        value => "Get More",
    );
    return $button;
}

sub no_tweets_found {
    return $html->p("No tweets found");
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
        my %link_for;
        for my $thing (@things) {
            ( my $cleaned_thing = $thing ) =~ s/$span_re//g;
            $link_for{$thing} = $html->a(
                href => $urliser->($cleaned_thing),
                text => $thing,
            );
        }
        while ( my ( $lhs, $rhs ) = each %link_for ) {
            $text =~ s/\Q$lhs\E/$rhs/g;
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
    my $return_value = eval {
        my $tweet_box    = make_tweet_display_box($tweet);
        my $tagging_form = make_tweet_tagger_form($tweet);

        return $tweet_box . $tagging_form;
    };
    if (my $e = $@) {
        confess "Problem making tweet list item: $e";
    }
    return $return_value;
}

sub make_tweet_li_with_pic {
    my $tweet = shift;
    return '' unless $tweet;
    my $return_value = eval {
        my $tweet_box    = make_tweet_display_box_with_pic($tweet);
        my $tagging_form = make_tweet_tagger_form($tweet);

        return $tweet_box . $tagging_form;
    };
    if (my $e = $@) {
        confess "Problem making tweet list item: $e";
    }
    return $return_value;
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
        $tweet->tweeted_at->strftime(DATE_FORMAT) 
    );
    my $body      = $html->p($text);
    my $tag_box   = make_tag_list_box($tweet);
    my $div_end   = $html->div_end;
    return $div_start . $heading . $body . $div_end . $tag_box;
}

sub make_tweet_display_box_with_pic {
    my $tweet     = shift;

    my $id        = $tweet->tweet_id;
    my $text      = get_linkified_text(
        $tweet->{highlighted_text} || $tweet->text
    );
    my $div_start = $html->div_start( 
        onclick => "toggleForm('$id');" 
    );
    my $pic = $tweet->twitter_account->profile_image_url;
    my $heading   = $html->img({src => $pic}) 
                    . $html->h2( 
        $tweet->tweeted_at->strftime(DATE_FORMAT) 
    );
    my $body      = $html->p($text);
    my $tag_box   = make_tag_list_box($tweet);
    my $div_end   = $html->div_end;
    return $div_start . $heading . $body . $div_end . $tag_box;
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
        {   
            id => "tagList-$id",
            class => 'tags-ul',
        },
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
    my $username = session('username');
    if ($tweet->tags->count) {
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
        my @li_elems = map {
            make_tweet_tags_list_item(
                $tweet->twitter_account->screen_name, $_, $tweet->tweet_id)} @tags;
        return $html->li_group([@li_elems]);
    } else {
        return '';
    }
}

sub make_tweet_tags_list_item {
    my $username = shift;
    my $tag_text = shift;
    my $tweet_id = shift;
    my $deleterId = $tweet_id . '-' . $tag_text;
    my $deleter = $html->a(
        style => 'display: none',
        href => '#',
        onclick => "removeTag('$tweet_id', '$tag_text')",
        text => 'delete',
        id => $deleterId,
    );
    my $span = $html->span(
        { 
            onmouseover => "toggleElem('$deleterId')",
            onmouseout => "toggleElem('$deleterId')",
            tag        => $tag_text,
        },
        $tag_text . '   ' . $deleter);
    return $span;
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
    my $user = $tweet->twitter_account->screen_name;
    my $id = $tweet->tweet_id;

    my $text_box = $html->input( 
        type    => 'text', 
        id      => "tag-$id" 
    );
    my $add_button = $html->input(
        value   => 'Add',
        type    => 'button',
        onclick => "javascript:addTags('$id');",
    );
    my $remove_button = $html->input(
        value   => 'Remove',
        type    => 'button',
        onclick => "javascript:removeTags('$id');",
    );
    ## Stupidly enough, this is needed to stop auto-submission
    ## of a one text field, two button form. Sheesh
    my $dummy_field = $html->input(
        name => "dummy",
        type => "text",
        style => "display: none",
    ); 

    my $form_body = $html->p(
        "Tag:" . $text_box . $add_button . $remove_button . $dummy_field
    );
    return $form_body;
}

=head2 make_popular_sidebar( username, action )

Function: Make a sidebar summarising retweeted and favourited tweets

=cut

sub make_retweeted_sidebar {
    my %args = @_;
    my $thing;
    my $uri;
    if (my $screen_name = $args{screen_name}) {
        $thing = get_twitter_account($screen_name);
        $uri   = proxy->uri_for("/show/$screen_name/retweeted" );
    } elsif (my $topic = $args{topic} ) {
        $thing = get_hashtag($topic);
        $uri   = proxy->uri_for("/show/tweets/on/$topic/retweeted");
    } else {
        confess "Bad Arguments";
    }

    my $total    = $thing->tweets
                        ->search( { retweeted_count => { '>' => 0 } } )
                        ->count;
    my $list     = $html->li_group(
        [
            $html->a(
                href => $uri,
                text => "All Retweeted Statuses ($total)",
            )
        ]
    );
    if ($total) {
        my @rows = get_retweet_summary( %args );
        $list .= $html->li_group(
            [
                map { make_retweet_link( 
                        $_->retweeted_count, $_->get_column("occurs")) }
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
    my $uri;
    confess "retweet count '$retweet_count' is not a number" 
        unless $retweet_count =~ /^\d+$/;
    confess "number of tweets '$number_of_tweets' is not a number"
        unless $number_of_tweets =~ /^\d+$/;
    if (my $screen_name = params->{screen_name}) {
        $uri = proxy->uri_for( "/show/$screen_name/retweeted" );
    } elsif (my $topic = params->{topic}) {
        $uri = proxy->uri_for( "/show/tweets/on/$topic/retweeted" );
    } else {
        confess "Bad Parameters";
    }

    my $text = 'Retweeted ';
    if ( $retweet_count == 1 ) {
        $text .= "once";
    } elsif ( $retweet_count == 2 ) {
        $text .= "twice";
    } else {
        $text .= "$retweet_count times";
    }
    $text .= " ($number_of_tweets)";

    $uri = URI->new($uri);
    $uri->query_form( count => $retweet_count );
    return $html->a(
        href => "$uri",
        text => $text,
    );
}

=head2 make_year_group( username, year )

Function: Make a html list section for each year of the form:
          h3      - Year heading
          ul > li - List of month links

=cut

sub make_year_group {
    my %args = @_;
    my @mons = get_months_in( %args );
    my $month_group =
      $html->li_group([map {make_month_link(%args, month => $_)} @mons]);
    my $list_item = $html->h3($args{year}) 
                    . "\n" 
                    . $html->ul($month_group);
    return $list_item;
}

=head2 make_user_home_link( [screen_name] )

Function: get the link to the user's home status list
Returns:  '<a href="/show/username">username</a>'

=cut

sub make_user_home_link {
    my $screen_name = shift;
    unless ($screen_name) {
        my $user = session('username');
        my $screen_name = get_user_record($user)->twitter_account
                                                ->screen_name;
    }
    my $link = $html->a(
        href => proxy->uri_for( "/show/$screen_name" ),
        text => $screen_name,
    );
    return $link;
}

=head2 make_month_link(username, year, month) 

Function: make the link for each month in the timeline summary
Returns:  '<a href="/show/username/2010/12">December (7 tweets)</a>'

=cut

sub make_month_link {
    my %args = @_;
    my $number_of_tweets = get_tweets_in_month( %args )->count;
    my $uri;
    if (my $screen_name = $args{screen_name}) {
        $uri = proxy->uri_for(
            "show/$screen_name/$args{year}-$args{month}");
    } elsif (my $topic = $args{topic}) {
        $uri = proxy->uri_for(
            "show/tweets/on/$topic/$args{year}-$args{month}");
    } else {
        confess "Bad Arguments";
    }
    my $text = sprintf( "%s (%s tweets)", 
        get_month_name_for($args{month}), $number_of_tweets 
    );
    return $html->a(
        href => "$uri",
        text => $text,
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
    my $uri;
    if (my $who = params->{screen_name}) {
        $uri = URI->new( proxy->uri_for("show/$who/links/to"));
    } elsif (my $topic = params->{topic}) {
        $uri = URI->new(proxy->uri_for("show/tweets/on/$topic/links"));
    } else {
        confess "Bad Parameters";
    }
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
    my $tag    = shift;
    my $result = make_tag_link($tag->tag_text, $tag->get_column('count'));
    return $result;
}

=head2 make_tag_link( user, tagtext, count )

Function: Make the link for the given tag
Returns: '<a href="show/user/tag/tagtext">tagtext (7)</a>'

=cut

sub make_tag_link {
    my ( $tag, $count ) = @_;
    my $uri;
    if (my $who = params->{screen_name}) {
        $uri = proxy->uri_for("show/$who/tagged/$tag");
    } elsif (my $topic = params->{topic}) {
        $uri = proxy->uri_for("show/tweets/on/$topic/tagged/$tag");
    } else {
        confess "Bad Parameters";
    }
    my $href = URI->new($uri);
    return $html->a(
        href => "$href",
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
#    my $uri   = URI->new(TWITTER_SEARCH);
#    $uri->query_form( q => $topic );
    $topic = substr($topic, 1);
    my $uri = proxy->uri_for("/show/tweets/on/$topic");
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
    for ([0, 'topic'], [1, 'count']) {
        confess "No ", $_->[1] unless $_[$_->[0]];
    }
    my ( $topic, $count ) = @_;
    confess "Topic is not a hashtag: got $topic"
        unless ($topic =~ /^#/);
    my $uri;
    if (my $me = params->{screen_name}) {
        $uri = proxy->uri_for("show/$me/on" . substr($topic, 1) );
    } elsif (my $topicA = params->{topic}) {
        $uri = proxy->uri_for("show/tweets/on/$topicA/and/$topic");
    } else {
        confess "Bad Parameters";
    }
    return $html->a(
        href => $uri,
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
            make_mention_link( $mention->screen_name ),
            make_mention_report_link( 
                $mention->screen_name, 
                $mention->get_column("count"), 
            ) 
        );
    };
    if (my $e = $@) {
        confess "Problem making mention sidebar item: $e";
    }
    return $result;
}

=head2 get_url_url( url )

Function: Construct a url we can link to
Return:   http://some.url

=cut

sub get_url_url {
    my $url = shift;
    if ($url !~ m!^https?://!) {
        $url = 'http://' . $url;
    }
    return $url;
}

=head2 get_mention_url( screen_name )

Function: construct a url pointing to the twitter profile of user
Return:   'http://twitter.com/mention'

=cut 

sub get_mention_url {
    my $mention = shift;
    confess "Mention is undefined" unless (defined $mention);
    $mention = substr( $mention, 1 ) if ($mention =~ /^\@/);
    # return TWITTER_BASE . $mention;
    return proxy->uri_for("/show/$mention");
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
    my $uri;
    if (my $me = params->{screen_name}) {
        $uri = proxy->uri_for("show/$me/to/$screen_name");
    } elsif (my $topic = params->{topic}) {
        $uri = proxy->uri_for("show/tweets/on/$topic/by/$screen_name");
    } else {
        confess "Bad Parameters";
    }
    for ([0, 'mention'], [1, 'count']) {
        confess "No ", $_->[1] unless $_[$_->[0]];
    }
    return $html->a(
        href => $uri,
        text  => "($count mentions)",
        class => 'sidebarinternallink',
    );
}

true;
