package Twarchiver::Routes::Home;

use Dancer ':syntax';

get '/' => sub {
    my $quote = "The only thing I can predict is the past - Watshisface";
    template 'index' => {
        quote => $quote,
    };
};

true;
