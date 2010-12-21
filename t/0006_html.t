use warnings;
use Test::Most 'bail';
use Test::Exception;
use Test::MockObject;
use Carp qw/confess/;

use lib 'lib';
use lib 't/lib';

use Test::Object (
    allow_setting => 1,
    confess_non_existant_fields => 0
);
use Twarchiver::Functions::DBAccess ':all';

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
    use_ok('Twarchiver::Functions::PageContent' => ':all')
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
            '<a href="show/UserOne/2010-1">January (3 tweets)</a>';
    is make_month_link('UserOne', 2010, 1), $expected
        => "Can make a month link - 3 results";
    $expected = "\n" . 
            '<a href="show/UserTwo/2010-1">January (0 tweets)</a>';
    is make_month_link('UserTwo', 2010, 1), $expected
        => "Can make a month link - 0 results";
    $expected = "\n" . 
            '<a href="show/UserOne/2009-12">December (2 tweets)</a>';
    is make_month_link('UserOne', 2009, 12), $expected
        => "Can make a month link - 2 results";
    $expected = "\n" . 
            '<a href="show/UserOne/1066-8">August (0 tweets)</a>';
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

    my $mock_tag = Test::Object->new(tag_text => 'tagtext');
    is make_tag_sidebar_item($mock_tag), $expected
        => "Can make a tag sidebar item";
    throws_ok(
        sub {make_tag_sidebar_item('Foo')},
        qr/Problem making tag sidebar item.*Foo/,
        "Catches problems, and confesses"
    );
};

subtest 'Test make_hashtag_link' => sub {
    my $expected = "\n" . '<a href="http://twitter.com/search?q=topic">topic</a>';

    is make_hashtag_link('topic'), $expected
        => "Can make a simple hashtag external link";
    is make_hashtag_link('top<span class="highlightingspan">ic</span>'), 
        $expected => "Can make a hashtag external link from a dirty topic";
    throws_ok(
        sub {make_hashtag_link(undef)},
        qr/No topic/,
        "Catches lack of topic"
    );

};

subtest 'Test make_hashtag_report_link' => sub {
    my $expected = "\n" . '<a href="show/FAKE_USER/on/THIS_TOPIC" class="sidebarinternallink">(1 hashtags)</a>';

    is make_hashtag_report_link('#THIS_TOPIC', 1), $expected
        => "Can make a simple hashtag report link";
    $expected = "\n" . '<a href="show/FAKE_USER/on/THIS%20TOPIC" class="sidebarinternallink">(42 hashtags)</a>';
    is make_hashtag_report_link('#THIS TOPIC', 42), $expected
        => "Can make a hashtag report link with funky characters";
    throws_ok(
        sub {make_hashtag_report_link(undef, 42)},
        qr/No topic/,
        "Catches lack of topic"
    );
    throws_ok(
        sub {make_hashtag_report_link('topic', 0)},
        qr/No count/,
        "Catches lack of count"
    );
    throws_ok(
        sub {make_hashtag_report_link('topic', 42)},
        qr/Topic is not a hashtag: got topic/,
        "Catches unhashed topics",
    );
};

subtest 'Test make_hashtag_sidebar_item' => sub {
    my $expected = "\n" .
        '<a href="http://twitter.com/search?q=%23topic">#topic</a> ' . "\n" 
        . '<a href="show/FAKE_USER/on/topic" class="sidebarinternallink">(count hashtags)</a>';
    my $mock_tag = Test::Object->new(topic => "#topic");
    is make_hashtag_sidebar_item($mock_tag), $expected
        => "Can make a hashtag sidebar item";

    throws_ok(
        sub {make_hashtag_sidebar_item('Foo')},
        qr/Problem making hashtag sidebar item.*Foo/,
        "Catches problems and confesses errors"
    );
};

subtest 'Test make_mention_link' => sub {
    my $expected = "\n" . 
        '<a href="http://twitter.com/mention">@mention</a>';
        
    is make_mention_link('@mention'), $expected
        => "Can make a simple mention link";
    
    is make_mention_link('@men<span class="someclass">ti</span>on'), 
        $expected => "Can make a dirty mention link";

    throws_ok(
        sub {make_mention_link('')},
        qr/No mention/,
        "Catches lack of mention"
    );

};

