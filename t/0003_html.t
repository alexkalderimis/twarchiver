use strict;
use warnings;
use Test::More;
use Test::Exception;

require Dancer;
use lib 'lib';
use lib 't/lib';

use Twarchiver::DBActions ':all';

BEGIN {
    use_ok('Twarchiver::HTMLActions' => ':all')
        or BAIL_OUT("Could not use module");
}

my $test_data = do 't/etc/test_data';
if (my $err = $@) {
    BAIL_OUT("Error parsing test data: $err");
}
if (ref $test_data ne 'ARRAY' || @$test_data != 10) {
    diag explain $test_data;
    BAIL_OUT("Could not load test data") 
}
## Set up test database
Dancer::set(database => ':memory:');
store_twitter_statuses(@$test_data);

## Test get_mention_url 
{
    my $mention = '@somebody';
    my $expected_url = 'http://twitter.com/somebody';

    is get_mention_url($mention), $expected_url
        => "Can make an external mention url";
}

## Test get_hashtag_url
{
    my $hashtag = '#something';
    my $expected_url = 'http://twitter.com?q=something';

    is get_hashtag_url($hashtag), $expected_url
        => "Can make an external hashtag url";
}

## Test linkify text

my $text = 'This is text with a hashtag: #here-is-a-topic, a mention: @somebody, and a url: http://some.url';
{
    my $expected_text =  'This is text with a hashtag: #here-is-a-topic, a mention: @somebody, and a url: <a href="http://some.url">http://some.url</a>';
    is linkify_text('urls', $text), $expected_text
        => "Can linkify urls";

}
{
    my $expected_text = 'This is text with a hashtag: #here-is-a-topic, a mention: <a href="http://twitter.com/somebody">@somebody</a>, and a url: http://some.url';
    is linkify_text('mentions', $text), $expected_text
        => "Can linkify mentions";
}
{
    my $expected_text = 'This is text with a hashtag: <a href="http://twitter.com?q=here-is-a-topic">#here-is-a-topic</a>, a mention: @somebody, and a url: http://some.url';
    is linkify_text('hashtags', $text), $expected_text
        => "Can linkify hashtags";
}
{
    my $multiple_text = 'This is #text with many @hashtags, http://mention.coms, and #urls, @including multiple @hashtags and http://mention.coms and #text';
    my $text_with_urllinks = 'This is #text with many @hashtags, http://mention.coms, and #urls, @including multiple @hashtags and http://mention.coms and #text';
    is linkify_text('urls', $multiple_text), $text_with_urllinks
        => 'Can put in url links in complex text';
    my $text_with_mentionlinks = 'This is #text with many @hashtags, http://mention.coms, and #urls, @including multiple @hashtags and http://mention.coms and #text';
    is linkify_text('urls', $multiple_text), $text_with_mentionlinks
        => 'Can put in url links in complex text';
    my $text_with_hashtaglinks = 'This is #text with many @hashtags, http://mention.coms, and #urls, @including multiple @hashtags and http://mention.coms and #text';
    is linkify_text('urls', $multiple_text), $text_with_hashtaglinks
        => 'Can put in url links in complex text';
    my $transformed_text = linkify_text('urls', $multiple_text);
    $transformed_text = linkify_text('mentions', $transformed_text);
    $transformed_text = linkify_text('hashtags', $transformed_text);
    my $expected_text = 'foo';
    is $transformed_text, $expected_text, "Can apply all links to one text";
}


