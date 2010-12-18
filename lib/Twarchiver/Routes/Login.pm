package Twarchiver::Routes::Login;

use strict;
use warnings;

use Dancer ':syntax';
use Crypt::SaltedHash qw/validate/;
use Twarchiver::Functions::DBAccess qw/get_user_record/;
use Twarchiver::Functions::PageContent qw/:login/;



post '/login' => sub {
    my $user = get_user_record(params->{username});
    
    if (not $user->passhash) {
        warning "Failed login for unrecognised user " . params->{username};
        $user->delete;
        redirect '/login?failed=1';
    } else {
        if (Crypt::SaltedHash->validate($user->passhash, params->password)) 
        {
            debug "Password correct";
            # Logged in successfully
            session user => $user;
            redirect params->{path} || '/';
        } else {
            debug("Login failed - password incorrect for " . params->{username});
            redirect '/login?failed=incorrect';
        }
    }
};

post '/register' => sub {
    my $user = get_user_record(params->{username});
    if ($user->passhash) {
        debug "User already exists";
        redirect '/login?failed=exists';
    } else {
        my $csh = Crypt::SaltedHash->new(algorithm => 'SHA-1');
        $csh->add(params->{password});
        my $pashhash = $csh->generate;
        $user->update({passhash => $passhash});
        session user => $user;
        redirect params->{path} || '/';
    }
};

 before sub {

    # If an unlogged-in user wants to do anything but login or go to the root
    if (! session('user') && request->path_info !~ m{^/(?:$|login)}) {
        var requested_path => request->path_info;
        request->path_info('/login');
    }
};

get '/login' => sub {
    # Display a login page; the original URL they requested is available as
    # vars->{requested_path}, so could be put in a hidden field in the form
    my $message_box;
    if (my $reason = params->{failed}) {
        $message_box = get_failed_login_message_box($reason);
    } else {
        $message_box = get_normal_login_message_box();
    }

    template 'login', { 
        path => vars->{requested_path},
        message => $message_box,
    };
};

true;