subtest 'Test make_mention_report_link' => sub {
    my $expected = "\n" . 
        '<a href="show/FAKE_USER/to/mentioned_name" class="sidebarinternallink">(7 mentions)</a>';

    is make_mention_report_link('@mentioned_name', 7), $expected
        => "Can a simple mention report link";

    throws_ok(
        sub {make_mention_report_link('', 7)},
        qr/No mention/,
        "Catches lack of mention"
    );
    throws_ok(
        sub {make_mention_report_link('Foo', 0)},
        qr/No count/,
        "Catches zero count"
    );
    throws_ok(
        sub {make_mention_report_link('Foo', undef)},
        qr/No count/,
        "Catches undef count"
    );
};

subtest 'Test make_mention_sidebar_item' => sub {
    my $expected = "\n" . 
      '<a href="http://twitter.com/mentioned_name">@mentioned_name</a> ' 
      . "\n" 
      . '<a href="show/FAKE_USER/to/mentioned_name" class="sidebarinternallink">(count mentions)</a>';

    my $mock_mention = Test::Object->new(mention_name => '@mentioned_name');

    is make_mention_sidebar_item($mock_mention), $expected
        => "Can make a mention sidebar item";

    throws_ok(
        sub {make_mention_sidebar_item('Foo')},
        qr/Problem making mention sidebar item.*Foo/,
        "Catches problems and confesses errors"
    );
};

subtest 'Test make_tagger_form_body' => sub {
    my $tweet = get_tweet_record('UserOne', 987654321);

    my $expected = <<'EXP';

<p>Tag:
<input type="text" id="tag-987654321" />
<input type="button" value="Add" onclick="javascript:addTags('UserOne', '987654321');" />
<input type="button" value="Remove" onclick="javascript:removeTags('UserOne', '987654321');" />
<input type="text" name="dummy" style="display: none" /></p>
EXP
    chomp $expected;

    is make_tagger_form_body($tweet), $expected
        => "Can make the body of a tagger form";
};

subtest 'Test make_tweet_tagger_form' => sub {
    my $tweet = get_tweet_record('UserOne', 987654321);

    my $expected = <<'EXP';

<form method="post" style="display: none;" class="tag-form" id="987654321">
<p>Tag:
<input type="text" id="tag-987654321" />
<input type="button" value="Add" onclick="javascript:addTags('UserOne', '987654321');" />
<input type="button" value="Remove" onclick="javascript:removeTags('UserOne', '987654321');" />
<input type="text" name="dummy" style="display: none" /></p>
</form>
EXP
    chomp $expected;

    is make_tweet_tagger_form($tweet), $expected
        => "Can make the a tagger form";
};

subtest 'Test make_tags_list' => sub {
    my $tweet = get_tweet_record('UserOne', 987654321);

    $tweet->add_to_tags({
            tag_text => "An added example tag",
        });
    $tweet->add_to_tags({
            tag_text => "Eine zugefügte Bemerkung"
        });

    my $expected = <<'EXP';

<li>
<span onclick="toggleElem('987654321-An added example tag')">An added example tag</span>   
<a href="#" style="display: none" id="987654321-An added example tag" onclick="removeTag('UserOne', '987654321', 'An added example tag')">delete</a></li>
<li>
<span onclick="toggleElem('987654321-Eine zugefügte Bemerkung')">Eine zugefügte Bemerkung</span>   
<a href="#" style="display: none" id="987654321-Eine zugefügte Bemerkung" onclick="removeTag('UserOne', '987654321', 'Eine zugefügte Bemerkung')">delete</a></li>
EXP
    chomp $expected;

    is make_tags_list($tweet), $expected
        => "Can make a tweet tag list";

    my $tweet_without_tags = get_tweet_record('UserOne', 987654320);

    $expected = '';

    is make_tags_list($tweet_without_tags), $expected
        => "Can make a tweet tag list when there are no tags";

};

