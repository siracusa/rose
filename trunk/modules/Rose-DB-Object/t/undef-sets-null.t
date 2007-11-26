#!/usr/bin/perl -w

use strict;

require Test::More;

require 't/test-lib.pl';

if(have_db('sqlite_admin'))
{
  Test::More->import('no_plan'); # tests => 287;
}
else
{
  Test::More->import(skip_all => 'No SQLite');
}

use_ok('DateTime');
use_ok('DateTime::Duration');
use_ok('Time::Clock');
use_ok('Bit::Vector');
use_ok('Rose::DB::Object');

package My::DB::Object;
our @ISA = qw(Rose::DB::Object);
sub init_db { Rose::DB->new('sqlite') }
My::DB::Object->meta->table('rose_db_object_nonesuch');

package My::DB::Object::USN;
our @ISA = qw(Rose::DB::Object);
sub init_db { Rose::DB->new('sqlite') }
My::DB::Object::USN->meta->table('rose_db_object_nonesuch');

package My::DB::Object::USN::Default;
our @ISA = qw(Rose::DB::Object);
sub init_db { Rose::DB->new('sqlite') }
My::DB::Object::USN::Default->meta->table('rose_db_object_nonesuch');
My::DB::Object::USN::Default->meta->column_undef_sets_null(1);

package main;

my $classes = My::DB::Object->meta->column_type_classes;

my $meta      = My::DB::Object->meta;
my $meta_usn  = My::DB::Object::USN->meta;
my $meta_usnd = My::DB::Object::USN::Default->meta;

my $DT   = DateTime->new(year => 2007, month => 12, day => 31);
my $Time = Time::Clock->new('12:34:56');
my $Dur   = DateTime::Duration->new(years => 3);
my $Set   = [ 1, 2, 3 ];
my $Array = [ 4, 5, 6 ];
my $BV    = Bit::Vector->new_Dec(32, 123);

my $DT2   = DateTime->new(year => 2008, month => 12, day => 31);
my $Time2 = Time::Clock->new('22:34:56');
my $Dur2   = DateTime::Duration->new(years => 5);
my $Set2   = [ 7, 8, 9 ];
my $Array2 = [ 9, 8, 7 ];
my $BV2    = Bit::Vector->new_Dec(32, 456);

my %extra =
(
  enum => { values => [ 'foo', 'bar' ] },
);

my $i = 0;

foreach my $type (qw(scalar integer varchar character array)) #(sort keys (%$classes)) (qw(array)) #
{
  $i++;

  my $default = default_for_column_type($type);

  my %e = $extra{$type} ? %{$extra{$type}} : ();

  $e{'add_method_types'} = [ qw(get get_set) ];

  $meta->add_column("c$i" => { type => $type, default => $default, %e });
  $meta_usn->add_column("c$i" => { type => $type, default => $default, undef_sets_null => 1, %e });
  $meta_usnd->add_column("c$i" => { type => $type, default => $default, %e });
}

$meta->initialize;
$meta_usn->initialize;
$meta_usnd->initialize;

foreach my $n (1 .. $i)
{
  my $col     = "c$n";
  my $type    = $meta->column($col)->type;
  my $default = $meta->column($col)->default;

  my $method_base = method_for_column_type($type, $n);

  my $db = db_for_column_type($meta->column($col)->type);

  unless($db)
  {
    SKIP:
    {
      skip("unavailable db tests", 12);
    }

    next;
  }
  
  foreach my $method ($method_base, "get_$method_base")
  {
    my $o      = My::DB::Object->new;
    my $o_usn  = My::DB::Object::USN->new;
    my $o_usnd = My::DB::Object::USN::Default->new;

    $o->db($db);
    $o_usn->db($db);
    $o_usnd->db($db);
  
    is(massage_value(scalar $o->$method()), massage_value($default), "$method $type default $n");
    is(massage_value(scalar $o_usn->$method()), massage_value($default), "$method $type USN explicit $n");
    is(massage_value(scalar $o_usnd->$method()), massage_value($default), "$method type USN default $n");

    $o->$method_base(undef);
    $o_usn->$method_base(undef);
    $o_usnd->$method_base(undef);
  
    is(massage_value(scalar $o->$method()), massage_value($default), "$method $type undef default $n");
    is(massage_value(scalar $o_usn->$method()), undef, "$method $type undef USN explicit $n");
    is(massage_value(scalar $o_usnd->$method()), undef, "$method $type undef USN default $n");
    
    my $value = value_for_column_type($type);  
  
    $o->$method_base($value);
    $o_usn->$method_base($value);
    $o_usnd->$method_base($value);
 
    is(massage_value(scalar $o->$method()), massage_value($value), "$method $type value default $n");
    is(massage_value(scalar $o_usn->$method()), massage_value($value), "$method $type value USN explicit $n");
    is(massage_value(scalar $o_usnd->$method()), massage_value($value), "$method $type value USN default $n");

    $o->$method_base(undef);
    $o_usn->$method_base(undef);
    $o_usnd->$method_base(undef);
  
    is(massage_value(scalar $o->$method()), massage_value($default), "$method $type undef default $n");
    is(massage_value(scalar $o_usn->$method()), undef, "$method $type undef USN explicit $n");
    is(massage_value(scalar $o_usnd->$method()), undef, "$method $type undef USN default $n");
  }
}

sub massage_value
{
  my($value) = shift;
  
  if(ref $value eq 'ARRAY')
  {
    return "@$value";
  }
  
  return defined $value ? "$value" : undef;
}

my %DB;

sub db_for_column_type
{
  my($type) = shift;
  
  if($type =~ / year to |^set$/)
  {
    return $DB{'informix'} ||= Rose::DB->new('informix');
  }
  elsif($type =~ /^(?:interval|chkpass)$/)
  {
    return $DB{'pg'} ||= Rose::DB->new('pg');
  }
  else
  {
    return $DB{'sqlite'} ||= Rose::DB->new('sqlite');
  }
}

sub method_for_column_type
{
  my($type, $i) = @_;
  
  if($type eq 'chkpass')
  {
    return "c${i}_encrypted";
  }
  
  return "c$i";
}

sub default_for_column_type
{
  my($type) = shift;

  if($type =~ /date|timestamp|epoch/)
  {
    return $DT;
  }
  elsif($type eq 'time')
  {
    return $Time;
  }
  elsif($type eq 'interval')
  {
    return $Dur;
  }
  elsif($type eq 'enum')
  {
    return 'foo';
  }
  elsif($type eq 'set')
  {
    return $Set;
  }
  elsif($type eq 'array')
  {
    return $Array;
  }
  elsif($type =~ /^(?:bitfield|bits)/)
  {
    return $BV;
  }
  elsif($type =~ /^bool/)
  {
    return 1;
  }
  elsif($type eq 'chkpass')
  {
    return ':vOR7BujbRZSLM';
  }

  return 123;
}

sub value_for_column_type
{
  my($type) = shift;

  if($type =~ /date|timestamp|epoch/)
  {
    return $DT2;
  }
  elsif($type eq 'time')
  {
    return $Time2;
  }
  elsif($type eq 'interval')
  {
    return $Dur2;
  }
  elsif($type eq 'enum')
  {
    return 'bar';
  }
  elsif($type eq 'set')
  {
    return $Set2;
  }
  elsif($type eq 'array')
  {
    return $Array2;
  }
  elsif($type =~ /^(?:bitfield|bits)/)
  {
    return $BV2;
  }
  elsif($type =~ /^bool/)
  {
    return 0;
  }
  elsif($type eq 'chkpass')
  {
    return ':vOR7BujbRZSLP';
  }

  return 456;
}