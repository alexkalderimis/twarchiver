package Twarchiver::Schema::Result::Tag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Twarchiver::Schema::Result::Tag

=cut

__PACKAGE__->table("tag");

=head1 ACCESSORS

=head2 tag_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 text

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "tag_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "tag_text",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("tag_id");

=head1 RELATIONS

=head2 tweet_tags

Type: has_many

Related object: L<Twarchiver::Schema::Result::TweetTag>

=cut

__PACKAGE__->has_many(
  "tweet_tags",
  "Twarchiver::Schema::Result::TweetTag",
  { "foreign.tag" => "self.tag_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-12-06 21:18:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1G5cXkWvVO3YQXTUza3fEw


=head2 tweets

Type: many_to_many

Related object: L<Twarchiver::Schema::Result::Tweet>

=cut

__PACKAGE__->many_to_many(
    'tweets',
    'tweet_tags',
    'tweet',
);


# You can replace this text with custom content, and it will be preserved on regeneration
1;
