#!/usr/bin/perl -w

use strict;

use Test::More tests => 7;

BEGIN 
{
  use_ok('Rose::DB');

  require 't/test-lib.pl';

  # Pg
  My::DB2->register_db(
    domain   => 'default',
    type     => 'pg',
    driver   => 'Pg',
    database => 'test',
    host     => 'localhost',
    username => 'postgres',
  );

  # MySQL
  My::DB2->register_db(
    domain   => 'default',
    type     => 'mysql',
    driver   => 'mysql',
    database => 'test',
    host     => 'localhost',
    username => 'root',
  );

  # Informix
  My::DB2->register_db(
    domain   => 'test',
    type     => 'informix',
    driver   => 'Informix',
    database => 'test@test',
  );
}

my $db = My::DB2->new(domain => 'test', type => 'pg');
is(ref $db, 'My::DB2::Pg', 'My::DB2::Pg 1');
is($db->subclass_special_pg, 'PG', 'My::DB2::Pg 2');

$db = My::DB2->new(domain => 'test', type => 'mysql');
is(ref $db, 'My::DB2::MySQL', 'My::DB2::MySQL 1');
is($db->subclass_special_mysql, 'MYSQL', 'My::DB2::MySQL 2');

$db = My::DB2->new(domain => 'test', type => 'informix');
is(ref $db, 'My::DB2::Informix', 'My::DB2::Informix 1');
is($db->subclass_special_informix, 'INFORMIX', 'My::DB2::Informix 2');
