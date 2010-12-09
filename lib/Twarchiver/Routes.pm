package Twarchiver::Routes;

use Dancer ':syntax';

get '/' => sub {
    template 'index';
};
true;
