#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 7;

my $pkg;
my $bootstrap;

BEGIN {
    $pkg = 'Apache::Bootstrap';
    use_ok($pkg);

    can_ok(
        $pkg, qw( new satisfy_mp_generation _wanted_mp_generation
          check_for_apache_test _require_mod_perl )
    );

    $bootstrap = $pkg->new( { mod_perl => 0, mod_perl2 => 1.99022 } );

    isa_ok( $bootstrap, $pkg );

}

diag("Testing Apache::Bootstrap $Apache::Bootstrap::VERSION, Perl $], $^X");

eval { require Apache::Test };
my $skip = $@ ? 'Apache::Test not installed, skipping test' : undef;

SKIP: {
    skip $skip, 1 if $skip;

    my $at_version = $bootstrap->check_for_apache_test;

    cmp_ok( $at_version, '==', $Apache::Test::VERSION, 'check a:t version' );
}

# TODO - figure out how to test absence of apache::test

eval { require mod_perl1 };
my $mp1_skip = $@ ? 'mod_perl1 not installed, skipping test' : undef;

SKIP: {
    skip $mp1_skip, 1 if $mp1_skip;

    my $mp1_version = $bootstrap->satisfy_mp_generation(1);
    cmp_ok( $mp1_version, '==', 1, 'mod_perl1 present' );

}

eval { require mod_perl2 };
my $mp2_skip = $@ ? 'mod_perl2 not installed, skipping test' : undef;

SKIP: {
    skip $mp2_skip, 1 if $mp2_skip;
    my $mp2_version = $bootstrap->satisfy_mp_generation(2);
    cmp_ok( $mp2_version, '==', 2, 'mod_perl2 present' );
}

SKIP: {
    skip 'both mp1 and mp2, skipping', 1 unless ( $mp2_skip && !$mp1_skip );

    # mp1 present but not mp2, so run this test
    my $mp1_version = $bootstrap->satisfy_mp_generation(2);

    ok( !$mp1_version, 'could not satisfy mp2 request with mp1' );
}
