package Twarchiver::Routes::TweetAnalysis;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;
use HTML::EasyTags;
use URI;

use Twarchiver::Functions::DBAccess    ':routes';
use Twarchiver::Functions::PageContent ':routes';
use Twarchiver::Functions::TwitterAPI  ':routes';
use Twarchiver::Functions::Util        ':routes';
use Twarchiver::Functions::Export 'export_tweets_in_format';

my $digits = qr/^\d+$/;
my $html = HTML::EasyTags->new();


get '/show/:username/to/*.*' => sub {
    my ($mention, $format) = splat;
    $format = lc $format;

    if ($format eq 'html') {
        redirect '/show/' . params->{username} . /to/ . $mention;
    } else {
        my $username = params->{username};
        my $mention = '@' . $mention;
        my @tweets  = get_tweets_with_mention($username, $mention);
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/:username/to/:mention' => sub {
    my $user    = params->{username};
    my $mention = params->{mention};
    return authorise($user) if needs_authorisation($user);

    my $content_url = join('/', $user, 'to', $mention);
    my $title = sprintf "Statuses from %s mentioning %s",
        make_user_home_link(), $mention;

    return_tweet_analysis_page($content_url, $title, $user);
};

sub return_tweet_analysis_page {
    my $content_url = shift;
    my $title = shift;
    my $username = shift;
    my $params = shift;
    my $text_url = request->uri_for(request->path . '.txt', $params);
    my $tsv_url  = request->uri_for(request->path . '.tsv', $params);
    my $csv_url  = request->uri_for(request->path . '.csv', $params);
    my $profile_image = get_user_record($username)->profile_image_url
                        || '/images/squirrel_icon64.gif';
    return template statuses => {
        content_url => $content_url,
        title => $title,
        username => $username,
        text_export_url => $text_url,
        tsv_export_url => $tsv_url,
        csv_export_url => $csv_url,
        profile_image => $profile_image,
    };
}

get '/show/:username/on/:topic.:format' => sub {
    my $format = lc params->{format};

    if ($format eq 'html') {
        redirect '/show/' . params->{username} . /on/ . params->{topic};
    } else {
        my $username = params->{username};
        
        my $hashtag = '#' . params->{topic};
        my @tweets  = get_tweets_with_hashtag($username, $hashtag);
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/:username/on/:topic' => sub {
    my $user    = params->{username};
    my $topic = params->{topic};
    return authorise($user) if needs_authorisation($user);

    my $content_url = join('/', $user, 'on', $topic);
    my $title = sprintf "Statuses from %s about %s",
        make_user_home_link(), $topic;

    return_tweet_analysis_page($content_url, $title, $user);
};

get '/show/:username/url' => sub {
    my $username = params->{username};
    my $address  = params->{address};
    
    return authorise($username) if needs_authorisation($username);

    my $content_url = URI->new(join('/', $username, 'url'));
    $content_url->query_form(address => $address);
    my $title = sprintf "Statuses from %s with a link to %s",
        make_user_home_link(), $address;

    return_tweet_analysis_page($content_url, $title, $username);
};

get '/show/:username/url.:format' => sub {
    my $format = lc params->{format};

    if ($format eq 'html') {
        my $url = URI->new('/show/' . params->{username} . '/url');
        $url->query_form(address => params->{address});
        redirect $url;
    } else {
        my $username = params->{username}; 
        my $address = params->{address};
        my @tweets;
        if ($address) {
            @tweets  = get_tweets_with_url($username, $address);
        } else {
            my @addresses = get_urls_for($username)
                                ->get_column('address')
                                ->all;
            @tweets = map {get_tweets_with_url($username, $_)->all}
                            @addresses;
        }
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/:username/tag/*.*' => sub {
    my ($tag, $format) = splat;
    $format = lc $format;

    if ($format eq 'html') {
        redirect '/show/' . params->{username} . /tag/ . $tag;
    } else {
        my $username = params->{username};
        
        my @tweets  = get_tweets_with_tag($username, $tag);
        return export_tweets_in_format($format, @tweets);
    }
};
get '/show/:username/tag/:tag' => sub {
    my $user = params->{username};
    my $tag  = params->{tag};

    return authorise($user) if needs_authorisation($user);

    my $content_url = join('/', $user, 'tag', $tag);
    my $title = sprintf "Statuses from %s tagged with %s",
        make_user_home_link(), $tag;

    return_tweet_analysis_page($content_url, $title, $user);
};


=head2 /show/:username

Function: return a page loading all the statuses from a user

=cut

get '/show/*.*' => sub {
    my ($username, $format) = splat;
    $format = lc $format;

    if ($format eq 'html') {
        redirect '/show/' . $username;
    } else {
        my @tweets  = get_all_tweets_for($username);
        return export_tweets_in_format($format, @tweets);
    }
};
get '/show/:username' => sub {
    my $user = params->{username};

    return authorise($user) if needs_authorisation($user);

    my $title       = "Status Archive for $user";
    my $content_url = $user;

    return_tweet_analysis_page($content_url, $title, $user);
};


get '/show/:username/:year/:month.:format' => sub {
    my $format = params->{format};
    $format = lc $format;
    my ($username, $year, $month) = @{{(params)}}{qw/username year month/};

    if ($format eq 'html') {
        redirect '/show/' . join('/', $username, $year, $month);
    } else {
        my @tweets  = get_tweets_in_month($username, $year, $month);
        return export_tweets_in_format($format, @tweets);
    }
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

    return_tweet_analysis_page($content_url, $title, $username);
};

get '/show/:username/retweeted.:format' => sub {
    my $username = params->{username};
    my $format = lc params->{format};
    my $count = params->{count};

    if ($format eq 'html') {
        my $path = "/show/$username/retweeted";
        redirect request->uri_for( $path, params );
    } else {
        my @tweets  = get_retweeted_tweets($username, $count);
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/:username/retweeted' => sub {
    my $username = params->{username};
    my $count    = params->{count};
    return authorise($username) if needs_authorisation($username);
    my $content_url = join('/', $username, 'retweeted');
    my $params = {count => $count};

    my $title = sprintf "Statuses by %s which have been retweeted",
        make_user_home_link();

    if ($count) {
        $content_url .= "?count=$count";
        if     ($count  == 1) {
            $title .= " once";
        } elsif ($count == 2) {
            $title .= " twice";
        } else {
            $title .= " $count times";
        }
    }

    return_tweet_analysis_page($content_url, $title, $username, $params);
};

get '/download/:username.:format' => sub {
    my $user   = params->{username};
    my $format = params->{format};

    my @tweets = get_all_tweets_for($user);
    return export_tweets_in_format($format, @tweets);
};

get '/search/:username.:format' => sub {
    my $format = lc params->{format};
    my ($username, $st, $i) = @{{(params)}}{qw/username searchterm i/};
    if ($format eq 'html') {
        my $url = URI->new('/search/' . $username);
        $url->query_form(
            searchterm => $st,
            i          => $i
        );
        redirect $url;
    } else {
        my ($re, @tweets) = get_tweets_matching_search($username, $st, $i);
        export_tweets_in_format($format, @tweets);
    }
};

get '/search/:username' => sub {
    my $user       = params->{username};
    my $searchterm = params->{searchterm};
    my $case_insensitive = params->{i};

    return authorise($user) if needs_authorisation($user);

    my $title = 'Statuses from '
      . $html->a(
        href => request->uri_for( join( '/', 'show', $user ) ),
        text => $user,
      ) . " matching $searchterm";
    my $content_url = URI->new( join( '/', $user, 'search' ) );

    $content_url->query_form(
        searchterm => $searchterm,
        i          => $case_insensitive,
    );

    return_tweet_analysis_page($content_url, $title, $user);
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

get '/load/content/:username/to/:mention' => sub {
    my $user    = params->{username};
    my $mention = '@' . params->{mention};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    download_latest_tweets_for($user);

    my @tweets  = get_tweets_with_mention($user, $mention);
    my $content = make_highlit_content($mention, @tweets);
    return $content;
};

get '/load/content/:username/on/:topic' => sub {
    my $user  = params->{username};
    my $topic = '#' . params->{topic};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    download_latest_tweets_for($user);

    my @tweets  = get_tweets_with_hashtag($user, $topic);
    my $content = make_highlit_content($topic, @tweets);
    return $content;
};

get '/load/content/:username/url' => sub {
    my $user = params->{username};
    my $address = params->{address};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    download_latest_tweets_for($user);

    my @tweets  = get_tweets_with_url($user, $address);
    my $content = make_highlit_content($address, @tweets);
    return $content;
};


get '/load/content/:username/retweeted' => sub {
    my $user   = params->{username};
    my $count  = params->{count};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    download_latest_tweets_for($user);

    my @tweets  = get_retweeted_tweets($user, $count);
    my $content = make_content(@tweets);
    return $content;
};

get '/load/content/:username/search' => sub {
    my $user                = params->{username};
    my $searchterm          = params->{searchterm};
    my $is_case_insensitive = params->{i};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    download_latest_tweets_for($user);

    my ($re, @tweets) = get_tweets_matching_search(
                $user, $searchterm, $is_case_insensitive);

    my $content = make_highlit_content($re, @tweets);
    return $content;
};

sub get_tweets_matching_search {
    my $user = shift;
    my $searchterm = shift;
    my $is_case_insensitive = shift;
    my $re = eval { ($is_case_insensitive) 
                        ? qr/$searchterm/i 
                        : qr/$searchterm/; };
    if ($@) {
        $re =
          ($is_case_insensitive)
          ? qr/\Q$searchterm\E/i
          : qr/\Q$searchterm\E/;
    }
    my $rs = get_all_tweets_for($user);
    my @tweets;
    while ( my $tweet = $rs->next() ) {
        if ( $tweet->text =~ $re ) {
            push @tweets, $tweet;
        }
    }
    debug( "Got " . scalar(@tweets) . " tweets with searchterm" );
    return ($re, @tweets);
}


get '/load/timeline/for/:username' => sub {
    my $username = params->{username};
    my @years = get_years_for($username);
    if (@years) {
        return $html->li_group([
            map {make_year_group($username, $_)} @years]);
    } else {
        return $html->p("No tweets found");
    }
};

get '/load/mentions/for/:username' => sub {
    my $username = params->{username};
    my @mentions = get_mentions_for($username)->all;
    if (@mentions) {
        return $html->li_group([
            map {make_mention_sidebar_item($_)} @mentions]);
    } else {
        return $html->p("No mentions found");
    }
};

get '/load/hashtags/for/:username' => sub {
    my $username = params->{username};
    my @hashtags = get_hashtags_for($username)->all;
    if (@hashtags) {
        return $html->li_group([
            map {make_hashtag_sidebar_item($_)} @hashtags]);
    } else {
        return $html->p("No hashtags found");
    }
};

get '/load/urls/for/:username' => sub {
    my $username = params->{username};
    my @urls = get_urls_for($username)->all;
    if (@urls) {
        return $html->li_group([
            map {make_url_sidebar_item($_)} @urls]);
    } else {
        return $html->p("No urls found");
    }
};

get '/load/tags/for/:username' => sub {
    my $username = params->{username};
    my @tags = get_tags_for($username)->all;
    if (@tags) {
        return $html->li_group([
            map {make_tag_sidebar_item($_)} @tags]);
    } else {
        return $html->p("No Tags Found");
    }
};

get '/load/retweeteds/for/:username' => sub {
    my $username = params->{username};
    return make_retweeted_sidebar($username);
};

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
};


get '/load/summary/:username' => sub {
    my $username = params->{username};
    my $user     = get_user_record($username);
    my %data;
    $data{tweet_count}     = $user->tweets->count;
    $data{retweet_count}   = $user->tweets->search(
                             { retweeted_count => {'>' => 0}})->count;
    $data{mention_count}   = get_mentions_for($username)->count;
    $data{hashtag_count}   = get_hashtags_for($username)->count;
    $data{tag_count}       = get_tags_for($username)->count;
    $data{urls_total}      = get_urls_for($username)->count;
    $data{beginning}       = $user->created_at->dmy();
    $data{most_recent}     = get_most_recent_tweet_by($username)->created_at->dmy();
    return to_json( \%data );
};

ajax '/addtags' => sub {
    my $user      = params->{username};
    my @tags      = split( /,/, params->{tags} );
    my @tweet_ids = split( /,/, params->{tweetIds} );
    my $response  = add_tags_to_tweets([@tags], [@tweet_ids]);
    return to_json($response);
};

ajax '/removetags' => sub {
    my $user      = params->{username};
    my @tags      = split( /,/, params->{tags} );
    my @tweet_ids = split( /,/, params->{tweetIds} );
    my $response  = remove_tags_from_tweets([@tags], [@tweet_ids]);
    return to_json($response);
};

true;
