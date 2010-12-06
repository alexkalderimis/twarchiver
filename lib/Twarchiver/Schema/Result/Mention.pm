package Twarchiver::Schema::Result::Mention;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Twarchiver::Schema::Result::Mention

=cut

__PACKAGE__->table("mention");

=head1 ACCESSORS

=head2 mention_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 screen_name

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "mention_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "screen_name",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("mention_id");

=head1 RELATIONS

=head2 tweet_mentions

Type: has_many

Related object: L<Twarchiver::Schema::Result::TweetMention>

=cut

__PACKAGE__->has_many(
  "tweet_mentions",
  "Twarchiver::Schema::Result::TweetMention",
  { "foreign.mention" => "self.mention_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-12-06 21:18:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1bVdvd9zyD4i6zTTuaQedQ


=head2 tweets

Type: many_to_many

Related object: L<Twarchiver::Schema::Result::Tweet>

=cut

__PACKAGE__->many_to_many(
    'tweets',
    'tweet_mentions',
    'tweet',
);


1;
