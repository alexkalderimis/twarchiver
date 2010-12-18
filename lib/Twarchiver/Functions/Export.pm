package Twarchiver::Functions::Export;
use Dancer ':syntax';

use feature ':5.10';

our $VERSION = '0.1';

use Text::CSV;
use Carp qw/confess/;

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
  /;

our %EXPORT_TAGS = (
    'all' => [qw/
        get_tweets_as_textfile 
        get_tweets_as_spreadsheet 
        tweet_to_text
    /]
);

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
                $_->created_at->strftime(DATE_FORMAT), 
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
    my $created_at  = $tweet->created_at->strftime(DATE_FORMAT);
    my $text  = $tweet->text;
    my @tags  = $tweet->tags->get_column('tag_text')->all;
    my $tags =
      (@tags)
      ? 'Tags: ' . join( ', ', @tags )
      : '';
    my $result;
    eval {
        local $SIG{__WARN__};
        open( TEMP, '>', \$result );
        format TEMP = 
Time:   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        $created_at
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
    return $result;
}

true;
