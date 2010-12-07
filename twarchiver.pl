#!/usr/bin/perl

use utf8;
use Dancer;
use Dancer::Plugin::Ajax;
use lib 'lib';
use Net::Twitter::Scraper;
use DateTime::Format::Strptime;
use DateTime;
use HTML::Table;
use HTML::EasyTags;
use List::MoreUtils qw(uniq);
use URI;
use Text::CSV;
use Data::Dumper;

use constant TWITTER_BASE   => 'http://twitter.com/';
use constant TWITTER_SEARCH => 'http://twitter.com/search';
use constant ACTIONS => qw/retweeted favorited/;
my %order_by_recent = ('order_by' => {-'desc' => 'tweet_id'});
my $TAGS_KEY = 'twarchiver:tags';

my $html = HTML::EasyTags->new();
my $dt_prsr = DateTime::Format::Strptime->new( pattern => '%a %b %d %T %z %Y' );

my %cookies;
my $span_re           = qr/<.?span.*?>/;
my $mentions_re       = qr/(\@(?:$span_re|\w+)+\b)/;
my $hashtags_re       = qr/(\#(?:$span_re|[\w-]+)+)/;
my $urls_re           = qr{(http://(?:$span_re|[\w\./]+)+\b)};
my $date_format       = "%d %b %Y";

get '/show/:username/to/:mention' => \&show_mentions_to;

get '/show/:username/on/:hashtag' => \&show_tweets_about;

get '/show/:username/tag/:tag' => \&show_tweets_tagged_with;

get '/show/:username' => \&show_statuses_for;

get '/show/:username/:year/:month' => \&show_statuses_within;

get '/download/:username.:format' => \&download_tweets;

get '/search/:username' => \&search_username;

get '/show/:username/:prefix' => \&show_popular_stats;

get '/show/:username/favourited' => \&show_favourited_stats;



sub show_popular_stats {
    my $user = params->{username};
    my $count = params->{count};
    my $prefix = params->{prefix};
    if (not $prefix or not grep {$prefix eq $_} ACTIONS) {
        pass and return false;
    }
    my $col = $prefix . '_count';
    my $value = ($count) ? $count : {'>=', 1};
    my $db = get_db();
    my $user_rec = get_user_record();
    my @populars = $user_rec->search_related('tweets',
        {$col => $value},
        {%order_by_recent},
    );

    my $title = 'Statuses from '
      . $html->a(
        href => request->uri_for( join( '/', 'show', $user ) ),
        text => $user,
      ) . ' which have been ' . $prefix;
      $title .= " $count times" if $count;
    return_status_page( \@populars, $title );
}

sub search_username {
    my $user       = params->{username};
    my $searchterm = params->{searchterm};
    show_tweets_including( $user, $searchterm, 1 );
}

post '/addtags/:time' => sub {
    my $user      = params->{username};
    my $tags      = params->{tags};
    my @tweet_ids = split( /,/, params->{tweetIds} );
    my $statuses  = get_statuses( $user, 1 );
    die "not authorised" unless ( ref $statuses );
    my @statuses;
    for my $id (@tweet_ids) {
        push @statuses, grep { $_->{id} eq $id } @$statuses;
    }
    unless ( @statuses == @tweet_ids ) {
        status 500;
        header Results => "Tags not added: didn't find all tweets";
        return;
    }

    my @results;
    for my $status (@statuses) {
        my @status_results;
        for my $tag ( split( /,/, $tags ) ) {
            if ( grep { $_ eq $tag } @{ $status->{$TAGS_KEY} } ) {
                my $id = $status->{id};
                push @status_results,
                  "Tag not added - status '$id' is already tagged with '$tag'";
            } else {
                push @status_results, "added";
                push @{ $status->{$TAGS_KEY} }, $tag;
            }
        }
        push @results, join( ',', @status_results );
    }
    my $result = join( ',,', @results );
    debug($result);
    store_statuses( $user, $statuses );
    header Results => $result;
    return;
};

post '/removetags/:time' => sub {
    my $user      = params->{username};
    my $tags      = params->{tags};
    my @tweet_ids = split( /,/, params->{tweetIds} );
    my $statuses  = get_statuses( $user, 1 );
    die "not authorised" unless ( ref $statuses );
    my @statuses;
    for my $id (@tweet_ids) {
        push @statuses, grep { $_->{id} eq $id } @$statuses;
    }
    unless ( @statuses == @tweet_ids ) {
        status 500;
        header Results => "Tags not removed: didn't find all tweets";
        return;
    }

    my @results;
    for my $status (@statuses) {
        my @status_results;
        for my $tag ( split( /,/, $tags ) ) {
            if ( grep { $_ eq $tag } @{ $status->{$TAGS_KEY} } ) {
                $status->{$TAGS_KEY} = [ grep { $_ ne $tag } 
                    @{ $status->{$TAGS_KEY} } ];
                push @status_results, "deleted";
            } else {
                my $id = $status->{id};
                push @status_results,
                  "Tag not removed - status '$id' is not tagged with '$tag'";
            }
        }
        push @results, join( ',', @status_results );
    }
    my $result = join( ',,', @results );
    debug($result);
    store_statuses( $user, $statuses );
    header Results => $result;
    return;
};

sub show_mentions_to {
    my $user    = params->{username};
    my $mention = '@' . params->{mention};
    show_tweets_including( $user, $mention, 0 );
}

sub show_tweets_about {
    my $user    = params->{username};
    my $hashtag = params->{hashtag};
    show_tweets_including( $user, $hashtag, 0 );
}

sub show_tweets_including {
    my ( $user, $searchterm, $is_case_insensitive ) = @_;

    eval { $re = ($is_case_insensitive) 
            ? qr/$searchterm/i 
            : qr/$searchterm/; 
    };
    if ($@) {
        $re = ($is_case_insensitive)
          ? qr/\Q$searchterm\E/i
          : qr/\Q$searchterm\E/;
    }
    my $db = get_db();
    my $user_rec = get_user_record($user);
    my $rs = $user_rec->tweets;
    my @tweets_with_searchterm;
    while (my $tweet = $rs->next()) {
        push @tweets_with_searchterm, $tweet if ($tweet->text =~ $re);
    }
    for (@tweets_with_searchterm) {
        my $x = $_->text; 
        $x =~ s{$re}{<span class="key-term">$&</span>}g;
        $_->{highlighted_text} = $x;
    }
    debug( "Got " . scalar(@tweets_with_searchterm)
            . " tweets with searchterm" );

    my $title = 'Statuses from '
      . $html->a(
        href => request->uri_for( join( '/', 'show', $user ) ),
        text => $user,
      ) . " mentioning $searchterm";
    return_status_page( \@tweets_with_searchterm, $title );
}

sub show_tweets_tagged_with {
    my $user     = params->{username};
    my $tag      = params->{tag};
    my $user_rec = get_user_record($user);
    my @tagged_stats = $user_rec->tweets->search(
        {'tag.text' => $tag},
        {join {tweet_tags => 'tag'},
        %order_by_recent},
    );

    my $title = 'Statuses from '
      . $html->a(
        href => request->uri_for( join( '/', 'show', $user ) ),
        text => $user,
      ) . " tagged with $tag";
    return_status_page( \@tagged_stats, $title );
}

sub return_status_page {
    my ( $relevant_stats, $title ) = @_;
    my $user_rec = get_user_record(params->{username});
    my ( $mentions, $mention_count ) = make_mention_list();
    my ( $hashtags, $hashtag_count ) = make_hashtag_list();
    my ( $usertags, $usertag_count ) = make_tag_list();
    my ( $to, $from ) = (@$relevant_stats) 
        ? map {$_->created_at->strftime($date_format)} @{$relevant_stats}[0, -1]
        : ( "No tweets found" x 2 );

    my $profile_image    = $user_rec->profile_image_url || '/images/squirrel_icon64.gif';
    my $background_image = $user_rec->profile_bkg_url   || '/images/perldancer-bg.jpg';

    my ($retweeted_count, $favourited_count)  = 
        map {$user_rec->search_related('tweets', {$_.'_count' => {'>' => 0}})->count} ACTIONS;

    my $most_recent = $user_rec->tweets->search(undef, {%order_by_recent})
        ->first()->created_at()->strftime($date_format);
    my $beginning   = $user_rec->tweets->search(undef, {order_by => 'tweet_id'})
        ->first()->created_at()->strftime($date_format);

    my $content = make_content($relevant_stats);

    my @args = (
        profile_image    => $profile_image,
        bkg_image        => $background_image,
        retweeted_count  => $retweeted_count,
        favourited_count => $favourited_count,
        tweet_count      => $user_rec->tweets->count;
        username         => params->{username},
        title            => $title,
        search_url       => request->uri_for( join( '/', 'search', params->{username} ) ),
        tweet_number     => scalar(@$relevant_stats),
        to               => $to,
        from             => $from,
        content          => $content,
        timeline         => make_timeline(),
        mentions         => $mentions,
        hashtags         => $hashtags,
        usertags         => $usertags,
        retweeteds_list  => make_popular_list('retweeted'),
        faveds_list      => make_popular_list('favorited'),
        beginning        => $beginning,
        most_recent      => $most_recent,
        no_of_mentions   => $mention_count,
        no_of_hashtags   => $hashtag_count,
        no_of_usertags   => $usertag_count,
        download_base    => request->uri_for( join( '/', 'download', params->{username} ) ),
    );
    template statuses => {@args};
}

sub show_statuses_within {
    my $user   = params->{username};
    my $year   = params->{year};
    my $month  = params->{month};
    my $digits = qr/^\d+$/;
    pass and return false if ( $year !~ $digits && $month !~ $digits );
    my $db = get_db();
    my $user = get_user_record($user);
    my @stats_for_the_month = $user->search_related('tweets',
        {
            year => $year,
            month => $month,
        },
        {%order_by_recent},
    );
    my $title = sprintf( "Statuses for %s from %s %s", 
          $user, get_month_name_for($month), $year);

    return_status_page( [@stats_for_the_month], $title );
}

sub get_statuses {
    my ( $user, $do_not_fetch ) = @_;
    debug "Getting statūs of $user";

    my @tokens =
        ($do_not_fetch)
      ? ()
      : get_tokens_for($user);

    if ( @tokens or $do_not_fetch ) {
        return retrieve_statuses( $user, @tokens );
    } else {
        return authorise($user);
    }
}

sub show_statuses_for {
    my $user = params->{username};

    my $statuses = get_statuses($user);
    return unless ( ref $statuses );

    my $title    = "Status Archive for $user";
    return_status_page( $statuses, $statuses, $title);
}

sub download_tweets {
    my $user   = params->{username};
    my $format = params->{format};

    my $statuses = get_statuses($user);
    return unless ( ref $statuses );

    if ( $format eq 'txt' ) {
        get_tweets_as_textfile($statuses);
    } elsif ( $format eq 'tsv' ) {
        get_tweets_as_spreadsheet( $statuses, "\t" );
    } elsif ( $format eq 'csv' ) {
        get_tweets_as_spreadsheet( $statuses, ',' );
    } else {
        die "Unknown format requested: $format";
    }
}

sub get_tweets_as_textfile {
    my $statuses = shift;

    content_type 'text/plain';

    return join( "\n\n", map { status_to_text($_) } @$statuses );
}

sub get_tweets_as_spreadsheet {
    my ( $statuses, $separator ) = @_;

    content_type "text/tab-separated-values";

    my $csv = Text::CSV->new(
        {
            sep_char     => $separator,
            binary       => 1,
            always_quote => 1,
        }
    );
    my $response;
    for my $st (@$statuses) {
        $csv->combine( map {$st->$_} qw/created_at text/ );
        $response .= $csv->string() . "\n";
    }
    return $response;
}

sub status_to_text {
    my $status = shift;
    my $year = $status->year;
    my $month = get_month_name_for($status->month);
    my $text = $status->text;
    my @tags = $status->search_related('tags')->all;
    $tags = (@tags) 
            ? 'Tags: ' . join(', ', @tags)
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
        error( "Problem with " . $status->text . $e );
    }
    return $result;
}

sub make_content {
    my $statuses = shift;
    if (@$statuses) {
        return $html->ol( $html->li_group( [ map { make_table($_) } @$statuses ] ) );
    } else {
        return $html->p("No tweets found");
    }
}

sub make_timeline {
    my $db = get_db();
    my $user = get_user_record($user);
    my @years = map {$_->year} $user_rec->search_related('tweets',
        undef,
        {
            columns => ['year'],
            distinct => 1,
            order_by => {-desc => 'year'},
        }
    );
    my @list_items;
    for my $year ( @years ) {
        my @months = map {$_->month} $user_rec->search_related('tweets',
            {year => $year},
            {
                columns => ['month'],
                distinct => 1,
                order_by => {-desc => 'month'},
            }
        );
        my @month_links = map {make_month_link($year, $_)} @months;
        my $year_item = join( "\n", 
            $html->h3($year), 
            $html->li_group( \@month_links ), );
        push @list_items, $year_item;
    }
    return $html->li_group( \@list_items );
}

sub make_month_link {
    my ($year, $month) = @_;
    my $db = get_db();
    my $user = get_user_record(params->{username});
    my $number_of_tweets = $user_rec->search_related('tweets',
        {
            year => $year,
            month => $month,
        }
    })->count;
    return $html->a(
        href => request->uri_for(join( '/',
                'show', $user, $year, $month)),
        text => sprintf( "%s (%s tweets)",
            get_month_name_for($month), $number_of_tweets),
    );
}

sub make_mention_list {
    my $db = get_db();
    my @mentions = $db->resultset('Mention')->search(
        {
            'tweets.user' => params->{username},
        },
        {
            'join' => 'tweets',
            order_by => 'mention.screen_name',
        }
    );

    my @list_items;
    if (@mentions) {
        @list_items = map { sprintf( "%s %s", 
                        make_mention_link($_->screen_name), 
                        make_mention_report_link(
                            $_->screen_name, 
                            count($_, 'tweets')
                        ))}
                    sort {count($b, 'tweets') <=> count($a, 'tweets')}
                    @mentions;
    } else {
        push @list_items, $html->p("No mentions found");
    }
    return ( $html->li_group( \@list_items ), scalar(@mentions) );
}

sub count {
    my ($record, $key) = @_;
    return $record->search_related(
        $key, 
        {user => params->{username}},
        {cache => 1}
    )->count;
}

sub make_hashtag_list {
    my $db = get_db();
    my @hashtags = $db->resultset('HashTag')->search(
        {
            'tweets.user' => params->{username},
        },
        {
            'join' => 'tweets',
            order_by => 'hashtag.topic',
        }
    );

    my @list_items;
    if (@hashtags) {
        @list_items = map { sprintf( "%s %s", 
                        make_hashtag_link($_->topic), 
                        make_hashtag_report_link(
                            $_->topic, 
                            count($_, 'tweets')
                        ))}
                    sort {count($b, 'tweets') <=> count($a, 'tweets')}
                    @hashtags;
    } else {
        push @list_items, $html->p("No hashtags found");
    }
    return ( $html->li_group( \@list_items ), scalar(@hashtags) );
}

sub make_tag_list {
    my $db = get_db();
    my @tags = $db->resultset('Tag')->search(
        {
            'tweets.user' => params->{username},
        },
        {
            'join' => 'tweets',
            order_by => 'tag.tag_text',
        }
    );

    my @list_items;
    if (@tags) {
        @list_items = map { make_tag_link($_->tag_text, count($_, 'tweets')))}
                      sort {count($b, 'tweets') <=> count($a, 'tweets')}
                      @tags;
    } else {
        push @list_items, $html->p("No tags found");
    }
    return ( $html->li_group( \@list_items ), scalar(@tags) );
}

