#!/usr/bin/perl -w

use strict;

use Test::More tests => 45;

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB');
}

our($HAVE_PG, $HAVE_MYSQL, $HAVE_INFORMIX);

My::DB2->default_domain('test');

#
# Postgres
#

SKIP: foreach my $db_type ('pg')
{
  skip("Postgres tests", 18)  unless($HAVE_PG);

  My::DB2->default_type($db_type);

  my $db = My::DB2->new;

  is($db->commit, 0, "commit() no-op - $db_type");
  is($db->rollback, 0, "commit() no-op - $db_type");

  is($db->autocommit, 1, "autocommit() 1 - $db_type");
  is($db->raise_error, 1, "raise_error() 1 - $db_type");
  is($db->print_error, 1, "print_error() 1 - $db_type");

  ok($db->begin_work, "begin_work() 1 - $db_type");

  ok(!$db->autocommit, "autocommit() 2 - $db_type");
  is($db->raise_error, 1, "raise_error() 2 - $db_type");
  is($db->print_error, 1, "print_error() 2 - $db_type");

  $db->dbh->do(q(INSERT INTO rose_db_test_other (id, name) VALUES (1, 'a')));
  $db->dbh->do(q(INSERT INTO rose_db_test_other (id, name) VALUES (2, 'b')));

  $db->dbh->do(q(INSERT INTO rose_db_test (id, name, fid) VALUES (1, 'a', 1)));
  $db->dbh->do(q(INSERT INTO rose_db_test (id, name, fid) VALUES (2, 'b', 2)));

  ok($db->commit, "commit() 1 - $db_type");

  FAIL_COMMIT:
  {
    local $db->dbh->{'PrintError'} = 0;
    ok($db->begin_work, "begin_work() 2 - $db_type");

    $db->dbh->do(q(INSERT INTO rose_db_test (id, name, fid) VALUES (3, 'c', 3)));
    $db->dbh->do(q(INSERT INTO rose_db_test (id, name, fid) VALUES (4, 'd', 4)));

    ok(!defined $db->commit && $db->error, "commit() 2 - $db_type");
  }

  ok($db->rollback, "rollback() 1 - $db_type");

  ok($db->begin_work, "begin_work() 3 - $db_type");

  $db->dbh->do(q(INSERT INTO rose_db_test (id, name, fid) VALUES (3, 'c', 1)));
  $db->dbh->do(q(INSERT INTO rose_db_test (id, name, fid) VALUES (4, 'd', 2)));

  ok($db->rollback, "rollback() 2 - $db_type");

  ok($db->do_transaction(sub
  {
    $db->dbh->do(q(INSERT INTO rose_db_test (id, name, fid) VALUES (3, 'c', 1)));
    $db->dbh->do(q(INSERT INTO rose_db_test (id, name, fid) VALUES (4, 'd', 2)));
  }), "do_transaction() 1 - $db_type");

  ok(!defined $db->do_transaction(sub
  {
    local $db->dbh->{'PrintError'} = 0;
    $db->dbh->do(q(INSERT INTO rose_db_test (id, name, fid) VALUES (3, 'c', 1)));
    $db->dbh->do(q(INSERT INTO rose_db_test (id, name, fid) VALUES (4, 'd', 2)));
  }), "do_transaction() 2 - $db_type");

  my $sth = $db->dbh->prepare('SELECT COUNT(*) FROM rose_db_test');
  $sth->execute;
  my $count = $sth->fetchrow_array;

  is($count, 4, "do_transaction() 3 - $db_type");
}

#
# MySQL
#

SKIP: foreach my $db_type ('mysql')
{
  skip("MySQL tests", 13)  unless($HAVE_MYSQL);

  My::DB2->default_type($db_type);

  my $db = My::DB2->new;

  is($db->commit, 0, "commit() no-op - $db_type");
  is($db->rollback, 0, "commit() no-op - $db_type");

  is($db->autocommit, 1, "autocommit() 1 - $db_type");
  is($db->raise_error, 1, "raise_error() 1 - $db_type");
  is($db->print_error, 1, "print_error() 1 - $db_type");

  ok($db->begin_work, "begin_work() 1 - $db_type");

  ok(!$db->autocommit, "autocommit() 2 - $db_type");
  is($db->raise_error, 1, "raise_error() 2 - $db_type");
  is($db->print_error, 1, "print_error() 2 - $db_type");

  $db->dbh->do(q(INSERT INTO rose_db_test (id, name) VALUES (1, 'a')));
  $db->dbh->do(q(INSERT INTO rose_db_test (id, name) VALUES (2, 'b')));

  ok($db->commit, "commit() 1 - $db_type");

  ok($db->do_transaction(sub
  {
    $db->dbh->do(q(INSERT INTO rose_db_test (id, name) VALUES (3, 'c')));
    $db->dbh->do(q(INSERT INTO rose_db_test (id, name) VALUES (4, 'd')));
  }), "do_transaction() 1 - $db_type");

  ok(!defined $db->do_transaction(sub
  {
    local $db->dbh->{'PrintError'} = 0;
    $db->dbh->do(q(INSERT INTO rose_db_test (id, name) VALUES (3, 'c')));
    $db->dbh->do(q(INSERT INTO rose_db_test (id, name) VALUES (4, 'd')));
  }), "do_transaction() 2 - $db_type");

  my $sth = $db->dbh->prepare('SELECT COUNT(*) FROM rose_db_test');
  $sth->execute;
  my $count = $sth->fetchrow_array;

  is($count, 4, "do_transaction() 3 - $db_type");
}

