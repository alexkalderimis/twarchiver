use Module::Build;

my $build = Module::Build->new(
    module_name   => 'Twarchiver',
    license       => 'perl',
    dist_author   => 'Alex Kalderimis <alex@gmail.com>',
    dist_abstract => 'A twitter archiving webapp',
    create_readme => 1,
    recursive_test_files => 1,
    create_makefile_pl   => 'traditional',
    requires             => {
        'perl'                          => '5.10.00',
        'Dancer'                        => 1.2,
        'Dancer::Plugin::Ajax'          => 0,
        'Dancer::Plugin::ProxyPath'     => 0,
        'Crypt::SaltedHash'             => 0,
        URI                             => 0,
        Template                        => 0,
        DateTime                        => 0,
        'DateTime::Format::SQLite'      => 0,
        'Statistics::Basic'             => 0,
        'Net::Twitter'                  => 0,
        'Try::Tiny'                     => 0,
        'HTML::EasyTags'                => 0,
        'List::MoreUtils'               => 0,
        'Text::CSV'                     => 0,
        'DBIx::Class'                   => 0,
        'DBIx::Class::Relationship::Predicate' => 0.03,
    },
    build_requires => {
        'SQL::Translator' => 0.11006,
        'Test::Exception' => 0,
        'Test::More'      => 0,
        'Test::MockObject' => 0,
        'Test::Most'       => 0,
        'Test::DBIx::Class' => 0,
    },
);
$build->create_build_script;
