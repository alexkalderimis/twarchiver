package Twarchiver::Schema::Result::User;

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

=head2 created_at

  data_type: 'datetime'
  is_nullable: 1
=head2 passhash

  data_type: 'text'
  is_nullable: 1

=head2 username 
    
 data_type: 'text'
 is_nullable: 0

=head2 preferred_page_size

 data_type: 'integer'
 is_nullable: 1

=head2 last_login

 data_type: 'datetime'
 is_nullable: 1

=cut

__PACKAGE__->load_components(qw/InflateColumn::DateTime Relationship::Predicate/);
__PACKAGE__->add_columns(
  "user_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "created_at",
  { data_type => "datetime", is_nullable => 1 },
  "passhash",
  { data_type => "text", is_nullable => 1 },
  "username",
  { data_type => "text", is_nullable => 0 },
  "preferred_page_size",
  { data_type => "integer", is_nullable => 1 },
  "last_login",
  { data_type => "datetime", is_nullable => 1 },
  "last_update",
  { data_type => "datetime", is_nullable => 1 },
  "twitter_account",
  { data_type => "text", is_nullable => 1, 
    is_foreign_key => 1},

);
__PACKAGE__->set_primary_key("user_id");

=head2 twitter_account

Type: belongs_to

Related object: L<Twarchiver::Schema::Result::TwitterAccount>

=cut

__PACKAGE__->belongs_to(
  "twitter_account",
  "Twarchiver::Schema::Result::TwitterAccount",
  "twitter_account",
  { cascade_copy => 0, cascade_delete => 0 },
);

1;
