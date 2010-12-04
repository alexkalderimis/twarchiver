#!/usr/bin/perl

use utf8;
use Dancer;
use Dancer::Plugin::Ajax;
use lib 'lib';
use Net::Twitter::Scraper;
use DateTime::Format::Strptime;
use DateTime;
use HTML::Table;
use HTML::EasyTags;
use List::MoreUtils qw(uniq);
use URI;
use Text::CSV;
use Data::Dumper;

use constant TWITTER_BASE => 'http://twitter.com/';
use constant TWITTER_SEARCH => 'http://twitter.com/search';
my $TAGS_KEY = 'twarchiver:tags';

my $html = HTML::EasyTags->new();
my $datetime_parser = DateTime::Format::Strptime->new(pattern => '%a %b %d %T %z %Y');    

my %cookies;
my $span_re = qr/<.?span.*?>/;
my $mentions_re = qr/(\@(?:<.?span.*?>|\w+)+\b)/;
my $mentions_parse_re = qr/\@(?:<.?span.*?>|(\w+))+\b/;
my $hashtags_re = qr/(\#(?:<.?span.*?>|[\w-]+)+)/;
my $hashtags_parse_re =  qr/\#(?:<.?span.*?>|([\w-]+))+/;
my $urls_re = qr{(http://(?:<.?span.*?>|[\w\./]+)+\b)};
my $urls_parse_re = qr{http://(?:<.?span.*?>|([\w\./]+))};

get '/show/:username/to/:mention' => \&show_mentions_to;

get '/show/:username/on/:hashtag' => \&show_tweets_about;

get '/show/:username/tag/:tag' => \&show_tweets_tagged_with;

get '/show/:username' => \&show_statuses_for;

get '/show/:username/:year/:month' => \&show_statuses_within;

get '/download/:username.:format' => \&download_tweets;

get '/search/:username' => \&search_username;

post '/addtags/:time' => sub {
    my $user = params->{username};
    debug("user is $user");
    my $id = params->{tweetId};
    debug("id is $id");
    my $tags = params->{tags};
    debug("tags are $tags");
    my $statuses = get_statuses($user, 1);
    die "not authorised" unless (ref $statuses);
    my $status;
    for (my $i = 0; $i < @$statuses; $i++) {
        if ($statuses->[$i]->{id} == $id) {
            $status = $statuses->[$i];
            last;
        }
    }
    die "id not found" unless $status;
    my @results;
    for my $tag (split(/,/, $tags)) {
        if (grep {$_ eq $tag} @{$status->{$TAGS_KEY}}) {
            push @results, "Tag not added - This status is already tagged with $tag";
        } else {
            push @results, "added";
            push @{$status->{$TAGS_KEY}}, $tag;
        }
    }
    my $result = join(',', @results);
    debug($result);
    store_statuses($user, $statuses);
    header Status => $result;
    return;
};

post '/deletetags/:time' => sub {
    my $user = params->{username};
    debug("user is $user");
    my $id = params->{tweetId};
    debug("id is $id");
    my $tags = params->{tags};
    debug("tags are $tags");
    my $statuses = get_statuses($user, 1);
    die "not authorised" unless (ref $statuses);
    my $status;
    for (my $i = 0; $i < @$statuses; $i++) {
        if ($statuses->[$i]->{id} == $id) {
            $status = $statuses->[$i];
            last;
        }
    }
    die "id not found" unless $status;
    my @results;

    for my $tag (split(/,/, $tags)) {
        if (grep {$_ eq $tag} @{$status->{$TAGS_KEY}}) {
            push @results, "deleted";
            $status->{$TAGS_KEY} = [grep {$_ ne $tag} @{$status->{$TAGS_KEY}}];

        } else {
            push @results, "Status not deleted - can't find tag '$tag' on status";
        }
    }
    debug(join(',', @results));
    store_statuses($user, $statuses);
    header Status => join(',', @results);
    return;
};
sub search_username {
    my $user = params->{username};
    my $searchterm = params->{searchterm};
    show_tweets_including($user, $searchterm, 1);
}

post '/addmasstags/:time' => sub {
    my $user = params->{username};
    my $tags = params->{tags};
    my @tweet_ids = split(/,/, params->{tweetIds});
    my $statuses = get_statuses($user, 1);
    die "not authorised" unless (ref $statuses);
    my @statuses;
    for my $id (@tweet_ids) {
        push @statuses, grep {$_->{id} eq $id} @$statuses;
    }
    unless (@statuses == @tweet_ids) {
        status 500;
        header Status => "Tags not added: didn't find all tweets";
        return;
    }

    my @results;
    for my $status (@statuses) {
        my @status_results;
        for my $tag (split(/,/, $tags)) {
            if (grep {$_ eq $tag} @{$status->{$TAGS_KEY}}) {
                my $id = $status->{id};
                push @status_results, "Tag not added - status '$id' is already tagged with '$tag'";
            } else {
                push @status_results, "added";
                push @{$status->{$TAGS_KEY}}, $tag;
            }
        }
        push @results, join(',', @status_results);
    }
    my $result = join(',,', @results);
    debug($result);
    store_statuses($user, $statuses);
    header Status => $result;
    return;
};


sub show_mentions_to {
    my $user = params->{username};
    my $mention = '@' . params->{mention};
    show_tweets_including($user, $mention, 0);
}

sub show_tweets_about {
    my $user = params->{username};
    my $hashtag = params->{hashtag};
    show_tweets_including($user, $hashtag, 0);
}

sub show_tweets_including {
    my ($user, $searchterm, $is_case_insensitive) = @_;
    my $statuses = get_statuses($user);
    return unless (ref $statuses eq 'ARRAY');
    my $re;
    eval {
        $re = ($is_case_insensitive)
            ? qr/$searchterm/i
            : qr/$searchterm/;
    };
    if ($@) {
        $re = ($is_case_insensitive) 
            ? qr/\Q$searchterm\E/i
            : qr/\Q$searchterm\E/;
    }
    my @stats_with_searchterm = 
        map {$_->{text} =~ s{$re}{<span class="key-term">$&</span>}g; $_}
        grep {$_->{text} =~ $re} @$statuses;
    debug("Got ".scalar(@stats_with_searchterm)." tweets with searchterm");

    my $data = organise_tweets($statuses);
    my $title = 'Statuses from ' . $html->a(
        href => request->uri_for(join('/','show', $user)),
        text => $user,
    ) . " mentioning $searchterm";
    my $subtitle = 'Just the tweets making a mention';
    return_status_page($statuses, \@stats_with_searchterm, $data, $title);
}

sub show_tweets_tagged_with {
    my $user = params->{username};
    my $tag = params->{tag};
    my $statuses = get_statuses($user);
    return unless (ref $statuses);
    my @tagged_stats;
    OUTER: for (my $i = 0; $i < @$statuses; $i++) {
        my $status = $statuses->[$i];
        next OUTER unless ($status->{$TAGS_KEY});
        INNER: for (my $j = 0; $j < @{$status->{$TAGS_KEY}}; $j++) {
            if ($status->{$TAGS_KEY}->[$j] eq $tag) {
                push @tagged_stats, $status;
                last INNER;
            }
        }
    }
    my $data = organise_tweets($statuses);
    my $title = 'Statuses from ' . $html->a(
        href => request->uri_for(join('/','show', $user)),
        text => $user,
    ) . " tagged with $tag";
    return_status_page($statuses, \@tagged_stats, $data, $title);
}



sub return_status_page {
    my ($all_stats, $relevant_stats, $data, $title) = @_;
    my ($mentions, $mention_count) = make_mention_list($all_stats);
    my ($hashtags, $hashtag_count) = make_hashtag_list($all_stats);
    my ($usertags, $usertag_count) = make_tag_list($all_stats);
    my ($to, $from) = ($relevant_stats->[0])
        ? map( {$relevant_stats->[$_]->{created_at}} 0, -1)
        : ("No tweets found" x 2);

    my @args = (
        username     => params->{username},
        title        => $title,
        search_url   => request->uri_for(join('/',
                'search', params->{username})),
        tweet_number => scalar(@$relevant_stats),
        to           => $to,
        from         => $from,
        content      => make_content($relevant_stats),
        timeline     => make_timeline($data),
        mentions     => $mentions,
        hashtags     => $hashtags,
        usertags     => $usertags,
        beginning    => $datetime_parser->parse_datetime($all_stats->[-1]->{created_at})->strftime("%d %b %Y"),
        most_recent  => $datetime_parser->parse_datetime($all_stats->[0]->{created_at})->strftime("%d %b %Y"),
        no_of_mentions => $mention_count,
        no_of_hashtags => $hashtag_count,
        no_of_usertags => $usertag_count,
        download_base => request->uri_for(join('/', 
                'download', params->{username})),
    );
    template statuses => {@args};
}

sub show_statuses_within {
    my $user = params->{username};
    my $year = params->{year};
    my $month = params->{month};
    my $digits = qr/^\d+$/;
    pass and return false if ($year !~ $digits && $month !~ $digits);
    debug("Showing statuses within");
    my $statuses = get_statuses($user);
    return unless (ref $statuses);
    my $data = organise_tweets($statuses);
    my $stats_for_the_month = $data->{sts}{$year}{$month};
    my $title  = sprintf("Statuses for %s from %s %s",
                        $user, $data->{month_names}{$month}, $year);

    return_status_page($statuses, $stats_for_the_month, $data, $title);
}

sub get_statuses {
    my ($user, $do_not_fetch) = @_;
    debug "Getting statūs of $user";

    my @tokens = ($do_not_fetch) 
        ? ()
        : get_tokens_for($user);

    if (@tokens or $do_not_fetch) {
        return retrieve_statuses($user, @tokens);
    } else {
        return authorise($user);
    }
}

sub show_statuses_for {
    my $user = params->{username};

    my $statuses = get_statuses($user);
    return unless (ref $statuses);
    my $data = organise_tweets($statuses);

    my $title = "Status Archive for $user";
    my $subtitle = "All the statuses I could find";
    return_status_page($statuses, $statuses, $data, $title, $subtitle);
}

sub download_tweets {
    my $user = params->{username};
    my $format = params->{format};

    my $statuses = get_statuses($user);
    return unless (ref $statuses);

    if ($format eq 'txt') {
        get_tweets_as_textfile($statuses);
    } elsif($format eq 'tsv') {
        get_tweets_as_spreadsheet($statuses, "\t");
    } elsif($format eq 'csv') {
        get_tweets_as_spreadsheet($statuses, ',');
    } else {
        die "Unknown format requested: $format";
    }
}

sub get_tweets_as_textfile {
    my $statuses = shift;

    content_type 'text/plain';

    return join("\n\n", map {status_to_text($_)} @$statuses);
}

sub get_tweets_as_spreadsheet {
    my ($statuses, $separator) = @_;

    content_type "text/tab-separated-values";

    my $csv = Text::CSV->new({
            sep_char => $separator,
            binary => 1,
            always_quote => 1,
        });
    my $response;
    for my $st (@$statuses) {
        $csv->combine(@{$st}{qw/created_at text/});
        $response .= $csv->string() . "\n";
    }
    return $response;
}

sub status_to_text {
    my $status = shift;
    my ($created_at, $text) = @{$status}{qw/created_at text/};
    my $tags = ($status->{$TAGS_KEY})
        ? join(', ', @{$status->{$TAGS_KEY}})
        : '';
    $tags = 'Tags: ' . $tags if $tags;
    my $result;
    eval {
        local $SIG{__WARN__};
        open (TEMP, '>', \$result);
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
    if (my $e = $@) {
        error("Problem with ". $status->{text});
    }
    return $result;
}

sub make_content {
    my $statuses = shift;
    if (@$statuses) {
        return $html->ol(
            $html->li_group([map { make_table($_) } @$statuses]));
    } else {
        return $html->p("No tweets found");
    }
}

sub organise_tweets {
    my $statuses = shift;

    my $datetimes = [
        map { $datetime_parser->parse_datetime($_->{created_at}) } 
            @$statuses];
    my %data;
    for (0 .. $#{$datetimes}) {
        my $dt = $datetimes->[$_];
        my $st = $statuses->[$_];
        push @{$data{dts}{$dt->year}{$dt->month}}, $dt;
        push @{$data{sts}{$dt->year}{$dt->month}}, $st;
        $data{month_names}{$dt->month} = $dt->month_name;
    }
    return \%data;
}

sub make_timeline {
    my ($data) = @_;
    my @list_items;
    for my $year (sort {$b <=> $a} keys %{$data->{dts}}) {
        my @month_links =  map {
            $html->a(
                href => request->uri_for(join('/',
                     'show', params->{username}, $year, $_)), 
                text =>sprintf("%s (%d Tweets)",
                        $data->{month_names}{$_},
                        scalar(@{$data->{dts}{$year}{$_}})),
            );
        } sort {$b <=> $a} keys %{$data->{dts}{$year}};
        my $year_item = join("\n",
            $html->h3($year),
            $html->li_group(\@month_links),
        );
        push @list_items, $year_item;
    }
    return $html->li_group(\@list_items);

}

sub make_mention_list {
    my ($statuses) = @_;
    my @list_items;
    my %no_of_m;
    for my $status (@$statuses) {
        my @mentions_in_stat = $status->{text} =~ /$mentions_re/g;
        $no_of_m{$_}++ for @mentions_in_stat;
    }
    if (%no_of_m) {
        push @list_items, map 
            { sprintf("%s %s", 
                make_mention_link($_), 
                make_mention_report_link($_, $no_of_m{$_}))} 
                    sort {$no_of_m{$b} <=> $no_of_m{$a}} 
                        sort keys %no_of_m;
    } else {
        push @list_items, $html->p("No mentions found");
    }
    return (
        $html->li_group(\@list_items), 
        (%no_of_m) ? scalar(@list_items) : 0
    );
}

sub make_hashtag_list {
    my ($statuses) = @_;
    my @list_items;
    my %no_of_h;
    for my $status (@$statuses) {
        my @hashtags_in_stat = $status->{text} =~ /$hashtags_re/g;
        $no_of_h{$_}++ for @hashtags_in_stat;
    }
    if (%no_of_h) {
        push @list_items, map 
            { sprintf("%s %s", 
                make_hashtag_link($_), 
                make_hashtag_report_link($_, $no_of_h{$_}))} 
                    sort {$no_of_h{$b} <=> $no_of_h{$a}} 
                        sort keys %no_of_h;
    } else {
        push @list_items, $html->p("No hashtags found");
    }

    return (
        $html->li_group(\@list_items), 
        (%no_of_h) ? scalar(@list_items) : 0
    );
}

sub make_tag_list {
    my ($statuses) = @_;
    my @list_items;
    my %no_of_t;
    for my $status (@$statuses) {
        if ($status->{$TAGS_KEY}) {
            $no_of_t{$_}++ for @{$status->{$TAGS_KEY}};
        }
    }
    if (%no_of_t) {
        push @list_items, map { make_tag_link($_, $no_of_t{$_}) }  
                    sort {$no_of_t{$b} <=> $no_of_t{$a}} 
                        sort keys %no_of_t;
    } else {
        push @list_items, $html->p("No tags found");
    }

    return (
        $html->li_group(\@list_items), 
        (%no_of_t) ? scalar(@list_items) : 0
    );
}

sub authorise {
    my $user   = shift;
    my $cb_url = request->uri_for( request->path );
    debug("callback url is $cb_url");
    try {
        my $twitter = get_twitter();
        my $url = $twitter->get_authorization_url( callback => $cb_url );
        debug( "request token is " . $twitter->request_token );
        $cookies{$user}{token}  = $twitter->request_token;
        $cookies{$user}{secret} = $twitter->request_token_secret;
        redirect($url);
        return "authorise";
    }
    catch {
        error($_);
        send_error("Authorisation failed, $_");
    };
}

sub get_tokens_for {
    my $user = shift;

    my $twitter = get_twitter();
    my ( $token, $secret ) = restore_tokens($user);
    if ( $token && $secret ) {
        return ( $token, $secret );
    } elsif ( my $verifier = params->{oauth_verifier} ) {
        return request_tokens_for( $user, $verifier );
    } else {
        return;
    }
}

sub request_tokens_for {
    my ( $user, $verifier ) = @_;
    debug("Got verifier: $verifier");

    my $twitter = get_twitter();
    $twitter->request_token( $cookies{$user}{token} );
    $twitter->request_token_secret( $cookies{$user}{secret} );
    my @bits = $twitter->request_access_token( verifier => $verifier );

    #        die "names don't match - got $screen_name"
    #            unless ( $screen_name eq $user);
    save_tokens( @bits[ 3, 0, 1 ] );
    return ( @bits[ 0, 1 ] );
}

sub retrieve_statuses {
    my ($user, @tokens)  = @_;
    my %no_of_st;
    my @stats = grep {$no_of_st{$_->{id}}++ < 1} 
                            restore_statuses_for($user);

    if (@tokens) {
        my $twitter = get_twitter(@tokens);

        my $since = (@stats) 
            ? $stats[0]->{id}
            : 0;

        debug(sprintf "Restored %d statuses", scalar(@stats)) if @stats;

        if ( $twitter->authorized ) {

            for ( my $page = 1 ; ; ++$page ) {
                debug("Getting page $page of twitter statuses");
                my $args = {count => 100, page => $page};
                $args->{since_id} = $since if $since;
                my $statuses = $twitter->user_timeline($args);
                last unless @$statuses;
                unshift @stats, @$statuses;

                #			last if (@stats > 20);
            }
            store_statuses($user, \@stats);
            return \@stats;
        } else {
            die "Not authorised.";
        }
    } else {
        return \@stats;
    }
}
sub make_table {
    my $status    = shift;
    return '' unless $status;
    my $text = $status->{text};
    my @urls = $text =~ /$urls_re/g;
    if (@urls) {
        @urls = uniq(@urls);
        debug(sprintf("Found %d urls: %s",
                scalar(@urls), join(', ', @urls)));
        my %link_for;
        for my $url (@urls) {
            my @url_parts = $url =~ /$urls_parse_re/g;
            my $reconstituted_url = "http://" . join('', @url_parts);
            $link_for{$url} = $html->a(
                href => $reconstituted_url, 
                text => $url,
            );
        };
        while (my ($lhs, $rhs) = each %link_for) {
            $text =~ s/$lhs/$rhs/g;
        }
    }
    my @mentions = $text =~ /$mentions_re/g;
    if (@mentions) {
        @mentions = uniq(@mentions);
        debug(sprintf "Found %d mentions: %s",
            scalar(@mentions), join(', ', @mentions));
        my %link_for;
        for my $mention (@mentions) {
            my @mention_parts = $mention =~ /$mentions_parse_re/g;
            my $reconstituted_mention = "@" . join('', @mention_parts);
            $link_for{$mention} = $html->a(
                href => get_mention_url($reconstituted_mention), 
                text => $mention,
            );
        };
        while (my ($lhs, $rhs) = each %link_for) {
            $text =~ s/$lhs/$rhs/g;
        }
    }

    my @hashtags = $text =~ /$hashtags_re/g;
    if (@hashtags) {
        @hashtags = uniq(@hashtags);
        debug(sprintf "Found %d hashtags: %s",
            scalar(@hashtags), join(', ', @hashtags));
        my %link_for;
        for my $hashtag (@hashtags) {
            my @hashtag_parts = $hashtag =~ /$hashtags_parse_re/g;
            my $reconstituted_hashtag = "@" . join('', @hashtag_parts);
            $link_for{$hashtag} = $html->a(
                href => get_hashtag_url($reconstituted_hashtag), 
                text => $hashtag,
            );
        };
        while (my ($lhs, $rhs) = each %link_for) {
            $text =~ s/$lhs/$rhs/g;
        }
    }

    my $id = $status->{id};
    my $list_item = join( "\n",
        $html->div_start(
            onclick => "toggleForm('$id');",
        ),
        $html->h2($datetime_parser->parse_datetime($status->{created_at})->strftime("%d %b %Y %X")),
        $html->p( $text ),
    );
    $list_item .= $html->div_start(id => $id . '-tags', class => 'tags-list');
    $list_item .= 
        "\n" 
        . $html->ul({id => "tagList-$id"},
            (($status->{$TAGS_KEY} and @{$status->{$TAGS_KEY}}) 
                ? $html->li_group($status->{$TAGS_KEY})
                : '')
        );
    $list_item .= $html->div_end;
    $list_item .= $html->div_end;
    $list_item .= $html->form_start(
        style => 'display: none;', 
        class => 'tag-form',
        method => 'post', 
        id => $id
    );
    $list_item .= $html->p(
        "Tag:" .
        $html->input(type => 'text', id => "tag-$id") .
        $html->input(
            value => 'Add', 
            type => 'button',
            onclick => sprintf("javascript:addNewTag('%s', '%s');",
                            params->{username}, $id),
        ) .
        $html->input(
            value => 'Remove', 
            type => 'button',
            onclick => sprintf("javascript:deleteTag('%s', '%s');",
                            params->{username}, $id),
        ),
    );
    $list_item .= $html->form_end();

    return $list_item;
}

sub make_tag_link {
    my ($tag, $count) = @_;
    return $html->a(
        href => request->uri_for(join('/',
                'show', params->{username}, 'tag', $tag)),
        text => "$tag ($count)",
        count => $count,
        class => 'tagLink',
    );
}

sub get_mention_url {
    my $mention = shift;
    return TWITTER_BASE . substr($mention, 1);
}

sub make_mention_link {
    my $mention = shift;
    $mention =~ s/$span_re//g;
    return $html->a(
        href => get_mention_url($mention),
        text => $mention,
    );
}

sub get_hashtag_url {
    my $hashtag = shift;
    my $uri = URI->new(TWITTER_SEARCH);
    $uri->query_form(q => $hashtag);
    return "$uri";
}
    
sub make_hashtag_link {
    my $hashtag = shift;
    $hashtag =~ s/$span_re//g;

    return $html->a(
        href => get_hashtag_url($hashtag),
        text => $hashtag,
    );
}

sub make_hashtag_report_link {
    my ($hashtag, $count) = @_;
    return $html->a(
        href => request->uri_for(join('/', 'show', params->{username}, 'on', substr($hashtag, 1))),
        text => "($count hashtags)",
        class => 'sidebarinternallink',
    );
}

sub make_mention_report_link {
    my ($mention, $count) = @_;
    return $html->a(
        href => request->uri_for(join('/', 'show', params->{username}, 'to', substr($mention, 1))),
        text => "($count mentions)",
        class => 'sidebarinternallink',
    );
}

get '/' => sub {
    template 'index' => { page_title => 'twarchiver' };
};

set show_errors => 1;
dance;
