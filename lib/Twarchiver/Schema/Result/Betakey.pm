package Twarchiver::Schema::Result::Betakey;

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

Twarchiver::Schema::Result::Betakey

=cut

__PACKAGE__->table("betakey");

=head1 ACCESSORS

=head2 key_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 key

  data_type: 'text'
  is_nullable: 0

=head2 user

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->load_components(qw/Relationship::Predicate/);
__PACKAGE__->add_columns(
  "key_id",
  { data_type => "integer", is_nullable => 0 },
  "key",
  { data_type => "text", is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1,
      is_nullable => 1 },
);
__PACKAGE__->set_primary_key("key_id");

=head1 RELATIONS

=head2 user

Type: belongs_to

Related object: L<Twarchiver::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "Twarchiver::Schema::Result::User",
  "user_id",
  { join_type => 'left' },
);


1;