subtest 'Test make_tag_list_box' => sub {
    my $tweet = get_tweet_record('UserOne', 987654321);

    my $expected = <<'EXP';

<div class="tags-list" id="987654321-tags">
<ul class="tags-ul" id="tagList-987654321">
<li>
<span onclick="toggleElem('987654321-An added example tag')">An added example tag</span>   
<a href="#" style="display: none" id="987654321-An added example tag" onclick="removeTag('UserOne', '987654321', 'An added example tag')">delete</a></li>
<li>
<span onclick="toggleElem('987654321-Eine zugefügte Bemerkung')">Eine zugefügte Bemerkung</span>   
<a href="#" style="display: none" id="987654321-Eine zugefügte Bemerkung" onclick="removeTag('UserOne', '987654321', 'Eine zugefügte Bemerkung')">delete</a></li></ul>
</div>
EXP
    chomp $expected;

    is make_tag_list_box($tweet), $expected
        => "Can make a tweet tag list box";

    $expected = <<'EXP';

<div class="tags-list" id="987654320-tags">
<ul class="tags-ul" id="tagList-987654320"></ul>
</div>
EXP
    chomp $expected;

    my $tweet_without_tags = get_tweet_record('UserOne', 987654320);

    is make_tag_list_box($tweet_without_tags), $expected
        => "Can make a tweet tag list box without tags";
};

subtest 'Test make_tweet_display_box' => sub {
    my $tweet = get_tweet_record('UserOne', 987654321);

    my $expected = <<'EXP';

<div onclick="toggleForm('987654321');">
<h2>01 Feb 2010 12:00:00 AM</h2>
<p>This is the first 
<a href="http://twitter.com/search?q=%23example">#example</a> tweet from the test data set for 
<a href="http://twitter.com/twarchiver">@twarchiver</a></p>
</div>
<div class="tags-list" id="987654321-tags">
<ul class="tags-ul" id="tagList-987654321">
<li>
<span onclick="toggleElem('987654321-An added example tag')">An added example tag</span>   
<a href="#" style="display: none" id="987654321-An added example tag" onclick="removeTag('UserOne', '987654321', 'An added example tag')">delete</a></li>
<li>
<span onclick="toggleElem('987654321-Eine zugefügte Bemerkung')">Eine zugefügte Bemerkung</span>   
<a href="#" style="display: none" id="987654321-Eine zugefügte Bemerkung" onclick="removeTag('UserOne', '987654321', 'Eine zugefügte Bemerkung')">delete</a></li></ul>
</div>
EXP
    chomp $expected;

    is make_tweet_display_box($tweet), $expected
        => "Can make a tweet display box";

    my $tweet_without_tags = get_tweet_record('UserOne', 987654320);

    $expected = <<'EXP';

<div onclick="toggleForm('987654320');">
<h2>31 Jan 2010 11:59:59 PM</h2>
<p>This is the second 
<a href="http://twitter.com/search?q=%23example">#example</a> tweet from the test data set for 
<a href="http://twitter.com/twarchiver">@twarchiver</a>, it is about 
<a href="http://twitter.com/search?q=%23fish">#fish</a></p>
</div>
<div class="tags-list" id="987654320-tags">
<ul class="tags-ul" id="tagList-987654320"></ul>
</div>
EXP
    chomp $expected;

    is make_tweet_display_box($tweet_without_tags), $expected
        => "Can make a tweet display box without tags";

};

