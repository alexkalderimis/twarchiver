package Twarchiver::Routes;

use Dancer ':syntax';

get '/' => sub {
    template 'index';
};

get '/show/:username/to/:mention' => sub {
    my $user = params->{username};
    my $mention = '@' . params->{mention};
    show_tweets_including( $user, $mention, 0 );
}

get '/show/:username/on/:hashtag' => sub {
    my $user    = params->{username};
    my $hashtag = params->{hashtag};
    show_tweets_including( $user, $hashtag, 0 );
};

get '/show/:username/tag/:tag' => \&show_tweets_tagged_with;

get '/show/:username' => \&show_statuses_for;

get '/show/:username/:year/:month' => \&show_statuses_within;

get '/download/:username.:format' => \&download_tweets;

get '/search/:username' => sub {
    my $user       = params->{username};
    my $searchterm = params->{searchterm};
    show_tweets_including( $user, $searchterm, 1 );
};

get '/show/:username/:prefix' => \&show_popular_stats;

get '/show/:username/favourited' => \&show_favourited_stats;

get '/load/mentions/for/:username' => \&get_mention_sidebar;

get '/load/timeline/for/:username' => \&get_timeline;

get '/load/hashtags/for/:username' => \&get_hashtags_sidebar;

get '/load/urls/for/:username' => \&get_urls_sidebar;

get '/load/tags/for/:username' => \&get_tags_sidebar;

get '/load/retweeteds/for/:username' => \&get_retweets_sidebar;
# should begin with:
#<li><a href="/show/<% username %>/retweeted">All Retweeted Statuses (<% retweeted_count %>)</a></h3>

get '/load/favourites/for/:username' => \&get_favourites_sidebar;
# Should begin with:
#<li><a href="/show/<% username %>/favorited">All Favourited Statuses (<% favourited_count %>)</a></h3>

ajax '/load/usersummary/for/:username' => \&get_user_summary;

get '/load/content/:username' => \&get_username_content;

get '/load/summary/:username' => \&get_username_summary;

true;
