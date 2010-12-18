package Twarchiver::Routes::Home;

use Dancer ':syntax';

get '/' => sub {
    template 'index' => {page_title => 'twarchiver'};
};

true;
