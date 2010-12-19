package Twarchiver::Routes::Graph;

use Dancer ':syntax';

use Twarchiver::Functions::DBAccess 'get_user_record';
use Twarchiver::Functions::TwitterAPI qw/authorise needs_authorisation/;

my %title_for_interval = (
    1 => "Tweets by day",
    7 => "Tweets by Week",
    14 => "Tweets by Fortnight",
    month => "Tweets by Month",
    quarter => "Tweets by Quarter",
);
get '/graphdata/:username/tweets/by/week' => sub {
    my $interval = params->{interval} || 7;
    my %addition;
    if ($interval eq "month") {
        $addition{months} = 1;
    } elsif ($interval eq "quarter") {
        $addition{months} = 3;
    } else {
        $addition{days} = $interval;
    }
    my $user = get_user_record(params->{username});
    my $creation = DateTime->from_epoch(epoch => $user->created_at->epoch);
    $creation->truncate( to => "month" );
    
    my $now = DateTime->now();
    my $start_of_frame = DateTime->from_epoch(epoch => $creation->epoch);
    my $end_of_frame = DateTime->from_epoch(epoch => $creation->epoch)
                            ->add(%addition);
    my @data_points;
    my @cumulatives;
    my $sum = 0;
    while ($start_of_frame < $now) {
        my $tweet_count = $user->tweets
                    ->search({created_at => {'>=', $start_of_frame->ymd}})
                    ->search({created_at => {'<', $end_of_frame->ymd}})
                    ->count;
        $sum += $tweet_count;
        my $time = $end_of_frame->epoch * 1000;
        my $data_point = [$time, $tweet_count];
        push @data_points, $data_point;
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
        title => "Timeline for $username",
        profile_image => $profile_image,
    };
};

true;
