package Twarchiver::Schema::Result::Tweet;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Twarchiver::Schema::Result::Tweet

=cut

__PACKAGE__->table("tweet");

=head1 ACCESSORS

=head2 tweet_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 text

  data_type: 'text'
  is_nullable: 0

=head2 retweeted

  data_type: 'boolean'
  is_nullable: 1

=head2 retweeted_count

  data_type: 'integer'
  is_nullable: 1

=head2 favorited

  data_type: 'boolean'
  is_nullable: 1

=head2 favorited_count

  data_type: 'integer'
  is_nullable: 1

=head2 created_at

  data_type: 'datetime'
  is_nullable: 1

=head2 user

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "tweet_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "text",
  { data_type => "text", is_nullable => 0 },
  "retweeted",
  { data_type => "boolean", is_nullable => 1 },
  "retweeted_count",
  { data_type => "integer", is_nullable => 1 },
  "favorited",
  { data_type => "boolean", is_nullable => 1 },
  "favorited_count",
  { data_type => "integer", is_nullable => 1 },
  "created_at",
  { data_type => "datetime", is_nullable => 1 },
  "user",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("tweet_id");

=head1 RELATIONS

=head2 user

Type: belongs_to

Related object: L<Twarchiver::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "Twarchiver::Schema::Result::User",
  { user_id => "user" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 tweet_mentions

Type: has_many

Related object: L<Twarchiver::Schema::Result::TweetMention>

=cut

__PACKAGE__->has_many(
  "tweet_mentions",
  "Twarchiver::Schema::Result::TweetMention",
  { "foreign.tweet" => "self.tweet_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tweet_hashtags

Type: has_many

Related object: L<Twarchiver::Schema::Result::TweetHashtag>

=cut

__PACKAGE__->has_many(
  "tweet_hashtags",
  "Twarchiver::Schema::Result::TweetHashtag",
  { "foreign.tweet" => "self.tweet_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tweet_tags

Type: has_many

Related object: L<Twarchiver::Schema::Result::TweetTag>

=cut

__PACKAGE__->has_many(
  "tweet_tags",
  "Twarchiver::Schema::Result::TweetTag",
  { "foreign.tweet" => "self.tweet_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tweet_urls

Type: has_many

Related object: L<Twarchiver::Schema::Result::TweetUrl>

=cut

__PACKAGE__->has_many(
  "tweet_urls",
  "Twarchiver::Schema::Result::TweetUrl",
  { "foreign.tweet" => "self.tweet_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-12-06 21:33:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:F+8275R8WjKFi7JAfr/HdQ


=head2 mentions

Type: many_to_many

Related object: L<Twarchiver::Schema::Result::Mention>

=cut

__PACKAGE__->many_to_many(
    'mentions',
    'tweet_mentions',
    'mentions',
);

=head2 hashtags

Type: many_to_many

Related object: L<Twarchiver::Schema::Result::Hashtag>

=cut

__PACKAGE__->many_to_many(
    'hashtags',
    'tweet_hashtags',
    'hashtag',
);

=head2 tags

Type: many_to_many

Related object: L<Twarchiver::Schema::Result::Tag>

=cut

__PACKAGE__->many_to_many(
    'tags',
    'tweet_tags',
    'tag',
);

=head2 urls

Type: many_to_many

Related object: L<Twarchiver::Schema::Result::Url>

=cut

__PACKAGE__->many_to_many(
    'urls',
    'tweet_urls',
    'url',
);

1;
