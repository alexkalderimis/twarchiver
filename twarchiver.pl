#!/usr/bin/perl

use Dancer;
use lib 'lib';
use Twarchiver::Routes;

dance;


sub return_status_page {
    my ( $relevant_stats, $title ) = @_;
    my $user_rec = get_user_record(params->{username});
    my ( $mentions, $mention_count ) = make_mention_list();
    my ( $hashtags, $hashtag_count ) = make_hashtag_list();
    my ( $usertags, $usertag_count ) = make_tag_list();
    my ( $to, $from ) = (@$relevant_stats) 
        ? map {$_->created_at->strftime($date_format)} @{$relevant_stats}[0, -1]
        : ( "No tweets found" x 2 );

    my $profile_image    = $user_rec->profile_image_url || '/images/squirrel_icon64.gif';
    my $background_image = $user_rec->profile_bkg_url   || '/images/perldancer-bg.jpg';

    my ($retweeted_count, $favourited_count)  = 
        map {$user_rec->search_related('tweets', {$_.'_count' => {'>' => 0}})->count} ACTIONS;

    my $most_recent = $user_rec->tweets->search(undef, {%order_by_recent})
        ->first()->created_at()->strftime($date_format);
    my $beginning   = $user_rec->tweets->search(undef, {order_by => 'tweet_id'})
        ->first()->created_at()->strftime($date_format);

    my $content = make_content($relevant_stats);

    my @args = (
        profile_image    => $profile_image,
        bkg_image        => $background_image,
        retweeted_count  => $retweeted_count,
        favourited_count => $favourited_count,
        tweet_count      => $user_rec->tweets->count;
        username         => params->{username},
        title            => $title,
        search_url       => request->uri_for( join( '/', 'search', params->{username} ) ),
        tweet_number     => scalar(@$relevant_stats),
        to               => $to,
        from             => $from,
        content          => $content,
        timeline         => make_timeline(),
        mentions         => $mentions,
        hashtags         => $hashtags,
        usertags         => $usertags,
        retweeteds_list  => make_popular_list('retweeted'),
        faveds_list      => make_popular_list('favorited'),
        beginning        => $beginning,
        most_recent      => $most_recent,
        no_of_mentions   => $mention_count,
        no_of_hashtags   => $hashtag_count,
        no_of_usertags   => $usertag_count,
        download_base    => request->uri_for( join( '/', 'download', params->{username} ) ),
    );
    template statuses => {@args};
}

set show_errors => 1;
dance;
