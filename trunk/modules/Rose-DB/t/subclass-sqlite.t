#!/usr/bin/perl -w

use strict;

use Rose::DateTime::Util qw(parse_date);

BEGIN
{
  require Test::More;
  eval { require DBD::SQLite };

  if($@ || $DBD::SQLite::VERSION < 1.08 || $ENV{'RDBO_NO_SQLITE'})
  {
    Test::More->import(skip_all =>  $ENV{'RDBO_NO_SQLITE'} ? 
      'SQLite tests disabled' : 'Missing DBD::SQLite 1.08+');
  }
  elsif($DBD::SQLite::VERSION == 1.13)
  {
    Test::More->import(skip_all =>  'DBD::SQLite 1.13 is broken');  
  }
  else
  {
    Test::More->import(tests => 44);
  }
}

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB');
}

My::DB2->default_domain('test');
My::DB2->default_type('sqlite_admin');

my $db = My::DB2->new();

ok(ref $db && $db->isa('Rose::DB'), 'new()');

my $dbh;
eval { $dbh = $db->dbh };

SKIP:
{
  skip("Could not connect to db - $@", 9)  if($@);

  ok($dbh, 'dbh() 1');

  ok($db->has_dbh, 'has_dbh() 1');

  my $db2 = My::DB2->new();

  $db2->dbh($dbh);

  foreach my $field (qw(dsn driver database host port username password))
  { 
    is($db2->$field() || '', $db->$field() || '', "$field()");
  }

  $db->disconnect;
  $db2->disconnect;
}

$db = My::DB2->new();

ok(ref $db && $db->isa('Rose::DB'), "new()");

$db->init_db_info;

ok($db->supports_limit_with_offset, 'supports_limit_with_offset');

my @letters = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);
my $rand;

$rand .= $letters[int rand(@letters)] for(1 .. int(rand(20)));
$rand = 'default'  unless(defined $rand); # got under here once!

ok(!$db->validate_timestamp_keyword($rand), "validate_timestamp_keyword ($rand)");

is($db->format_timestamp('Foo(Bar)'), 'Foo(Bar)', 'format_timestamp (Foo(Bar))');

ok(!$db->validate_datetime_keyword($rand), "validate_datetime_keyword ($rand)");

is($db->format_datetime('Foo(Bar)'), 'Foo(Bar)', 'format_datetime (Foo(Bar))');

ok(!$db->validate_date_keyword($rand), "validate_date_keyword ($rand)");

is($db->format_date('Foo(Bar)'), 'Foo(Bar)', 'format_date (Foo(Bar))');

ok(!$db->validate_time_keyword($rand), "validate_time_keyword ($rand)");

is($db->format_time('Foo(Bar)'), 'Foo(Bar)', 'format_time (Foo(Bar))');

is($db->format_array([ 'a', 'b' ]), q({"a","b"}), 'format_array() 1');
is($db->format_array('a', 'b'), q({"a","b"}), 'format_array() 2');

eval { $db->format_array('x' x 300) };
ok($@, 'format_array() 3');

my $a = $db->parse_array(q({"a","b"}));

ok(@$a == 2 && $a->[0] eq 'a' && $a->[1] eq 'b', 'parse_array() 1');

SKIP:
{
  eval { $db->connect };
  skip("Could not connect to db 'test', 'sqlite' - $@", 17)  if($@);
  $dbh = $db->dbh;

  is($db->domain, 'test', "domain()");
  is($db->type, 'sqlite_admin', "type()");

  is($db->print_error, $dbh->{'PrintError'}, 'print_error() 2');
  is($db->print_error, $db->connect_option('PrintError'), 'print_error() 3');

  is($db->null_date, '0000-00-00', "null_date()");
  is($db->null_datetime, '0000-00-00 00:00:00', "null_datetime()");

  is($db->format_date(parse_date('12/31/2002', 'floating')), '2002-12-31', "format_date() floating");
  is($db->format_datetime(parse_date('12/31/2002 12:34:56', 'floating')), '2002-12-31 12:34:56', "format_datetime() floating");

  is($db->format_timestamp(parse_date('12/31/2002 12:34:56.123456789', 'floating')), '2002-12-31 12:34:56.123456789', "format_timestamp() floating");
  #is($db->format_time(parse_date('12/31/2002 12:34:56', 'floating')), '12:34:56', "format_time() floating");

  is($db->format_bitfield($db->parse_bitfield('1010')),
     q(b'1010'), "format_bitfield() 1");

  is($db->format_bitfield($db->parse_bitfield(q(B'1010'))),
     q(b'1010'), "format_bitfield() 2");

  is($db->format_bitfield($db->parse_bitfield(2), 4),
     q(b'0010'), "format_bitfield() 3");

  is($db->format_bitfield($db->parse_bitfield('0xA'), 4),
     q(b'1010'), "format_bitfield() 4");

  #is($db->autocommit + 0, $dbh->{'AutoCommit'} + 0, 'autocommit() 1');

  $db->autocommit(1);

  is($db->autocommit + 0, 1, 'autocommit() 2');
  is($dbh->{'AutoCommit'} + 0, 1, 'autocommit() 3');

  $db->autocommit(0);

  is($db->autocommit + 0, 0, 'autocommit() 4');
  is($dbh->{'AutoCommit'} + 0, 0, 'autocommit() 5');

  my $dbh_copy = $db->retain_dbh;

  $db->disconnect;
}

$db->dsn('dbi:SQLite:dbname=dbfoo');

#ok(!defined($db->database) || $db->database eq 'dbfoo', 'dsn() 1');
#ok(!defined($db->host) || $db->host eq 'hfoo', 'dsn() 2');
#ok(!defined($db->port) || $db->port eq 'port', 'dsn() 3');

eval { $db->dsn('dbi:Pg:dbname=dbfoo') };

ok($@ || $DBI::VERSION <  1.43, 'dsn() driver change');

My::DB2->register_db(
  domain      => My::DB2->default_domain,
  type        => 'nonesuch',
  driver      => 'SQLITE',
  database    => '/tmp/rdbo_does_not_exist.db',
  auto_create => 0,
);

if((! -e '/tmp/rdbo_does_not_exist.db') || unlink('/tmp/rdbo_does_not_exist.db'))
{
  $db = My::DB2->new('nonesuch');
  
  eval { $db->connect };
  
  ok($@ =~ /^Refus/, 'nonesuch database');
}
else
{
  ok(1, "could not unlink /tmp/rdbo_does_not_exist.db - $!");
}
