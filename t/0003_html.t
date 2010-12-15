use strict;
use warnings;
use Test::Most 'bail';
use Test::Exception;
use Test::MockObject;

use lib 'lib';
use lib 't/lib';

use Test::Object allow_setting => 1;
use Twarchiver::DBActions ':all';

my $params = {username => 'FAKE_USER'};

BEGIN {
    my $mock = Test::MockObject->new();
    my $mock_request = Test::MockObject->new();
    $mock_request->mock(uri_for => sub {return $_[1]});
    $mock->fake_module('Dancer',
        settings => sub {return ':memory:'},
        params   => sub {return $params},
        request  => sub {return $mock_request},
    );
}

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

subtest 'Test make_retweet_link' => sub {

    my $pt1 = "\n"
            . '<a href="show/FAKE_USER/retweeted?count=';
    my $pt2 = '">Retweeted ';
    my $pt3 = ' (';
    my $pt4 = ')</a>';

    is(
        make_retweet_link(3, 3),
        $pt1 . 3 . $pt2 . '3 times' . $pt3 . 3 . $pt4,
        => "Makes a retweet link"
    );

    is(
        make_retweet_link(5, 6),
        $pt1 . 5 . $pt2 . '5 times' . $pt3 . 6 . $pt4,
        "Puts the numbers in the right place"
    );

    is(
        make_retweet_link(1, 10),
        $pt1 . 1 . $pt2 . 'once' . $pt3 . 10 . $pt4,
        "Make a retweet link for retweeted once"
    );

    is(
        make_retweet_link(2, 11),
        $pt1 . 2 . $pt2 . 'twice' . $pt3 . 11 . $pt4,
        "Make a retweet link for retweeted twice"
    );

    throws_ok(
        sub {make_retweet_link('abc', 1)},
        qr/count.*not a number/,
        "Catches count is not a number",
    );
    throws_ok(
        sub {make_retweet_link(1, 'abc')},
        qr/tweets.*not a number/,
        "Catches occurs is not a number",
    );
};

subtest 'Test make_retweeted_sidebar' => sub {
    my $expected = <<'EXP';

<li>
<a href="show/FAKE_USER/retweeted">All Retweeted Statuses (8)</a></li>
<li>
<a href="show/FAKE_USER/retweeted?count=2">Retweeted twice (3)</a></li>
<li>
<a href="show/FAKE_USER/retweeted?count=1">Retweeted once (2)</a></li>
<li>
<a href="show/FAKE_USER/retweeted?count=4">Retweeted 4 times (2)</a></li>
<li>
<a href="show/FAKE_USER/retweeted?count=3">Retweeted 3 times (1)</a></li>
EXP
    chomp $expected;
    is make_retweeted_sidebar('UserOne'), $expected,
        => "Makes a retweeted sidebar";
    $expected = <<'EXP';

<li>
<a href="show/FAKE_USER/retweeted">All Retweeted Statuses (0)</a></li>
EXP
    chomp $expected;
    is make_retweeted_sidebar('NonExistingUser'), $expected
        => "Makes a retweeted sidebar without data";
};

subtest 'Test make_user_home_link' => sub {
    my $expected = "\n" . '<a href="show/FAKE_USER">FAKE_USER</a>';
    is make_user_home_link(), $expected
        => "Can get the user's home link";
    $expected = "\n" . '<a href="show/UserOne">UserOne</a>';
    is make_user_home_link("UserOne"), $expected
        => "... and with an explicitly specified user";
    my $username = delete $params->{username};
    throws_ok(sub {make_user_home_link}, qr/No username/
        => "... and catches missing username");
    $params->{username} = $username;
};

