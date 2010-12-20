package Twarchiver::Routes::Graph;

use Dancer ':syntax';

use Twarchiver::Functions::DBAccess 'get_user_record';
use Twarchiver::Functions::TwitterAPI qw/authorise needs_authorisation/;
use Twarchiver::Functions::PageContent qw/make_user_home_link/;

my %title_for_interval = (
    1 => "Tweets by day",
    7 => "Tweets by Week",
    14 => "Tweets by Fortnight",
    month => "Tweets by Month",
    quarter => "Tweets by Quarter",
);
get '/graphdata/:username/tweets/by/week' => sub {
    my $interval = params->{interval} || 7;
    my $user = get_user_record(params->{username});
    my $creation = DateTime->from_epoch(epoch => $user->created_at->epoch);
    $creation->truncate( to => "month" );
    my %addition;
    if ($interval eq "month") {
        $addition{months} = 1;
        $creation->truncate( to => "month" );
    } elsif ($interval eq "quarter") {
        $addition{months} = 3;
        $creation->truncate( to => "month" );
        my $months_into_quarter = ($creation->month - 1) % 3;
        $creation->subtract( months => $months_into_quarter);
    } else {
        $addition{days} = $interval;
        if ($interval == 7 or $interval == 14) {
            $creation->truncate( to => "week" );
        } else {
            $creation->truncate( to => "day" );
        }
    }
    
    my $now = DateTime->now();
    my $start_of_frame = DateTime->from_epoch(epoch => $creation->epoch);
    my $end_of_frame = DateTime->from_epoch(epoch => $creation->epoch)
                            ->add(%addition);
    my @data_points;
    my $sum = 0;
    my @cumulatives = ([$creation->epoch * 1000, 0]);
    while ($start_of_frame < $now) {
        my $tweet_count = $user->tweets
                    ->search({created_at => {'>=', $start_of_frame->ymd}})
                    ->search({created_at => {'<', $end_of_frame->ymd}})
                    ->count;
        $sum += $tweet_count;
        my $time = $start_of_frame->epoch * 1000;
        my $data_point = [$time, $tweet_count];
        push @data_points, $data_point;
        $time = $end_of_frame->epoch * 1000;
        my $cumulation = [$time, $sum];
        push @cumulatives, $cumulation;
        $start_of_frame->add(%addition);
        $end_of_frame->add(%addition);
    }

    my @json = ();
    if (params->{cumulative}) {
        push @json, {
            label => "Cumulative total",
            hoverable => \1,
            lines => {show => \1},
            bars => {show => \0},
            data => \@cumulatives,
        };
    }
    push @json, {
            label => $title_for_interval{$interval},
            hoverable => \1,
            data => \@data_points,
        };
    return to_json(\@json);
};

get '/graph/:username/tweets/by/week' => sub {
    my $username = params->{username};

    return authorise($username) if needs_authorisation($username);

    my $profile_image = get_user_record($username)->profile_image_url
                        || '/images/squirrel_icon64.gif';
    template 'graph' => {
        username => $username,
        title => "Timeline for " . make_user_home_link($username),
        profile_image => $profile_image,
    };
};

true;
