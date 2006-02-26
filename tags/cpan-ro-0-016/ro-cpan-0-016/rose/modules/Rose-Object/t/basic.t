#!/usr/bin/perl

use strict;

use Test::More tests => 17;

BEGIN
{
  use_ok('Rose::Object');
  use_ok('Rose::Class');
}

my($p, $name, $age, $ok);


$p = Person->new();
ok($p && $p->isa('Person'), 'new() 1');

is($p->name('John'), 'John', 'set 1');
is($p->age(26), 26, 'set 2');

is($p->name(), 'John', 'get 1');
is($p->age(), 26, 'get 2');

$p = Person->new(name => 'John2', age => 26);
ok($p && $p->isa('Person'), 'new() 2');

is($p->name(), 'John2', 'get 3');
is($p->age(), 26, 'get 4');

is($p->name('Craig'), 'Craig', 'set 3');
is($p->age(50), 50, 'set 4');

is($p->name(), 'Craig', 'get 5');
is($p->age(), 50, 'get 6');

is(Person->error, undef, 'class get 1');
is(Person->error('foo'), 'foo', 'class set 1');
is(Person->error, 'foo', 'class get 2');

BEGIN
{
  package Person;

  use strict;

  @Person::ISA = qw(Rose::Class Rose::Object);

  use Rose::Object::MakeMethods::Generic
  (
    scalar => [ qw(name age) ],
  );
}
