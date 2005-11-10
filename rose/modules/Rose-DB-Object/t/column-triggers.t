#!/usr/bin/perl -w

use strict;

use Test::More tests => 6;

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object');
  use_ok('Rose::DB::Object::Manager');
}

our(%HAVE, $DID_SETUP, %TEMP);

#
# Setup
#

SETUP:
{
  package MyObject;

  our @ISA = qw(Rose::DB::Object);

  MyObject->meta->table('rose_db_object_test');

  MyObject->meta->columns
  (
    id       => { primary_key => 1, not_null => 1 },
    name     => { type => 'varchar', length => 32 },
    code     => { type => 'char', length => 6 },
    start    => { type => 'date', default => '12/24/1980' },
    last_modified => { type => 'timestamp' },
    date_created  => { type => 'timestamp' },
  );

  foreach my $column (MyObject->meta->columns)
  {
    $column->add_auto_method_types(qw(get set));
    $column->method_name('get' => 'xget_' . $column->name);
    $column->method_name('set' => 'xset_' . $column->name);
  }

  MyObject->meta->column('name')->add_trigger(on_get => sub 
  { 
    $TEMP{'get'}{'name'} = shift->name 
  });
}

#
# Tests
#

#$Rose::DB::Object::Manager::Debug = 1;

foreach my $db_type (qw(mysql pg pg_with_schema informix))
{
  SKIP:
  {
    skip("$db_type tests", 1)  unless($HAVE{$db_type});
  }
  
  next  unless($HAVE{$db_type});

  Rose::DB->default_type($db_type);

  unless($DID_SETUP++)
  {
    MyObject->meta->initialize;
  }

  # Run tests

  my $o = MyObject->new(name => 'Fred');
  my $name = $o->xget_name;

  is($TEMP{'get'}{'name'}, 'Fred', "on_get 1 - $db_type");
  %TEMP = ();
}

BEGIN
{
  our %HAVE;

  #
  # Postgres
  #

  my $dbh;

  eval 
  {
    $dbh = Rose::DB->new('pg_admin')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    $HAVE{'pg'} = 1;
    $HAVE{'pg_with_schema'} = 1;

    # Drop existing tables and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE Rose_db_object_test');
      $dbh->do('DROP TABLE Rose_db_object_private.Rose_db_object_test');
      $dbh->do('CREATE SCHEMA Rose_db_object_private');
    }

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_test
(
  id             SERIAL NOT NULL PRIMARY KEY,
  name           VARCHAR(32) NOT NULL,
  code           CHAR(6),
  start          DATE NOT NULL DEFAULT '1980-12-24',
  date_created   TIMESTAMP
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_private.Rose_db_object_test
(
  id             SERIAL NOT NULL PRIMARY KEY,
  name           VARCHAR(32) NOT NULL,
  code           CHAR(6),
  start          DATE NOT NULL DEFAULT '1980-12-24',
  date_created   TIMESTAMP
)
EOF

    $dbh->disconnect;
  }

  #
  # MySQL
  #

  eval 
  {
    my $db = Rose::DB->new('mysql_admin');
    $dbh = $db->retain_dbh or die Rose::DB->error;

    # Drop existing tables, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE Rose_db_object_test');
    }
  };

  if(!$@ && $dbh)
  {
    $HAVE{'mysql'} = 1;

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_test
(
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name           VARCHAR(32) NOT NULL,
  code           CHAR(6),
  start          DATE NOT NULL DEFAULT '1980-12-24',
  date_created   TIMESTAMP
)
EOF
    
    $dbh->disconnect;
  }

  #
  # Informix
  #

  eval
  {
    $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    $HAVE{'informix'} = 1;

    # Drop existing tables, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE Rose_db_object_test');
    }

    $dbh->do(<<"EOF");
CREATE TABLE Rose_db_object_test
(
  id             SERIAL NOT NULL PRIMARY KEY,
  name           VARCHAR(32) NOT NULL,
  code           CHAR(6),
  start          DATE DEFAULT '12/24/1980' NOT NULL,
  date_created   DATETIME YEAR TO SECOND
)
EOF

    $dbh->commit;
    $dbh->disconnect;
  }
}

END
{
  # Delete test table

  if($HAVE{'pg'})
  {
    # Postgres
    my $dbh = Rose::DB->new('pg_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE Rose_db_object_test');
    $dbh->do('DROP TABLE Rose_db_object_private.Rose_db_object_test');

    $dbh->disconnect;
  }

  if($HAVE{'mysql'})
  {
    # MySQL
    my $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE Rose_db_object_test');

    $dbh->disconnect;
  }

  if($HAVE{'informix'})
  {
    # Informix
    my $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE Rose_db_object_test');

    $dbh->disconnect;
  }
}
