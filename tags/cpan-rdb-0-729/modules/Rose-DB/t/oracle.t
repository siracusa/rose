#!/usr/bin/perl -w

use strict;

use Rose::DateTime::Util qw(parse_date);

BEGIN
{
  require Test::More;
  eval { require DBD::Oracle };

  if($@)
  {
    Test::More->import(skip_all => 'Missing DBD::Oracle');
  }
  else
  {
    Test::More->import(tests => 23);
  }
}

BEGIN
{
  require 't/test-lib.pl';
  use_ok('Rose::DB');
}

Rose::DB->default_domain('test');
Rose::DB->default_type('oracle');

# Note: $db here is of type Rose::DB::Oracle.

my $db = Rose::DB->new();

ok(ref $db && $db->isa('Rose::DB'), 'new()');

my $dbh;
eval { $dbh = $db->dbh };

SKIP:
{
  skip("Could not connect to db - $@", 9)  if($@);

  ok($dbh, 'dbh() 1');

  ok($db->has_dbh, 'has_dbh() 1');

  my $db2 = Rose::DB->new();

  $db2->dbh($dbh);

  foreach my $field (qw(dsn driver database host port username password))
  {
    is($db2->$field(), $db->$field(), "$field()");
  }

  $db->disconnect;
  $db2->disconnect;
}

$db = Rose::DB->new();

ok(ref $db && $db->isa('Rose::DB'), "new()");

$db->init_db_info;

SKIP:
{
  unless(lookup_ip($db->host))
  {
    skip("Host '@{[$db->host]}' not found", 11);
  }

  eval { $db->connect };
  skip("Could not connect to db 'test', 'oracle' - $@", 11)  if($@);
  $dbh = $db->dbh;

  is($db->domain, 'test', "domain()");
  is($db->type, 'oracle', "type()");

  is($db->print_error, $dbh->{'PrintError'}, 'print_error() 2');
  is($db->print_error, $db->connect_option('PrintError'), 'print_error() 3');

  is($db->null_date, '0000-00-00', "null_date()");
  is($db->null_datetime, '0000-00-00 00:00:00', "null_datetime()");

  #is($db->autocommit + 0, $dbh->{'AutoCommit'} + 0, 'autocommit() 1');

  $db->autocommit(1);

  is($db->autocommit + 0, 1, 'autocommit() 2');
  is($dbh->{'AutoCommit'} + 0, 1, 'autocommit() 3');

  $db->autocommit(0);

  is($db->autocommit + 0, 0, 'autocommit() 4');
  is($dbh->{'AutoCommit'} + 0, 0, 'autocommit() 5');

  is($db->auto_sequence_name(table => 'foo', column => 'bar'), 'foo_bar_seq', 'auto_sequence_name()');

  my $dbh_copy = $db->retain_dbh;

  $db->disconnect;
}

sub lookup_ip
{
  my($name) = shift;

  my $address = (gethostbyname($name))[4] or return 0;

  my @octets = unpack("CCCC", $address);

  return 0  unless($name && @octets);
  return join('.', @octets), "\n";
}
