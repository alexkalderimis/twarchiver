package Twarchiver::Schema::Result::Hashtag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Twarchiver::Schema::Result::Hashtag

=cut

__PACKAGE__->table("hashtag");

=head1 ACCESSORS

=head2 hashtag_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 topic

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->load_components(qw/InflateColumn::DateTime Relationship::Predicate/);
__PACKAGE__->add_columns(
  "hashtag_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "topic",
  { data_type => "text", is_nullable => 0 },
  "last_update",
  { data_type => "datetime", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("hashtag_id");

=head1 RELATIONS

=head2 tweet_hashtags

Type: has_many

Related object: L<Twarchiver::Schema::Result::TweetHashtag>

=cut

__PACKAGE__->has_many(
  "tweet_hashtags",
  "Twarchiver::Schema::Result::TweetHashtag",
  { "foreign.hashtag" => "self.hashtag_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-12-06 21:18:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:L2WZpdxCjgByrrNZl5jy+w


=head2 tweets

Type: many_to_many

Related object: L<Twarchiver::Schema::Result::Tweet>

=cut

__PACKAGE__->many_to_many(
    'tweets',
    'tweet_hashtags',
    'tweet',
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
