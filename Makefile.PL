use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'twarchiver',
    AUTHOR              => q{YOUR NAME <youremail@example.com>},
    VERSION_FROM        => 'lib/twarchiver.pm',
    ABSTRACT            => 'YOUR APPLICATION ABSTRACT',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'YAML'       => 0,
        'Dancer'     => 1.2000,
        'DBIx::Class' => 0,
        'DBI::SQLite' => 0,
        'DateTime' => 0,
        'DateTime::Format::SQLite' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'twarchiver-*' },
);
