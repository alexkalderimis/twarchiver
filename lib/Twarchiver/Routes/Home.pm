package Twarchiver::Routes::Home;

use Dancer ':syntax';

use feature ':5.10';

use Twarchiver::Functions::DBAccess qw/:routes/;
use Twarchiver::Functions::TwitterAPI qw/:routes/;
use Twarchiver::Functions::Util qw/:all/;

get '/' => sub {
    my $quote = get_quote();
    if (session('username')) {
        my $username = session('username');
        my $user = get_user_record($username);
        return authorise($username) if needs_authorisation($username);
        my $tweet_count = get_tweet_count($username);
        my $user_creation = $user->created_at->strftime(LONG_MONTH_FORMAT);

        template 'loggedin_index' => {
            quote => $quote,
            tweet_count => $tweet_count,
            username => $username,
            user_creation => $user_creation,
            
        };

    } else {
        my %failure_message_for = (
        incorrect => 
            "Incorrect login details, I'm afraid - please try again",
        notexists => 
            "There is no user with that username - please register",
        exists    => 
            "There is already a user with that username - please login",
        nopass    =>
            "You must supply both a password and a confirmation password",
        notmatchingpass =>
            "The passwords don't match - please try again",
        );
        my $callback = vars->{requested_path} || '';
        debug("Failure reason is " . params->{failed}) 
            if params->{failed};
        my $msg = (params->{failed}) 
                ? $failure_message_for{params->{failed}}
                : '';
        template 'index' => {
            callback_url => $callback,
            failure_message => $msg,
            quote => $quote,
        };
    }
};

sub get_quote {
    state @quotes;
    unless (@quotes) {
        open (my $quotes, '<', 'data/history_quotes');
        while (<$quotes>) {
            chomp;
            push @quotes, $_;
        }
        close $quotes;
    }
    return $quotes[rand @quotes];
}

true;
