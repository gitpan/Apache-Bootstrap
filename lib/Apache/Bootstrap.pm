package Apache::Bootstrap;

use warnings;
use strict;

=head1 NAME

Apache::Bootstrap - Bootstraps dual life mod_perl1 and mod_perl2 Apache modules

=cut

our $VERSION = '0.04_01';

=head1 SYNOPSIS

In your Makefile.PL

 use Apache::Bootstrap 0.04;

 my $bootstrap;

 BEGIN {
    # make sure we have at least one minimum version required
    $bootstrap = Apache::Bootstrap->new({ mp2 => '1.99022', mp1 => 0, });
 }

 # write the Makefile using a mod_perl version dependent build subsystem
 $bootstrap->WriteMakefile( %maker_options );

 # check for Apache::Test, return the installed version if exists
 my $has_apache_test = $bootstrap->check_for_apache_test();

 # see if mod_perl2 is installed
 my $mp_generation = $bootstrap->satisfy_mp_generation( 2 );

 unless ($mp_generation) {

     # no mod_perl2?  look for mod_perl 1
     $mp_generation = $bootstrap->satisfy_mp_generation( 1 );
 }

 # any mod_perl version will do
 $mp_generation = Apache::Bootstrap->satisfy_mp_generation();
 unless ( $mp_generation ) {
      warn( 'No mod_perl installation was found' )
 } else {
      warn( "mod_perl generation $mp_generation was found" );
 }

=head1 METHODS

=head2 new()

 # try to find these versions of mod_perl, die if none are found
 $bootstrap = Apache::Bootstrap->new({
     mod_perl2 => 1.99022, # after mp2 renaming
     mod_perl1 => 0,       # any verison of mp1
 });

=cut

sub new {
    my ( $class, $args ) = @_;

    die 'perldoc Apache::Bootstrap'
      unless $args
      && ref $args eq 'HASH'
      && ( defined $args->{mod_perl1} or defined $args->{mod_perl2} );

    my %self;
    if ( defined $args->{mod_perl1} ) {

        eval { require mod_perl1 };
        die 'mod_perl1 not present, cannot bootstrap:  ' . $@ if $@;
        die sprintf( "mod_perl1 version %s not found, we have %s",
            $args->{mod_perl1}, $mod_perl1::VERSION )
          unless $mod_perl1::VERSION >= $args->{mod_perl1};
    }
    else {
        $self{mod_perl1} = $args->{mod_perl1};
    }

    if ( defined $args->{mod_perl2} ) {

        eval { require mod_perl2 };
        die 'mod_perl2 not present, cannot bootstrap:  ' . $@ if $@;
        die sprintf( "mod_perl2 version %s not found, we have %s",
            $args->{mod_perl2}, $mod_perl2::VERSION )
          unless $mod_perl2::VERSION >= $args->{mod_perl2};
    }
    else {
        $self{mod_perl2} = $args->{mod_perl2};
    }

    bless \%self, $class;

    return \%self;
}

=head2 mp_prereqs()

 # returns the prerequisites for mod_perl versions in a hash reference

=cut

sub mp_prereqs {
    my $self = shift;
    return { map { $_ => $self->{$_} } grep { /^mod_perl?\d+/ } keys %{$self} };
}

=head2 check_for_apache_test()

 $apache_test_version = Apache::Bootstrap->check_for_apache_test;

Returns the version of Apache::Test installed.  Returns undefined if
Apache::Test is not installed.

=cut

sub check_for_apache_test {
    my ( $self, $at_min_ver ) = @_;

    return unless eval {
        require Apache::Test;
        if ( $Apache::Test::VERSION < ( $at_min_ver || 0 ) ) {
            warn "Apache::Test version is "
              . $Apache::Test::VERSION
              . ", minimum version required is $at_min_ver"
              . ", tests will be skipped\n";
            die;
        }
        require Apache::TestMM;
        require Apache::TestRunPerl;
        1;
    };

    Apache::TestMM::filter_args();

    no warnings;    # silence '@Apache::TestMM::Argv used only once' warning
    my %args = @Apache::TestMM::Argv;

    return 0
      unless (
        (
            Apache::TestConfig->can('custom_config_path')
            and -f Apache::TestConfig->custom_config_path()
        )
        or $args{apxs}
        or $args{httpd}
        or $ENV{APACHE_TEST_HTTPD}
        or $ENV{APACHE_TEST_APXS}
      );

    Apache::TestRunPerl->generate_script();

    return $Apache::Test::VERSION;
}

=head2 satisfy_mp_generation()

 # see if mod_perl2 is installed
 my $mp_generation = Apache::Bootstrap->satisfy_mp_generation( 2 );

 unless ($mp_generation) {

     # no mod_perl2?  look for mod_perl 1
     $mp_generation = Apache::Bootstrap->satisfy_mp_generation( 1 );
 }

 # any mod_perl version will do
 $mp_generation = Apache::Bootstrap->satisfy_mp_generation();
 unless ( $mp_generation ) {
     warn( 'No mod_perl installation was found' )
 } else {
     warn( "mod_perl generation $mp_generation was found" );
 }

Currently the logic for determining the mod_perl generation
is as follows.

 # If a specific generation was passed as an argument,
 #     if satisfied
 #         return the same generation
 #     else
 #         die
 # else @ARGV and %ENV will be checked for specific orders
 #     if the specification will be found
 #         if satisfied
 #             return the specified generation
 #         else
 #             die
 #     else if any mp generation is found
 #              return it
 #           else
 #              die

