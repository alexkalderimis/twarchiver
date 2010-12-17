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
        'Test::Exception' => 0,
        'Test::MockObject' => 0,
        'YAML'       => 0,
        'Dancer'     => 1.2000,
        'DBIx::Class' => 0,
        'DBI::SQLite' => 0,
        'DateTime' => 0,
        'DateTime::Format::SQLite' => 0,
        'Net::Twitter' => 0,
        'HTML::EasyTags' => 0,
        'DateTime::Format::Strptime' => 0,
        'List::MoreUtils' => 0,
        'URI' => 0,
        'Text::CSV' => 0,


    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'twarchiver-*' },
);

sub MY::postamble {
        my $postamble = <<'MAKE_FRAG';
.PHONY: tags

tags:
    ctags -f tags --recurse --totals \
         --exclude=blib \
         --exclude=.svn \
         --exclude='*~' \
         --languages=Perl --langmap=Perl:+.t \
MAKE_FRAG
}

