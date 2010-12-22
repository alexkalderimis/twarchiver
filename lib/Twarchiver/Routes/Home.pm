package Twarchiver::Routes::Home;

use Dancer ':syntax';

my $failure_message_for = (
    incorrect => "Incorrect login details, I'm afraid - please try again",
    notexists => "There is no user with that username - please register",
    exists    => "There is already a user with that username - please login",
);

get '/' => sub {
    my $quote = "The only thing I can predict is the past - Watshisface";
    if (session('username')) {
        my $user = get_user_record(session('username'));
        $tweet_count = $user->tweets->count;
        template 'loggedin_index' => {
            quote => $quote,
            tweet_count => $tweet_count,
            
        };

    } else {
        template 'index' => {
            callback_url => vars->{requested_path},
            failure_message => $failure_message_for{params->{failed}},
            quote => $quote,
        };
    }
};

true;
