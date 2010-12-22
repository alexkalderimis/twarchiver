package Twarchiver::Routes::Graph;

use Dancer ':syntax';

use Twarchiver::Functions::DBAccess 'get_user_record';
use Twarchiver::Functions::TwitterAPI qw/authorise needs_authorisation/;
use Twarchiver::Functions::PageContent qw/make_user_home_link/;

get '/graphdata/tweets/by/:interval' => sub {
    my $interval = lc params->{interval};
    my $user = get_user_record(session('username'));
    my $creation = DateTime->from_epoch(epoch => $user->created_at->epoch);
    my %addition;
    if ($interval eq "month") {
        $addition{months} = 1;
        $addition{months} *= params->{unit} if params->{unit};
        $creation->truncate( to => "month" );
    } elsif ($interval eq "quarter") {
        $addition{months} = 3;
        $addition{months} *= params->{unit} if params->{unit};
        $creation->truncate( to => "month" );
        my $months_into_quarter = ($creation->month - 1) % 3;
        $creation->subtract( months => $months_into_quarter);
    } elsif ($interval eq "fortnight") {
        $creation->truncate(to => "week");
        $addition{weeks} = 2;
        $addition{weeks} *= params->{unit} if params->{unit};
    } elsif ($interval eq "week") {
        $creation->truncate(to => "week");
        $addition{weeks} = 1;
        $addition{weeks} *= params->{unit} if params->{unit};
    } elsif ($interval eq "day") {
        $creation->truncate( to => "day" );
        $addition{days} = 1;
        $addition{days} *= params->{unit} if params->{unit};
    } else {
        pass and return false;
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
            label => "Tweets by $interval",
            hoverable => \1,
            data => \@data_points,
        };
    return to_json(\@json);
};

get '/graph/tweets/by/:interval' => sub {
    my $interval = params->{interval};
    my $cumulative = params->{cumulative};
    my $unit = params->{unit} || 1;

    my $profile_image = get_user_record(session('username'))
                            ->profile_image_url
                        || '/images/squirrel_icon64.gif';
    my $graphdataurl = "/graphdata/tweets/by/$interval";
    $graphdataurl .= "?unit=" . $unit;
    $graphdataurl .= "&cumulative=1" if $cumulative;
    template 'graph' => {
        title => "Timeline for " . make_user_home_link(),
        profile_image => $profile_image,
        graphdataurl => $graphdataurl,
        interval => $interval,
        unit => $unit,
    };
};

true;
