package Twarchiver::Routes::TweetAnalysis;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;
use HTML::EasyTags;
use DateTime;
use URI;
use Template;

use Twarchiver::Functions::DBAccess    ':routes';
use Twarchiver::Functions::PageContent ':routes';
use Twarchiver::Functions::TwitterAPI  ':routes';
use Twarchiver::Functions::Util        ':routes';
use Twarchiver::Functions::Export 'export_tweets_in_format';
use DateTime::Format::SQLite;

my $digits = qr/^\d+$/;
my $html = HTML::EasyTags->new();

before sub {
    if (request->path_info =~ m{/(show|search|download|graph)}) {
        my $user = session('username');
        return authorise($user) if needs_authorisation($user);
    }
};

get '/show/tweets/on/:topic/to/:screen_name' => sub {
    # TODO: this route needed for hashtag analysis
};

get '/show/tweets/on/:topic' => sub {
    my $topic = '#' . params->{topic};
    my $content_url = params->{topic};
    my $title = "Tweets On $topic";

    template 'hashtag' => {
        content_url => $content_url,
        title       => $title,
        topic       => $topic,
    };
};

get '/show/tweets/on/:topicA/and/:topicB' => sub {
    # TODO: This is need for hashtag analysis
};

get '/show/tweets/on/:topic/links/' => sub {
    # TODO: This is needed for hashtag analysis
};

get '/show/tweets/on/:topic/retweeted' => sub {
    # TODO: This is needed for hashtag analysis
};

get '/show/tweets/on/:topic/by/:screen_name' => sub {
    # TODO: This is needed for hashtag analysis
};

get '/show/tweets/on/:topic/tagged/:tag' => sub {
    # TODO: This is needed for hashtag analysis
};


