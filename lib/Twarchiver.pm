package Twarchiver;

our $VERSION = 0.1;

use Twarchiver::Routes::Home;
use Twarchiver::Routes::Login;
use Twarchiver::Routes::TweetAnalysis;
use Twarchiver::Routes::Graph;

1;

=pod

=head1 TITLE

Twarchiver - A twitter archive web-app

=head1 SYNOPSIS

    use Dancer;

    load_app 'Twarchiver';

    dance;

=head1 DESCRIPTION

This webapp is based around archiving and presenting tweets to their author in a number
of different analyses:

=over

=item All tweets (/show/USER)

=item Tweets by Mention (/show/USER/to/SOMEONE)

=item Tweets by Hashtag (/show/USER/on/SOMETHING)

=item Tweets by Arbitrary User Defined Tag (/show/USER/tag/SOME-TAG)

Tags can be added and deleted in the application interface.

=item Tweets by Month (/show/USER/year/month)

=item Tweets by arbitrary time period (/show/USER/from/UNIX_EPOCH?days=NUM

=item Tweets by link (/show/USER/url?address=URL)

=item A graph of the timeline (/graph/USER/tweets)

Tweets can be exported in JSON, XML, .txt, .csv, and .tsv formats