sub make_popular_list {
    my $action = shift;
    my $db = get_db();

    my $count_col = $action . '_count';
    my @action_numbers = sort {$b <=> $a} map {$_->$count_col} 
        $db->resultset('Tweet')->search(
            {
                user => params->{username},
            },
            {
                columns => [$count_col],
                distinct => 1,
                order_by => $count_col,
            }
    );
    my @tweet_numbers = map {
        $db->resultset('Tweet')->count({
                user => params->{username},
                $count_col => $_
            });
    } @action_numbers;
    my @list_items;
    if (@action_numbers) {
        for (0 .. $#action_numbers) {
            push @list_items, make_popular_link(
                $action_numbers[$_],
                $tweet_numbers[$_],
                $action,
            );
        }
    } else {
        push @list_items, $html->p("No $action tweets found");
    }

    return $html->li_group( \@list_items );
}

sub make_popular_link {
    my $actioned_count = shift;
    my $number_of_tweets = shift;
    my $action = my $text = shift;
    $text =~ s/^./uc($&)/e;
    if ($actioned_count == 1) {
        $text .= "once";
    } elsif ($actioned_count == 2) {
        $text .= "twice";
    } else {
        $text .= "$actioned_count times";
    }
    $text .= "($number_of_tweets)";

    my $uri = URI->new(request->uri_for(join('/', 
                'show', params->{username}, $action)));
    $uri->query_form(count => $actioned_count);
    return $html->a(
        href => $uri,
        text => $text,
    );
}

