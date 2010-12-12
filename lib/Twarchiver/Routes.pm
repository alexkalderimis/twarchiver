package Twarchiver::Routes;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;
use Twarchiver::DBActions ':routes';
use Twarchiver::HTMLActions ':routes';

get '/' => sub {
    template 'index' => {page_title => 'twarchiver'};
};

get '/show/:username/to/:mention' => sub {
    my $user    = params->{username};
    my $mention = '@' . params->{mention};
    show_tweets_including( $user, $mention, 0 );

get '/show/:username/on/:hashtag' => sub {
    my $user    = params->{username};
    my $hashtag = params->{hashtag};
    show_tweets_including( $user, $hashtag, 0 );
};

get '/show/:username/url' => sub {
    my $user = params->{username};
    my $url  = params->{address};
    show_tweets_including( $user, $url, 0 );
};

get '/show/:username/tag/:tag' => sub {
    my $user = params->{username};
    my $tag  = params->{tag};

    return authorise($user) if needs_authorisation($user);

    my $content_url = join('/', $user, 'tag', $tag);
    my $title = sprintf "Statuses from %s tagged with %s",
        make_user_home_link(), $tag;

    template 'statuses' => {
        content_url => $content_url,
        title       => $title,
        username    => $user,
    };
};

=head2 /show/:username

Function: return a page loading all the statuses from a user

=cut

get '/show/:username' => sub {
    my $user = params->{username};

    return authorise($user) if needs_authorisation($user);

    my $title       = "Status Archive for $user";
    my $content_url = $user;

    template 'statuses' => {
        content_url => $content_url,
        title       => $title,
        username    => $user,
    };
};

get '/show/:username/:year/:month' => sub {
    my $username = params->{username};
    my $year = params->{year};
    my $month = params->{month};
    
    pass and return false if
        ($year !~ $digits && $month !~ $digits);

    return authorise($username) if needs_authorisation($username);

    my $content_url = join('/', $username, $year, $month);

    my $title = sprintf "Statuses by %s from %s %s",
        make_user_home_link(), get_month_name_for($month), $year;

    template 'statuses' => {
        content_url => $content_url,
        title => $title,
        username => $username,
    };
};

get '/show/:username/:action' => sub {
    my $username = params->{username};
    my $action = params->{action};
    my $count = params->{count};
    pass and return false unless (grep {$_ eq $action} ACTIONS);
    return authorise($username) if needs_authorisation($username);
    my $content_url = join('/', $username, $action);

    my $title = sprintf "Statuses by %s which have been %s",
        make_user_home_link(), $action;

    if ($count) {
        $content_url .= "?count=$count";
        $title .= " $count times";
    }

    template 'statuses' => {
        content_url => $content_url,
        title => $title,
        username => $username,
    };
};

get '/download/:username.:format' => sub {
    my $user   = params->{username};
    my $format = params->{format};

    my @tweets = get_all_tweets_for($user);

    if ( $format eq 'txt' ) {
        get_tweets_as_textfile(@tweets);
    } elsif ( $format eq 'tsv' ) {
        get_tweets_as_spreadsheet( "\t", @tweets );
    } elsif ( $format eq 'csv' ) {
        get_tweets_as_spreadsheet( ',', @tweets );
    } else {
        send_error "Unknown format requested: $format";
    }
}

get '/search/:username' => sub {
    my $user       = params->{username};
    my $searchterm = params->{searchterm};
    show_tweets_including( $user, $searchterm, true );
};

=head2 /load/content/:username/search/:searchterm?i=isCaseInsensitive

Function: Called by ajax to populate the page with content for all tweets
          matching a particular search term
Returns:  The content html string

=cut

get '/load/content/:username/tag/:tag' => sub {

    my $user = params->{username};
    my $tag  = params->{tag};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    download_latest_tweets_for($user);

    my @tweets = get_tweets_with_tag($user, $tag);
    my $content = make_content(@tweets);
    return $content;
};

get '/load/content/:username/:action' => sub {
    my $user   = params->{username};
    my $action = params->{action};
    my $count  = params->{count};
    pass and return false unless (grep {$_ eq $action} ACTIONS);

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    download_latest_tweets_for($user);

    my @tweets = get_popular_tweets($user, $action, $count);
    my $content = make_content(@tweets);
    return $content;
};

get '/load/content/:username/search' => sub {
    my $user                = params->{username};
    my $searchterm          = params->{searchterm};
    my $is_case_insensitive = params->{i};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    eval { $re = ($is_case_insensitive) ? qr/$searchterm/i : qr/$searchterm/; };
    if ($@) {
        $re =
          ($is_case_insensitive)
          ? qr/\Q$searchterm\E/i
          : qr/\Q$searchterm\E/;
    }
    download_latest_tweets_for($user);
    my $rs = get_all_tweets_for($user);
    my @tweets;
    while ( my $tweet = $rs->next() ) {
        if ( $tweet->text =~ $re ) {
            ( $_->{highlighted_text} = $_->text ) 
                =~ s{$re}{<span class="key-term">$&</span>}g;
            push @tweets, $tweet;
        }
    }
    debug( "Got " . scalar(@tweets) . " tweets with searchterm" );

    my $content = make_content(@tweets);
    return $content;
};

get '/load/timeline/for/:username' => sub {
    my $username = params->{username};
    my @years = get_years_for($username);
    if (@years) {
        return $html->li_group([
            map {make_year_group($username, $_)} @years]);
    } else {
        return $html->p("No tweets found");
    }
}

get '/load/mentions/for/:username' => sub {
    my $username = params->{username};
    my @mentions = get_mentions_for($username);
    if (@mentions) {
        return $html->li_group([
            map {make_mention_sidebar_item($_) @mentions}]);
    } else {
        return $html->p("No mentions found");
    }
}

get '/load/hashtags/for/:username' => \&get_hashtags_sidebar;
    my $username = params->{username};
    my @mentions = get_hashtags_for($username);
    if (@mentions) {
        return $html->li_group([
            map {make_hashtag_sidebar_item($_) @hashtags}]);
    } else {
        return $html->p("No hashtags found");
    }
}

