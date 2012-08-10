#!/usr/bin/env perl
use strict;
use warnings;

# our little lib
use File::Basename 'dirname';
use File::Spec::Functions qw(splitdir);
push(@INC, join('/', splitdir(dirname(__FILE__)), 'lib'));


use Rose::DB::Object::Loader;
use Test::More;

$ENV{RDBO_NO_SQLITE} ? plan('skip_all' => 'sqlite skipped') : plan(tests => 3);

# overwrite our model with the help of the loader
my $loader = Rose::DB::Object::Loader->new(
  db_class     => 'My::DB::Opa',
  base_classes => 'My::DB::Opa::Object',
  class_prefix => 'My::ModelDynamic::',
);

#1 test if the Loader works as expected
#cmp_deeply [$loader->make_classes],
#  [qw/My::ModelDynamic::Site My::ModelDynamic::Site::Manager/], "the loader works";
is (@{$loader->make_classes}, 2, "the loader works");

#2 check, if we are still connected
is(My::ModelDynamic::Site->new->dbh, My::DB::Opa->new_or_cached->dbh, 'dbh is cached');
$DB::single = 1;
#3 check if our Loader were using the correct init_db method
is (My::DB::Opa->_conn_count, 1, 'connect 1 time only');
