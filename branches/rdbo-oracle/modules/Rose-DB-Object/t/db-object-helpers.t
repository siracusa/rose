#!/usr/bin/perl -w

use strict;

use Test::More tests => (27 * 4) + 2;

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object');
  use_ok('Rose::DB::Object::Helpers');
}

our %Have;

#
# Tests
#

my $i = 0;

foreach my $db_type (qw(mysql pg informix sqlite))
{
  SKIP:
  {
    skip("$db_type tests", 27)  unless($Have{$db_type});
  }

  next  unless($Have{$db_type});

  MyMixIn->clear_export_tags;
  MyMixIn->export_tag('all' => [ 'a', 'b' ]);

  my $class = 'My' . ucfirst($db_type) . 'Object';

  my $o = $class->new(id => 1, name => 'John', age => 30);

  my @tags = MyMixIn->export_tags;
  is_deeply(\@tags, [ 'all' ], "export_tags() 1 - $db_type");

  my $tags = MyMixIn->export_tags;
  is_deeply($tags, [ 'all' ], "export_tags() 1 - $db_type");

  eval { MyMixIn->export_tag('foo') };
  ok($@, "export_tag() 1 - $db_type");

  MyMixIn->export_tag('foo' => [ 'bar', 'baz' ]);

  my @methods = sort(MyMixIn->export_tag('foo'));
  is_deeply(\@methods, [ 'bar', 'baz' ], "export_tag() 1 - $db_type");

  my $methods = MyMixIn->export_tag('foo');
  $methods = [ sort @$methods ];
  is_deeply($methods, [ 'bar', 'baz' ], "export_tag() 2 - $db_type");

  eval { MyMixIn->export_tag('foo', 'bar') };
  ok($@, "export_tag() 3 - $db_type");

  eval { MyMixIn->export_tag('foo', [ 'bar' ], 'baz') };
  ok($@, "export_tag() 4 - $db_type");

  MyMixIn->clear_export_tags;
  @tags = MyMixIn->export_tags;
  is_deeply(\@tags, [ ], "clear_export_tags() 1 - $db_type");

  MyMixIn->add_export_tags('foo', 'all');
  MyMixIn->delete_export_tags('foo', 'all');

  @tags = MyMixIn->export_tags;
  is_deeply(\@tags, [ ], "delete_export_tags() 1 - $db_type");

  MyMixIn->export_tag('xx', [ 'a' ]);
  @tags = MyMixIn->export_tags;
  is_deeply(\@tags, [ 'xx' ], "export_tag() 5 - $db_type");

  MyMixIn->delete_export_tag('xx');
  @tags = MyMixIn->export_tags;
  is_deeply(\@tags, [ ], "delete_export_tag() 1 - $db_type");  

  ok(!$o->load_speculative, "load_speculative() 1 - $db_type");
  ok($o->load_or_insert(), "load_or_insert() 1 - $db_type");

  $o = $class->new(id => 1);
  ok($o->load_speculative, "load_speculative() 2 - $db_type");

  $o = $class->new(id => 2, name => 'Alex');
  ok($o->find_or_create(), "find_or_create() 1 - $db_type");

  $o = $class->new(id => 2);
  ok($o->find_or_create(), "find_or_create() 2 - $db_type");

  $o = $class->new(id => 2);
  ok($o->load_speculative, "load_speculative() 3 - $db_type");
  
  my $o2 = $o->clone;
  
  is($o2->id, $o->id, "clone() 1 - $db_type");
  is($o2->name, $o->name, "clone() 2 - $db_type");
  is($o2->age, $o->age, "clone() 3 - $db_type");
  ok(!defined $o2->{'db'}, "clone() 4 - $db_type");

  $o2 = $o->clone_and_reset;

  ok(!defined $o2->id, "clone_and_reset() 1 - $db_type");
  
  # Crazy MySQL prvides an empty string as a default value
  if($db_type eq 'mysql') 
  {
    ok(!length $o2->name, "clone_and_reset() 2 - $db_type");
  }
  else
  {
    ok(!defined $o2->name, "clone_and_reset() 2 - $db_type");
  }

  is($o2->age, $o->age, "clone_and_reset() 3 - $db_type");
  is($o2->db, $o->db, "clone_and_reset() 4 - $db_type");
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
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,
  age   INT,

  UNIQUE(name)
)
EOF

    $dbh->disconnect;

    package MyPgObject;
    our @ISA = qw(Rose::DB::Object);
    use Rose::DB::Object::Helpers qw(:all);

    eval { Rose::DB::Object::Helpers->import(qw(:all)) };
    Test::More::ok($@, 'import conflict - pg');
    eval { Rose::DB::Object::Helpers->import(qw(-force :all)) };
    Test::More::ok(!$@, 'import override - pg');

    Rose::DB::Object::Helpers->import({ load_or_insert => 'find_or_create' });

    sub init_db { Rose::DB->new('pg') }

    __PACKAGE__->meta->table('rose_db_object_test');
    __PACKAGE__->meta->auto_initialize;
  }

  #
  # MySQL
  #

  eval 
  {
    my $db = Rose::DB->new('mysql_admin');
    $dbh = $db->retain_dbh or die Rose::DB->error;

    die "MySQL version too old"  unless($db->database_version >= 4_000_000);

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
  name  VARCHAR(255) NOT NULL,
  age   INT,

  UNIQUE(name)
)
EOF

    $dbh->disconnect;

    package MyMysqlObject;
    our @ISA = qw(Rose::DB::Object);
    use Rose::DB::Object::Helpers qw(:all);

    eval { Rose::DB::Object::Helpers->import(qw(load_or_insert load_speculative)) };
    Test::More::ok($@, 'import conflict - mysql');
    eval { Rose::DB::Object::Helpers->import(qw(--force load_or_insert load_speculative)) };
    Test::More::ok(!$@, 'import override - mysql');

    Rose::DB::Object::Helpers->import({ load_or_insert => 'find_or_create' });

    sub init_db { Rose::DB->new('mysql') }

    __PACKAGE__->meta->table('rose_db_object_test');
    __PACKAGE__->meta->auto_initialize;
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
    $Have{'informix'} = 1;

    # Drop existing tables, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;

      $dbh->do('DROP TABLE rose_db_object_test');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id    SERIAL NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,
  age   INT,

  UNIQUE(name)
)
EOF

    $dbh->disconnect;

    package MyInformixObject;
    our @ISA = qw(Rose::DB::Object);
    use Rose::DB::Object::Helpers qw(:all);

    eval { Rose::DB::Object::Helpers->import(qw(:all)) };
    Test::More::ok($@, 'import conflict - informix');
    eval { Rose::DB::Object::Helpers->import(qw(-force :all)) };
    Test::More::ok(!$@, 'import override - informix');

    Rose::DB::Object::Helpers->import({ load_or_insert => 'find_or_create' });

    sub init_db { Rose::DB->new('informix') }

    __PACKAGE__->meta->table('rose_db_object_test');
    __PACKAGE__->meta->auto_initialize;
  }

  #
  # SQLite
  #

  eval
  {
    $dbh = Rose::DB->new('sqlite_admin')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    $Have{'sqlite'} = 1;

    # Drop existing tables, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;

      $dbh->do('DROP TABLE rose_db_object_test');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  name  VARCHAR(255) NOT NULL,
  age   INT,

  UNIQUE(name)
)
EOF

    $dbh->disconnect;

    package MySqliteObject;
    our @ISA = qw(Rose::DB::Object);
    use Rose::DB::Object::Helpers qw(:all);

    eval { Rose::DB::Object::Helpers->import(qw(:all)) };
    Test::More::ok($@, 'import conflict - sqlite');
    eval { Rose::DB::Object::Helpers->import(qw(--force :all)) };
    Test::More::ok(!$@, 'import override - sqlite');

    Rose::DB::Object::Helpers->import({ load_or_insert => 'find_or_create' });

    sub init_db { Rose::DB->new('sqlite') }

    __PACKAGE__->meta->table('rose_db_object_test');
    __PACKAGE__->meta->auto_initialize;
  }

  package MyMixIn;
  our @ISA = qw(Rose::DB::Object::MixIn);
}

END
{
  # Delete test tables
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

  if($Have{'informix'})
  {
    # Informix
    my $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->disconnect;
  }

  if($Have{'sqlite'})
  {
    # Informix
    my $dbh = Rose::DB->new('sqlite_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->disconnect;
  }
}
