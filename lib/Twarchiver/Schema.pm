package Twarchiver::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2010-12-06 21:18:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AvyUO+u4cqww95F1CHSuYw

$SIG{INT} = sub {
    __PACKAGE__->storage->disconnect;
};

# You can replace this text with custom content, and it will be preserved on regeneration
1;
