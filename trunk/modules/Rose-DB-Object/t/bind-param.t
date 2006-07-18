#!/usr/bin/perl -w

use strict;

use Test::More tests => 1 + (2 * 2);

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object::Loader');
}

our %Have;

#
# Tests
#

#$Rose::DB::Object::Manager::Debug = 1;

foreach my $db_type (qw(pg mysql))
{
  SKIP:
  {
    skip("$db_type tests", 2)  unless($Have{$db_type});
  }

  next  unless($Have{$db_type});

  Rose::DB->default_type($db_type);

  my $class_prefix =  ucfirst($db_type);

  my $loader = 
    Rose::DB::Object::Loader->new(
      db           => Rose::DB->new,
      class_prefix => $class_prefix);

  my @classes = $loader->make_classes(include_tables => '^rose_db_object_test$');

  my $object_class = $class_prefix . '::RoseDbObjectTest';

  my $data = "\000\001\002\003\004\005" x 10;

  # Standard save

  my $o = $object_class->new(num => 123, data => $data);
  $o->save;

  $o = $object_class->new(id => $o->id)->load;
  is($o->data, $data, "save 1 - $db_type");

  $o->save;

  $o = $object_class->new(id => $o->id)->load;
  is($o->data, $data, "save 2 - $db_type");  

  # Changes only
  
  my $short_data = substr($data, 0, length($data) - 6);

  #$o->data($short_data);
  #$o->save(changes_only => 1);
}

BEGIN
{
  our %Have;

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
    $Have{'pg'} = 1;
    $Have{'pg_with_schema'} = 1;

    # Drop existing tables and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_test');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test 
(
  id    SERIAL PRIMARY KEY,
  num   INT,
  data  BYTEA
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
      $dbh->do('DROP TABLE rose_db_object_test');
    }
  };

  if(!$@ && $dbh)
  {
    $Have{'mysql'} = 1;

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test 
(
  id    INT AUTO_INCREMENT PRIMARY KEY,
  num   INT,
  data  BLOB
)
EOF
  }
}

END
{
  # Delete test table

  if($Have{'pg'})
  {
    # Postgres
    my $dbh = Rose::DB->new('pg_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->disconnect;
  }

  if($Have{'mysql'})
  {
    # MySQL
    my $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->disconnect;
  }
}