sub authorise {
    my $user   = shift;
    my $cb_url = request->uri_for( request->path );
    debug("callback url is $cb_url");
    try {
        my $twitter = get_twitter();
        my $url = $twitter->get_authorization_url( callback => $cb_url );
        debug( "request token is " . $twitter->request_token );
        $cookies{$user}{token}  = $twitter->request_token;
        $cookies{$user}{secret} = $twitter->request_token_secret;
        redirect($url);
        return "authorise";
    }
    catch {
        error($_);
        send_error("Authorisation failed, $_");
    };
}

sub get_tokens_for {
    my $user = shift;

    my $twitter = get_twitter();
    my ( $token, $secret ) = restore_tokens($user);
    if ( $token && $secret ) {
        return ( $token, $secret );
    } elsif ( my $verifier = params->{oauth_verifier} ) {
        return request_tokens_for( $user, $verifier );
    } else {
        return;
    }
}

sub request_tokens_for {
    my ( $user, $verifier ) = @_;
    debug("Got verifier: $verifier");

    my $twitter = get_twitter();
    $twitter->request_token( $cookies{$user}{token} );
    $twitter->request_token_secret( $cookies{$user}{secret} );
    my @bits = $twitter->request_access_token( verifier => $verifier );

    die "names don't match - got $screen_name"
        unless ( $screen_name eq $user);
    save_tokens( @bits[ 3, 0, 1 ] );
    return ( @bits[ 0, 1 ] );
}

