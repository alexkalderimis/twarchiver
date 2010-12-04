#!/usr/bin/perl

use Dancer;
use lib 'lib';
use Net::Twitter::Scraper;
use HTML::Table;
use HTML::EasyTags;

my $html = HTML::EasyTags->new();
layout 'main';

my %cookies;

get '/show/:username' => \&show_statuses_for;

sub show_statuses_for {
    my $user = params->{username};
    debug "Getting statūs of $user";
    my @tokens = get_tokens_for($user);

    unless (@tokens) {
        return authorise($user);
    }
    my @statuses = get_statuses(@tokens);

    my @tables = map{ make_table($_) } @statuses;

    my $response = join($html->br(), @tables);

    template main => {content => $response};
}


sub authorise {
    my $user = shift;
    my $cb_url = request->uri_for( request->path );
    debug("callback url is $cb_url");
    try {
        my $twitter = get_twitter();
        my $url = $twitter->get_authorization_url( 
            callback => $cb_url );
        debug( "request token is " . $twitter->request_token );
        $cookies{$user}{token} = $twitter->request_token;
        $cookies{$user}{secret} = $twitter->request_token_secret;
        redirect($url);
        return "see you later";
    } catch {
        error($_);
        die("oauth redirect failed, $_");
    };
}
    

sub get_tokens_for {
    my $user = shift;

    my $twitter = get_twitter();
    my ( $token, $secret ) = restore_tokens($user);
    if ( $token && $secret ) {
        return($token,$secret);
    } elsif (my $verifier = params->{oauth_verifier}) {
        return request_tokens_for($user, $verifier);
    } else {
        return;
    }
}

sub request_tokens_for {
    my ($user, $verifier) = @_;
    debug("Got verifier: $verifier");

    my $twitter = get_twitter();
    $twitter->request_token($cookies{$user}{token});
    $twitter->request_token_secret($cookies{$user}{secret});
    my @bits = $twitter->request_access_token( verifier => $verifier );
#        die "names don't match - got $screen_name"
#            unless ( $screen_name eq $user);
    save_tokens( @bits[3, 0, 1] );
    return( @bits[0, 1] );
}

sub get_statuses {
    my @tokens = @_;
    my $twitter = get_twitter(@tokens);
    
    if ( $twitter->authorized ) {
        my @stats;

        for ( my $page = 1 ; ; ++$page ) {
            debug("Getting page $page of twitter statuses");
            my $statuses = $twitter->user_timeline(
                {
                    count => 50,
                    page  => $page,
                }
            );
            last unless @$statuses;
            push @stats, @$statuses;

            #			last if (@stats > 20);
        }
        return @stats;
    } else {
        die "Not authorised.";
    }
}

sub make_table {
    my $status = shift;
    my $table = HTML::Table->new();
    $table->addRow(@{$status}{qw/created_at id/});
    $table->addRow($status->text);
    return $table;
}


get '/debug/:name' => sub {
    return "Hello " . params->{name};
};

set show_errors => 1;
dance;
