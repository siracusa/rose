#!/usr/bin/perl -w

use strict;

use Rose::DateTime::Util qw(parse_date);

BEGIN
{
  require Test::More;
  eval { require DBD::Pg };

  if($@)
  {
    Test::More->import(skip_all => 'Missing DBD::Pg');
  }
  else
  {
    Test::More->import(tests => 123);
  }
}

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB');
}

Rose::DB->default_domain('test');
Rose::DB->default_type('pg');

my $db = Rose::DB->new();

ok(ref $db && $db->isa('Rose::DB'), 'new()');

my $dbh;
eval { $dbh = $db->dbh };

SKIP:
{
  skip("Could not connect to db - $@", 8)  if($@);

  ok($dbh, 'dbh() 1');

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

ok($db->supports_limit_with_offset, 'supports_limit_with_offset');

ok($db->validate_timestamp_keyword('now'), 'validate_timestamp_keyword (now)');
ok($db->validate_timestamp_keyword('infinity'), 'validate_timestamp_keyword (infinity)');
ok($db->validate_timestamp_keyword('-infinity'), 'validate_timestamp_keyword (-infinity)');
ok($db->validate_timestamp_keyword('epoch'), 'validate_timestamp_keyword (epoch)');
ok($db->validate_timestamp_keyword('today'), 'validate_timestamp_keyword (today)');
ok($db->validate_timestamp_keyword('tomorrow'), 'validate_timestamp_keyword (tomorrow)');
ok($db->validate_timestamp_keyword('yesterday'), 'validate_timestamp_keyword (yesterday)');
ok($db->validate_timestamp_keyword('allballs'), 'validate_timestamp_keyword (allballs)');

is($db->format_timestamp('now'), 'now', 'format_timestamp (now)');
is($db->format_timestamp('infinity'), 'infinity', 'format_timestamp (infinity)');
is($db->format_timestamp('-infinity'), '-infinity', 'format_timestamp (-infinity)');
is($db->format_timestamp('epoch'), 'epoch', 'format_timestamp (epoch)');
is($db->format_timestamp('today'), 'today', 'format_timestamp (today)');
is($db->format_timestamp('tomorrow'), 'tomorrow', 'format_timestamp (tomorrow)');
is($db->format_timestamp('yesterday'), 'yesterday', 'format_timestamp (yesterday)');
is($db->format_timestamp('allballs'), 'allballs', 'format_timestamp (allballs)');
is($db->format_timestamp('Foo(Bar)'), 'Foo(Bar)', 'format_timestamp (Foo(Bar))');

ok($db->validate_datetime_keyword('now'), 'validate_datetime_keyword (now)');
ok($db->validate_datetime_keyword('infinity'), 'validate_datetime_keyword (infinity)');
ok($db->validate_datetime_keyword('-infinity'), 'validate_datetime_keyword (-infinity)');
ok($db->validate_datetime_keyword('epoch'), 'validate_datetime_keyword (epoch)');
ok($db->validate_datetime_keyword('today'), 'validate_datetime_keyword (today)');
ok($db->validate_datetime_keyword('tomorrow'), 'validate_datetime_keyword (tomorrow)');
ok($db->validate_datetime_keyword('yesterday'), 'validate_datetime_keyword (yesterday)');
ok($db->validate_datetime_keyword('allballs'), 'validate_datetime_keyword (allballs)');

is($db->format_datetime('now'), 'now', 'format_datetime (now)');
is($db->format_datetime('infinity'), 'infinity', 'format_datetime (infinity)');
is($db->format_datetime('-infinity'), '-infinity', 'format_datetime (-infinity)');
is($db->format_datetime('epoch'), 'epoch', 'format_datetime (epoch)');
is($db->format_datetime('today'), 'today', 'format_datetime (today)');
is($db->format_datetime('tomorrow'), 'tomorrow', 'format_datetime (tomorrow)');
is($db->format_datetime('yesterday'), 'yesterday', 'format_datetime (yesterday)');
is($db->format_datetime('allballs'), 'allballs', 'format_datetime (allballs)');
is($db->format_datetime('Foo(Bar)'), 'Foo(Bar)', 'format_datetime (Foo(Bar))');

ok($db->validate_date_keyword('now'), 'validate_date_keyword (now)');
ok($db->validate_date_keyword('epoch'), 'validate_date_keyword (epoch)');
ok($db->validate_date_keyword('today'), 'validate_date_keyword (today)');
ok($db->validate_date_keyword('tomorrow'), 'validate_date_keyword (tomorrow)');
ok($db->validate_date_keyword('yesterday'), 'validate_date_keyword (yesterday)');

is($db->format_date('now'), 'now', 'format_date (now)');
is($db->format_date('epoch'), 'epoch', 'format_date (epoch)');
is($db->format_date('today'), 'today', 'format_date (today)');
is($db->format_date('tomorrow'), 'tomorrow', 'format_date (tomorrow)');
is($db->format_date('yesterday'), 'yesterday', 'format_date (yesterday)');
is($db->format_date('Foo(Bar)'), 'Foo(Bar)', 'format_date (Foo(Bar))');

ok($db->validate_time_keyword('now'), 'validate_time_keyword (now)');
ok($db->validate_time_keyword('allballs'), 'validate_time_keyword (allballs)');

is($db->format_time('now'), 'now', 'format_time (now)');
is($db->format_time('allballs'), 'allballs', 'format_time (allballs)');
is($db->format_time('Foo(Bar)'), 'Foo(Bar)', 'format_time (Foo(Bar))');

is($db->parse_boolean('t'), 1, 'parse_boolean (t)');
is($db->parse_boolean('true'), 1, 'parse_boolean (true)');
is($db->parse_boolean('y'), 1, 'parse_boolean (y)');
is($db->parse_boolean('yes'), 1, 'parse_boolean (yes)');
is($db->parse_boolean('1'), 1, 'parse_boolean (1)');
is($db->parse_boolean('TRUE'), 'TRUE', 'parse_boolean (TRUE)');

is($db->parse_boolean('f'), 0, 'parse_boolean (f)');
is($db->parse_boolean('false'), 0, 'parse_boolean (false)');
is($db->parse_boolean('n'), 0, 'parse_boolean (n)');
is($db->parse_boolean('no'), 0, 'parse_boolean (no)');
is($db->parse_boolean('0'), 0, 'parse_boolean (0)');
is($db->parse_boolean('FALSE'), 'FALSE', 'parse_boolean (FALSE)');

is($db->parse_boolean('Foo(Bar)'), 'Foo(Bar)', 'parse_boolean (Foo(Bar))');

# Undocumented, and may go away, but leave tests for now...
is($db->compare_timestamps('-infinity', 'now'), -1, "compare_timestamps('-infinity', 'now')");
is($db->compare_timestamps('now', '-infinity'), 1, "compare_timestamps('now', '-infinity')");
is($db->compare_timestamps('-infinity', '-infinity'), -1, "compare_timestamps('-infinity', '-infinity')");

is($db->compare_timestamps('infinity', 'now'), 1, "compare_timestamps('infinity', 'now')");
is($db->compare_timestamps('now', 'infinity'), -1, "compare_timestamps('now', 'infinity')");
is($db->compare_timestamps('infinity', 'infinity'), 1, "compare_timestamps('infinity', 'infinity')");

SKIP:
{
  unless(lookup_ip($db->host))
  {
    skip("Host '@{[$db->host]}' not found", 41);
  }

  eval { $db->connect };
  skip("Could not connect to db 'test', 'pg' - $@", 41)  if($@);
  $dbh = $db->dbh;

  is($db->domain, 'test', "domain()");
  is($db->type, 'pg', "type()");

  is($db->print_error, $dbh->{'PrintError'}, 'print_error() 2');
  is($db->print_error, $db->connect_option('PrintError'), 'print_error() 3');

  is($db->null_date, '0000-00-00', "null_date()");
  is($db->null_datetime, '0000-00-00 00:00:00', "null_datetime()");

  is($db->format_date(parse_date('12/31/2002', 'floating')), '2002-12-31', "format_date() floating");
  is($db->format_datetime(parse_date('12/31/2002 12:34:56.123456789', 'floating')), '2002-12-31 12:34:56.123456789', "format_datetime() floating");

  is($db->format_timestamp(parse_date('12/31/2002 12:34:56.12345', 'floating')), '2002-12-31 12:34:56.123450000', "format_timestamp() floating");
  is($db->format_time(parse_date('12/31/2002 12:34:56', 'floating')), '12:34:56', "format_datetime() floating");

  $db->server_time_zone('UTC');

  is($db->format_date(parse_date('12/31/2002', 'UTC')), '2002-12-31', "format_date()");
  is($db->format_datetime(parse_date('12/31/2002 12:34:56', 'UTC')), '2002-12-31 12:34:56+0000', "format_datetime()");

  is($db->format_timestamp(parse_date('12/31/2002 12:34:56')), '2002-12-31 12:34:56', "format_timestamp()");
  is($db->format_time(parse_date('12/31/2002 12:34:56')), '12:34:56', "format_datetime()");

  is($db->parse_date('12-31-2002'), parse_date('12/31/2002', 'UTC'),  "parse_date()");
  is($db->parse_datetime('2002-12-31 12:34:56'), parse_date('12/31/2002 12:34:56', 'UTC'),  "parse_datetime()");
  is($db->parse_timestamp('2002-12-31 12:34:56'), parse_date('12/31/2002 12:34:56', 'UTC'),  "parse_timestamp()");
  #is($db->parse_time('12:34:56'), parse_date('12/31/2002 12:34:56', 'UTC')->strftime('%H:%M:%S'),  "parse_time()");

  $db->european_dates(1);

  is($db->parse_date('31-12-2002'), parse_date('12/31/2002', 'UTC'),  "parse_date() european");
  is($db->parse_datetime('2002-12-31 12:34:56'), parse_date('12/31/2002 12:34:56', 'UTC'),  "parse_datetime() european");
  is($db->parse_timestamp('2002-12-31 12:34:56'), parse_date('12/31/2002 12:34:56', 'UTC'),  "parse_timestamp() european");

  is($db->format_bitfield($db->parse_bitfield('1010')),
     q(1010), "format_bitfield() 1");

  is($db->format_bitfield($db->parse_bitfield(q(B'1010'))),
     q(1010), "format_bitfield() 2");

  is($db->format_bitfield($db->parse_bitfield(2), 4),
     q(0010), "format_bitfield() 3");

  is($db->format_bitfield($db->parse_bitfield('0xA'), 4),
     q(1010), "format_bitfield() 4");

  my $str = $db->format_array([ 'a' .. 'c' ]);
  is($str, '{"a","b","c"}', 'format_array() 1');

  eval { $db->format_array('a', undef) };
  ok($@ =~ /undefined/i, 'format_array() 2');

  eval { $db->format_array([ 'a', undef ]) };
  ok($@ =~ /undefined/i, 'format_array() 3');

  my $ar = $db->parse_array('[-3:3]={1,2,3}');
  ok(ref $ar eq 'ARRAY' && @$ar == 3 && $ar->[0] eq '1' && $ar->[1] eq '2' && $ar->[2] eq '3',
     'parse_array() 2');

  $ar = $db->parse_array($str);
  ok(ref $ar eq 'ARRAY' && $ar->[0] eq 'a' && $ar->[1] eq 'b' && $ar->[2] eq 'c',
     'parse_array() 1');

  $str = $db->format_array($ar);
  is($str, '{"a","b","c"}', 'format_array() 2');

  $str = $db->format_array([ 1, -2, 3.5 ]);
  is($str, '{1,-2,3.5}', 'format_array() 3');

  $ar = $db->parse_array($str);
  ok(ref $ar eq 'ARRAY' && $ar->[0] == 1 && $ar->[1] == -2 && $ar->[2] == 3.5,
     'parse_array() 2');

  $str = $db->format_array($ar);
  is($str, '{1,-2,3.5}', 'format_array() 4');

  $str = $db->format_array(1, -2, 3.5);
  is($str, '{1,-2,3.5}', 'format_array() 5');

  $ar = $db->parse_array($str);
  ok(ref $ar eq 'ARRAY' && $ar->[0] == 1 && $ar->[1] == -2 && $ar->[2] == 3.5,
     'parse_array() 3');

  #is($db->autocommit + 0, $dbh->{'AutoCommit'} + 0, 'autocommit() 1');

  $db->autocommit(1);

  is($db->autocommit + 0, 1, 'autocommit() 2');
  is($dbh->{'AutoCommit'} + 0, 1, 'autocommit() 3');

  $db->autocommit(0);

  is($db->autocommit + 0, 0, 'autocommit() 4');
  is($dbh->{'AutoCommit'} + 0, 0, 'autocommit() 5');

  eval { $db->sequence_name(table => 'foo') };
  ok($@, 'auto_sequence_name() 1');

  eval { $db->sequence_name(column => 'bar') };
  ok($@, 'auto_sequence_name() 2');

  is($db->auto_sequence_name(table => 'foo.goo', column => 'bar'), 'foo.goo_bar_seq', 'auto_sequence_name() 3');

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