=cut

sub satisfy_mp_generation {
    my ( $self, $wanted ) = @_;

    $wanted ||= $self->_wanted_mp_generation();

    unless ( $wanted == 1 || $wanted == 2 ) {
        warn "don't know anything about mod_perl generation: $wanted\n"
          . "currently supporting only generations 1 and 2";
        exit;
    }

    my $selected = 0;

    if ( $wanted == 1 ) {
        _require_mod_perl();
        if ( $mod_perl::VERSION >= 1.99 ) {

            # so we don't pick 2.0 version if 1.0 is wanted
            warn "You don't seem to have mod_perl 1.0 installed";
            exit;
        }
        $selected = 1;
    }
    elsif ( $wanted == 2 ) {

        #warn "Looking for mod_perl 2.0";
        _require_mod_perl();
        if ( $mod_perl::VERSION < 2.0 ) {
            warn "You don't seem to have mod_perl 2.0 installed";
            exit;
        }
        $selected = 2;
    }
    else {
        _require_mod_perl();
        $selected = $mod_perl::VERSION >= 1.99 ? 2 : 1;
        warn "Using $mod_perl::VERSION\n";
    }

    # make sure we have the needed build modules
    my $build_pkg =
      ( $selected == 2 ) ? 'ModPerl::BuildMM' : 'ExtUtils::MakeMaker';
    eval "require $build_pkg";
    $self->{maker} = $build_pkg;

    return $self->{mp_gen} = $selected;
}

# _wanted_mp_generation()
#
# the function looks at %ENV and Makefile.PL option to figure out
# whether a specific mod_perl generation was requested.
# It uses the following logic:
# via options:
# perl Makefile.PL MOD_PERL=2
# or via %ENV:
# env MOD_PERL=1 perl Makefile.PL
#
# return value is:
# 1 or 2 if the specification was found (mp 1 and mp 2 respectively)
# 0 otherwise

sub _wanted_mp_generation {
    my $self = shift;

    # check if we have a command line specification
    # flag: 0: unknown, 1: mp1, 2: mp2
    my $flag = 0;
    foreach my $key (@ARGV) {
        if ( $key =~ /^MOD_PERL=(\d)$/ ) {
            $flag = $1;
        }
    }

    # check %ENV
    my $env = exists $ENV{MOD_PERL} ? $ENV{MOD_PERL} : 0;

    # check for contradicting requirements
    if ( $env && $flag && $flag != $env ) {
        warn <<EOF;
Can\'t decide which mod_perl version should be used, since you have
supplied contradicting requirements:
    enviroment variable MOD_PERL=$env
    Makefile.PL option  MOD_PERL=$flag
EOF
        exit;
    }

    my $wanted = 0;
    $wanted = 2 if $env == 2 || $flag == 2;
    $wanted = 1 if $env == 1 || $flag == 1;

    unless ($wanted) {

        # if still unknown try to require mod_perl2.pm
        eval { require mod_perl2 };
        if ($@) {

            # if we don't have mp2, check for mp1
            eval { require mod_perl1 } if ($@);
            unless ($@) {
                $wanted = 1;
            }
        }
        else {
            $wanted = 2;
        }
    }

    return $wanted;
}

# version dependent require of mod_perl

sub _require_mod_perl {
    eval { require mod_perl2 };
    eval { require mod_perl } if ($@);
    if ($@) {
        warn "Can't find mod_perl installed\nThe error was: $@";
        exit;
    }
}

=head2 apache_major_version()

 $apache_major_version = $bootstrap->apache_major_version;

The major version number of the target apache install

=cut

sub apache_major_version {
    return ( shift->{mp_gen} == 1 ) ? 'Apache' : 'Apache2';
}

=head2 WriteMakefile()

 $bootstrap->write_makefile( %makefile_options );

Writes the makefile using the appropriate make engine depending on what
mod_perl version is in use.  Same API as ExtUtils::MakeMaker or ModPerl::BuildMM

=cut

sub WriteMakefile {
    my ( $self, %maker_opts ) = @_;

    # write the makefile
    my $sub = "$self->{maker}\:\:WriteMakefile";
    {
        no strict 'refs';
        $sub->(%maker_opts);
    }
}

=head1 AUTHOR

Fred Moyer <fred@redhotpenguin.com>

The mod_perl development team C<<dev at perl.apache.org>> and numerous contributors.

This code was lifted from Apache::SizeLimit in an effort to make it useful to
other modules such as Apache::Reload, Apache::Dispatch, any dual life Apache module.

=head1 BUGS

Please report bugs to the mod_perl development mailing list C<<dev at perl.apache.org>>.


=head1 COPYRIGHT & LICENSE

This is a derivative work of Apache::SizeLimit.

# Licensed to the Apache Software Foundation (ASF) under one or more
# # contributor license agreements.  See the NOTICE file distributed with
# # this work for additional information regarding copyright ownership.
# # The ASF licenses this file to You under the Apache License, Version 2.0
# # (the "License"); you may not use this file except in compliance with
# # the License.  You may obtain a copy of the License at
# #
# #     http://www.apache.org/licenses/LICENSE-2.0
# #
# # Unless required by applicable law or agreed to in writing, software
# # distributed under the License is distributed on an "AS IS" BASIS,
# # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# # See the License for the specific language governing permissions and
# # limitations under the License.


=cut

1;