subtest 'Test make_tweet_li'  => sub {
    my $tweet = get_tweet_record('UserOne', 987654321);

    my $expected = <<'EXP';

<div onclick="toggleForm('987654321');">
<h2>01 Feb 2010 12:00:00 AM</h2>
<p>This is the first 
<a href="http://twitter.com/search?q=%23example">#example</a> tweet from the test data set for 
<a href="http://twitter.com/twarchiver">@twarchiver</a></p>
</div>
<div class="tags-list" id="987654321-tags">
<ul class="tags-ul" id="tagList-987654321">
<li>
<span onclick="toggleElem('987654321-An added example tag')">An added example tag</span>   
<a href="#" style="display: none" id="987654321-An added example tag" onclick="removeTag('UserOne', '987654321', 'An added example tag')">delete</a></li>
<li>
<span onclick="toggleElem('987654321-Eine zugefügte Bemerkung')">Eine zugefügte Bemerkung</span>   
<a href="#" style="display: none" id="987654321-Eine zugefügte Bemerkung" onclick="removeTag('UserOne', '987654321', 'Eine zugefügte Bemerkung')">delete</a></li></ul>
</div>
<form method="post" style="display: none;" class="tag-form" id="987654321">
<p>Tag:
<input type="text" id="tag-987654321" />
<input type="button" value="Add" onclick="javascript:addTags('UserOne', '987654321');" />
<input type="button" value="Remove" onclick="javascript:removeTags('UserOne', '987654321');" />
<input type="text" name="dummy" style="display: none" /></p>
</form>
EXP
    chomp $expected;

    is make_tweet_li($tweet), $expected
        => "Can make a tweet li inner html";

    my $tweet_without_tags = get_tweet_record('UserOne', 987654320);

    $expected = <<'EXP';

<div onclick="toggleForm('987654320');">
<h2>31 Jan 2010 11:59:59 PM</h2>
<p>This is the second 
<a href="http://twitter.com/search?q=%23example">#example</a> tweet from the test data set for 
<a href="http://twitter.com/twarchiver">@twarchiver</a>, it is about 
<a href="http://twitter.com/search?q=%23fish">#fish</a></p>
</div>
<div class="tags-list" id="987654320-tags">
<ul class="tags-ul" id="tagList-987654320"></ul>
</div>
<form method="post" style="display: none;" class="tag-form" id="987654320">
<p>Tag:
<input type="text" id="tag-987654320" />
<input type="button" value="Add" onclick="javascript:addTags('UserOne', '987654320');" />
<input type="button" value="Remove" onclick="javascript:removeTags('UserOne', '987654320');" />
<input type="text" name="dummy" style="display: none" /></p>
</form>
EXP
    chomp $expected;

    is make_tweet_li($tweet_without_tags), $expected
        => "Can make a tweet li inner html";

    is make_tweet_li(), ''
        => "Returns an empty string for no tweet";

    throws_ok(
        sub {make_tweet_li('Foo')},
        qr/Problem making tweet list item.*Foo/,
        "Catches errors and confesses"
    );
}; 

subtest 'Test make_content' => sub {

    my @tweets = ();

    my $expected = "\n" . '<p>No tweets found</p>';

    is make_content(@tweets), $expected
        => "Returns a sensible message when there are no tweets";

    @tweets = get_all_tweets_for('UserOne');
    
    $expected = qx{cat t/etc/tests_tweets.html};
    chomp $expected;

    is make_content(@tweets), $expected
        => "Can make content with a list of tweets";
};

subtest 'Test make_highlit_content' => sub {
    my @tweets = get_tweets_in_month('UserOne', 2010, 1);

    my $expected = qx{cat t/etc/tests_highlit_tweets.html};
    chomp $expected;

    is make_highlit_content('twe', @tweets), $expected
        => "Can highlight search terms in content";

    $expected = qx{cat t/etc/tests_highlit_mentions.html};
    chomp $expected;

    is make_highlit_content('arch', @tweets), $expected
        => "Can highlight search terms without breaking links in mentions";

    $expected = qx{cat t/etc/tests_highlit_hashtags.html};
    chomp $expected;

    is make_highlit_content('amp', @tweets), $expected
        => "Can highlight search terms without breaking links in hashtags";

    $expected = qx{cat t/etc/tests_highlit_urls.html};
    chomp $expected;

    is make_highlit_content('ani', @tweets), $expected
        => "Can highlight search terms without breaking links in urls";

    $expected = qx{cat t/etc/tests_highlit_all.html};
    chomp $expected;

    is make_highlit_content('\w+e\w+', @tweets), $expected
        => "Can do it everywhere - and using regexen too";
};

done_testing();
