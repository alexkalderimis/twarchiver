package Twarchiver::Routes::Home;

use Dancer ':syntax';

use Twarchiver::Functions::DBAccess qw/get_user_record/;

get '/' => sub {
    my $quote = "The only thing I can predict is the past - Watshisface";
    if (session('username')) {
        my $user = get_user_record(session('username'));
        my $tweet_count = $user->tweets->count;
        template 'loggedin_index' => {
            quote => $quote,
            tweet_count => $tweet_count,
            
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

true;
