package Twarchiver::Routes::Login;

use strict;
use warnings;

use Dancer ':syntax';
use Crypt::SaltedHash qw/validate/;
use Twarchiver::Functions::DBAccess qw/:login/;
use Twarchiver::Functions::PageContent qw/:login/;
use DateTime;



post '/login' => sub {
    my $user = params->{login_user};
    
    if (not exists_user($user)) {
        warning "Failed login for unrecognised user '$user'";
        redirect '/?failed=notexists';
    } else {
        my $user_rec = get_user_record($user);
        if (validate_user($user, params->{login_password})) {
            debug "Password correct";
            $user_rec->update(
                {last_login => DateTime->now()}
            );
            # Logged in successfully
            session username => $user;
            redirect params->{url} || '/';
        } else {
            debug("Login failed - password incorrect for " . params->{username});
            redirect '/?failed=incorrect';
        }
    }
};

post '/register' => sub {
    my $user = params->{reg_user};
    my $beta_key = params->{beta_key};
    if ($beta_key !~ /^\{SSHA\}/) {
        $beta_key = '{SSHA}' . $beta_key;
    }

    if (exists_user($user)) {
        debug "User already exists";
        redirect '/?failed=exists';
    } else {
        if (not (params->{reg_password} && params->{confirm_password})) {
            redirect '/?failed=nopass';
        } elsif (params->{reg_password} ne params->{confirm_password}) {
            redirect '/?failed=notmatchingpass';
        } elsif (setting("in_beta") and not beta_key_is_valid_and_unused($beta_key)) {
            redirect '/?failed=notinbeta';
        } else {
            my $csh = Crypt::SaltedHash->new(algorithm => 'SHA-1');
            $csh->add(params->{reg_password});
            my $passhash = $csh->generate;
            my $user_rec = get_user_record($user);
            eval {
                assign_beta_key(key => $beta_key, user => $user_rec);
            };
            if (my $e = $@) {
                redirect '/?failed=notinbeta';
            } else {
                $user_rec->update({
                    passhash => $passhash,
                    created_at => DateTime->now(),
                    last_login => DateTime->now(),
                });
                session username => $user;
                redirect params->{url} || '/';
            }
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