#TODO Rewrite make table

sub make_table {
    my $status = shift;
    return '' unless $status;
    my $text = $status->text;
    my @urls = $text =~ /$urls_re/g;
    if (@urls) {
        @urls = uniq(@urls);
        debug( sprintf( "Found %d urls: %s", scalar(@urls), join( ', ', @urls ) ) );
        my %link_for;
        for my $url (@urls) {
            (my $cleaned_url = $url) =~ s/$span_re//g;
            $link_for{$url} = $html->a(
                href => $cleaned_url,
                text => $url,
            );
        }
        while ( my ( $lhs, $rhs ) = each %link_for ) {
            $text =~ s/$lhs/$rhs/g;
        }
    }
    my @mentions = $text =~ /$mentions_re/g;
    if (@mentions) {
        @mentions = uniq(@mentions);
        debug( sprintf "Found %d mentions: %s", scalar(@mentions), join( ', ', @mentions ) );
        my %link_for;
        for my $mention (@mentions) {
            (my $cleaned_mention = $mention) =~ s/$span_re//g;
            $link_for{$mention} = $html->a(
                href => get_mention_url($cleaned_mention),
                text => $mention,
            );
        }
        while ( my ( $lhs, $rhs ) = each %link_for ) {
            $text =~ s/$lhs/$rhs/g;
        }
    }

    my @hashtags = $text =~ /$hashtags_re/g;
    if (@hashtags) {
        @hashtags = uniq(@hashtags);
        debug( sprintf "Found %d hashtags: %s", scalar(@hashtags), join( ', ', @hashtags ) );
        my %link_for;
        for my $hashtag (@hashtags) {
            (my $cleaned_hashtag = $hashtag) =~ s/$span_re//g;
            $link_for{$hashtag} = $html->a(
                href => get_hashtag_url($cleaned_hashtag),
                text => $hashtag,
            );
        }
        while ( my ( $lhs, $rhs ) = each %link_for ) {
            $text =~ s/$lhs/$rhs/g;
        }
    }

    my $id        = $status->{id};
    my $list_item = join(
        "\n",
        $html->div_start( onclick => "toggleForm('$id');", ),
        $html->h2(
            $dt_prsr->parse_datetime( $status->{created_at} )->strftime("%d %b %Y %X")
        ),
        $html->p($text),
    );
    $list_item .= $html->div_start( id => $id . '-tags', class => 'tags-list' );
    $list_item .= "\n"
      . $html->ul(
        { id => "tagList-$id" },
        (
            ( $status->{$TAGS_KEY} and @{ $status->{$TAGS_KEY} } )
            ? $html->li_group( $status->{$TAGS_KEY} )
            : ''
        )
      );
    $list_item .= $html->div_end;
    $list_item .= $html->div_end;
    $list_item .= $html->form_start(
        style  => 'display: none;',
        class  => 'tag-form',
        method => 'post',
        id     => $id
    );
    $list_item .= $html->p(
            "Tag:" 
          . $html->input( type => 'text', id => "tag-$id" )
          . $html->input(
            value   => 'Add',
            type    => 'button',
            onclick => sprintf( "javascript:addNewTag('%s', '%s');", params->{username}, $id ),
          )
          . $html->input(
            value   => 'Remove',
            type    => 'button',
            onclick => sprintf( "javascript:deleteTag('%s', '%s');", params->{username}, $id ),
          ),
    );
    $list_item .= $html->form_end();

    return $list_item;
}

