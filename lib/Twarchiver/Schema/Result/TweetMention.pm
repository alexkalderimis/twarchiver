package Twarchiver::Schema::Result::TweetMention;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Twarchiver::Schema::Result::TweetMention

=cut

__PACKAGE__->table("tweet_mention");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 tweet

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 mention

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "tweet",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "mention",
  { data_type => "text", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 mention

Type: belongs_to

Related object: L<Twarchiver::Schema::Result::Mention>

=cut

__PACKAGE__->belongs_to(
  "mention",
  "Twarchiver::Schema::Result::TwitterAccount",
  { screen_name => "mention" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 tweet

Type: belongs_to

Related object: L<Twarchiver::Schema::Result::Tweet>

=cut

__PACKAGE__->belongs_to(
  "tweet",
  "Twarchiver::Schema::Result::Tweet",
  { tweet_id => "tweet" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);
1;