#
# Informix
#

SKIP: foreach my $db_type ('informix')
{
  skip("Informix tests", 13)  unless($HAVE_INFORMIX);

  My::DB2->default_type($db_type);

  my $db = My::DB2->new;

  is($db->commit, 0, "commit() no-op - $db_type");
  is($db->rollback, 0, "commit() no-op - $db_type");

  is($db->autocommit, 1, "autocommit() 1 - $db_type");
  is($db->raise_error, 1, "raise_error() 1 - $db_type");
  is($db->print_error, 1, "print_error() 1 - $db_type");

  ok($db->begin_work, "begin_work() 1 - $db_type");

  ok(!$db->autocommit, "autocommit() 2 - $db_type");
  is($db->raise_error, 1, "raise_error() 2 - $db_type");
  is($db->print_error, 1, "print_error() 2 - $db_type");

  $db->dbh->do(q(INSERT INTO rose_db_test (id, name) VALUES (1, 'a')));
  $db->dbh->do(q(INSERT INTO rose_db_test (id, name) VALUES (2, 'b')));

  ok($db->commit, "commit() 1 - $db_type");

  ok($db->do_transaction(sub
  {
    $db->dbh->do(q(INSERT INTO rose_db_test (id, name) VALUES (3, 'c')));
    $db->dbh->do(q(INSERT INTO rose_db_test (id, name) VALUES (4, 'd')));
  }), "do_transaction() 1 - $db_type");

  ok(!defined $db->do_transaction(sub
  {
    local $db->dbh->{'PrintError'} = 0;
    $db->dbh->do(q(INSERT INTO rose_db_test (id, name) VALUES (3, 'c')));
    $db->dbh->do(q(INSERT INTO rose_db_test (id, name) VALUES (4, 'd')));
  }), "do_transaction() 2 - $db_type");

  my $sth = $db->dbh->prepare('SELECT COUNT(*) FROM rose_db_test');
  $sth->execute;
  my $count = $sth->fetchrow_array;

  is($count, 4, "do_transaction() 3 - $db_type");
}

BEGIN
{
  #
  # Postgres
  #

  my $dbh;

  eval 
  {
    $dbh = My::DB2->new('pg_admin')->retain_dbh()
      or die My::DB2->error;
  };

  if(!$@ && $dbh)
  {
    our $HAVE_PG = 1;

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_test');
      $dbh->do('DROP TABLE rose_db_test_other');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_test_other
(
  id    INT NOT NULL PRIMARY KEY,
  name  VARCHAR(32) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_test
(
  id    INT NOT NULL PRIMARY KEY,
  name  VARCHAR(32) NOT NULL,
  fid   INT NOT NULL REFERENCES rose_db_test_other (id) INITIALLY DEFERRED
)
EOF

    $dbh->disconnect;
  }

  #
  # MySQL
  #

  eval 
  {
    $dbh = My::DB2->new('mysql_admin')->retain_dbh()
      or die My::DB2->error;
  };

  if(!$@ && $dbh)
  {
    our $HAVE_MYSQL = 1;

    # Drop existing table, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_test');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_test
(
  id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(32) NOT NULL
)
EOF

    $dbh->disconnect;
  }

  #
  # Informix
  #

  eval 
  {
    $dbh = My::DB2->new('informix_admin')->retain_dbh()
      or die My::DB2->error;
  };

  if(!$@ && $dbh)
  {
    our $HAVE_INFORMIX = 1;

    # Drop existing table, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_test');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_test
(
  id    INT PRIMARY KEY,
  name  VARCHAR(32) NOT NULL
)
EOF

    $dbh->disconnect;
  }
}

END
{
  # Delete test table

  if($HAVE_PG)
  {
    # Postgres
    my $dbh = My::DB2->new('pg_admin')->retain_dbh()
      or die My::DB2->error;

    $dbh->do('DROP TABLE rose_db_test');
    $dbh->do('DROP TABLE rose_db_test_other');

    $dbh->disconnect;
  }

  if($HAVE_MYSQL)
  {
    # MySQL
    my $dbh = My::DB2->new('mysql_admin')->retain_dbh()
      or die My::DB2->error;

    $dbh->do('DROP TABLE rose_db_test');

    $dbh->disconnect;
  }

  if($HAVE_INFORMIX)
  {
    # Informix
    my $dbh = My::DB2->new('informix_admin')->retain_dbh()
      or die My::DB2->error;

    $dbh->do('DROP TABLE rose_db_test');

    $dbh->disconnect;
  }
}
