#!/usr/bin/perl -w

use strict;

require Test::More;

eval { require Storable };

if($@)
{
  Test::More->import(skip_all => 'Could not load Storable');
}
else
{
  Test::More->import(tests => 4);
}

require 't/test-lib.pl';
use_ok('Rose::DB');

my $db;

SKIP:
{
  eval
  {
    $db = Rose::DB->new('pg_admin');
    $db->connect;
  };
  
  if($@)
  {
    eval
    {
      $db = Rose::DB->new('mysql_admin');
      $db->connect;
    };
  
    if($@)
    {
      eval
      {
        $db = Rose::DB->new('sqlite_admin');
        $db->connect;
      };
      
      if($@)
      {
        skip('Could not connect to database', 3);
      }
    }
  }

  $db->dbh->do('CREATE TABLE rose_db_storable_test (i INT)');  

  my $frozen = Storable::freeze($db);
  my $thawed = Storable::thaw($frozen);

  ok(!defined $thawed->{'dbh'}, 'check dbh');
  
  if($db->driver eq 'sqlite')
  {
    ok(!defined $thawed->{'password'}, 'check password');
    ok(!defined $thawed->{'password_closure'}, 'check password closure');
  }
  else
  {
    ok(!defined $thawed->{'password'}, 'check password');
    ok(ref $thawed->{'password_closure'}, 'check password closure');
  }

  $thawed->dbh->do('DROP TABLE rose_db_storable_test');
  $db = undef;
}

END
{
  if($db)
  {
    $db->disconnect;
    $db->dbh->do('DROP TABLE rose_db_storable_test');
  }
}
