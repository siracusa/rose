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
  Test::More->import(tests => 1 + (3 * 5));
}

require 't/test-lib.pl';
use_ok('Rose::DB');

my($db, @Cleanup);

foreach my $db_type (qw(pg mysql informix sqlite oracle))
{
  $db = get_db($db_type);

  unless($db)
  {
    SKIP: { skip("Could not connect to $db_type", 3) }
    next;
  }

  $db->dbh->do('CREATE TABLE rose_db_storable_test (i INT)');  

  CLEANUP:
  {
    my $dbh = $db->dbh;
    push(@Cleanup, sub { $dbh->do('DROP TABLE rose_db_storable_test') });
  }

  my $frozen = Storable::freeze($db);
  my $thawed = Storable::thaw($frozen);

  ok(!defined $thawed->{'dbh'}, "check dbh - $db_type");

  if(!defined $db->password)
  {
    ok(!defined $thawed->{'password'}, "check password - $db_type");
    ok(!defined $thawed->{'password_closure'}, "check password closure - $db_type");
  }
  else
  {
    ok(!defined $thawed->{'password'}, "check password - $db_type");
    ok(ref $thawed->{'password_closure'}, "check password closure - $db_type");
  }

  $thawed->dbh->do('DROP TABLE rose_db_storable_test');
  pop(@Cleanup);
}

END
{
  foreach my $code (@Cleanup)
  {
    $code->();
  }
}
