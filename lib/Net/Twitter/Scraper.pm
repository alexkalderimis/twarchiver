package Net::Twitter::Scraper;

use warnings;
use strict;
use Data::Dumper;

=head1 NAME

Net::Twitter::Scraper - The great new Net::Twitter::Scraper!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Net::Twitter::Scraper;

    my $foo = Net::Twitter::Scraper->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

use Net::Twitter;
use Try::Tiny;
use File::Basename;
use File::Path qw(make_path);
use File::Spec::Functions;
use Scalar::Util 'blessed';
use Twarchiver::DB::Schema;

use constant CONS_KEY      => 'duo83UgzZ99BRPpf56pUnA';
use constant CONS_SEC      => '6Si7yg4S1USpVFFYpL6N8Bc3MftddMXEQYefbn9U3w';
use constant STORAGE_PATHS => ( dirname($0), 'data', 'auth-tokens' );
use constant STATUS_STORAGE => (dirname($0), 'data', 'statuses');

use Exporter 'import';
our @EXPORT = qw/get_twitter restore_tokens save_tokens store_statuses restore_statuses_for get_db get_user_record/;

my %cookies;
my $schema;

my $span_re           = qr/<.?span.*?>/;
my $mentions_re       = qr/(\@(?:$span_re|\w+)+\b)/;
my $hashtags_re       = qr/(\#(?:$span_re|[\w-]+)+)/;
my $urls_re           = qr{(http://(?:$span_re|[\w\./]+)+\b)};

sub get_db {
    unless ($schema) {
        $schema = Twarchiver::DB::Schema->connect(
            "dbi:SQLite:dbname=".setting('database'));
    }

    return $schema;
}

my %name_of_month;
sub get_month_name_for {
    my $month_number = shift;
    unless (%name_of_month) {
        %name_of_month = map 
            {$_ => DateTime->new(year => 2010, month => $_)->month_name} 
                1 .. 12;
    }
    return $name_of_month{$month_number};
}

sub get_twitter {
    my @tokens = @_;
    my %args = (
        traits          => [qw/OAuth API::REST/],
        consumer_key    => CONS_KEY,
        consumer_secret => CONS_SEC,
    );
    if (@tokens == 2) {
        @args{qw/access_token access_token_secret/} = @tokens;
    }

    return Net::Twitter->new(%args);
}

=head2 function2

=cut
    
sub restore_statuses_for {
    my $user = shift;
    my $user_rec = get_user_record($user);
    my @statuses = $user_rec->search_related('tweets')->all;
    return @statuses;
}

sub get_since_id_for {
    my $user = shift;
    my $user_rec = get_user_record($user);
    my ($most_recent_tweet) = $user_rec->search_related('tweets',
        {   
            undef,
            {order_by => { -desc => 'tweet_id' }},
        }
    );
    if ($most_recent_tweet) {
        return $most_recent_tweet->id;
    } else {
        return 0;
    }
}


sub retrieve_statuses {
    my ( $user, @tokens ) = @_;
    my %no_of_st;

    if (@tokens) {
        my $twitter = get_twitter(@tokens);

        my $since = get_since_for($user);

        if ( $twitter->authorized ) {

            for ( my $page = 1 ; ; ++$page ) {
                debug("Getting page $page of twitter statuses");
                my $args = { count => 100, page => $page };
                $args->{since_id} = $since if $since;
                my $statuses = $twitter->user_timeline($args);
                last unless @$statuses;
                store_twitter_statuses(@stats);
            }
        } else {
            die "Not authorised.";
        }
    } 
    return restore_statuses_for($user);
}

sub store_twitter_statuses {
    my @statuses = @_;
    my $db = get_db;
    for (@statuses) {
        my $tweet_rec = get_tweet_record($_->{id}, $_->{screen_name});
        my ($text, $retweeted, $retweeted_no, $favorited, $favorited_no) 
            = @{$_}{qw/text retweeted retweeted_count 
                favorited favorited_count/};
        }
        $tweet_rec->text($text);
        $tweet_rec->retweeted($retweeted);
        $tweet_rec->retweeted_count($retweeted_no);
        $tweet_rec->favorited($favorited);
        $tweet_rec->favorited_count($favorited_no);

        my $dt = $datetime_parser->parse_datetime($_->{created_at});
        $tweet_rec->created_at($dt);

        my @mentions = $text =~ /$mentions_re/g;
        for my $mention (@mentions) {
            my $mention_rec = $db->resultset('Mention')->find_or_create({
                screen_name => $mention
            });
            $mention_rec->add_to_tweets($tweet_rec);
            $tweet_rec->add_to_mentions($mention_rec);
            $mention_rec->update;
        }
        my @hashtags = $text =~ /$hashtags_re/g;
        for my $hashtag (@hashtags) {
            my $hashtag_rec = $db->resultset('Hashtag')->find_or_create({
                topic => $hashtag
            });
            $hashtag_rec->add_to_tweets($tweet_rec);
            $tweet_rec->add_to_hashtags($hashtag_rec);
            $hashtag_rec->update;
        }
        my @urls = $tweet_text =~ /$urls_re/g;
        for my $url (@urls) {
            my $url_rec = $db->resultset('Url')->find_or_create({
                address => $url
            });
            $url_rec->add_to_tweets($tweet_rec);
            $tweet_rec->add_to_urls($url_rec);
            $url_rec->update;
        }
        $tweet_rec->update;
    }
}

sub restore_tokens {
    my $user = shift;
    my $user_rec = get_user_record($user);

    my @tokens = (
        $user_rec->access_token,
        $user_rec->access_token_secret,
    );

    return unless (@tokens == 2);
    return @tokens;
}

sub get_user_record {
    my $user = shift;
    my $db = get_db();
    my $user_rec = $db->resultset('User')->find_or_create(
        {
            screen_name => $user,
        },
    );
    return $user_rec;
}

sub get_tweet_record {
    my ($id, $screen_name) = @_;
    my $db = get_db();
    my $user_rec = get_user_record($screen_name);
    my $tweet_rec = $user_rec->tweets->find(
        {'tweet_id' = > $id,}
    );
    unless ($tweet_rec) {
        $tweet_rec = $user_rec->add_to_tweets({
                tweet_id => $id,
        });
    }
    return $tweet_rec;
}

    

sub save_tokens {
    my ( $user, $token, $secret ) = @_;
    my $user_rec = get_user_record($user);

    $user_rec->update({
            access_token => $token,
            access_token_secret => $secret,
    });
}



=head1 AUTHOR

Alex Kalderimis, C<< <alex at gmail dot com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-twitter-scraper at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-Twitter-Scraper>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::Twitter::Scraper


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-Twitter-Scraper>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-Twitter-Scraper>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-Twitter-Scraper>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-Twitter-Scraper/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Alex Kalderimis.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of Net::Twitter::Scraper