sub make_tag_link {
    my ( $tag, $count ) = @_;
    return $html->a(
        href  => request->uri_for( join( '/', 
                'show', params->{username}, 'tag', $tag ) ),
        text  => "$tag ($count)",
        count => $count,
        tag   => $tag,
        class => 'tagLink',
    );
}

sub get_mention_url {
    my $mention = shift;
    return TWITTER_BASE . substr( $mention, 1 );
}

sub make_mention_link {
    my $mention = shift;
    $mention =~ s/$span_re//g;
    return $html->a(
        href => get_mention_url($mention),
        text => $mention,
    );
}

sub get_hashtag_url {
    my $hashtag = shift;
    my $uri     = URI->new(TWITTER_SEARCH);
    $uri->query_form( q => $hashtag );
    return "$uri";
}

sub make_hashtag_link {
    my $hashtag = shift;
    $hashtag =~ s/$span_re//g;

    return $html->a(
        href => get_hashtag_url($hashtag),
        text => $hashtag,
    );
}

sub make_hashtag_report_link {
    my ( $hashtag, $count ) = @_;
    return $html->a(
        href => request->uri_for(
            join( '/', 'show', params->{username}, 'on', substr( $hashtag, 1 ) )
        ),
        text  => "($count hashtags)",
        class => 'sidebarinternallink',
    );
}

sub make_mention_report_link {
    my ( $mention, $count ) = @_;
    return $html->a(
        href => request->uri_for(
            join( '/', 'show', params->{username}, 'to', substr( $mention, 1 ) )
        ),
        text  => "($count mentions)",
        class => 'sidebarinternallink',
    );
}

get '/' => sub {
    template 'index' => { page_title => 'twarchiver' };
};

set show_errors => 1;
dance;
