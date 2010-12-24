package Twarchiver::Schema::Result::TwitterAccount;

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

Twarchiver::Schema::Result::TwitterAccount

=cut

__PACKAGE__->table("twitteraccount");

=head1 ACCESSORS

=head2 twitter_id

  data_type: 'text'
  is_nullable: 1

=head2 screen_name

  data_type: 'text'
  is_nullable: 1

=head2 friends_count

  data_type: 'integer'
  is_nullable: 1

=head2 created_at

  data_type: 'datetime'
  is_nullable: 1

=head2 profile_image_url

  data_type: 'text'
  is_nullable: 1

=head2 profile_bkg_url

  data_type: 'text'
  is_nullable: 1

=head2 access_token

  data_type: 'text'
  is_nullable: 1

=head2 access_token_secret

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->load_components(qw/InflateColumn::DateTime Relationship::Predicate/);
__PACKAGE__->add_columns(
  "twitter_id",
  { data_type => "text", is_nullable => 1 },
  "screen_name",
  { data_type => "text", is_nullable => 0 },
  "friends_count",
  { data_type => "integer", is_nullable => 1 },
  "created_at",
  { data_type => "datetime", is_nullable => 1 },
  "profile_image_url",
  { data_type => "text", is_nullable => 1 },
  "profile_bkg_url",
  { data_type => "text", is_nullable => 1 },
  "access_token",
  { data_type => "text", is_nullable => 1 },
  "access_token_secret",
  { data_type => "text", is_nullable => 1 },
  "user",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  );
__PACKAGE__->set_primary_key("screen_name");

=head1 RELATIONS

=head2 user

Type: has_many

Related object: L<Twarchiver::Schema::Result::User>

=cut

__PACKAGE__->might_have(
    "user",
    "Twarchiver::Schema::Result::User",
    { "foreign.user_id" => "self.user" },
    { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tweets

Type: has_many

Related object: L<Twarchiver::Schema::Result::Tweet>

=cut

__PACKAGE__->has_many(
  "tweets",
  "Twarchiver::Schema::Result::Tweet",
  { "foreign.twitter_account" => "self.screen_name" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
    "tweet_mentions",
    "Twarchiver::Schema::Result::TweetMention",
    { "foreign.mention" => "self.screen_name" },
    { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->many_to_many(
    "mentioning_tweets",
    "tweet_mentions",
    "tweet",
);

