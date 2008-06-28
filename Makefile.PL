use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Apache::Bootstrap',
    AUTHOR              => 'Fred Moyer <fred@redhotpenguin.com>',
    VERSION_FROM        => 'lib/Apache/Bootstrap.pm',
    ABSTRACT_FROM       => 'lib/Apache/Bootstrap.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Apache-Bootstrap-*' },
);
