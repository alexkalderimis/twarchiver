package Twarchiver::Schema::Result::Url;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Twarchiver::Schema::Result::Url

=cut

__PACKAGE__->table("url");

=head1 ACCESSORS

=head2 url_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 address

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "url_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "address",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("url_id");

=head1 RELATIONS

=head2 tweet_urls

Type: has_many

Related object: L<Twarchiver::Schema::Result::TweetUrl>

=cut

__PACKAGE__->has_many(
  "tweet_urls",
  "Twarchiver::Schema::Result::TweetUrl",
  { "foreign.url" => "self.url_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-12-06 21:18:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wNKnjr5o6eqbk1B51YJpBQ


=head2 tweets

Type: many_to_many

Related object: L<Twarchiver::Schema::Result::Tweet>

=cut

__PACKAGE__->many_to_many(
    'tweets',
    'tweet_urls',
    'tweet',
);

1;