get '/show/:screen_name/to/*.*' => sub {
    my $screen_name = params->{screen_name};
    my ($mention, $format) = splat;
    $format = lc $format;

    if ($format eq 'html') {
        redirect "/show/$screen_name/to/$mention";
    } else {
        my @tweets  = get_tweets_with_mention($screen_name, $mention);
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/:screen_name/to/:mention' => sub {
    my $mention = params->{mention};
    my $screen_name = params->{screen_name};

    my $content_url = "$screen_name/to/$mention";
    my $title = sprintf "Statuses from %s mentioning %s",
        make_user_home_link($screen_name), $mention;

    return_tweet_analysis_page(
        content_url => $content_url, 
        title => $title,
        screen_name => $screen_name,
    );
};

sub return_tweet_analysis_page {
    my %args = @_;
    my $content_url = $args{content_url};
    my $title = $args{title};
    my $username = session('username');
    my $params = $args{params};
    my $screen_name = $args{screen_name} 
        || get_user_record($username)->twitter_account->screen_name;
    my $text_url = request->uri_for(request->path . '.txt', $params);
    my $tsv_url  = request->uri_for(request->path . '.tsv', $params);
    my $csv_url  = request->uri_for(request->path . '.csv', $params);
    my $profile_image = get_twitter_account($screen_name)
                            ->profile_image_url
                        || '/images/' . setting("headericon");
    return template statuses => {
        content_url => $content_url,
        title => $title,
        username => $username,
        text_export_url => $text_url,
        tsv_export_url => $tsv_url,
        csv_export_url => $csv_url,
        profile_image => $profile_image,
        screen_name => $screen_name,
    };
}

get '/show/tweets' => sub {

    my $screen_name = get_user_record(session('username'))
                        ->twitter_account->screen_name;
    redirect request->uri_for("/show/$screen_name");
};

get qr{/show/([[:alnum:]]+)/(\d{4})-(\d{1,2}).(\w{3,4})} => sub {
    my ($screen_name, $year, $month, $format) = splat;
    $format = lc $format;

    if ($format eq 'html') {
        redirect "/show/$screen_name/$year-$month";
    } else {
        my @tweets  = get_tweets_in_month(
            $screen_name, $year, $month);
        return export_tweets_in_format($format, @tweets);
    }
};


get qr{/show/([[:alnum:]]+)/(\d{4})-(\d{1,2})} => sub {
    my ($screen_name, $year, $month) = splat;

    my $content_url = "$year-$month?screen_name=$screen_name";

    my $title = sprintf "Statuses by %s from %s %s",
        make_user_home_link($screen_name), 
        get_month_name_for($month), $year;

    return_tweet_analysis_page(
        content_url => $content_url, 
        title => $title,
        screen_name => $screen_name,
    );
};

get '/show/tweets.:format' => sub {
    my $format = lc params->{format};
    my $screen_name = get_user_record(session('username'))
                        ->twitter_account->screen_name;
    redirect request->uri_for("/show/$screen_name.$format");
};

get '/show/:screen_name.:format' => sub {
    my $format = lc params->{format};
    my $screen_name = params->{screen_name};

    if ($format eq 'html') {
        redirect "/show/$screen_name";
    } else {
        my @tweets = get_tweets_by($screen_name)->all;
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/:username' => sub {
    my $twitter_user = params->{username};
    my $title       = "Twistory for " . $twitter_user;
    my $content_url = 'by/' . $twitter_user;

    download_user_info(for => $twitter_user);

    return_tweet_analysis_page(
        content_url => $content_url, 
        title => $title,
        screen_name => $twitter_user,
    );
};

get '/show/:screen_name/on/:topic.:format' => sub {
    my $format = lc params->{format};
    my $screen_name = params->{screen_name};
    my $topic = params->{topic};

    if ($format eq 'html') {
        redirect "/show/$screen_name/on/$topic";
    } else {
        my $username = session('username');
        
        my $hashtag = '#' . params->{topic};
        my @tweets  = get_tweets_with_hashtag($username, $hashtag);
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/:screen_name/on/:topic' => sub {
    my $screen_name = params->{screen_name};
    my $topic = params->{topic};

    my $content_url = "$screen_name/on/$topic";
    my $title = sprintf "Statuses from %s about %s",
        make_user_home_link($screen_name), $topic;

    return_tweet_analysis_page(
        content_url => $content_url, 
        title => $title,
        screen_name => $screen_name,
    );
};

get '/show/:screen_name/links/to.:format' => sub {
    my $screen_name = params->{screen_name};
    my $format = lc params->{format};

    if ($format eq 'html') {
        my $url = URI->new("/show/$screen_name/links/to");
        $url->query_form(address => params->{address});
        redirect "$url";
    } else {
        my $address = params->{address};
        my @tweets;
        if ($address) {
            @tweets  = get_tweets_with_url($screen_name, $address);
        } else {
            my @addresses = get_urls_for($screen_name)
                                ->get_column('address')
                                ->all;
            @tweets = map {get_tweets_with_url($screen_name, $_)->all}
                            @addresses;
        }
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/:screen_name/links/to' => sub {
    my $screen_name = params->{screen_name};
    my $address  = params->{address};

    my $content_url = URI->new("$screen_name/links/to");
    $content_url->query_form(address => $address);
    my $title = sprintf "Statuses from %s with a link to %s",
        make_user_home_link($screen_name), $address;

    return_tweet_analysis_page(
        content_url => $content_url, 
        title => $title,
        screen_name => $screen_name,
    );
};


get '/show/:screen_name/tagged/:tag.:format' => sub {
    my $format = lc params->{format};
    my $tag = params->{tag};
    my $screen_name = params->{screen_name};

    if ($format eq 'html') {
        my $uri = URI->new("/show/$screen_name/tagged/$tag");
        redirect "$uri";
    } else {
        my @tweets  = get_tweets_with_tag($screen_name, $tag);
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/:screen_name/tagged/:tag' => sub {
    my $screen_name = params->{screen_name};
    my $tag  = params->{tag};

    my $content_url = URI->new("$screen_name/tagged/$tag");
    my $title = sprintf "Statuses from %s tagged with: %s",
        make_user_home_link($screen_name), $tag;

    return_tweet_analysis_page(
        content_url => "$content_url", 
        title => $title,
        screen_name => $screen_name,
    );
};


=head2 /show/tweets

Function: return a page loading all the statuses from a user

=cut


get '/show/:screen_name/from/:epoch.:format' => sub {
    my $epoch = params->{epoch};
    my $days = params->{days};
    my $screen_name = params->{screen_name};

    my $format = lc params->{format};
    if ($format eq 'html') {
        my $url = "/show/$screen_name/from/$epoch";
        $url .= "?days=$days" if $days;
        redirect $url;
    } else {
        my @tweets = get_tweets_from($screen_name, $epoch, $days);
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/:screen_name/from/:epoch' => sub {
    my $epoch = params->{epoch};
    my $days = params->{days};
    my $screen_name = params->{screen_name};

    my $content_url = "$screen_name/from/$epoch";
    $content_url .= "?days=$days" if $days;

    my $start = DateTime->from_epoch(epoch => $epoch);

    my $title = sprintf "Statuses by %s %sfrom %s",
        make_user_home_link($screen_name), 
        (($days) ? "in the $days days " : ''),
        $start->ymd;

    my $params = {days => $days};
    return_tweet_analysis_page(
        content_url => $content_url, 
        title => $title, 
        params => $params,
        screen_name => $screen_name,
    );
};

get '/show/:screen_name/retweeted.:format' => sub {
    my $format = lc params->{format};
    my $screen_name = params->{screen_name};
    my $count = params->{count};

    if ($format eq 'html') {
        my $path = "/show/$screen_name/retweeted";
        redirect request->uri_for( $path, params );
    } else {
        my @tweets  = get_retweeted_tweets($screen_name, $count);
        return export_tweets_in_format($format, @tweets);
    }
};

get '/show/:screen_name/retweeted' => sub {
    my $count       = params->{count};
    my $screen_name = params->{screen_name};

    my $content_url = "$screen_name/retweeted";
    my $params = {count => $count};

    my $title = sprintf "Statuses by %s which have been retweeted",
        make_user_home_link($screen_name);

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

    return_tweet_analysis_page(
        content_url => $content_url, 
        title => $title, 
        params => $params,
        screen_name => $screen_name,
    );
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
    my $screen_name = get_user_record(session('username'))
                        ->twitter_account->screen_name;
    redirect request->uri_for("/search/$screen_name");
};


get '/search/:screen_name' => sub {
    my $searchterm = params->{searchterm};
    my $screen_name = params->{screen_name};
    my $case_insensitive = params->{i};

    my $title = sprintf "Tweets by %s matching $searchterm",
                    make_user_home_link($screen_name);
    my $content_url = URI->new( "search/$screen_name" );

    $content_url->query_form(
        searchterm => $searchterm,
        i          => $case_insensitive,
    );

    return_tweet_analysis_page(
        content_url => $content_url, 
        title => $title, 
        screen_name => $screen_name,
    );
};

=head2 /load/content/:username/search/:searchterm?i=isCaseInsensitive

Function: Called by ajax to populate the page with content for all tweets
          matching a particular search term
Returns:  The content html string

=cut

get '/load/content/:screen_name/tagged/:tag' => sub {

    my $user = session('username');
    my $tag  = params->{tag};
    my $max_id = params->{from};
    my $screen_name = params->{screen_name};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    download_latest_tweets();

    my $tweets = get_tweets_with_tag($screen_name, $tag, $max_id);
    template 'tweets' => {tweets => $tweets}, {layout => 0};
};

get '/load/content/:screen_name/to/:mention' => sub {
    my $user = session('username');
    my $max_id = params->{from};
    my $mention = params->{mention};
    my $screen_name = params->{screen_name};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    download_latest_tweets();

    my $tweets  = get_tweets_with_mention($screen_name, $mention, $max_id);
    my $re = qr/\@$mention/;
    template 'tweets' => {tweets => $tweets, re => $re}, {layout => 0};
};

get '/load/content/:screen_name/on/:topic' => sub {
    my $topic = '#' . params->{topic};
    my $max_id = params->{from};
    my $user = session('username');
    my $screen_name = params->{screen_name};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    my $tweets  = get_tweets_with_hashtag($screen_name, $topic, $max_id);
    my $re = qr/$topic/;
    template 'tweets' => {tweets => $tweets, re => $re}, {layout => 0};
};

get '/load/content/by/:screen_name' => sub {
    my $screen_name = params->{screen_name};
    my $max_id = params->{from};
    my $user = session('username');

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    my $tweets = get_tweets_by($screen_name, $max_id);
    template 'tweets' => {tweets => $tweets}, {layout => 0};
};

get '/load/content/on/:topic' => sub {
    my $topic = '#' . params->{topic};
    my $maxId = params->{from};
    my $user = session('username');

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    my $tweets = get_tweets_on($topic, $maxId);
    template 'tweets_on' => {tweets => $tweets}, {layout => 0};
};

before_template sub {
    my $tokens = shift;
    $tokens->{get_linkified_text} = \&get_linkified_text;
    $tokens->{highlight} = \&highlight;
    $tokens->{get_tags_for} = \&get_tags_from_tweet;
    $tokens->{date_format} = DATE_FORMAT, 
    $tokens->{sqlite_date} =
        sub {DateTime::Format::SQLite->format_datetime(shift)};
    $tokens->{make_user_home_link} = \&make_user_home_link;
};

get '/load/content/:screen_name/links/to' => sub {
    my $address = params->{address};
    my $max_id = params->{from};
    my $user = session('username');
    my $screen_name = params->{screen_name};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    my $tweets  = get_tweets_with_url($screen_name, $address, $max_id);
    my $re = qr/\Q$address\E/;
    template 'tweets' => {tweets => $tweets, re => $re}, {layout => 0};
};


get '/load/content/:screen_name/retweeted' => sub {
    my $user = session('username');
    my $count  = params->{count};
    my $max_id = params->{from};
    my $screen_name = params->{screen_name};

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    my $tweets  = get_retweeted_tweets($screen_name, $count, $max_id);
    template 'tweets' => {tweets => $tweets}, {layout => 0};
};

get '/load/content/search/:screen_name' => sub {
    my $user        = session('username');
    my $max_id      = params->{from};
    my $screen_name = params->{screen_name};
    my $searchterm  = params->{searchterm};
    return $html->p("Not Authorised") if ( needs_authorisation($user) );
    #my $is_case_insensitive = params->{i};

    my $tweets = get_tweets_matching($screen_name, $searchterm, $max_id);
    my $re = qr/\Q$searchterm\E/;
    template 'tweets' => {tweets => $tweets, re => $re}, {layout => 0};
};

get qr{/load/content/(\d{4})-(\d{1,2})} => sub {
    my $user = session('username');
    my ($year, $month) = splat;
    my $max_id = params->{from};
    my $screen_name = params->{screen_name}
        || get_user_record($user)
                ->twitter_account->screen_name;

    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    my @tweets = get_tweets_in_month($screen_name, $year, $month, $max_id);
    my $content = make_content(@tweets);
    return $content;
};

get '/load/content/:screen_name/from/:epoch' => sub {
    my $user = session('username');
    my $screen_name = params->{screen_name};
    my $epoch = params->{epoch};
    my $days = params->{days};
    my $max_id = params->{from};
    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    my @tweets = get_tweets_from($screen_name, $epoch, $days, $max_id);
    my $content = make_content(@tweets);
    return $content;
};

=head2 /load/content/:username

Function: Called by ajax to populate the page with content for all tweets
Returns:  The content html string

=cut

get '/load/content/tweets' => sub {
    my $user = session('username');
    my $max_id = params->{from};
    my $screen_name = get_user_record($user)->twitter_account->screen_name;
    return $html->p("Not Authorised") if ( needs_authorisation($user) );

    my @tweets = get_tweets_by($screen_name, $max_id);
    my $content = make_content(@tweets);
    return $content;
};

sub get_tweets_matching_search {
    my $screen_name = shift;
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
    my $rs = get_twitter_account($screen_name)->tweets;
    my @tweets;
    while ( my $tweet = $rs->next() ) {
        if ( $tweet->text =~ $re ) {
            push @tweets, $tweet;
        }
    }
    debug( "Got " . scalar(@tweets) . " tweets with searchterm" );
    return ($re, @tweets);
}

sub get_kv {
    if (my $screen_name = params->{screen_name}) {
        return (screen_name => $screen_name);
    } elsif (my $topic = params->{topic}) {
        return (topic => $topic);
    } 
}

ajax '/load/timeline' => sub {
    my %kv = get_kv();
    return send_error("Bad Parameters") unless (%kv);
    my @years = get_years_for(%kv);
    if (@years) {
        return $html->li_group([
            map {make_year_group(%kv, year => $_)} @years]);
    } else {
        return $html->p("No tweets found");
    }
};

ajax '/load/tweeters' => sub {
    my $topic = params->{on};
    return send_error("Bad Parameters") unless ($topic);
    my @authors = get_authors_for_topic($topic)->all;
    return template tweeters_sidebar => {
        tweeters => \@authors,
        get_tweets_with_hashtag => \&get_tweets_with_hashtag,
        topic => $topic,
    };
};

ajax '/load/mentions' => sub {
    my %kv = get_kv();
    return send_error("Bad Parameters") unless (%kv);
    my @mentions = get_mentions_for(%kv)->all;
    if (@mentions) {
        return $html->li_group([
            map {make_mention_sidebar_item($_)} @mentions]);
    } else {
        return $html->p("No mentions found");
    }
};

ajax '/load/hashtags' => sub {
    my %kv = get_kv();
    return send_error("Bad Parameters") unless (%kv);
    my @hashtags = get_hashtags_for(%kv)->all;
    if (@hashtags) {
        return $html->li_group([
            map {make_hashtag_sidebar_item($_)} @hashtags]);
    } else {
        return $html->p("No hashtags found");
    }
};

ajax '/load/urls' => sub {
    my %kv = get_kv();
    return send_error("Bad Parameters") unless (%kv);
    my @urls = get_urls_for(%kv)->all;
    if (@urls) {
        return $html->li_group([
            map {make_url_sidebar_item($_)} @urls]);
    } else {
        return $html->p("No urls found");
    }
};

ajax '/load/tags' => sub {
    my %kv = get_kv();
    return send_error("Bad Parameters") unless (%kv);

    my @tags = get_tags_for(%kv)->all;
    if (@tags) {
        return $html->li_group([
            map {make_tag_sidebar_item($_)} @tags]);
    } else {
        return $html->p("No Tags Found");
    }
};

ajax '/load/retweeteds' => sub {
    my %kv = get_kv();
    return send_error("Bad Parameters") unless (%kv);

    return make_retweeted_sidebar(%kv);
};


ajax '/load/summary' => sub {
    my %kv = get_kv();
    return send_error("Bad Parameters") unless (%kv);

    my $data = get_user_count_summary(%kv);
    return to_json( $data );
};

get '/downloadtweets' => sub {
    my $maxId     = params->{maxId};
    my $twitterer = params->{by};
    my $topic     = params->{on};
    my $page      = params->{page};
    my $response = download_tweets(
        from => $maxId, 
        by   => $twitterer,
        on   => $topic,
        page => $page,
    );
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
