#!/usr/bin/perl -w

use strict;

use Test::More tests => 34;

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object');
  use_ok('Rose::DB::Object::Manager');
}

our(%Have, $Did_Setup, %Temp);

#
# Setup
#

SETUP:
{
  package MyObject;

  our @ISA = qw(Rose::DB::Object);

  MyObject->meta->table('Rose_db_object_test');

  MyObject->meta->columns
  (
    id       => { primary_key => 1, not_null => 1 },
    name     => { type => 'varchar', length => 32 },
    code     => { type => 'char', length => 6 },
    start    => { type => 'date', default => '12/24/1980' },
    date_created => { type => 'timestamp' },
  );

  foreach my $column (MyObject->meta->columns)
  {
    $column->add_auto_method_types(qw(get set));
    $column->method_name('get' => 'xget_' . $column->name);
    $column->method_name('set' => 'xset_' . $column->name);
  }

  my $column = MyObject->meta->column('name');
  
  # 0: die
  $column->add_trigger(event => 'on_get', 
                       name  => 'die',
                       code  => sub { die "blah" });

  # 1: die, dyn
  $column->add_trigger(event => 'on_get', 
                       code => sub { $Temp{'get'}{'name'} = shift->name });

  my $dyn_name = "dyntrig_${$}_1";

  # 0: warn, die, dyn
  $column->add_trigger(event => 'on_get', 
                       name  => 'warn',
                       code  => sub { warn "boo" },
                       position => 'first');

  Test::More::is($column->trigger_index('on_get', 'warn'), 0, 'trigger_index 1');
  Test::More::is($column->trigger_index('on_get', 'die'), 1, 'trigger_index 2');
  Test::More::is($column->trigger_index('on_get', $dyn_name), 2, 'trigger_index 3');

  $column->delete_trigger(event => 'on_get',
                          name  => 'die');

  Test::More::is($column->trigger_index('on_get', 'warn'), 0, 'trigger_index 4');
  Test::More::is($column->trigger_index('on_get', $dyn_name), 1, 'trigger_index 5');

  $column->delete_trigger(event => 'on_get',
                          name  => 'warn');

  Test::More::is($column->trigger_index('on_get', $dyn_name), 0, 'trigger_index 6');

  my $indexes = $column->trigger_indexes('on_get');
  Test::More::is(keys %$indexes, 1, 'trigger_indexes 1');
  my $triggers = $column->triggers('on_get');
  Test::More::is(scalar @$triggers, 1, 'triggers 1');

  $column->add_trigger(event => 'on_set', 
                       code => sub { $Temp{'set'}{'name'} = shift->name });

  $column->add_trigger(on_load => sub { $Temp{'on_load'}{'name'} = shift->name });
  $column->add_trigger(on_save => sub { $Temp{'on_save'}{'name'} = shift->name });

  $column->add_trigger(inflate => sub { $Temp{'inflate'}{'name'} = shift->name });
  $column->add_trigger(deflate => sub { $Temp{'deflate'}{'name'} = uc $_[1] });

  $column = MyObject->meta->column('code');

  $column->add_trigger(inflate => sub { lc $_[1] });
  $column->add_trigger(deflate => sub { uc $_[1] });
}

#
# Tests
#

#$Rose::DB::Object::Manager::Debug = 1;

foreach my $db_type (qw(mysql pg pg_with_schema informix))
{
  SKIP:
  {
    #21
    skip("$db_type tests", 1)  unless($Have{$db_type});
  }
  
  next  unless($Have{$db_type});

  Rose::DB->default_type($db_type);

  unless($Did_Setup++)
  {
    MyObject->meta->initialize;
  }

  # Run tests

  my $o = MyObject->new;
  
  $o->name('Fred');
  is($Temp{'set'}{'name'}, 'Fred', "on_set 1 - $db_type");
  is(keys %Temp, 1, "on_set 2 - $db_type");
  %Temp = ();

  $o->xset_name('Fred');
  is($Temp{'set'}{'name'}, 'Fred', "on_set 3 - $db_type");
  is(keys %Temp, 1, "on_set 4 - $db_type");
  %Temp = ();

  my $name = $o->xget_name;
  is($Temp{'get'}{'name'}, 'Fred', "on_get 1 - $db_type");
  is($Temp{'inflate'}{'name'}, 'Fred', "on_get 2 - $db_type");
  is(keys %Temp, 2, "on_get 3 - $db_type");
  %Temp = ();

  $name = $o->name;
  is($Temp{'get'}{'name'}, 'Fred', "on_get 4 - $db_type");
  is(keys %Temp, 1, "on_get 5 - $db_type");
  %Temp = ();

  #$Rose::DB::Object::Debug = 1;

  $o->save;
  is($Temp{'on_save'}{'name'}, 'FRED', "on_save 1 - $db_type");
  is($Temp{'deflate'}{'name'}, 'FRED', "on_save 2 - $db_type");
  is(keys %Temp, 2, "on_save 3 - $db_type");
  %Temp = ();

  $o->load;
  is($Temp{'on_load'}{'name'}, 'FRED', "on_load 1 - $db_type");
  is(keys %Temp, 1, "on_load 2 - $db_type");
  %Temp = ();

  is($o->name, 'FRED', "deflate 1 - $db_type");
  is($Temp{'get'}{'name'}, 'FRED', "on_get 6 - $db_type");
  is($Temp{'inflate'}{'name'}, 'FRED', "on_get 7 - $db_type");
  is(keys %Temp, 2, "on_get 8 - $db_type");
  %Temp = ();
  
  $o->name('Fred');
  is($Temp{'set'}{'name'}, 'Fred', "on_set 5 - $db_type");
  is(keys %Temp, 1, "on_set 6 - $db_type");
  %Temp = ();

  MyObject->meta->column('name')->add_trigger(
    inflate => sub { $Temp{'inflate'}{'lc_name'} = lc shift->name });

  is($o->name, 'fred', "inflate 1 - $db_type");
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
    $Have{'mysql'} = 1;

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
    $Have{'informix'} = 1;

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

  if($Have{'pg'})
  {
    # Postgres
    my $dbh = Rose::DB->new('pg_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE Rose_db_object_test');
    $dbh->do('DROP TABLE Rose_db_object_private.Rose_db_object_test');

    $dbh->disconnect;
  }

  if($Have{'mysql'})
  {
    # MySQL
    my $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE Rose_db_object_test');

    $dbh->disconnect;
  }

  if($Have{'informix'})
  {
    # Informix
    my $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE Rose_db_object_test');

    $dbh->disconnect;
  }
}
