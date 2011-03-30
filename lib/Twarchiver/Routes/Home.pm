package Twarchiver::Routes::Home;

use Dancer ':syntax';
use Dancer::Plugin::ProxyPath;

use Template;
use Twarchiver::Functions::DBAccess qw/:routes/;
use Twarchiver::Functions::TwitterAPI qw/:routes/;
use Twarchiver::Functions::Util qw/:all/;

get '/' => sub {
    my $args = params;
    $args->{quote} = sub {get_quote()};
    $args->{date_format} = LONG_MONTH_FORMAT;
    if (session('username')) {
        my $username = session('username');
        return authorise($username) if needs_authorisation($username);
        $args->{user} = get_user_record($username);
        $args->{tagged_tweet_count} = get_tagged_tweets->count();
        $args->{my_tagged_tweet_count} 
            = tweets_tagged_by($args->{user})->count;
        $args->{screen_name_list} = get_screen_name_list();
        $args->{hashtag_list} = get_hashtags_list();
        $args->{tag_list} = get_tag_list();
        template 'loggedin_index' => $args;

    } else {
        template 'index' => $args;
    }
};

my @quotes;
sub get_quote {
    unless (@quotes) {
        @quotes = @{setting('historyquotes')};
    }
    return $quotes[rand @quotes];
}

true;
