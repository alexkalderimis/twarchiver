package Twarchiver::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Twarchiver::Schema::Result::User

=cut

__PACKAGE__->table("user");

=head1 ACCESSORS

=head2 user_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 screen_name

  data_type: 'text'
  is_nullable: 0

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

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "user_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
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
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("user_id");

=head1 RELATIONS

=head2 tweets

Type: has_many

Related object: L<Twarchiver::Schema::Result::Tweet>

=cut

__PACKAGE__->has_many(
  "tweets",
  "Twarchiver::Schema::Result::Tweet",
  { "foreign.user" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-12-06 21:20:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HrYywIxk5cRDZILy/MERNA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
