package Twarchiver::Routes::TweetAnalysis;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;
use HTML::EasyTags;
use DateTime;
use URI;

use Twarchiver::Functions::DBAccess    ':routes';
use Twarchiver::Functions::PageContent ':routes';
use Twarchiver::Functions::TwitterAPI  ':routes';
use Twarchiver::Functions::Util        ':routes';
use Twarchiver::Functions::Export 'export_tweets_in_format';

my $digits = qr/^\d+$/;
my $html = HTML::EasyTags->new();

before sub {
    if (request->path_info =~ m{/(show|search|download|graph)}) {
        my $user = session('username');
        return authorise($user) if needs_authorisation($user);
    }
};

get '/show/mentions/of/*.*' => sub {
    my ($mention, $format) = splat;
    $format = lc $format;

    if ($format eq 'html') {
        redirect "/show/mentions/of/$mention";
    } else {
        my $username = session('username');
        my $mention = '@' . $mention;
        my @tweets  = get_tweets_with_mention($username, $mention);
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/mentions/of/:mention' => sub {
    my $mention = params->{mention};

    my $content_url = "mentions/of/$mention";
    my $title = sprintf "Statuses from %s mentioning %s",
        make_user_home_link(), $mention;

    return_tweet_analysis_page($content_url, $title);
};

sub return_tweet_analysis_page {
    my $content_url = shift;
    my $title = shift;
    my $username = session('username');
    my $params = shift;
    my $text_url = request->uri_for(request->path . '.txt', $params);
    my $tsv_url  = request->uri_for(request->path . '.tsv', $params);
    my $csv_url  = request->uri_for(request->path . '.csv', $params);
    my $profile_image = get_user_record($username)
                            ->twitter_account->profile_image_url
                        || '/images/' . settings("headericon");
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

get '/show/tweets/on/:topic.:format' => sub {
    my $format = lc params->{format};

    if ($format eq 'html') {
        redirect "/show/tweets/on/" . params->{topic};
    } else {
        my $username = session('username');
        
        my $hashtag = '#' . params->{topic};
        my @tweets  = get_tweets_with_hashtag($username, $hashtag);
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/tweets/on/:topic' => sub {
    my $topic = params->{topic};

    my $content_url = "tweets/on/$topic";
    my $title = sprintf "Statuses from %s about %s",
        make_user_home_link(), $topic;

    return_tweet_analysis_page($content_url, $title);
};

get '/show/links/to' => sub {
    my $address  = params->{address};

    my $content_url = URI->new('links/to');
    $content_url->query_form(address => $address);
    my $title = sprintf "Statuses from %s with a link to %s",
        make_user_home_link(), $address;

    return_tweet_analysis_page($content_url, $title);
};

get '/show/links/to.:format' => sub {
    my $format = lc params->{format};

    if ($format eq 'html') {
        my $url = URI->new('/show/links/to');
        $url->query_form(address => params->{address});
        redirect "$url";
    } else {
        my $username = session('username');
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

get '/show/tweets/tagged/:tag.:format' => sub {
    my $format = lc params->{format};
    my $tag = params->{tag};

    if ($format eq 'html') {
        my $uri = URI->new("/show/tweets/tagged/$tag");
        redirect "$uri";
    } else {
        my $username = session('username');
        
        my @tweets  = get_tweets_with_tag($username, $tag);
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/tweets/tagged/:tag' => sub {
    my $tag  = params->{tag};

    my $content_url = URI->new("tweets/tagged/$tag");
    my $title = sprintf "Statuses from %s tagged with: %s",
        make_user_home_link(), $tag;

    return_tweet_analysis_page("$content_url", $title);
};


=head2 /show

Function: return a page loading all the statuses from a user

=cut

get '/show/tweets.:format' => sub {
    my $format = lc params->{format};

    if ($format eq 'html') {
        redirect '/show';
    } else {
        my @tweets  = get_all_tweets_for(session('username'));
        return export_tweets_in_format($format, @tweets);
    }
};
get '/show/tweets' => sub {

    my $title       = "Twistory for " . session('username');
    my $content_url = 'tweets';

    return_tweet_analysis_page($content_url, $title);
};


get qr{/show/(\d{4})-(\d{1,2}).(\w{3,4})} => sub {
    my ($year, $month, $format) = splat;
    $format = lc $format;

    if ($format eq 'html') {
        redirect "/show/$year-$month";
    } else {
        my @tweets  = get_tweets_in_month(
            session('username'), $year, $month);
        return export_tweets_in_format($format, @tweets);
    }
};

get qr{/show/(\d{4})-(\d{1,2})} => sub {
    my ($year, $month) = splat;

    my $content_url = "$year-$month";

    my $title = sprintf "Statuses by %s from %s %s",
        make_user_home_link(), get_month_name_for($month), $year;

    return_tweet_analysis_page($content_url, $title);
};

get '/show/tweets/from/:epoch.:format' => sub {
    my $epoch = params->{epoch};
    my $days = params->{days};
    my $format = lc params->{format};
    if ($format eq 'html') {
        my $url = "/show/tweets/from/$epoch";
        $url .= "?days=$days" if $days;
        redirect $url;
    } else {
        my @tweets = get_tweets_from(
            session('username'), $epoch, $days);
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/tweets/from/:epoch' => sub {
    my $epoch = params->{epoch};
    my $days = params->{days};

    my $content_url = "tweets/from/$epoch";
    $content_url .= "?days=$days" if $days;

    my $start = DateTime->from_epoch(epoch => $epoch);

    my $title = sprintf "Statuses by %s %sfrom %s",
        make_user_home_link(), 
        (($days) ? "in the $days days " : ''),
        $start->ymd;

    my $params = {days => $days};
    return_tweet_analysis_page($content_url, $title, $params);
};

get '/show/tweets/retweeted.:format' => sub {
    my $format = lc params->{format};
    my $count = params->{count};

    if ($format eq 'html') {
        my $path = "/show/tweets/retweeted";
        redirect request->uri_for( $path, params );
    } else {
        my @tweets  = get_retweeted_tweets(session('username'), $count);
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/tweets/retweeted' => sub {
    my $count    = params->{count};

    my $content_url = "retweeted";
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

    return_tweet_analysis_page($content_url, $title, $params);
};

get '/download/tweets.:format' => sub {
    my $format = params->{format};

    my @tweets = get_all_tweets_for(session('username'));
    return export_tweets_in_format($format, @tweets);
};

get '/search/tweets.:format' => sub {
    my $format = lc params->{format};
    my ($st, $i) = @{{(params)}}{qw/searchterm i/};
    if ($format eq 'html') {
        my $url = URI->new('/search/tweets');
        $url->query_form(
            searchterm => $st,
            i          => $i
        );
        redirect $url;
    } else {
        my ($re, @tweets) = get_tweets_matching_search(
            session('username'), $st, $i);
        export_tweets_in_format($format, @tweets);
    }
};

get '/search/tweets' => sub {
    my $searchterm = params->{searchterm};
    my $case_insensitive = params->{i};

    my $title = sprintf "Tweets by %s matching $searchterm",
                    make_user_home_link();
    my $content_url = URI->new( 'search' );

    $content_url->query_form(
        searchterm => $searchterm,
        i          => $case_insensitive,
    );

    return_tweet_analysis_page($content_url, $title, );
};

=head2 /load/content/:username/search/:searchterm?i=isCaseInsensitive

Function: Called by ajax to populate the page with content for all tweets
          matching a particular search term
Returns:  The content html string

=cut

get '/load/content/tweets/tagged/:tag' => sub {

    my $user = session('username');
    my $tag  = params->{tag};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    download_latest_tweets_for($user);

    my @tweets = get_tweets_with_tag($user, $tag);
    my $content = make_content(@tweets);
    return $content;
};

get '/load/content/mentions/of/:mention' => sub {
    my $user = session('username');
    my $mention = '@' . params->{mention};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    download_latest_tweets_for($user);

    my @tweets  = get_tweets_with_mention($user, $mention);
    my $content = make_highlit_content($mention, @tweets);
    return $content;
};

get '/load/content/tweets/on/:topic' => sub {
    my $topic = '#' . params->{topic};
    my $user = session('username');

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    download_latest_tweets_for($user);

    my @tweets  = get_tweets_with_hashtag($user, $topic);
    my $content = make_highlit_content($topic, @tweets);
    return $content;
};

get '/load/content/links/to' => sub {
    my $address = params->{address};
    my $user = session('username');

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    download_latest_tweets_for($user);

    my @tweets  = get_tweets_with_url($user, $address);
    my $content = make_highlit_content($address, @tweets);
    return $content;
};


get '/load/content/retweeted' => sub {
    my $user = session('username');
    my $count  = params->{count};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    download_latest_tweets_for($user);

    my @tweets  = get_retweeted_tweets($user, $count);
    my $content = make_content(@tweets);
    return $content;
};

get '/load/content/search' => sub {
    my $user = session('username');
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


get '/load/timeline' => sub {
    my $username = session('username');
    my @years = get_years_for($username);
    if (@years) {
        return $html->li_group([
            map {make_year_group($username, $_)} @years]);
    } else {
        return $html->p("No tweets found");
    }
};

get '/load/mentions' => sub {
    my $username = session('username');
    my @mentions = get_mentions_for($username)->all;
    if (@mentions) {
        return $html->li_group([
            map {make_mention_sidebar_item($_)} @mentions]);
    } else {
        return $html->p("No mentions found");
    }
};

get '/load/hashtags' => sub {
    my $username = session('username');
    my @hashtags = get_hashtags_for($username)->all;
    if (@hashtags) {
        return $html->li_group([
            map {make_hashtag_sidebar_item($_)} @hashtags]);
    } else {
        return $html->p("No hashtags found");
    }
};

get '/load/urls' => sub {
    my $username = session('username');
    my @urls = get_urls_for($username)->all;
    if (@urls) {
        return $html->li_group([
            map {make_url_sidebar_item($_)} @urls]);
    } else {
        return $html->p("No urls found");
    }
};

get '/load/tags' => sub {
    my $username = session('username');
    my @tags = get_tags_for($username)->all;
    if (@tags) {
        return $html->li_group([
            map {make_tag_sidebar_item($_)} @tags]);
    } else {
        return $html->p("No Tags Found");
    }
};

get '/load/retweeteds' => sub {
    my $username = session('username');
    return make_retweeted_sidebar($username);
};

=head2 /load/content/:username

Function: Called by ajax to populate the page with content for all tweets
Returns:  The content html string

=cut

get '/load/content/tweets' => sub {
    my $user = session('username');
    return $html->p("Not Authorised") if ( needs_authorisation($user) );
    download_latest_tweets_for($user);
    my @tweets  = get_all_tweets_for($user);
    my $content = make_content(@tweets);
    return $content;
};
get qr{/load/content/(\d{4})-(\d{1,2})} => sub {
    my $user = session('username');
    my ($year, $month) = splat;

    return $html->p("Not Authorised") if ( needs_authorisation($user) );
    download_latest_tweets_for($user);
    my @tweets = get_tweets_in_month($user, $year, $month);
    my $content = make_content(@tweets);
    return $content;
};

get '/load/content/tweets/from/:epoch' => sub {
    my $user = session('username');
    my $epoch = params->{epoch};
    my $days = params->{days};
    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    my @tweets = get_tweets_from($user, $epoch, $days);
    my $content = make_content(@tweets);
    return $content;
};

get '/load/summary' => sub {
    my $username = session('username');
    download_latest_tweets_for($username);
    my $user     = get_user_record($username);
    my %data;
    $data{tweet_count}     = get_tweet_count($username);
    $data{retweet_count}   = get_retweet_count($username);
    $data{hashtag_count}   = get_hashtags_for($username)->count;
    $data{tag_count}       = get_tags_for($username)->count;
    $data{mention_count}   = get_mentions_for($username)->count;
    $data{urls_total}      = get_urls_for($username)->count;
    $data{beginning}       = $user->twitter_account->created_at->dmy();
    $data{most_recent}     = get_most_recent_tweet_by($username)->tweeted_at->dmy();
    return to_json( \%data );
};

get '/downloadtweets' => sub {
    my $maxId = params->{maxId};
    my $response = download_tweets_from($maxId);
    return to_json( $response );
};

ajax '/addtags' => sub {
    my @tags      = split( /,/, params->{tags} );
    my @tweet_ids = split( /,/, params->{tweetIds} );
    my $response  = add_tags_to_tweets([@tags], [@tweet_ids]);
    return to_json($response);
};

ajax '/removetags' => sub {
    my @tags      = split( /,/, params->{tags} );
    my @tweet_ids = split( /,/, params->{tweetIds} );
    my $response  = remove_tags_from_tweets([@tags], [@tweet_ids]);
    return to_json($response);
};

true;
