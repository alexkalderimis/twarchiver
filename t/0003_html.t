
use strict;
use warnings;
use Test::Most 'bail';
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
{
    local $SIG{__WARN__} = sub {
    }; # Silence warnings here because Data::Dumper in 
       # SQL::Translator doesn't like code refs
    get_db()->deploy({
        show_warnings => 0,
    });
}
store_twitter_statuses(@$test_data);

subtest 'Test get_mention_url' => sub {
    my $mention = 'aperson';
    my $expected_url = 'http://twitter.com/aperson';

    is get_mention_url($mention), $expected_url
        => "Can make an external mention url with bare name";
    
    $mention = '@somebody';
    $expected_url = 'http://twitter.com/somebody';

    is get_mention_url($mention), $expected_url
        => 'Can make an external mention url with an @ sign';

    $mention = undef;
    throws_ok( sub {get_mention_url($mention)}, qr/Mention is undefined/
        => 'Throws errors at undefined mentions');

};

subtest 'Test get_hashtag_url' => sub {
    my $hashtag = 'searchstring';
    my $expected_url = 'http://twitter.com/search?q=searchstring';

    is get_hashtag_url($hashtag), $expected_url
        => "Can make an external hashtag url";

    $hashtag = '#something';
    $expected_url = 'http://twitter.com/search?q=%23something';

    is get_hashtag_url($hashtag), $expected_url
        => "Can make an external hashtag url with funky characters";

    $hashtag = undef;
    throws_ok( sub {get_hashtag_url($hashtag)}, qr/Topic is undefined/
        => 'Throws errors at undefined hashtag');
};

subtest 'Test linkify text' => sub {

    my $text = 'This is text with a hashtag: #here-is-a-topic, a mention: @somebody, and a url: http://some.url';
    {
        my $expected_text =  'This is text with a hashtag: #here-is-a-topic, a mention: @somebody, and a url: ' . "\n" . '<a href="http://some.url">http://some.url</a>';
        is linkify_text('urls', $text), $expected_text
            => "Can linkify urls";

    }
    {
        my $expected_text = 'This is text with a hashtag: #here-is-a-topic, a mention: ' . "\n" . '<a href="http://twitter.com/somebody">@somebody</a>, and a url: http://some.url';
        is linkify_text('mentions', $text), $expected_text
            => "Can linkify mentions";
    }
    {
        my $expected_text = 'This is text with a hashtag: ' . "\n" . '<a href="http://twitter.com/search?q=%23here-is-a-topic">#here-is-a-topic</a>, a mention: @somebody, and a url: http://some.url';
        is linkify_text('hashtags', $text), $expected_text
            => "Can linkify hashtags";
    }
    {
        my $multiple_text = 'This is #text with many @hashtags, http://mention.coms, and #urls, @including multiple @hashtags and http://mention.coms and #text';
        my $text_with_urllinks = 'This is #text with many @hashtags, ' . "\n" . '<a href="http://mention.coms">http://mention.coms</a>, and #urls, @including multiple @hashtags and ' . "\n" . '<a href="http://mention.coms">http://mention.coms</a> and #text';
        is linkify_text('urls', $multiple_text), $text_with_urllinks
            => 'Can put in url links in complex text';
        my $text_with_mentionlinks = 'This is #text with many ' . "\n" . '<a href="http://twitter.com/hashtags">@hashtags</a>, http://mention.coms, and #urls, ' .  "\n" . '<a href="http://twitter.com/including">@including</a> multiple ' . "\n" . '<a href="http://twitter.com/hashtags">@hashtags</a> and http://mention.coms and #text';

        is linkify_text('mentions', $multiple_text), $text_with_mentionlinks
            => 'Can put in mention links in complex text';
        my $text_with_hashtaglinks = 'This is ' . "\n" . '<a href="http://twitter.com/search?q=%23text">#text</a> with many @hashtags, http://mention.coms, and '. "\n" . '<a href="http://twitter.com/search?q=%23urls">#urls</a>, @including multiple @hashtags and http://mention.coms and ' . "\n" . '<a href="http://twitter.com/search?q=%23text">#text</a>';
        
        is linkify_text('hashtags', $multiple_text), $text_with_hashtaglinks
            => 'Can put in hashtags links in complex text';
        my $transformed_text = linkify_text('urls', $multiple_text);
        $transformed_text = linkify_text('mentions', $transformed_text);
        $transformed_text = linkify_text('hashtags', $transformed_text);
        my $expected_text = 'This is 
<a href="http://twitter.com/search?q=%23text">#text</a> with many 
<a href="http://twitter.com/hashtags">@hashtags</a>, 
<a href="http://mention.coms">http://mention.coms</a>, and 
<a href="http://twitter.com/search?q=%23urls">#urls</a>, 
<a href="http://twitter.com/including">@including</a> multiple 
<a href="http://twitter.com/hashtags">@hashtags</a> and 
<a href="http://mention.coms">http://mention.coms</a> and 
<a href="http://twitter.com/search?q=%23text">#text</a>';

        is $transformed_text, $expected_text, "Can apply all links to one text";
    }
};

subtest 'Test get_month_name_for' => sub {
    my @month_names = (qw/
        January February March April May June July
        August September October November December
    /);
    for (0 .. $#month_names) {
        is get_month_name_for($_ + 1), $month_names[$_]
            => "Can get month name for month " . ($_ + 1);
    }
    for ('', undef, 0) {
        throws_ok(sub {get_month_name_for($_)}, qr/No month number/
            => "Catches no month number");
    }
    for (-1, 13, 1_000_000, 'not a number') {
        throws_ok(sub {get_month_name_for($_)}, qr/expected a number/
            => "Catches number of of bounds: $_"
        );
    }
};
