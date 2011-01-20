#!/usr/bin/perl -w

use strict;

use Test::More tests => 2 + (6 * 2);

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object');
  use_ok('Rose::DB::Object::Loader');
}

#
# Tests
#

foreach my $db_type (qw(mysql oracle))
{
  SKIP:
  {
    skip("$db_type tests", 6)  unless(have_db($db_type));
  }

  next  unless(have_db($db_type));

  Rose::DB->default_type($db_type);

  my $class_prefix =  ucfirst($db_type);

  my $loader = 
    Rose::DB::Object::Loader->new(
      db              => Rose::DB->new,
      class_prefix    => $class_prefix,
      force_lowercase => 1,
      include_tables  => [ qw(users) ]);

  my @classes = $loader->make_classes;

  #foreach my $class (@classes)
  #{
  #  print $class->meta->perl_class_definition(braces => 'k&r', indent => 2)
  #    if($class->can('meta'));
  #}

  my $user_class = $class_prefix . '::User';

  my $user = $user_class->new(name => 'John');

  $user->save;

  like($user->id, qr/^\d+$/, "pk from sequence 1 - $db_type");

  $user->name(undef);

  ok($user->load(speculative => 1), "reload 1 - $db_type");
  is($user->name, 'John', "reload 2 - $db_type");

  my $pk = $user->meta->primary_key_column_names->[0];
  $user->meta->replace_column($pk => { type => 'serial', not_null => 1 });
  $user->meta->make_column_methods(replace_existing => 1);

  $user = $user_class->new(name => 'John 2');
  $user->save;

  like($user->id, qr/^\d+$/, "pk from sequence 2 - $db_type");

  $user->name(undef);

  ok($user->load(speculative => 1), "reload 3 - $db_type");
  is($user->name, 'John 2', "reload 4 - $db_type");
}

BEGIN
{
  my $dbh;

  #
  # MySQL
  #

  if(have_db('mysql') && mysql_supports_innodb())
  {
    $dbh = get_dbh('mysql_admin');

    # Drop existing tables, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE users');
    }

    $dbh->do(<<"EOF");
CREATE TABLE users
(
  id    INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  UNIQUE(name)
)
TYPE=InnoDB
EOF

    $dbh->disconnect;
  }

  #
  # Oracle
  #

  if(have_db('oracle_admin'))
  {
    $dbh = get_dbh('oracle_admin');

    # Drop existing tables, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;

      $dbh->do('DROP TABLE users');
      $dbh->do('DROP SEQUENCE users_id_seq');
    }

    $dbh->do(<<"EOF");
CREATE TABLE users
(
  id    INT NOT NULL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL,

  CONSTRAINT users_name UNIQUE (name)
)
EOF

    $dbh->do('CREATE SEQUENCE users_id_seq');
    $dbh->do(<<"EOF");
CREATE OR REPLACE TRIGGER users_insert BEFORE INSERT ON users
FOR EACH ROW
BEGIN
    SELECT NVL(:new.id, users_id_seq.nextval)
      INTO :new.id FROM dual;
END;
EOF

    $dbh->disconnect;
  }
}

END
{
  if(have_db('mysql'))
  {
    my $dbh = get_dbh('mysql_admin');
    $dbh->do('DROP TABLE users');
    $dbh->disconnect;
  }

  if(have_db('oracle'))
  {
    my $dbh = get_dbh('oracle_admin');
    $dbh->do('DROP TABLE users');
    $dbh->do('DROP SEQUENCE users_id_seq');
    $dbh->disconnect;
  }
}
