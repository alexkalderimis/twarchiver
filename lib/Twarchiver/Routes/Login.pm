package Twarchiver::Routes::Login;

use strict;
use warnings;

use Dancer ':syntax';
use Crypt::SaltedHash qw/validate/;
use Twarchiver::Functions::DBAccess qw/get_user_record/;
use Twarchiver::Functions::PageContent qw/:login/;



post '/login' => sub {
    my $user = params->{login_user};
    
    if (not exists_user($user)) {
        warning "Failed login for unrecognised user '$user'";
        redirect '/?loginfailed=notexists';
    } else {
        my $user_rec = get_user_record($user);
        if (validate_user($user, params->{login_password}) {
            debug "Password correct";
            # Logged in successfully
            session username => $user;
            redirect params->{url} || '/';
        } else {
            debug("Login failed - password incorrect for " . params->{username});
            redirect '/?loginfailed=incorrect';
        }
    }
};

post '/register' => sub {
    my $user = params->{login_user};

    if (exists_user($user) {
        debug "User already exists";
        redirect '/login?failed=exists';
    } else {
        if (params->{reg_password} ne params->{confirm_password}) {
            redirect '/login?failed=notmatchingpass';
        } else {
            my $csh = Crypt::SaltedHash->new(algorithm => 'SHA-1');
            $csh->add(params->{reg_password});
            my $pashhash = $csh->generate;
            my $user_rec = get_user_record($user);
            $user_rec->update({passhash => $passhash});
            session username => $user;
            redirect params->{url} || '/';
        }
    }
};

post '/logout' => sub {
    session->destroy;
    redirect('/');
};

before sub {

    # If an unlogged-in user wants to do anything but login,
    # register, or go to the root
    if (! session('username') 
        && request->path_info !~ m{^/(?:$|login|logout|register)}) {
        var requested_path => request->path_info;
        return request->path_info('/');
    }
};

true;
