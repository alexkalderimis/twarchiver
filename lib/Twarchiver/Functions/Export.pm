package Twarchiver::Functions::Export;
use Dancer ':syntax';

use feature ':5.10';

our $VERSION = '0.1';

use Text::CSV;
use Carp qw/confess/;
use Encode;

use Twarchiver::Functions::Util 'DATE_FORMAT';

use constant {
    CONS_KEY       => 'duo83UgzZ99BRPpf56pUnA',
    CONS_SEC       => '6Si7yg4S1USpVFFYpL6N8Bc3MftddMXEQYefbn9U3w',
};

use Exporter 'import';

our @EXPORT_OK = qw/
    get_tweets_as_textfile 
    get_tweets_as_spreadsheet 
    tweet_to_text
    export_tweets_in_format
  /;

our %EXPORT_TAGS = (
    'all' => [qw/
        get_tweets_as_textfile 
        get_tweets_as_spreadsheet 
        tweet_to_text
        export_tweets_in_format
    /]
);

=head2 get_tweets_in_format ( format, @tweets )

Function: Transform a list of tweets into a given format
Returns:  A text string

=cut

sub export_tweets_in_format {
    my ($format, @tweets) = @_;

    if ( $format eq 'txt' ) {
        get_tweets_as_textfile(@tweets);
    } elsif ( $format eq 'tsv' ) {
        get_tweets_as_spreadsheet( "\t", @tweets );
    } elsif ( $format eq 'csv' ) {
        get_tweets_as_spreadsheet( ',', @tweets );
    } else {
        send_error "Unknown format requested: $format";
    }
}

=head2 get_tweets_as_textfile( @tweets )

Function: Transform a list of tweets into a text string for downloading
Returns:  A text string

=cut

sub get_tweets_as_textfile {
    my @tweets = @_;

    content_type 'text/plain';

    return join( "\n\n", map { tweet_to_text($_) } @tweets );
}

=head2 get_tweets_as_spreadsheet( separator, tweets )

Function: Transform a list of tweets into csv, or tsv file format
Returns:  A text string

=cut

sub get_tweets_as_spreadsheet {
    my ( $separator, @tweets ) = @_;

    content_type "text/tab-separated-values";

    my $csv = Text::CSV->new(
        {
            sep_char     => $separator,
            binary       => 1,
            always_quote => 1,
        }
    );
    return join(
        "\n",
        map {
            $csv->combine(
                $_->tweeted_at->strftime(DATE_FORMAT), 
                $_->text,
                $_->retweeted_count,
                join(':', $_->tags->get_column('tag_text')->all),
            );
            $csv->string()
          } @tweets
    );
}

=head2 tweet_to_text( tweet )

Function: Transform a tweet into a text string, with date, text and tags

=cut

sub tweet_to_text {
    my $tweet = shift;
    my $date  = $tweet->tweeted_at->strftime(DATE_FORMAT);
    my $text  = decode_utf8($tweet->text);
    my @tags  = $tweet->tags->get_column('tag_text')->all;
    my $tags = decode_utf8(
      (@tags)
      ? 'Tags: ' . join( ', ', @tags )
      : '');
    my $result;
    eval {
        local $SIG{__WARN__};
        open( TEMP, '>', \$result );
        format TEMP = 
Time:   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        $date
^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ~~
$text
^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< 
$tags
      ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ~~
      $tags
.
        write TEMP;
    };
    if ( my $e = $@ ) {
        error( "Problem with " . $tweet->text . $e );
    }
    return decode_utf8($result);
}

true;
