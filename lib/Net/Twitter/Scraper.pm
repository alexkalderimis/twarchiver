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

use constant CONS_KEY      => 'duo83UgzZ99BRPpf56pUnA';
use constant CONS_SEC      => '6Si7yg4S1USpVFFYpL6N8Bc3MftddMXEQYefbn9U3w';
use constant STORAGE_PATHS => ( dirname($0), 'data', 'auth-tokens' );
use constant STATUS_STORAGE => (dirname($0), 'data', 'statuses');

use Exporter 'import';
our @EXPORT = qw/get_twitter restore_tokens save_tokens store_statuses restore_statuses_for/;

my %cookies;

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
    my $status_file = catfile(STATUS_STORAGE, $user);
    if (-f $status_file) {
        if (open(my $in, '<', $status_file)) {
            my $content = join('', <$in>);
            close($in) or die("Couldn't close $status_file, $!");
            my $VAR1;
            eval($content);
            my $stats = $VAR1;
            if (ref $stats ne 'ARRAY') {
                my $type = ref $stats;
                die("Wrong content - got $type\n$content");
            }
            return @$stats;
        } else {
            unlink $status_file;
        }
    }
    return;
}

sub restore_tokens {
    my $user = shift;
    my $key_file = catfile( STORAGE_PATHS, $user );
    if ( -f $key_file ) {
        if ( open( my $in, '<', $key_file ) ) {
            my %keys;
            for (<$in>) {
                chomp;
                my ( $k, $v ) = split(/\t/);
                $keys{$k} = $v;
            }
            close($in) or die "Couldn't close $key_file, $!";
            return @keys{qw/access_token access_token_secret/};
        } else {
            print "Couldn't open key file - deleting\n";
            unlink $key_file;
        }
    }
    return;
}

sub print_tokens {
    my ( $glob, $token, $secret ) = @_;
    printf( $glob "%s\t%s\n%s\t%s",
        'access_token', $token, 'access_token_secret', $secret );
    close($glob) or die("Couldn't close key file, $!");
    return;
}

sub print_statuses {
    my ( $glob, $stats ) = @_;
    print $glob Dumper($stats);
    close($glob) or die("Couldn't close status file, $!");
    return;
}

sub save_tokens {
    my ( $user, $token, $secret ) = @_;
    my $key_file = catfile( STORAGE_PATHS, $user );
    if ( -f $key_file ) {
        if ( open( my $out, '>', $key_file ) ) {
            return print_tokens( $out, $token, $secret );
        } else {
            unlink $key_file;
            return save_tokens( $user, $token, $secret );
        }
    } else {
        my $base_dir = catfile(STORAGE_PATHS);
        unless ( -d $base_dir ) {
            make_path($base_dir);
        }
        open( my $out, '>', $key_file )
          or die("Couldn't write to $key_file, $!");
        return print_tokens( $out, $token, $secret );
    }
}

sub store_statuses {
    my ($user, $stats) = @_;
    my $status_file = catfile(STATUS_STORAGE, $user);
    if (-f $status_file) {
        if ( open( my $out, '>', $status_file ) ) {
            return print_statuses( $out, $stats );
        } else {
            unlink $status_file;
            return store_statuses( $user, $stats );
        }
    } else {
        my $base_dir = catfile(STATUS_STORAGE);
        unless ( -d $base_dir ) {
            make_path($base_dir);
        }
        open( my $out, '>', $status_file )
          or die("Couldn't write to $status_file, $!");
        return print_statuses( $out, $stats );
    }
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
