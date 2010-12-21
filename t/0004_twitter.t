use warnings;
use Test::Most tests => 6;
use Test::Exception;
use Test::MockObject;
use Carp qw/confess/;

use lib 'lib';
use lib 't/lib';

use Twarchiver::Functions::DBAccess qw/
    get_db restore_tokens store_twitter_statuses
    /;

use Test::Object (
    allow_setting => 1,
    confess_non_existant_fields => 0
);
my @test_user_data = (
    Test::Object->new(
        id => 123,
        screen_name => "USER_FROM_TEST_DATA",
    )
);
my $params = {username => 'FAKE_USER'};
my $authdata = {};
my $cookie = Test::Object->new(
    value => 'COOKIE_REQ_TOK___COOKIE_SECRET'
);
my %extra_twitter_attr = ();
BEGIN {
    my $mock = Test::MockObject->new();
    $mock->fake_module('Net::Twitter',
        new => sub { 
            shift; 
            my $ret = Test::Object->new(@_, 
                %extra_twitter_attr);
            die 'Foo' if ($ret->access_token eq 'Foo');
            return $ret; 
        },
    );
}
BEGIN {
    require Dancer;
    my $mock = Test::MockObject->new();
    my $mock_request = Test::MockObject->new();
    $mock_request->mock(uri_for => sub {return $_[1]});
    $mock_request->mock(path => sub {return 'TEST_PATH'});
    $mock->fake_module('Dancer',
        settings => sub {return ':memory:'},
        params   => sub {return $params},
        request  => sub {return $mock_request},
        set_cookie => sub {$authdata->{$_[0]} = $_[1]},
        redirect => sub {$authdata->{redirect} = shift;},
        send_error => sub {confess @_},
        cookies => sub {return {tok_sec => $cookie,}},
    );
}

BEGIN {
    use_ok('Twarchiver::Functions::TwitterAPI' => ':all');
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
{
    local $SIG{__WARN__} = sub {
    }; # Silence warnings here because Data::Dumper in 
       # SQL::Translator doesn't like code refs
    get_db()->deploy({
        show_warnings => 0,
    });
}
store_twitter_statuses(@$test_data);

subtest 'Test get_twitter' => sub {
    my $expected = {
        traits => [qw/OAuth API::REST InflateObjects/],
        consumer_key => Twarchiver::Functions::TwitterAPI->CONS_KEY,
        consumer_secret => Twarchiver::Functions::TwitterAPI->CONS_SEC,
    };

    is_deeply get_twitter, $expected
        => "Passes the right default arguments to the twitter constructor"
            or diag explain get_twitter;

    $expected->{access_token} = 'FAKE_TOKEN';
    $expected->{access_token_secret} = 'FAKE_SECRET';

    is_deeply get_twitter('FAKE_TOKEN', 'FAKE_SECRET') , $expected
        => "Passes the right token arguments to the twitter constructor";

    throws_ok(
        sub {get_twitter('Foo', 'FAKE_SECRET')},
        qr/Problem making twitter connection.*Foo/,
        "Catches errors and confesses"
    );
};

subtest 'Test authorise' => sub {
   my $expected = {
       tok_sec => 'TEST_REQ_TOKEN___REQ_TOK_SECRET',
       redirect => 'callback',
   };
   %extra_twitter_attr = (
        request_token => 'TEST_REQ_TOKEN',
        request_token_secret => 'REQ_TOK_SECRET',
    );

   ok ! authorise, "Authorise returns false";
   is_deeply($authdata, $expected, 
       "But it does the right things behind the scenes")
        or diag explain $authdata;
};

subtest 'Test request_tokens_for' => sub {
    %extra_twitter_attr = (
        request_access_token => sub {
            my $self = shift;
            return (
                $self->request_token,
                $self->request_token_secret, 
                '', 'FAKE_USER'
            );
        },
    );

    ok request_tokens_for('FAKE_USER', '12345')
        => "Returns true on success";

    is_deeply(
        [restore_tokens('FAKE_USER')],
        ['COOKIE_REQ_TOK', 'COOKIE_SECRET'],
        "Tokens are stored in the db correctly"
    );

    throws_ok(
        sub {request_tokens_for('FAKE_USER')},
        qr/No verifier/,
        "Catches lack of verifier"
    );

    throws_ok(
        sub {request_tokens_for()},
        qr/No user/,
        "Catches lack of user"
    );
    throws_ok(
        sub {request_tokens_for('DIFFERENT_USER', 12345)},
        qr/names don't match/,
        "Catches non-matching twitter names"
    );
};

subtest 'Test has_been_authorised & needs_authorisation' => sub {
    %extra_twitter_attr = (
        request_access_token => sub {
            my $self = shift;
            return (
                $self->request_token,
                $self->request_token_secret, 
                '', 'UNAUTHORISED_USER'
            );
        },
    );
    ok has_been_authorised('FAKE_USER')
        => "Returns true for authorised user";
    ok ! needs_authorisation('FAKE_USER')
        => "The opposite for needs_authorisation";

    ok ! has_been_authorised('UNAUTHORISED_USER')
        => "Returns false for unauthorised user";
    ok needs_authorisation('UNAUTHORISED_USER')
        => "The opposite for needs_authorisation";

    $params->{oauth_verifier} = 12345;

    ok has_been_authorised('UNAUTHORISED_USER')
        => "Returns true when the user gets verified";
    ok ! needs_authorisation('UNAUTHORISED_USER')
        => "The opposite for needs_authorisation";

    %extra_twitter_attr = (
        request_access_token => sub {
            my $self = shift;
            return (
                $self->request_token,
                $self->request_token_secret, 
                '', 'UNAUTHORISED_USER'
            );
        },
    );

    throws_ok(
        sub {has_been_authorised('MISMATCHING_NAME')},
        qr/names don't match/,
        "Gets the errors from request_tokens_for"
    );
    throws_ok(
        sub {needs_authorisation('MISMATCHING_NAME')},
        qr/names don't match/,
        "The same for needs_authorisation"
    );

};
    
subtest 'Test download_latest_tweets_for' => sub {

    throws_ok(
        sub {download_latest_tweets_for('NeverAuthorised')},
        qr/Not authorised/,
        "Unauthorised users don't get tweets"
    );
    my $test_data;
    %extra_twitter_attr = (
        user_timeline => sub {
            shift;
            $test_data = shift;
            return [];
        },
        authorized => 1,
        lookup_users => sub {return [@test_user_data]},
    );
    lives_ok(
        sub {download_latest_tweets_for('NeverAuthorised')},
        "Lives downloading tweets for an authorised user"
    );
    my $expected = {count => 100, page => 1};
    is_deeply $test_data, $expected, "Passed the right args to twitter";

    lives_ok(
        sub {download_latest_tweets_for('UserOne')},
        "Lives downloading tweets for a user with existing tweets"
    );
    $expected = {count => 100, page => 1, since_id => 987654321};
    is_deeply $test_data, $expected, "Passed the right args to twitter";
};

done_testing();