get '/load/urls/for/:username' => \&get_urls_sidebar;
    my $username = params->{username};
    my @urls = get_urls_for($username);
    if (@urls) {
        return $html->li_group([
            map {make_url_sidebar_item($_) @urls}]);
    } else {
        return $html->p("No urls found");
    }
}

get '/load/tags/for/:username' => \&get_tags_sidebar;
    my $username = params->{username};
    my @tags = get_tags_for($username);
    if (@tags) {
        return $html->li_group([
            map make_tag_sidebar_item($username, $_) @tags]);
    } else {
        return $html->p("No Tags Found");
    }
}

get '/load/retweeteds/for/:username' => sub {
    my $username = params->{username};
    return make_popular_sidebar($username, 'retweeted' x 2);
}

get '/load/favourites/for/:username' => sub {
    my $username = params->{username};
    return make_popular_sidebar($username, 'favorited', 'favourited');
}

=head2 /load/content/:username

Function: Called by ajax to populate the page with content for all tweets
Returns:  The content html string

=cut

get '/load/content/:username' => sub {
    my $user = params->{username};
    return $html->p("Not Authorised") if ( needs_authorisation($user) );
    download_latest_tweets_for($user);
    my @tweets  = get_all_tweets_for($user);
    my $content = make_content(@tweets);
    return $content;
};
get '/load/content/:username/:year/:month' => sub {
    my $user = params->{username};
    my $year = params->{year};
    my $month = params->{month};
    
    pass and return false if
        ($year !~ $digits && $month !~ $digits);
    return $html->p("Not Authorised") if ( needs_authorisation($user) );
    download_latest_tweets_for($user);
    my @tweets = get_tweets_in_month($user, $year, $month);
    my $content = make_content(@tweets);
    return $content;
}


get '/load/summary/:username' => sub {
    my $username = params->{username};
    my $user     = get_user_record($username);
    my %data;
    $data{tweet_total}    = $user->tweets->count;
    $data{mention_total}  = get_mentions_for($username)->count;
    $data{hashtags_total} = get_hashtags_for($username)->count;
    $data{tags_total}     = get_tags_for($username)->count;
    $data{urls_total}     = get_urls_for($username)->count;
    $data{tweeting_since} = $user->created_at->dmy();
    $data{up_til}         = $user->tweets->get_column('created_at')->max;
    return to_json( \%data );
};

ajax '/addtags' => sub {
    my $user      = params->{username};
    my @tags      = split( /,/, params->{tags} );
    my @tweet_ids = split( /,/, params->{tweetIds} );
    my $response  = add_tags_to_tweets([[@tags], [@tweet_ids]);
    return to_json($response);
};

ajax '/removetags' => sub {
    my $user      = params->{username};
    my @tags      = split( /,/, params->{tags} );
    my @tweet_ids = split( /,/, params->{tweetIds} );
    my $response  = remove_tags_from_tweets([[@tags], [@tweet_ids]);
    return to_json($response);
};

true;