subtest 'Test make_month_link' => sub {
    my $expected = "\n" . 
            '<a href="show/UserOne/2010/1">January (3 tweets)</a>';
    is make_month_link('UserOne', 2010, 1), $expected
        => "Can make a month link - 3 results";
    $expected = "\n" . 
            '<a href="show/UserTwo/2010/1">January (0 tweets)</a>';
    is make_month_link('UserTwo', 2010, 1), $expected
        => "Can make a month link - 0 results";
    $expected = "\n" . 
            '<a href="show/UserOne/2009/12">December (2 tweets)</a>';
    is make_month_link('UserOne', 2009, 12), $expected
        => "Can make a month link - 2 results";
    $expected = "\n" . 
            '<a href="show/UserOne/1066/8">August (0 tweets)</a>';
    is make_month_link('UserOne', 1066, 8), $expected
        => "Can make a month link - even for unreasonable dates";
};

subtest 'Test make_url_report_link' => sub {
    my $expected = "\n" . '<a href="show/FAKE_USER/url?address=Foo" class="sidebarinternallink">(linked to 1 times)</a>';
    is make_url_report_link('Foo', 1), $expected
        => "Can make a simple url report link";
    $expected = "\n" . '<a href="show/FAKE_USER/url?address=http%3A%2F%2Fwww.a.url.com" class="sidebarinternallink">(linked to 42 times)</a>';
    is make_url_report_link('http://www.a.url.com', 42), $expected
        => "Can make a more complex report link";
    $expected = "\n" . '<a href="show/FAKE_USER/url?address=http%3A%2F%2Fwww.a.url.com%3Fq%3Dsome%2520query" class="sidebarinternallink">(linked to 42 times)</a>';
    is make_url_report_link('http://www.a.url.com?q=some%20query', 42), 
        $expected => "Can make a rather complex report link";
    throws_ok(
        sub {make_url_report_link('foo', undef)},
        qr/no count/,
        "Catches lack of count"
    );
    lives_ok(
        sub {make_url_report_link('foo', 0)},
        "but is ok with a count of 0"
    );
    throws_ok(
        sub {make_url_report_link('', 10)},
        qr/no address/,
        "Catches lack of address"
    );
    
};

subtest 'Test make_url_sidebar_item'  => sub {
    my $expected = "\n" . '<a href="http://a.url.com/path">http://a.url.com/path</a> ' . "\n" . '<a href="show/FAKE_USER/url?address=http%3A%2F%2Fa.url.com%2Fpath" class="sidebarinternallink">(linked to count times)</a>';
    my $mock_url_rec = Test::Object->new({
            address => 'http://a.url.com/path',
            get_column => 3,
        });
    is make_url_sidebar_item($mock_url_rec), $expected
        => "Can make a url sidebar item";
    throws_ok(
        sub {make_url_sidebar_item('Foo')},
        qr/Problem making url sidebar.*Foo/,
        "Catches problems and confesses errors"
    );
};

subtest 'Test make_tag_link' => sub {
    my $expected = "\n" . '<a href="show/user/tag/tagtext">tagtext (7)</a>';

    is make_tag_link('user', 'tagtext', 7), $expected
        => "Can make an internal tag link";

    throws_ok(
        sub {make_tag_link(undef, 'foo', 10)},
        qr/No username/,
        "Catches lack of username"
    );
    throws_ok(
        sub {make_tag_link('foo', '', 10)},
        qr/No tag/,
        "Catches lack of tag"
    );
    throws_ok(
        sub {make_tag_link('foo', 'bar', 0)},
        qr/No count/,
        "Catches lack of count - and thus a duff link"
    );
    
};

subtest 'Test make_tag_sidebar_item' => sub {

    my $expected = "\n" . '<a href="show/FAKE_USER/tag/tagtext">tagtext (count)</a>'; 

    my $mock_tag = Test::Object->new(text => 'tagtext');
    is make_tag_sidebar_item($mock_tag), $expected
        => "Can make a tag sidebar item";
    throws_ok(
        sub {make_tag_sidebar_item('Foo')},
        qr/Problem making tag sidebar item.*Foo/,
        "Catches problems, and confesses"
    );
};
