use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Apache::Bootstrap',
    AUTHOR        => 'Fred Moyer <fred@redhotpenguin.com>',
    VERSION_FROM  => 'lib/Apache/Bootstrap.pm',
    ABSTRACT_FROM => 'lib/Apache/Bootstrap.pm',
    PL_FILES      => {},
    dist          => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Apache-Bootstrap-*' },
);

package MY;

sub test {
    my $self = shift;

    eval { require Test::More } or return <<EOF;
test::
\t\@echo sorry, cannot run tests without Test::More
EOF

    return $self->SUPER::test();
}
