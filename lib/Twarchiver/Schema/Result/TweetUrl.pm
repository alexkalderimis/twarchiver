package Twarchiver::Schema::Result::TweetUrl;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Twarchiver::Schema::Result::TweetUrl

=cut

__PACKAGE__->table("tweet_url");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 tweet

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 url

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "tweet",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "url",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 url

Type: belongs_to

Related object: L<Twarchiver::Schema::Result::Url>

=cut

__PACKAGE__->belongs_to(
  "url",
  "Twarchiver::Schema::Result::Url",
  { url_id => "url" },
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


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-12-06 21:18:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FrecR6PnbkFVeSInK/1G0Q


# You can replace this text with custom content, and it will be preserved on regeneration
1;
