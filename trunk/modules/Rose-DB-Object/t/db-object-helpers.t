#!/usr/bin/perl -w

use strict;

#use Test::LongString;
use Test::More tests => (74 * 4) + 2;

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object');
  use_ok('Rose::DB::Object::Helpers');
}

our(%Have, $Have_YAML, $Have_JSON);

#
# Tests
#

my $i = 0;

foreach my $db_type (qw(mysql pg informix sqlite))
{
  SKIP:
  {
    skip("$db_type tests", 74)  unless($Have{$db_type});
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

  MyMixIn->add_export_tags('foo' => [], 'all' => []);
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

  my $clone = $class->new(id => 2)->load->clone;
  $clone->laz('Z0');

  foreach my $i (1, 2)
  {
    $clone->update; # reset to initial state

    $o->meta->allow_inline_column_values($i == 2);

    #local $Rose::DB::Object::Debug = 1;

    # Insert or update

    $o = $class->new(id => 2, name => 'Alex', age => 2);
    $o->insert_or_update;

    $o2 = $class->new(id => 2)->load;
    is($o2->name, 'Alex', "insert_or_update() 1.$i - $db_type");
    is($o2->laz, 'Z0', "insert_or_update() 2.$i - $db_type");

    # Insert or update - update regular and lazy columns

    $o->name('Alex2');
    $o->laz('Z1');

    $o->insert_or_update;

    $o2 = $class->new(id => 2)->load;
    is($o2->name, 'Alex2', "insert_or_update() 3.$i - $db_type");
    is($o2->laz, 'Z1', "insert_or_update() 4.$i - $db_type");

    # Insert or update on duplicate key

    $o = $class->new(id => 2, name => 'Alex3', age => 3);

    $o->insert_or_update_on_duplicate_key;

    $o2 = $class->new(id => 2)->load;
    is($o2->name, 'Alex3', "insert_or_update_on_duplicate_key() 1.$i - $db_type");
    is($o2->age, 3, "insert_or_update_on_duplicate_key() 2.$i - $db_type");
    is($o2->laz, 'Z1', "insert_or_update_on_duplicate_key() 3.$i - $db_type");
    is($o2->id, 2, "insert_or_update_on_duplicate_key() 4.$i - $db_type");

    # Insert or update on duplicate key - with unique key only

    $o = $class->new(name => 'Alex3', age => 5);
    $o->insert_or_update_on_duplicate_key;

    $o = $class->new(name => 'Alex3')->load;
    is($o->name, 'Alex3', "insert_or_update_on_duplicate_key() 5.$i - $db_type");
    is($o->age, 5, "insert_or_update_on_duplicate_key() 6.$i - $db_type");
    is($o->laz, 'Z1', "insert_or_update_on_duplicate_key() 7.$i - $db_type");
    is($o->id, 2, "insert_or_update_on_duplicate_key() 8.$i - $db_type");

    $o = $class->new(name => 'Alex3', laz => 'Z2', age => 5);
    $o->insert_or_update_on_duplicate_key;

    $o = $class->new(name => 'Alex3')->load;
    is($o->name, 'Alex3', "insert_or_update_on_duplicate_key() 9.$i - $db_type");
    is($o->age, 5, "insert_or_update_on_duplicate_key() 10.$i - $db_type");
    is($o->laz, 'Z2', "insert_or_update_on_duplicate_key() 11.$i - $db_type");
    is($o->id, 2, "insert_or_update_on_duplicate_key() 12.$i - $db_type");

    $o = $class->new(name => 'Alex3')->load;
    $o->age(6);

    #local $Rose::DB::Object::Debug = 1;
    $o->insert_or_update_on_duplicate_key(changes_only => 1);

    $o = $class->new(name => 'Alex3')->load;
    is($o->name, 'Alex3', "insert_or_update_on_duplicate_key() 13.$i - $db_type");
    is($o->age, 6, "insert_or_update_on_duplicate_key() 14.$i - $db_type");
    is($o->laz, 'Z2', "insert_or_update_on_duplicate_key() 15.$i - $db_type");
    is($o->id, 2, "insert_or_update_on_duplicate_key() 16.$i - $db_type");
  }

  $o->meta->allow_inline_column_values(0);

  is_deeply(scalar $o->column_value_pairs(), 
           { age => 6, id => 2, laz => 'Z2', name => 'Alex3' },
           "column_value_pairs() - $db_type");

  is_deeply(scalar $o->column_accessor_value_pairs(), 
           { age => 6, id => 2, get_laz => 'Z2', name => 'Alex3' },
           "column_accessor_value_pairs() - $db_type");

  is_deeply(scalar $o->column_mutator_value_pairs(), 
           { age => 6, id => 2, set_laz => 'Z2', name => 'Alex3' },
           "column_mutator_value_pairs() - $db_type");

  if($Have_YAML)
  {
    local $YAML::Syck::SortKeys = 1;
    $YAML::Syck::SortKeys = 1; # quiet stupid perl 5.6.x warning
    my $yaml = $o->column_values_as_yaml;
    is($yaml, "--- \nage: 6\nid: 2\nlaz: Z2\nname: Alex3\n",
       "column_values_as_yaml() - $db_type");

    my $c = $class->new(age => 456);
    $c->init_with_yaml($yaml);
    is($c->column_values_as_yaml, "--- \nage: 6\nid: 2\nlaz: Z2\nname: Alex3\n",
       "init_with_yaml() - $db_type")
  }
  else 
  {
    ok(1, "skip column_values_as_yaml() - $db_type");
    ok(1, "skip init_with_yaml() - $db_type");
  }

  if($Have_JSON)
  {
    # I don't know if I can rely on this key order...
    # {"laz":"Z2","name":"Alex3","id":2,"age":6}
    my $json = $o->column_values_as_json;
    ok($json =~ /^\{/ && $json =~ /"laz":"Z2"/ &&
       $json =~ /"name":"Alex3"/ && $json =~ /"id":(?:2|"2")/ &&
       $json =~ /"age":(?:6|"6")/ && $json =~ /\}\z/, "column_values_as_json() - $db_type");

    my $c = $class->new(age => 456);
    $c->init_with_json($json);
    ok($json =~ /^\{/ && $json =~ /"laz":"Z2"/ &&
       $json =~ /"name":"Alex3"/ && $json =~ /"id":(?:2|"2")/ &&
       $json =~ /"age":(?:6|"6")/ && $json =~ /\}\z/, "init_with_json() - $db_type");
  }
  else 
  {
    ok(1, "skip column_values_as_json() - $db_type");
    ok(1, "skip init_with_json() - $db_type");
  }
}

BEGIN
{
  our(%Have, $Have_YAML, $Have_JSON, $All);

  eval { require YAML::Syck; require JSON::Syck; };

  $All = $@ ? ':all_noprereq' : ':all';

  unless($@)
  {
    $Have_YAML = $Have_JSON = 1;
  }
}

BEGIN
{
  our(%Have, $Have_YAML, $Have_JSON, $All);

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
  laz   VARCHAR(255),

  UNIQUE(name)
)
EOF

    $dbh->disconnect;

    package MyPgObject;
    our @ISA = qw(Rose::DB::Object);
    use Rose::DB::Object::Helpers ($All);

    eval { Rose::DB::Object::Helpers->import($All) };
    Test::More::ok($@, 'import conflict - pg');
    eval { Rose::DB::Object::Helpers->import('-force', $All) };
    Test::More::ok(!$@, 'import override - pg');

    Rose::DB::Object::Helpers->import({ load_or_insert => 'find_or_create' });

    sub init_db { Rose::DB->new('pg') }

    __PACKAGE__->meta->table('rose_db_object_test');
    __PACKAGE__->meta->auto_initialize;
    __PACKAGE__->meta->column('laz')->lazy(1);
    __PACKAGE__->meta->column('laz')->add_auto_method_types(qw(get set));
    __PACKAGE__->meta->initialize(replace_existing => 1);
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
  laz   VARCHAR(255),

  UNIQUE(name)
)
EOF

    $dbh->disconnect;

    package MyMysqlObject;
    our @ISA = qw(Rose::DB::Object);
    use Rose::DB::Object::Helpers ($All);

    eval { Rose::DB::Object::Helpers->import(qw(load_or_insert load_speculative insert_or_update)) };
    Test::More::ok($@, 'import conflict - mysql');
    eval { Rose::DB::Object::Helpers->import(qw(--force load_or_insert load_speculative)) };
    Test::More::ok(!$@, 'import override - mysql');

    Rose::DB::Object::Helpers->import({ load_or_insert => 'find_or_create' });

    sub init_db { Rose::DB->new('mysql') }

    __PACKAGE__->meta->table('rose_db_object_test');
    __PACKAGE__->meta->auto_initialize;
    __PACKAGE__->meta->column('laz')->lazy(1);
    __PACKAGE__->meta->column('laz')->add_auto_method_types(qw(get set));
    __PACKAGE__->meta->initialize(replace_existing => 1);
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
  laz   VARCHAR(255),

  UNIQUE(name)
)
EOF

    $dbh->disconnect;

    package MyInformixObject;
    our @ISA = qw(Rose::DB::Object);
    use Rose::DB::Object::Helpers ($All);

    eval { Rose::DB::Object::Helpers->import($All) };
    Test::More::ok($@, 'import conflict - informix');
    eval { Rose::DB::Object::Helpers->import('-force', $All) };
    Test::More::ok(!$@, 'import override - informix');

    Rose::DB::Object::Helpers->import({ load_or_insert => 'find_or_create' });

    sub init_db { Rose::DB->new('informix') }

    __PACKAGE__->meta->table('rose_db_object_test');
    __PACKAGE__->meta->auto_initialize;
    __PACKAGE__->meta->column('laz')->lazy(1);
    __PACKAGE__->meta->column('laz')->add_auto_method_types(qw(get set));
    __PACKAGE__->meta->initialize(replace_existing => 1);
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
  laz   VARCHAR(255),

  UNIQUE(name)
)
EOF

    $dbh->disconnect;

    package MySqliteObject;
    our @ISA = qw(Rose::DB::Object);
    use Rose::DB::Object::Helpers ($All);

    eval { Rose::DB::Object::Helpers->import($All) };
    Test::More::ok($@, 'import conflict - sqlite');
    eval { Rose::DB::Object::Helpers->import('--force', $All) };
    Test::More::ok(!$@, 'import override - sqlite');

    Rose::DB::Object::Helpers->import({ load_or_insert => 'find_or_create' });

    sub init_db { Rose::DB->new('sqlite') }

    __PACKAGE__->meta->table('rose_db_object_test');
    __PACKAGE__->meta->auto_initialize;
    __PACKAGE__->meta->column('laz')->lazy(1);
    __PACKAGE__->meta->column('laz')->add_auto_method_types(qw(get set));
    __PACKAGE__->meta->initialize(replace_existing => 1);
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
