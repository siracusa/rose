#!/usr/bin/perl -w

use strict;

use Test::More tests => 1016;

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object');
  use_ok('Rose::DB::Object::Manager');
}

our($PG_HAS_CHKPASS, $HAVE_PG, $HAVE_MYSQL, $HAVE_INFORMIX);

#
# Postgres
#

SKIP: foreach my $db_type (qw(pg)) #pg_with_schema
{
  skip("Postgres tests", 335)  unless($HAVE_PG);

  Rose::DB->default_type($db_type);

  my $o = MyPgObject->new(id         => 1,
                          name       => 'John',  
                          flag       => 't',
                          flag2      => 'f',
                          fkone      => 2,
                          status     => 'active',
                          bits       => '00001',
                          start      => '2001-01-02',
                          save_col   => 5,     
                          nums       => [ 1, 2, 3 ],
                          last_modified => 'now',
                          date_created  => '2004-03-30 12:34:56');

  ok($o->save, "object save() 1 - $db_type");

  my $objs = 
    MyPgObject->get_objectz(
      share_db     => 1,
      query_is_sql => 1,
      query        =>
      [
        id         => { ge => 1 },
        name       => 'John',  
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        or         => [ and => [ '!bits' => '00001', bits => { ne => '11111' } ],
                        and => [ bits => { lt => '10101' }, '!bits' => '10000' ] ],
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        nums       => '{1,2,3}',
        fk1        => 2,
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56'
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() 2 - $db_type");

  my $o2 = $o->clone;
  $o2->id(2);
  $o2->name('Fred');

  ok($o2->save, "object save() 2 - $db_type");

  my $o3 = $o2->clone;
  $o3->id(3);
  $o3->name('Sue');

  ok($o3->save, "object save() 3 - $db_type");

  my $o4 = $o3->clone;
  $o4->id(4);
  $o4->name('Bob');

  ok($o4->save, "object save() 4 - $db_type");

  $objs = 
    MyPgObjectManager->get_objectz(
      share_db     => 1,
      query_is_sql => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        nums       => '{1,2,3}',
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name DESC');

  is(ref $objs, 'ARRAY', "get_objects() 3 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 2, "get_objects() 4 - $db_type");
  is($objs->[0]->id, 3, "get_objects() 5 - $db_type");
  is($objs->[1]->id, 2, "get_objects() 6 - $db_type");

  my $count =
    MyPgObjectManager->object_count(
      share_db     => 1,
      query_is_sql => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        nums       => '{1,2,3}',
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name DESC');

  is($count, 2, "get_objects_count() 1 - $db_type");

  my $iterator = 
    MyPgObjectManager->get_objectz_iterator(
      share_db     => 1,
      query_is_sql => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        nums       => '{1,2,3}',
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name');

  is(ref $iterator, 'Rose::DB::Object::Iterator', "get_objects_iterator() 1 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator next() 1 - $db_type");
  is($o->id, 2, "iterator next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Sue', "iterator next() 3 - $db_type");
  is($o->id, 3, "iterator next() 4 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator next() 5 - $db_type");
  is($iterator->total, 2, "iterator total() - $db_type");

  my $fo = MyPgOtherObject->new(name => 'Foo 1',
                                k1   => 1,
                                k2   => 2,
                                k3   => 3);

  ok($fo->save, "object save() 5 - $db_type");

  $fo = MyPgOtherObject->new(name => 'Foo 2',
                             k1   => 2,
                             k2   => 3,
                             k3   => 4);

  ok($fo->save, "object save() 6 - $db_type");

  $fo = MyPgBB->new(id   => 1,
                    name => 'one');
  ok($fo->save, "bb object save() 1 - $db_type");

  $fo = MyPgBB->new(id   => 2,
                    name => 'two');
  ok($fo->save, "bb object save() 2 - $db_type");

  $fo = MyPgBB->new(id   => 3,
                    name => 'three');
  ok($fo->save, "bb object save() 3 - $db_type");

  $fo = MyPgBB->new(id   => 4,
                    name => 'four');
  ok($fo->save, "bb object save() 4 - $db_type");

  my $o5 = MyPgObject->new(id         => 5,
                           name       => 'Betty',  
                           flag       => 'f',
                           flag2      => 't',
                           status     => 'with',
                           bits       => '10101',
                           start      => '2002-05-20',
                           save_col   => 123,
                           nums       => [ 4, 5, 6 ],
                           fkone      => 1,
                           fk2        => 2,
                           fk3        => 3,
                           b1         => 2,
                           b2         => 4,
                           last_modified => '2001-01-10 20:34:56',
                           date_created  => '2002-05-10 10:34:56');

  ok($o5->save, "object save() 7 - $db_type");

  my $fo1 = $o5->other_obj;

  ok($fo1 && ref $fo1 && $fo1->k1 == 1 && $fo1->k2 == 2 && $fo1->k3 == 3,
     "foreign object 1 - $db_type");

  $fo1 = $o5->bb1;
  ok($fo1 && ref $fo1 && $fo1->id == 2, "bb foreign object 1 - $db_type");

  $fo1 = $o5->bb2;
  ok($fo1 && ref $fo1 && $fo1->id == 4, "bb foreign object 2 - $db_type");

  $objs = 
    MyPgObjectManager->get_objectz(
      share_db     => 1,
      query_is_sql => 1,
      query        =>
      [
        't1.id'    => { ge => 2 },
        't1.name'  => { like => '%tt%' },
      ],
      require_objects => [ 'other_obj', 'bb1', 'bb2' ]);

  ok(ref $objs->[0]->{'other_obj'} eq 'MyPgOtherObject', "foreign object 2 - $db_type");
  is($objs->[0]->other_obj->k2, 2, "foreign object 3 - $db_type");

  is($objs->[0]->bb1->name, 'two', "bb foreign object 3 - $db_type");
  is($objs->[0]->bb2->name, 'four', "bb foreign object 4 - $db_type");

  $iterator =
    MyPgObjectManager->get_objectz_iterator(
      share_db     => 1,
      query_is_sql => 1,
      query        =>
      [
        't1.id'    => { ge => 2 },
        't1.name'  => { like => '%tt%' },
      ],
      require_objects => [ 'other_obj', 'bb1', 'bb2' ]);

  $o = $iterator->next;

  ok(ref $o->{'other_obj'} eq 'MyPgOtherObject', "foreign object 4 - $db_type");
  is($o->other_obj->k2, 2, "foreign object 5 - $db_type");

  is($o->bb1->name, 'two', "bb foreign object 5 - $db_type");
  is($o->bb2->name, 'four', "bb foreign object 6 - $db_type");

  # Start "one to many" tests

  $fo = MyPgNick->new(id   => 1,
                      o_id => 5,
                      nick => 'none');
  ok($fo->save, "nick object save() 1 - $db_type");

  $fo = MyPgNick->new(id   => 2,
                      o_id => 2,
                      nick => 'ntwo');
  ok($fo->save, "nick object save() 2 - $db_type");

  $fo = MyPgNick->new(id   => 3,
                      o_id => 5,
                      nick => 'nthree');
  ok($fo->save, "nick object save() 3 - $db_type");

  $fo = MyPgNick->new(id   => 4,
                      o_id => 2,
                      nick => 'nfour');
  ok($fo->save, "nick object save() 4 - $db_type");

  $fo = MyPgNick->new(id   => 5,
                      o_id => 5,
                      nick => 'nfive');
  ok($fo->save, "nick object save() 5 - $db_type");

  $fo = MyPgNick->new(id   => 6,
                      o_id => 5,
                      nick => 'nsix');
  ok($fo->save, "nick object save() 6 - $db_type");

  #local $Rose::DB::Object::Manager::Debug = 1;

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyPgObject',
      share_db     => 1,
      with_objects => [ 'nicks' ],
      query        =>
      [
        't1.id'    => { ge => 1 },
        't1.name'  => 'Betty',  
        flag       => 'f',
        flag2      => 1,
        bits       => '10101',
        't2.nick'  => { like => 'n%' },
        start      => '5/20/2002',
        '!start'   => { gt => DateTime->new(year  => '2005', 
                                            month => 12,
                                            day   => 1) },
        '!rose_db_object_test.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 12,
                              day   => 2)
        },

        '!t1.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 12,
                              day   => 3)
        },

        save_col   => [ 1, 5, 123 ],
        nums       => [ 4, 5, 6 ],
        fk1        => 1,
        last_modified => { le => '6/6/2020' }, # XXX: breaks in 2020!
        date_created  => '5/10/2002 10:34:56 am'
      ],
      clauses => [ "LOWER(status) LIKE 'w%'" ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() with many 2 - $db_type");

  my $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many 3 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many 4 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many 5 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many 6 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many 7 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyPgObject',
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks', 'bb1' ],
      query        =>
      [
        't1.id'    => { ge => 1 },
        't1.name'  => 'Betty',  
        flag       => 'f',
        flag2      => 1,
        bits       => '10101',
        't3.nick'  => { like => 'n%' },
        start      => '5/20/2002',
        '!start'   => { gt => DateTime->new(year  => '2005', 
                                            month => 12,
                                            day   => 1) },
        '!rose_db_object_test.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 12,
                              day   => 2)
        },

        '!t1.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 12,
                              day   => 3)
        },

        save_col   => [ 1, 5, 123 ],
        nums       => [ 4, 5, 6 ],
        fk1        => 1,
        last_modified => { le => '6/6/2020' }, # XXX: breaks in 2020!
        date_created  => '5/10/2002 10:34:56 am'
      ],
      clauses => [ "LOWER(status) LIKE 'w%'" ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 8 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() with many 9 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many 10 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many 11 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many 12 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many 13 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many 14 - $db_type");

  $fo1 = $objs->[0]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects() with many bb1 1 - $db_type");

  $fo1 = $objs->[0]->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects() with many bb2 2 - $db_type");

  $iterator = 
    MyPgObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name');

  is(ref $iterator, 'Rose::DB::Object::Iterator', "get_objects_iterator() 1 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Betty', "iterator many next() 1 - $db_type");
  is($o->id, 5, "iterator many next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Bob', "iterator many next() 3 - $db_type");
  is($o->id, 4, "iterator many next() 4 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator many next() 5 - $db_type");
  is($o->id, 2, "iterator many next() 6 - $db_type");
  is(scalar @{$o->{'nicks'}}, 2, "iterator many sub-object 1 - $db_type");
  is($o->{'nicks'}[0]{'nick'}, 'ntwo', "iterator many sub-object 2 - $db_type");
  is($o->{'nicks'}[1]{'nick'}, 'nfour', "iterator many sub-object 3 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Sue', "iterator many next() 7 - $db_type");
  is($o->id, 3, "iterator many next() 8 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator many next() 9 - $db_type");
  is($iterator->total, 4, "iterator many total() - $db_type");

  $iterator = 
    MyPgObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 2);

  $o = $iterator->next;
  is($o->name, 'Betty', "iterator limit 2 many next() 1 - $db_type");
  is($o->id, 5, "iterator limit 2 many next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Bob', "iterator limit 2 many next() 3 - $db_type");
  is($o->id, 4, "iterator limit 2 many next() 4 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator limit 2 many next() 5 - $db_type");
  is($iterator->total, 2, "iterator limit 2 many total() - $db_type");

  $iterator = 
    MyPgObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 3);

  $o = $iterator->next;
  is($o->name, 'Betty', "iterator limit 3 many next() 1 - $db_type");
  is($o->id, 5, "iterator limit 3 many next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Bob', "iterator limit 3 many next() 3 - $db_type");
  is($o->id, 4, "iterator limit 3 many next() 4 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator limit 3 many next() 5 - $db_type");
  is($o->id, 2, "iterator limit 3 many next() 6 - $db_type");
  is(scalar @{$o->{'nicks'}}, 2, "iterator limit 3 many sub-object 1 - $db_type");
  is($o->{'nicks'}[0]{'nick'}, 'ntwo', "iterator limit 3 many sub-object 2 - $db_type");
  is($o->{'nicks'}[1]{'nick'}, 'nfour', "iterator limit 3 many sub-object 3 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator limit 3 many next() 7 - $db_type");
  is($iterator->total, 3, "iterator limit 3 many total() - $db_type");

  $objs = 
    MyPgObjectManager->get_objectz(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 2);

  ok(ref $objs && @$objs == 2, "get_objects() limit 2 many 1 - $db_type");
  is($objs->[0]->name, 'Betty', "get_objects() limit 2 many 2 - $db_type");
  is($objs->[0]->id, 5, "get_objects() limit 2 many 3 - $db_type");

  is($objs->[1]->name, 'Bob', "get_objects() limit 2 many 4 - $db_type");
  is($objs->[1]->id, 4, "get_objects() limit 2 many 5 - $db_type");

  $objs = 
    MyPgObjectManager->get_objectz(
      share_db     => 1,
      with_objects => [ 'nicks', 'bb2' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 3);

  ok(ref $objs && @$objs == 3, "get_objects() limit 3 many 1 - $db_type");
  is($objs->[0]->name, 'Betty', "get_objects() limit 3 many 2 - $db_type");
  is($objs->[0]->id, 5, "get_objects() limit 3 many 3 - $db_type");

  is($objs->[1]->name, 'Bob', "get_objects() limit 3 many 4 - $db_type");
  is($objs->[1]->id, 4, "get_objects() limit 3 many 5 - $db_type");

  is($objs->[2]->name, 'Fred', "get_objects() limit 3 many 6 - $db_type");
  is($objs->[2]->id, 2, "get_objects() limit 3 many 7 - $db_type");
  is(scalar @{$objs->[2]->{'nicks'}}, 2, 'get_objects() limit 3 many sub-object 1');
  is($objs->[2]->{'nicks'}[0]{'nick'}, 'ntwo', 'get_objects() limit 3 many sub-object 2');
  is($objs->[2]->{'nicks'}[1]{'nick'}, 'nfour', 'get_objects() limit 3 many sub-object 3');

  $iterator = 
    MyPgObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 2,
      offset  => 1);

  $o = $iterator->next;
  is($o->name, 'Bob', "iterator limit 2 offset 1 many next() 1 - $db_type");
  is($o->id, 4, "iterator limit 2 offset 1 many next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator limit 2 offset 1 many next() 3 - $db_type");
  is($o->id, 2, "iterator limit 2 offset 1 many next() 4 - $db_type");
  is(scalar @{$o->{'nicks'}}, 2, 'iterator limit 2 offset 1 many sub-object 1');
  is($o->{'nicks'}[0]{'nick'}, 'ntwo', 'iterator limit 2 offset 1 many sub-object 2');
  is($o->{'nicks'}[1]{'nick'}, 'nfour', 'iterator limit 2 offset 1 many sub-object 3');

  $o = $iterator->next;
  is($o, 0, "iterator limit 2 offset 1 many next() 5 - $db_type");
  is($iterator->total, 2, "iterator limit 2 offset 1 many total() - $db_type");

  $iterator = 
    MyPgObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 3,
      offset  => 2);

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator limit 3 offset 2 many next() 1 - $db_type");
  is($o->id, 2, "iterator limit 3 offset 2 many next() 2 - $db_type");
  is(scalar @{$o->{'nicks'}}, 2, 'iterator limit 3 offset 2 many sub-object 1');
  is($o->{'nicks'}[0]{'nick'}, 'ntwo', 'iterator limit 3 offset 2 many sub-object 2');
  is($o->{'nicks'}[1]{'nick'}, 'nfour', 'iterator limit 3 offset 2 many sub-object 3');

  $o = $iterator->next;
  is($o->name, 'Sue', "iterator limit 3 offset 2 many next() 3 - $db_type");
  is($o->id, 3, "iterator limit 3 offset 2 many next() 4 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator limit 3 offset 2 many next() 5 - $db_type");
  is($iterator->total, 2, "iterator limit 3 offset 2 many total() - $db_type");

  $objs = 
    MyPgObjectManager->get_objectz(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 2,
      offset  => 1);

  ok(ref $objs && @$objs == 2, "get_objects() limit 2 offset 1 many 1 - $db_type");
  is($objs->[0]->name, 'Bob', "get_objects() limit 2 offset 1 many 2 - $db_type");
  is($objs->[0]->id, 4, "get_objects() limit 2 offset 1 many 3 - $db_type");

  is($objs->[1]->name, 'Fred', "get_objects() limit 2 offset 1 many 4 - $db_type");
  is($objs->[1]->id, 2, "get_objects() limit 2 offset 1 many 5 - $db_type");
  is(scalar @{$objs->[1]->{'nicks'}}, 2, 'get_objects() limit 2 offset 1 many sub-object 1');
  is($objs->[1]->{'nicks'}[0]{'nick'}, 'ntwo', 'get_objects() limit 2 offset 1 many sub-object 2');
  is($objs->[1]->{'nicks'}[1]{'nick'}, 'nfour', 'get_objects() limit 2 offset 1 many sub-object 3');

  $objs = 
    MyPgObjectManager->get_objectz(
      share_db     => 1,
      with_objects => [ 'nicks', 'bb2' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 3,
      offset  => 2);

  ok(ref $objs && @$objs == 2, "get_objects() limit 3 offset 2 many 1 - $db_type");

  is($objs->[0]->name, 'Fred', "get_objects() limit 3 offset 2 many 2 - $db_type");
  is($objs->[0]->id, 2, "get_objects() limit 3 offset 2 many 3 - $db_type");
  is(scalar @{$objs->[0]->{'nicks'}}, 2, 'get_objects() limit 3 offset 2 many sub-object 1');
  is($objs->[0]->{'nicks'}[0]{'nick'}, 'ntwo', 'get_objects() limit 3 offset 2 many sub-object 2');
  is($objs->[0]->{'nicks'}[1]{'nick'}, 'nfour', 'get_objects() limit 3 offset 2 many sub-object 3');

  is($objs->[1]->name, 'Sue', "get_objects() limit 3 offset 2 many 4 - $db_type");
  is($objs->[1]->id, 3, "get_objects() limit 3 offset 2 many 5 - $db_type");

  my $o6 = $o2->clone;
  $o6->id(60);
  $o6->fkone(undef);
  $o6->fk2(undef);
  $o6->fk3(undef);
  $o6->b1(undef);
  $o6->b2(2);
  $o6->name('Ted');

  ok($o6->save, "object save() 8 - $db_type");

  my $o7 = $o2->clone;
  $o7->id(70);
  $o7->b1(3);
  $o7->b2(undef);
  $o7->name('Joe');

  ok($o7->save, "object save() 9 - $db_type");

  my $o8 = $o2->clone;
  $o8->id(80);
  $o8->b1(undef);
  $o8->b2(undef);
  $o8->name('Pete');

  ok($o8->save, "object save() 10 - $db_type");

  $fo = MyPgNick->new(id   => 7,
                      o_id => 60,
                      nick => 'nseven');

  ok($fo->save, "nick object save() 7 - $db_type");

  $fo = MyPgNick->new(id   => 8,
                      o_id => 60,
                      nick => 'neight');

  ok($fo->save, "nick object save() 8 - $db_type");

  $fo = MyPgNick->new(id   => 9,
                      o_id => 60,
                      nick => 'neight');

  ok($fo->save, "nick object save() 8 - $db_type");

  $fo = MyPgNick2->new(id    => 1,
                       o_id  => 5,
                       nick2 => 'n2one');

  ok($fo->save, "nick2 object save() 1 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyPgObject',
      share_db     => 1,
      require_objects => [ 'bb2', 'bb1' ],
      query        => [ '!t1.id' => 5 ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 15 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 0, "get_objects() with many 16 - $db_type");

  $count = 
    Rose::DB::Object::Manager->get_objects_count(
      object_class => 'MyPgObject',
      share_db     => 1,
      require_objects => [ 'bb2', 'bb1' ],
      with_objects    => [ 'nicks' ],
      query        => [ ],
      sort_by => 't1.id');

  is($count, 1, "get_objects_count() require 1 - $db_type"); 

  #local $Rose::DB::Object::Manager::Debug = 1;  
  #$DB::single = 1;

  $count = 
    Rose::DB::Object::Manager->get_objects_count(
      object_class => 'MyPgObject',
      share_db     => 1,
      require_objects => [ 'bb2' ],
      with_objects    => [ 'nicks' ],
      query        => [ ],
      sort_by => 't1.id');

  is($count, 2, "get_objects_count() require 2 - $db_type"); 

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyPgObject',
      share_db     => 1,
      require_objects => [ 'bb2', 'bb1' ],
      with_objects    => [ 'nicks' ],
      query        => [ ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 17 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() with many 18 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with many 19 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many 20 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many 21 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many 22 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many 23 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many 24 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyPgObject',
      share_db     => 1,
      require_objects => [ 'bb1', 'bb2' ],
      with_objects    => [ 'nicks2', 'nicks' ],
      multi_many_ok   => 1,
      query        => [ ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with multi many 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() with multi many 2 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with multi many 3 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with multi many 4 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with multi many 5 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with multi many 6 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with multi many 7 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with multi many 8 - $db_type");

  is($objs->[0]->{'nicks2'}[0]{'nick2'}, 'n2one', "get_objects() with multi many 9 - $db_type");

  $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class => 'MyPgObject',
      share_db     => 1,
      require_objects => [ 'bb1', 'bb2' ],
      with_objects    => [ 'nicks2', 'nicks' ],
      multi_many_ok   => 1,
      query        => [ ],
      sort_by => 't1.id');

  $o = $iterator->next;
  is($o->name, 'Betty', "iterator with and require 1 - $db_type");
  is($o->id, 5, "iterator with and require 2 - $db_type");

  $nicks = $o->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "iterator with and require 3 - $db_type");
  is($nicks->[0]->nick, 'nthree', "iterator with and require 4 - $db_type");
  is($nicks->[1]->nick, 'nsix', "iterator with and require 5 - $db_type");
  is($nicks->[2]->nick, 'none', "iterator with and require 6 - $db_type");
  is($nicks->[3]->nick, 'nfive', "iterator with and require 7 - $db_type");

  is($o->{'nicks2'}[0]{'nick2'}, 'n2one', "iterator with and require 8 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator with and require 9 - $db_type");
  is($iterator->total, 1, "iterator with and require 10 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyPgObject',
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks', 'bb1' ],
      query        => [ ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 25 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 8, "get_objects() with many 26 - $db_type");

  my $ids = join(',', map { $_->id } @$objs);

  is($ids, '1,2,3,4,5,60,70,80', "get_objects() with many 27 - $db_type");

  $nicks = $objs->[4]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many 28 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many 29 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many 30 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many 31 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many 32 - $db_type");

  is($objs->[6]->{'bb1'}->{'name'}, 'three', "get_objects() with many 33 - $db_type");
  ok(!defined $objs->[6]->{'bb2'}, "get_objects() with many 34 - $db_type");
  ok(!defined $objs->[6]->{'nicks'}, "get_objects() with many 35 - $db_type");

  ok(!defined $objs->[7]->{'bb1'}, "get_objects() with many 36 - $db_type");
  ok(!defined $objs->[7]->{'bb1'}, "get_objects() with many 37 - $db_type");
  ok(!defined $objs->[7]->{'nicks'}, "get_objects() with many 38 - $db_type");

  local $Rose::DB::Object::Manager::Debug = 0;

  $fo = MyPgNick->new(id => 7);
  ok($fo->delete, "with many clean-up 1 - $db_type");

  $fo = MyPgNick->new(id => 8);
  ok($fo->delete, "with many clean-up 2 - $db_type");

  $fo = MyPgNick->new(id => 9);
  ok($fo->delete, "with many clean-up 3 - $db_type");

  ok($o6->delete, "with many clean-up 4 - $db_type");
  ok($o7->delete, "with many clean-up 5 - $db_type");
  ok($o8->delete, "with many clean-up 6 - $db_type");

  $fo = MyPgNick2->new(id => 1);
  ok($fo->delete, "with many clean-up 7 - $db_type");

  # End "one to many" tests

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyPgObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 1 },
        name       => 'John',  
        flag       => 1,
        flag2      => 0,
        status     => 'active',
        bits       => '1',
        start      => '1/2/2001',
        '!start'   => { gt => DateTime->new(year  => '2005', 
                                            month => 1,
                                            day   => 1) },
        '!rose_db_object_test.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 2,
                              day   => 2)
        },

        '!t1.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 3,
                              day   => 3)
        },

        save_col   => [ 1, 5 ],
        nums       => [ 1, 2, 3 ],
        fk1        => 2,
        last_modified => { le => '6/6/2020' }, # XXX: breaks in 2020!
        date_created  => '3/30/2004 12:34:56 pm'
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() 7 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() 8 - $db_type");

  $objs = 
    MyPgObjectManager->get_objectz(
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        k1         => { lt => 900 },
        or         => [ k1 => { ne => 99 }, k1 => 100 ],
        or         => [ and => [ id => { ne => 123 }, id => { lt => 100  } ],
                        and => [ id => { ne => 456 }, id => { lt => 300  } ] ],
        '!k2'      => { gt => 999 },
        '!t2.name' => 'z',
        start      => { lt => DateTime->new(year => '2005', month => 1, day => 1) },
        '!start'   => { gt => DateTime->new(year => '2005', month => 1, day => 1) },
        'rose_db_object_test.name'   => { like => '%tt%' },
        '!rose_db_object_other.name' => 'q',
        '!rose_db_object_other.name' => [ 'x', 'y' ],
      ],
      require_objects => [ 'other_obj' ]);

  ok(ref $objs->[0]->{'other_obj'} eq 'MyPgOtherObject', "foreign object 6 - $db_type");
  is($objs->[0]->other_obj->k2, 2, "foreign object 7 - $db_type");

  # Test limit with offset

  foreach my $id (6 .. 20)
  {
    my $o = $o5->clone;
    $o->id($id);
    $o->name("Clone $id");

    ok($o->save, "object save() clone $id - $db_type");
  }

  $objs = 
    MyPgObjectManager->get_objectz(
      object_class => 'MyPgObject',
      sort_by      => 'id DESC',
      limit        => 2,
      offset       => 8);

  ok(ref $objs eq 'ARRAY' && @$objs == 2 && 
     $objs->[0]->id == 12 && $objs->[1]->id == 11,
     "get_objects() with offset - $db_type");

  $objs = 
    MyPgObjectManager->get_objectz(
      object_class => 'MyPgObject',
      sort_by      => 'id DESC',
      require_objects => [ 'other_obj' ],
      limit        => 2,
      offset       => 8);

  ok(ref $objs eq 'ARRAY' && @$objs == 2 && 
     $objs->[0]->id == 12 && $objs->[1]->id == 11,
     "get_objects() with objects and offset - $db_type");

  $iterator = 
    MyPgObjectManager->get_objectz_iterator(
      object_class => 'MyPgObject',
      sort_by      => 'id DESC',
      limit        => 2,
      offset       => 8);

  $o = $iterator->next;
  is($o->id, 12, "get_objects_iterator() with offset 1 - $db_type");

  $o = $iterator->next;
  is($o->id, 11, "get_objects_iterator() with offset 2 - $db_type");

  is($iterator->next, 0, "get_objects_iterator() with offset 3 - $db_type");

  eval
  {
    $objs = 
      MyPgObjectManager->get_objectz(
        object_class => 'MyPgObject',
        sort_by      => 'id DESC',
        offset       => 8)
  };

  ok($@ =~ /invalid without a limit/, "get_objects() missing offset - $db_type");

  eval
  {
    $iterator = 
      MyPgObjectManager->get_objectz_iterator(
        object_class => 'MyPgObject',
        sort_by      => 'id DESC',
        offset       => 8);
  };

  ok($@ =~ /invalid without a limit/, "get_objects_iterator() missing offset - $db_type");

  # Start *_sql comparison tests

  $o6->fk2(99);
  $o6->fk3(99);
  $o6->save;

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyPgObject',
      query        => [ 'fk2' => { eq_sql => 'fk3' } ],
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() eq_sql 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() eq_sql 2 - $db_type");

  is($objs->[0]->id, 60, "get_objects() eq_sql 3 - $db_type");

  # End *_sql comparison tests

  # Start "many to many" tests

  $fo = MyPgColor->new(id => 1, name => 'Red');
  $fo->save;

  $fo = MyPgColor->new(id => 2, name => 'Green');
  $fo->save;

  $fo = MyPgColor->new(id => 3, name => 'Blue');
  $fo->save;

  $fo = MyPgColorMap->new(id => 1, object_id => $o2->id, color_id => 1);
  $fo->save;

  $fo = MyPgColorMap->new(id => 2, object_id => $o2->id, color_id => 3);
  $fo->save;

  $o2->b1(4);
  $o2->b1(2);
  $o2->fkone(2);
  $o2->fk2(3);
  $o2->fk3(4);
  $o2->save;

  my @colors = $o2->colors;
  ok(@colors == 2 && $colors[0]->name eq 'Red' &&
     $colors[1]->name eq 'Blue', "Fetch many to many 1 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class  => 'MyPgObject',
      share_db      => 1,
      with_objects  => [ 'other_obj', 'bb2', 'nicks', 'bb1', 'colors' ],
      multi_many_ok => 1,
      query         => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by       => 't1.name');

  is(ref $objs, 'ARRAY', "get_objects() with many to many 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 3, "get_objects() with many to many 2 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with many to many 3 - $db_type");
  is($objs->[1]->id, 2, "get_objects() with many to many 4 - $db_type");
  is($objs->[2]->id, 1, "get_objects() with many to many 5 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many to many 6 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many to many 7 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many to many 8 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many to many 9 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many to many 10 - $db_type");

  $fo1 = $objs->[0]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects() with many to many 11 - $db_type");

  $fo1 = $objs->[0]->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects() with many to many 12 - $db_type");

  my $colors = $objs->[1]->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects() with many to many 13 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects() with many to many 14 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects() with many to many 15 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class  => 'MyPgObject',
      share_db      => 1,
      with_objects  => [ 'bb1', 'nicks', 'other_obj', 'colors', 'bb2' ],
      multi_many_ok => 1,
      query         => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by       => 't1.name');

  is(ref $objs, 'ARRAY', "get_objects() with many to many (reorder) 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 3, "get_objects() with many to many (reorder) 2 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with many to many (reorder) 3 - $db_type");
  is($objs->[1]->id, 2, "get_objects() with many to many (reorder) 4 - $db_type");
  is($objs->[2]->id, 1, "get_objects() with many to many (reorder) 5 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many to many (reorder) 6 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many to many (reorder) 7 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many to many (reorder) 8 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many to many (reorder) 9 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many to many (reorder) 10 - $db_type");

  $fo1 = $objs->[0]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects() with many to many (reorder) 11 - $db_type");

  $fo1 = $objs->[0]->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects() with many to many (reorder) 12 - $db_type");

  $colors = $objs->[1]->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects() with many to many (reorder) 13 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects() with many to many (reorder) 14 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects() with many to many (reorder) 15 - $db_type");

  #local $Rose::DB::Object::Manager::Debug = 1;
  #$DB::single = 1;

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class    => 'MyPgObject',
      share_db        => 1,
      with_objects    => [ 'nicks', 'colors', 'bb2' ],
      multi_many_ok   => 1,
      require_objects => [ 'bb1', 'other_obj' ],
      query           => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by         => 't1.name');

  is(ref $objs, 'ARRAY', "get_objects() with many to many require with 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 2, "get_objects() with many to many require with 2 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with many to many require with 3 - $db_type");
  is($objs->[1]->id, 2, "get_objects() with many to many require with 4 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many to many require with 6 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many to many 7 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many to many 8 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many to many 9 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many to many 10 - $db_type");

  $fo1 = $objs->[0]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects() with many to many require with 11 - $db_type");

  $fo1 = $objs->[0]->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects() with many to many require with 12 - $db_type");

  $colors = $objs->[1]->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects() with many to many require with 13 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects() with many to many require with 14 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects() with many to many require with 15 - $db_type");

  $fo1 = $objs->[1]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'two', "get_objects() with many to many require with 16 - $db_type");

  $fo1 = $objs->[0]->{'other_obj'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'Foo 1', "get_objects() with many to many require with 17 - $db_type");

  $fo1 = $objs->[1]->{'other_obj'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'Foo 2', "get_objects() with many to many require with 18 - $db_type");

  ok(!defined $objs->[0]->{'colors'}, "get_objects() with many to many require with 19 - $db_type");
  ok(!defined $objs->[1]->{'bb2'}, "get_objects() with many to many require with 20 - $db_type");

  #local $Rose::DB::Object::Manager::Debug = 1;
  #$DB::single = 1;

  $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class  => 'MyPgObject',
      share_db      => 1,
      with_objects  => [ 'other_obj', 'bb2', 'nicks', 'bb1', 'colors' ],
      multi_many_ok => 1,
      query         => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by       => 't1.name');

  $o = $iterator->next;
  is($o->name, 'Betty', "get_objects_iterator() with many to many 1 - $db_type");
  is($o->id, 5, "get_objects_iterator() with many to many 2 - $db_type");

  $nicks = $o->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects_iterator() with many to many 3 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects_iterator() with many to many 4 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects_iterator() with many to many 5 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects_iterator() with many to many 6 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects_iterator() with many to many 7 - $db_type");

  $fo1 = $o->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects_iterator() with many to many 8 - $db_type");

  $fo1 = $o->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects_iterator() with many to many 9 - $db_type"); 

  $o = $iterator->next;
  is($o->name, 'Fred', "get_objects_iterator() with many to many 10 - $db_type");
  is($o->id, 2, "get_objects_iterator() with many to many 11 - $db_type");

  $colors = $o->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects_iterator() with many to many 12 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many 13 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many 14 - $db_type");

  $o = $iterator->next;
  is($o->name, 'John', "get_objects_iterator() with many to many 15 - $db_type");
  is($o->id, 1, "get_objects_iterator() with many to many 16 - $db_type");

  $o = $iterator->next;
  is($o, 0, "get_objects_iterator() with many to many 17 - $db_type");
  is($iterator->total, 3, "get_objects_iterator() with many to many 18 - $db_type");

  $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class  => 'MyPgObject',
      share_db      => 1,
      with_objects  => [ 'bb1', 'nicks', 'other_obj', 'colors', 'bb2' ],
      multi_many_ok => 1,
      query         => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by       => 't1.name');

  $o = $iterator->next;
  is($o->name, 'Betty', "get_objects_iterator() with many to many 19 - $db_type");
  is($o->id, 5, "get_objects_iterator() with many to many 20 - $db_type");

  $nicks = $o->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects_iterator() with many to many 21 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects_iterator() with many to many 22 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects_iterator() with many to many 23 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects_iterator() with many to many 24 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects_iterator() with many to many 25 - $db_type");

  $fo1 = $o->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects_iterator() with many to many 26 - $db_type");

  $fo1 = $o->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects_iterator() with many to many 27 - $db_type"); 

  $o = $iterator->next;
  is($o->name, 'Fred', "get_objects_iterator() with many to many 28 - $db_type");
  is($o->id, 2, "get_objects_iterator() with many to many 29 - $db_type");

  $colors = $o->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects_iterator() with many to many 30 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many 31 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many 32 - $db_type");

  $o = $iterator->next;
  is($o->name, 'John', "get_objects_iterator() with many to many 33 - $db_type");
  is($o->id, 1, "get_objects_iterator() with many to many 34 - $db_type");

  $o = $iterator->next;
  is($o, 0, "get_objects_iterator() with many to many 35 - $db_type");
  is($iterator->total, 3, "get_objects_iterator() with many to many 36 - $db_type");

  $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class    => 'MyPgObject',
      share_db        => 1,
      with_objects    => [ 'nicks', 'colors', 'bb2' ],
      multi_many_ok   => 1,
      require_objects => [ 'bb1', 'other_obj' ],
      query           => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by         => 't1.name');

  $o = $iterator->next;
  is($o->name, 'Betty', "get_objects_iterator() with many to many require 1 - $db_type");
  is($o->id, 5, "get_objects_iterator() with many to many require 2 - $db_type");

  $fo1 = $o->{'other_obj'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'Foo 1', "get_objects_iterator() with many to many require 3 - $db_type");

  ok(!defined $o->{'colors'}, "get_objects_iterator() with many to many require 4 - $db_type");

  $nicks = $o->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects_iterator() with many to many require 5 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects_iterator() with many to many require 6 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects_iterator() with many to many require 7 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects_iterator() with many to many require 8 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects_iterator() with many to many require 9 - $db_type");

  $fo1 = $o->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects_iterator() with many to many require 10 - $db_type");

  $fo1 = $o->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects_iterator() with many to many require 11 - $db_type"); 

  $o = $iterator->next;
  is($o->name, 'Fred', "get_objects_iterator() with many to many require 12 - $db_type");
  is($o->id, 2, "get_objects_iterator() with many to many require 13 - $db_type");

  $colors = $o->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects_iterator() with many to many require 14 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many require 15 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many require 16 - $db_type");

  $fo1 = $o->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'two', "get_objects_iterator() with many to many require 17 - $db_type");

  $fo1 = $o->{'other_obj'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'Foo 2', "get_objects_iterator() with many to many require 18 - $db_type");

  ok(!defined $o->{'bb2'}, "get_objects_iterator() with many to many require 19 - $db_type");

  $o = $iterator->next;
  is($o, 0, "get_objects_iterator() with many to many require 20 - $db_type");
  is($iterator->total, 2, "get_objects_iterator() with many to many require 21 - $db_type");

  # End "many to many" tests
}

#
# MySQL
#

SKIP: foreach my $db_type ('mysql')
{
  skip("MySQL tests", 337)  unless($HAVE_MYSQL);

  Rose::DB->default_type($db_type);

  my $o = MyMySQLObject->new(id         => 1,
                             name       => 'John',  
                             flag       => 1,
                             flag2      => 0,
                             fkone      => 2,
                             status     => 'active',
                             bits       => '00001',
                             start      => '2001-01-02',
                             save_col   => 5,
                             nums       => [ 1, 2, 3 ],
                             last_modified => 'now',
                             date_created  => '2004-03-30 12:34:56');

  ok($o->save, "object save() 1 - $db_type");

  my $objs = 
    MyMySQLObject->get_objectz(
      share_db     => 1,
      query        =>
      [
        id         => { ge => 1 },
        name       => 'John',  
        flag       => 1,
        flag2      => 0,
        status     => 'active',
        bits       => '00001',
        or         => [ and => [ '!bits' => '00001', bits => { ne => '11111' } ],
                        and => [ bits => { lt => '10101' }, '!bits' => '10000' ] ],
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56'
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() 2 - $db_type");

  my $o2 = $o->clone;
  $o2->id(2);
  $o2->name('Fred');

  ok($o2->save, "object save() 2 - $db_type");

  my $o3 = $o2->clone;
  $o3->id(3);
  $o3->name('Sue');

  ok($o3->save, "object save() 3 - $db_type");

  my $o4 = $o3->clone;
  $o4->id(4);
  $o4->name('Bob');

  ok($o4->save, "object save() 4 - $db_type");

  $objs = 
    MyMySQLObjectManager->get_objectz(
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 1,
        flag2      => 0,
        status     => 'active',
        bits       => '00001',
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name DESC');

  is(ref $objs, 'ARRAY', "get_objects() 3 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 2, "get_objects() 4 - $db_type");
  is($objs->[0]->id, 3, "get_objects() 5 - $db_type");
  is($objs->[1]->id, 2, "get_objects() 6 - $db_type");

  my $count =
    MyMySQLObject->get_objectz_count(
      with_objects => [ 'nicks', 'bb1', 'bb2' ],
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 1,
        flag2      => 0,
        status     => 'active',
        bits       => '00001',
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      sort_by => 'name DESC');

  is($count, 2, "get_objects_count() 1 - $db_type");

  my $iterator = 
    MyMySQLObjectManager->get_objectz_iterator(
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 1,
        flag2      => 0,
        status     => 'active',
        bits       => '00001',
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name');

  is(ref $iterator, 'Rose::DB::Object::Iterator', "get_objects_iterator() 3 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator next() 1 - $db_type");
  is($o->id, 2, "iterator next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Sue', "iterator next() 3 - $db_type");
  is($o->id, 3, "iterator next() 4 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator next() 5 - $db_type");
  is($iterator->total, 2, "iterator total() - $db_type");

  my $fo = MyMySQLOtherObject->new(name => 'Foo 1',
                                   k1   => 1,
                                   k2   => 2,
                                   k3   => 3);

  ok($fo->save, "object save() 5 - $db_type");

  $fo = MyMySQLOtherObject->new(name => 'Foo 2',
                                k1   => 2,
                                k2   => 3,
                                k3   => 4);

  ok($fo->save, "object save() 6 - $db_type");

  $fo = MyMySQLBB->new(id   => 1,
                       name => 'one');
  ok($fo->save, "bb object save() 1 - $db_type");

  $fo = MyMySQLBB->new(id   => 2,
                       name => 'two');
  ok($fo->save, "bb object save() 2 - $db_type");

  $fo = MyMySQLBB->new(id   => 3,
                       name => 'three');
  ok($fo->save, "bb object save() 3 - $db_type");

  $fo = MyMySQLBB->new(id   => 4,
                       name => 'four');
  ok($fo->save, "bb object save() 4 - $db_type");

  my $o5 = MyMySQLObject->new(id         => 5,
                              name       => 'Betty',  
                              flag       => 'f',
                              flag2      => 't',
                              status     => 'with',
                              bits       => '10101',
                              start      => '2002-05-20',
                              save_col   => 123,
                              nums       => [ 4, 5, 6 ],
                              fkone      => 1,
                              fk2        => 2,
                              fk3        => 3,
                              b1         => 2,
                              b2         => 4,
                              last_modified => '2001-01-10 20:34:56',
                              date_created  => '2002-05-10 10:34:56');

  ok($o5->save, "object save() 7 - $db_type");

  my $fo1 = $o5->other_obj;

  ok($fo1 && ref $fo1 && $fo1->k1 == 1 && $fo1->k2 == 2 && $fo1->k3 == 3,
     "foreign object 1 - $db_type");

  $fo1 = $o5->bb1;
  ok($fo1 && ref $fo1 && $fo1->id == 2, "bb foreign object 1 - $db_type");

  $fo1 = $o5->bb2;
  ok($fo1 && ref $fo1 && $fo1->id == 4, "bb foreign object 2 - $db_type");

  $objs = 
    MyMySQLObject->get_objectz(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      query        =>
      [
        't1.id'    => { ge => 2 },
        't1.name'  => { like => '%tt%' },
      ],
      require_objects => [ 'other_obj', 'bb1', 'bb2' ]);

  ok(ref $objs->[0]->{'other_obj'} eq 'MyMySQLOtherObject', "foreign object 2 - $db_type");
  is($objs->[0]->other_obj->k2, 2, "foreign object 3 - $db_type");

  is($objs->[0]->bb1->name, 'two', "bb foreign object 3 - $db_type");
  is($objs->[0]->bb2->name, 'four', "bb foreign object 4 - $db_type");

  # Start "one to many" tests

  $fo = MyMySQLNick->new(id   => 1,
                         o_id => 5,
                         nick => 'none');
  ok($fo->save, "nick object save() 1 - $db_type");

  $fo = MyMySQLNick->new(id   => 2,
                         o_id => 2,
                         nick => 'ntwo');
  ok($fo->save, "nick object save() 2 - $db_type");

  $fo = MyMySQLNick->new(id   => 3,
                         o_id => 5,
                         nick => 'nthree');
  ok($fo->save, "nick object save() 3 - $db_type");

  $fo = MyMySQLNick->new(id   => 4,
                         o_id => 2,
                         nick => 'nfour');
  ok($fo->save, "nick object save() 4 - $db_type");

  $fo = MyMySQLNick->new(id   => 5,
                         o_id => 5,
                         nick => 'nfive');
  ok($fo->save, "nick object save() 5 - $db_type");

  $fo = MyMySQLNick->new(id   => 6,
                         o_id => 5,
                         nick => 'nsix');
  ok($fo->save, "nick object save() 6 - $db_type");

  #local $Rose::DB::Object::Manager::Debug = 1;

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      with_objects => [ 'nicks' ],
      query        =>
      [
        't1.id'    => { ge => 1 },
        't1.name'  => 'Betty',  
        flag       => 'f',
        flag2      => 1,
        bits       => '10101',
        't2.nick'  => { like => 'n%' },
        start      => '5/20/2002',
        '!start'   => { gt => DateTime->new(year  => '2005', 
                                            month => 12,
                                            day   => 1) },
        '!rose_db_object_test.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 12,
                              day   => 2)
        },

        '!t1.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 12,
                              day   => 3)
        },

        save_col   => [ 1, 5, 123 ],
        nums       => [ 4, 5, 6 ],
        fk1        => 1,
        last_modified => { le => '6/6/2020' }, # XXX: breaks in 2020!
        date_created  => '5/10/2002 10:34:56 am'
      ],
      clauses => [ "LOWER(status) LIKE 'w%'" ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() with many 2 - $db_type");

  my $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many 3 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many 4 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many 5 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many 6 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many 7 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks', 'bb1' ],
      query        =>
      [
        't1.id'    => { ge => 1 },
        't1.name'  => 'Betty',  
        flag       => 'f',
        flag2      => 1,
        bits       => '10101',
        't3.nick'  => { like => 'n%' },
        start      => '5/20/2002',
        '!start'   => { gt => DateTime->new(year  => '2005', 
                                            month => 12,
                                            day   => 1) },
        '!rose_db_object_test.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 12,
                              day   => 2)
        },

        '!t1.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 12,
                              day   => 3)
        },

        save_col   => [ 1, 5, 123 ],
        nums       => [ 4, 5, 6 ],
        fk1        => 1,
        last_modified => { le => '6/6/2020' }, # XXX: breaks in 2020!
        date_created  => '5/10/2002 10:34:56 am'
      ],
      clauses => [ "LOWER(status) LIKE 'w%'" ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 8 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() with many 9 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many 10 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many 11 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many 12 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many 13 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many 14 - $db_type");

  $fo1 = $objs->[0]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects() with many bb1 1 - $db_type");

  $fo1 = $objs->[0]->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects() with many bb2 2 - $db_type");

  $iterator = 
    MyMySQLObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name');

  is(ref $iterator, 'Rose::DB::Object::Iterator', "get_objects_iterator() 1 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Betty', "iterator many next() 1 - $db_type");
  is($o->id, 5, "iterator many next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Bob', "iterator many next() 3 - $db_type");
  is($o->id, 4, "iterator many next() 4 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator many next() 5 - $db_type");
  is($o->id, 2, "iterator many next() 6 - $db_type");
  is(scalar @{$o->{'nicks'}}, 2, "iterator many sub-object 1 - $db_type");
  is($o->{'nicks'}[0]{'nick'}, 'ntwo', "iterator many sub-object 2 - $db_type");
  is($o->{'nicks'}[1]{'nick'}, 'nfour', "iterator many sub-object 3 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Sue', "iterator many next() 7 - $db_type");
  is($o->id, 3, "iterator many next() 8 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator many next() 9 - $db_type");
  is($iterator->total, 4, "iterator many total() - $db_type");

  $iterator = 
    MyMySQLObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 2);

  $o = $iterator->next;
  is($o->name, 'Betty', "iterator limit 2 many next() 1 - $db_type");
  is($o->id, 5, "iterator limit 2 many next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Bob', "iterator limit 2 many next() 3 - $db_type");
  is($o->id, 4, "iterator limit 2 many next() 4 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator limit 2 many next() 5 - $db_type");
  is($iterator->total, 2, "iterator limit 2 many total() - $db_type");

  $iterator = 
    MyMySQLObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 3);

  $o = $iterator->next;
  is($o->name, 'Betty', "iterator limit 3 many next() 1 - $db_type");
  is($o->id, 5, "iterator limit 3 many next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Bob', "iterator limit 3 many next() 3 - $db_type");
  is($o->id, 4, "iterator limit 3 many next() 4 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator limit 3 many next() 5 - $db_type");
  is($o->id, 2, "iterator limit 3 many next() 6 - $db_type");
  is(scalar @{$o->{'nicks'}}, 2, "iterator limit 3 many sub-object 1 - $db_type");
  is($o->{'nicks'}[0]{'nick'}, 'ntwo', "iterator limit 3 many sub-object 2 - $db_type");
  is($o->{'nicks'}[1]{'nick'}, 'nfour', "iterator limit 3 many sub-object 3 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator limit 3 many next() 7 - $db_type");
  is($iterator->total, 3, "iterator limit 3 many total() - $db_type");

  $objs = 
    MyMySQLObjectManager->get_objectz(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 2);

  ok(ref $objs && @$objs == 2, "get_objects() limit 2 many 1 - $db_type");
  is($objs->[0]->name, 'Betty', "get_objects() limit 2 many 2 - $db_type");
  is($objs->[0]->id, 5, "get_objects() limit 2 many 3 - $db_type");

  is($objs->[1]->name, 'Bob', "get_objects() limit 2 many 4 - $db_type");
  is($objs->[1]->id, 4, "get_objects() limit 2 many 5 - $db_type");

  $objs = 
    MyMySQLObjectManager->get_objectz(
      share_db     => 1,
      with_objects => [ 'nicks', 'bb2' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 3);

  ok(ref $objs && @$objs == 3, "get_objects() limit 3 many 1 - $db_type");
  is($objs->[0]->name, 'Betty', "get_objects() limit 3 many 2 - $db_type");
  is($objs->[0]->id, 5, "get_objects() limit 3 many 3 - $db_type");

  is($objs->[1]->name, 'Bob', "get_objects() limit 3 many 4 - $db_type");
  is($objs->[1]->id, 4, "get_objects() limit 3 many 5 - $db_type");

  is($objs->[2]->name, 'Fred', "get_objects() limit 3 many 6 - $db_type");
  is($objs->[2]->id, 2, "get_objects() limit 3 many 7 - $db_type");
  is(scalar @{$objs->[2]->{'nicks'}}, 2, 'get_objects() limit 3 many sub-object 1');
  is($objs->[2]->{'nicks'}[0]{'nick'}, 'ntwo', 'get_objects() limit 3 many sub-object 2');
  is($objs->[2]->{'nicks'}[1]{'nick'}, 'nfour', 'get_objects() limit 3 many sub-object 3');

  $iterator = 
    MyMySQLObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 2,
      offset  => 1);

  $o = $iterator->next;
  is($o->name, 'Bob', "iterator limit 2 offset 1 many next() 1 - $db_type");
  is($o->id, 4, "iterator limit 2 offset 1 many next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator limit 2 offset 1 many next() 3 - $db_type");
  is($o->id, 2, "iterator limit 2 offset 1 many next() 4 - $db_type");
  is(scalar @{$o->{'nicks'}}, 2, 'iterator limit 2 offset 1 many sub-object 1');
  is($o->{'nicks'}[0]{'nick'}, 'ntwo', 'iterator limit 2 offset 1 many sub-object 2');
  is($o->{'nicks'}[1]{'nick'}, 'nfour', 'iterator limit 2 offset 1 many sub-object 3');

  $o = $iterator->next;
  is($o, 0, "iterator limit 2 offset 1 many next() 5 - $db_type");
  is($iterator->total, 2, "iterator limit 2 offset 1 many total() - $db_type");

  $iterator = 
    MyMySQLObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 3,
      offset  => 2);

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator limit 3 offset 2 many next() 1 - $db_type");
  is($o->id, 2, "iterator limit 3 offset 2 many next() 2 - $db_type");
  is(scalar @{$o->{'nicks'}}, 2, 'iterator limit 3 offset 2 many sub-object 1');
  is($o->{'nicks'}[0]{'nick'}, 'ntwo', 'iterator limit 3 offset 2 many sub-object 2');
  is($o->{'nicks'}[1]{'nick'}, 'nfour', 'iterator limit 3 offset 2 many sub-object 3');

  $o = $iterator->next;
  is($o->name, 'Sue', "iterator limit 3 offset 2 many next() 3 - $db_type");
  is($o->id, 3, "iterator limit 3 offset 2 many next() 4 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator limit 3 offset 2 many next() 5 - $db_type");
  is($iterator->total, 2, "iterator limit 3 offset 2 many total() - $db_type");

  $objs = 
    MyMySQLObjectManager->get_objectz(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 2,
      offset  => 1);

  ok(ref $objs && @$objs == 2, "get_objects() limit 2 offset 1 many 1 - $db_type");
  is($objs->[0]->name, 'Bob', "get_objects() limit 2 offset 1 many 2 - $db_type");
  is($objs->[0]->id, 4, "get_objects() limit 2 offset 1 many 3 - $db_type");

  is($objs->[1]->name, 'Fred', "get_objects() limit 2 offset 1 many 4 - $db_type");
  is($objs->[1]->id, 2, "get_objects() limit 2 offset 1 many 5 - $db_type");
  is(scalar @{$objs->[1]->{'nicks'}}, 2, 'get_objects() limit 2 offset 1 many sub-object 1');
  is($objs->[1]->{'nicks'}[0]{'nick'}, 'ntwo', 'get_objects() limit 2 offset 1 many sub-object 2');
  is($objs->[1]->{'nicks'}[1]{'nick'}, 'nfour', 'get_objects() limit 2 offset 1 many sub-object 3');

  $objs = 
    MyMySQLObjectManager->get_objectz(
      share_db     => 1,
      with_objects => [ 'nicks', 'bb2' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 3,
      offset  => 2);

  ok(ref $objs && @$objs == 2, "get_objects() limit 3 offset 2 many 1 - $db_type");

  is($objs->[0]->name, 'Fred', "get_objects() limit 3 offset 2 many 2 - $db_type");
  is($objs->[0]->id, 2, "get_objects() limit 3 offset 2 many 3 - $db_type");
  is(scalar @{$objs->[0]->{'nicks'}}, 2, 'get_objects() limit 3 offset 2 many sub-object 1');
  is($objs->[0]->{'nicks'}[0]{'nick'}, 'ntwo', 'get_objects() limit 3 offset 2 many sub-object 2');
  is($objs->[0]->{'nicks'}[1]{'nick'}, 'nfour', 'get_objects() limit 3 offset 2 many sub-object 3');

  is($objs->[1]->name, 'Sue', "get_objects() limit 3 offset 2 many 4 - $db_type");
  is($objs->[1]->id, 3, "get_objects() limit 3 offset 2 many 5 - $db_type");

  my $o6 = $o2->clone;
  $o6->id(60);
  $o6->fkone(undef);
  $o6->fk2(undef);
  $o6->fk3(undef);
  $o6->b1(undef);
  $o6->b2(2);
  $o6->name('Ted');

  ok($o6->save, "object save() 8 - $db_type");

  my $o7 = $o2->clone;
  $o7->id(70);
  $o7->b1(3);
  $o7->b2(undef);
  $o7->name('Joe');

  ok($o7->save, "object save() 9 - $db_type");

  my $o8 = $o2->clone;
  $o8->id(80);
  $o8->b1(undef);
  $o8->b2(undef);
  $o8->name('Pete');

  ok($o8->save, "object save() 10 - $db_type");

  ok($fo->save, "object save() 10 - $db_type");

  $fo = MyMySQLNick->new(id   => 7,
                         o_id => 60,
                         nick => 'nseven');

  ok($fo->save, "nick object save() 7 - $db_type");

  $fo = MyMySQLNick->new(id   => 8,
                         o_id => 60,
                         nick => 'neight');

  ok($fo->save, "nick object save() 8 - $db_type");

  $fo = MyMySQLNick->new(id   => 9,
                         o_id => 60,
                         nick => 'neight');

  ok($fo->save, "nick object save() 8 - $db_type");

  $fo = MyMySQLNick2->new(id    => 1,
                          o_id  => 5,
                          nick2 => 'n2one');

  ok($fo->save, "nick2 object save() 1 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      require_objects => [ 'bb2', 'bb1' ],
      query        => [ '!t1.id' => 5 ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 15 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 0, "get_objects() with many 16 - $db_type");

  $count = 
    Rose::DB::Object::Manager->get_objects_count(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      require_objects => [ 'bb2', 'bb1' ],
      with_objects    => [ 'nicks' ],
      query        => [ ],
      sort_by => 't1.id');

  is($count, 1, "get_objects_count() require 1 - $db_type"); 

  #local $Rose::DB::Object::Manager::Debug = 1;  
  #$DB::single = 1;

  $count = 
    Rose::DB::Object::Manager->get_objects_count(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      require_objects => [ 'bb2' ],
      with_objects    => [ 'nicks' ],
      query        => [ ],
      sort_by => 't1.id');

  is($count, 2, "get_objects_count() require 2 - $db_type"); 

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      require_objects => [ 'bb2', 'bb1' ],
      with_objects    => [ 'nicks' ],
      query        => [ ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 17 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() with many 18 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with many 19 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many 20 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many 21 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many 22 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many 23 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many 24 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      require_objects => [ 'bb1', 'bb2' ],
      with_objects    => [ 'nicks2', 'nicks' ],
      multi_many_ok   => 1,
      query        => [ ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with multi many 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() with multi many 2 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with multi many 3 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with multi many 4 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with multi many 5 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with multi many 6 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with multi many 7 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with multi many 8 - $db_type");

  is($objs->[0]->{'nicks2'}[0]{'nick2'}, 'n2one', "get_objects() with multi many 9 - $db_type");

  $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      require_objects => [ 'bb1', 'bb2' ],
      with_objects    => [ 'nicks2', 'nicks' ],
      multi_many_ok   => 1,
      query        => [ ],
      sort_by => 't1.id');

  $o = $iterator->next;
  is($o->name, 'Betty', "iterator with and require 1 - $db_type");
  is($o->id, 5, "iterator with and require 2 - $db_type");

  $nicks = $o->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "iterator with and require 3 - $db_type");
  is($nicks->[0]->nick, 'nthree', "iterator with and require 4 - $db_type");
  is($nicks->[1]->nick, 'nsix', "iterator with and require 5 - $db_type");
  is($nicks->[2]->nick, 'none', "iterator with and require 6 - $db_type");
  is($nicks->[3]->nick, 'nfive', "iterator with and require 7 - $db_type");

  is($o->{'nicks2'}[0]{'nick2'}, 'n2one', "iterator with and require 8 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator with and require 9 - $db_type");
  is($iterator->total, 1, "iterator with and require 10 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks', 'bb1' ],
      query        => [ ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 25 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 8, "get_objects() with many 26 - $db_type");

  my $ids = join(',', map { $_->id } @$objs);

  is($ids, '1,2,3,4,5,60,70,80', "get_objects() with many 27 - $db_type");

  $nicks = $objs->[4]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many 28 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many 29 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many 30 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many 31 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many 32 - $db_type");

  is($objs->[6]->{'bb1'}->{'name'}, 'three', "get_objects() with many 33 - $db_type");
  ok(!defined $objs->[6]->{'bb2'}, "get_objects() with many 34 - $db_type");
  ok(!defined $objs->[6]->{'nicks'}, "get_objects() with many 35 - $db_type");

  ok(!defined $objs->[7]->{'bb1'}, "get_objects() with many 36 - $db_type");
  ok(!defined $objs->[7]->{'bb1'}, "get_objects() with many 37 - $db_type");
  ok(!defined $objs->[7]->{'nicks'}, "get_objects() with many 38 - $db_type");

  local $Rose::DB::Object::Manager::Debug = 0;

  $fo = MyMySQLNick->new(id => 7);
  ok($fo->delete, "with many clean-up 1 - $db_type");

  $fo = MyMySQLNick->new(id => 8);
  ok($fo->delete, "with many clean-up 2 - $db_type");

  $fo = MyMySQLNick->new(id => 9);
  ok($fo->delete, "with many clean-up 3 - $db_type");

  ok($o6->delete, "with many clean-up 4 - $db_type");
  ok($o7->delete, "with many clean-up 5 - $db_type");
  ok($o8->delete, "with many clean-up 6 - $db_type");

  $fo = MyMySQLNick2->new(id => 1);
  ok($fo->delete, "with many clean-up 7 - $db_type");

  # End "one to many" tests

  $iterator =
    MyMySQLObjectManager->get_objectz_iterator(
      share_db     => 1,
      query        =>
      [
        't1.id'    => { ge => 2 },
        't1.name'  => { like => '%tt%' },
      ],
      require_objects => [ 'other_obj', 'bb1', 'bb2' ]);

  $o = $iterator->next;

  ok(ref $o->{'other_obj'} eq 'MyMySQLOtherObject', "foreign object 4 - $db_type");
  is($o->other_obj->k2, 2, "foreign object 5 - $db_type");

  is($o->bb1->name, 'two', "bb foreign object 5 - $db_type");
  is($o->bb2->name, 'four', "bb foreign object 6 - $db_type");

  $objs = 
    MyMySQLObjectManager->get_objectz(
      share_db     => 1,
      query        =>
      [
        id         => { ge => 1 },
        name       => 'John',  
        flag       => 1,
        flag2      => 0,
        status     => 'active',
        bits       => '1',
        start      => '1/2/2001',
        '!start'   => { gt => DateTime->new(year  => '2005', 
                                            month => 1,
                                            day   => 1) },
        '!rose_db_object_test.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 2,
                              day   => 2)
        },

        '!t1.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 3,
                              day   => 3)
        },

        save_col   => [ 1, 5 ],
        nums       => [ 1, 2, 3 ],
        fk1        => 2,
        last_modified => { le => '6/6/2020' }, # XXX: breaks in 2020!
        date_created  => '3/30/2004 12:34:56 pm'
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() 7 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() 8 - $db_type");

  $objs = 
    MyMySQLObject->get_objectz(
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        k1         => { lt => 900 },
        or         => [ k1 => { ne => 99 }, k1 => 100 ],
        or         => [ and => [ id => { ne => 123 }, id => { lt => 100  } ],
                        and => [ id => { ne => 456 }, id => { lt => 300  } ] ],
        '!k2'      => { gt => 999 },
        '!t2.name' => 'z',
        start      => { lt => DateTime->new(year => '2005', month => 1, day => 1) },
        '!start'   => { gt => DateTime->new(year => '2005', month => 1, day => 1) },
        'rose_db_object_test.name'   => { like => '%tt%' },
        '!rose_db_object_other.name' => 'q',
        '!rose_db_object_other.name' => [ 'x', 'y' ],
      ],
      require_objects => [ 'other_obj' ]);

  ok(ref $objs->[0]->{'other_obj'} eq 'MyMySQLOtherObject', "foreign object 6 - $db_type");
  is($objs->[0]->other_obj->k2, 2, "foreign object 7 - $db_type");

  # Test limit with offset

  foreach my $id (6 .. 20)
  {
    my $o = $o5->clone;
    $o->id($id);
    $o->name("Clone $id");

    ok($o->save, "object save() clone $id - $db_type");
  }

  $objs = 
    MyMySQLObjectManager->get_objectz(
      sort_by      => 'id DESC',
      limit        => 2,
      offset       => 8);

  ok(ref $objs eq 'ARRAY' && @$objs == 2 && 
     $objs->[0]->id == 12 && $objs->[1]->id == 11,
     "get_objects() with offset - $db_type");

  $objs = 
    MyMySQLObject->get_objectz(
      sort_by      => 'id DESC',
      require_objects => [ 'other_obj' ],
      limit        => 2,
      offset       => 8);

  ok(ref $objs eq 'ARRAY' && @$objs == 2 && 
     $objs->[0]->id == 12 && $objs->[1]->id == 11,
     "get_objects() with objects and offset - $db_type");

  $iterator = 
    MyMySQLObject->get_objectz_iterator(
      sort_by      => 'id DESC',
      limit        => 2,
      offset       => 8);

  $o = $iterator->next;
  is($o->id, 12, "get_objects_iterator() with offset 1 - $db_type");

  $o = $iterator->next;
  is($o->id, 11, "get_objects_iterator() with offset 2 - $db_type");

  is($iterator->next, 0, "get_objects_iterator() with offset 3 - $db_type");

  eval
  {
    $objs = 
      Rose::DB::Object::Manager->get_objects(
        object_class => 'MyMySQLObject',
        sort_by      => 'id DESC',
        offset       => 8)
  };

  ok($@ =~ /invalid without a limit/, "get_objects() missing offset - $db_type");

  eval
  {
    $iterator = 
      Rose::DB::Object::Manager->get_objects_iterator(
        object_class => 'MyMySQLObject',
        sort_by      => 'id DESC',
        offset       => 8);
  };

  ok($@ =~ /invalid without a limit/, "get_objects_iterator() missing offset - $db_type");

  # Start *_sql comparison tests

  $o6->fk2(99);
  $o6->fk3(99);
  $o6->save;

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyMySQLObject',
      query        => [ 'fk2' => { eq_sql => 'fk3' } ],
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() eq_sql 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() eq_sql 2 - $db_type");

  is($objs->[0]->id, 60, "get_objects() eq_sql 3 - $db_type");

  # End *_sql comparison tests

  # Start "many to many" tests

  $fo = MyMySQLColor->new(id => 1, name => 'Red');
  $fo->save;

  $fo = MyMySQLColor->new(id => 2, name => 'Green');
  $fo->save;

  $fo = MyMySQLColor->new(id => 3, name => 'Blue');
  $fo->save;

  $fo = MyMySQLColorMap->new(id => 1, object_id => $o2->id, color_id => 1);
  $fo->save;

  $fo = MyMySQLColorMap->new(id => 2, object_id => $o2->id, color_id => 3);
  $fo->save;

  $o2->b1(4);
  $o2->b1(2);
  $o2->fkone(2);
  $o2->fk2(3);
  $o2->fk3(4);
  $o2->save;

  my @colors = $o2->colors;
  ok(@colors == 2 && $colors[0]->name eq 'Red' &&
     $colors[1]->name eq 'Blue', "Fetch many to many 1 - $db_type");
#local $Rose::DB::Object::Manager::Debug = 1;
#$DB::single = 1;
  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class  => 'MyMySQLObject',
      share_db      => 1,
      with_objects  => [ 'other_obj', 'bb2', 'nicks', 'bb1', 'colors' ],
      multi_many_ok => 1,
      query         => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by       => 't1.name');

  is(ref $objs, 'ARRAY', "get_objects() with many to many 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 3, "get_objects() with many to many 2 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with many to many 3 - $db_type");
  is($objs->[1]->id, 2, "get_objects() with many to many 4 - $db_type");
  is($objs->[2]->id, 1, "get_objects() with many to many 5 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many to many 6 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many to many 7 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many to many 8 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many to many 9 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many to many 10 - $db_type");

  $fo1 = $objs->[0]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects() with many to many 11 - $db_type");

  $fo1 = $objs->[0]->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects() with many to many 12 - $db_type");

  my $colors = $objs->[1]->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects() with many to many 13 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects() with many to many 14 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects() with many to many 15 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class  => 'MyMySQLObject',
      share_db      => 1,
      with_objects  => [ 'bb1', 'nicks', 'other_obj', 'colors', 'bb2' ],
      multi_many_ok => 1,
      query         => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by       => 't1.name');

  is(ref $objs, 'ARRAY', "get_objects() with many to many (reorder) 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 3, "get_objects() with many to many (reorder) 2 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with many to many (reorder) 3 - $db_type");
  is($objs->[1]->id, 2, "get_objects() with many to many (reorder) 4 - $db_type");
  is($objs->[2]->id, 1, "get_objects() with many to many (reorder) 5 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many to many (reorder) 6 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many to many (reorder) 7 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many to many (reorder) 8 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many to many (reorder) 9 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many to many (reorder) 10 - $db_type");

  $fo1 = $objs->[0]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects() with many to many (reorder) 11 - $db_type");

  $fo1 = $objs->[0]->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects() with many to many (reorder) 12 - $db_type");

  $colors = $objs->[1]->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects() with many to many (reorder) 13 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects() with many to many (reorder) 14 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects() with many to many (reorder) 15 - $db_type");

  #local $Rose::DB::Object::Manager::Debug = 1;
  #$DB::single = 1;

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class    => 'MyMySQLObject',
      share_db        => 1,
      with_objects    => [ 'nicks', 'colors', 'bb2' ],
      multi_many_ok   => 1,
      require_objects => [ 'bb1', 'other_obj' ],
      query           => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by         => 't1.name');

  is(ref $objs, 'ARRAY', "get_objects() with many to many require with 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 2, "get_objects() with many to many require with 2 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with many to many require with 3 - $db_type");
  is($objs->[1]->id, 2, "get_objects() with many to many require with 4 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many to many require with 6 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many to many 7 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many to many 8 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many to many 9 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many to many 10 - $db_type");

  $fo1 = $objs->[0]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects() with many to many require with 11 - $db_type");

  $fo1 = $objs->[0]->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects() with many to many require with 12 - $db_type");

  $colors = $objs->[1]->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects() with many to many require with 13 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects() with many to many require with 14 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects() with many to many require with 15 - $db_type");

  $fo1 = $objs->[1]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'two', "get_objects() with many to many require with 16 - $db_type");

  $fo1 = $objs->[0]->{'other_obj'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'Foo 1', "get_objects() with many to many require with 17 - $db_type");

  $fo1 = $objs->[1]->{'other_obj'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'Foo 2', "get_objects() with many to many require with 18 - $db_type");

  ok(!defined $objs->[0]->{'colors'}, "get_objects() with many to many require with 19 - $db_type");
  ok(!defined $objs->[1]->{'bb2'}, "get_objects() with many to many require with 20 - $db_type");

  #local $Rose::DB::Object::Manager::Debug = 1;
  #$DB::single = 1;

  $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class  => 'MyMySQLObject',
      share_db      => 1,
      with_objects  => [ 'other_obj', 'bb2', 'nicks', 'bb1', 'colors' ],
      multi_many_ok => 1,
      query         => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by       => 't1.name');

  $o = $iterator->next;
  is($o->name, 'Betty', "get_objects_iterator() with many to many 1 - $db_type");
  is($o->id, 5, "get_objects_iterator() with many to many 2 - $db_type");

  $nicks = $o->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects_iterator() with many to many 3 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects_iterator() with many to many 4 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects_iterator() with many to many 5 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects_iterator() with many to many 6 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects_iterator() with many to many 7 - $db_type");

  $fo1 = $o->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects_iterator() with many to many 8 - $db_type");

  $fo1 = $o->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects_iterator() with many to many 9 - $db_type"); 

  $o = $iterator->next;
  is($o->name, 'Fred', "get_objects_iterator() with many to many 10 - $db_type");
  is($o->id, 2, "get_objects_iterator() with many to many 11 - $db_type");

  $colors = $o->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects_iterator() with many to many 12 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many 13 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many 14 - $db_type");

  $o = $iterator->next;
  is($o->name, 'John', "get_objects_iterator() with many to many 15 - $db_type");
  is($o->id, 1, "get_objects_iterator() with many to many 16 - $db_type");

  $o = $iterator->next;
  is($o, 0, "get_objects_iterator() with many to many 17 - $db_type");
  is($iterator->total, 3, "get_objects_iterator() with many to many 18 - $db_type");

  $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class  => 'MyMySQLObject',
      share_db      => 1,
      with_objects  => [ 'bb1', 'nicks', 'other_obj', 'colors', 'bb2' ],
      multi_many_ok => 1,
      query         => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by       => 't1.name');

  $o = $iterator->next;
  is($o->name, 'Betty', "get_objects_iterator() with many to many 19 - $db_type");
  is($o->id, 5, "get_objects_iterator() with many to many 20 - $db_type");

  $nicks = $o->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects_iterator() with many to many 21 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects_iterator() with many to many 22 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects_iterator() with many to many 23 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects_iterator() with many to many 24 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects_iterator() with many to many 25 - $db_type");

  $fo1 = $o->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects_iterator() with many to many 26 - $db_type");

  $fo1 = $o->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects_iterator() with many to many 27 - $db_type"); 

  $o = $iterator->next;
  is($o->name, 'Fred', "get_objects_iterator() with many to many 28 - $db_type");
  is($o->id, 2, "get_objects_iterator() with many to many 29 - $db_type");

  $colors = $o->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects_iterator() with many to many 30 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many 31 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many 32 - $db_type");

  $o = $iterator->next;
  is($o->name, 'John', "get_objects_iterator() with many to many 33 - $db_type");
  is($o->id, 1, "get_objects_iterator() with many to many 34 - $db_type");

  $o = $iterator->next;
  is($o, 0, "get_objects_iterator() with many to many 35 - $db_type");
  is($iterator->total, 3, "get_objects_iterator() with many to many 36 - $db_type");

  $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class    => 'MyMySQLObject',
      share_db        => 1,
      with_objects    => [ 'nicks', 'colors', 'bb2' ],
      multi_many_ok   => 1,
      require_objects => [ 'bb1', 'other_obj' ],
      query           => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by         => 't1.name');

  $o = $iterator->next;
  is($o->name, 'Betty', "get_objects_iterator() with many to many require 1 - $db_type");
  is($o->id, 5, "get_objects_iterator() with many to many require 2 - $db_type");

  $fo1 = $o->{'other_obj'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'Foo 1', "get_objects_iterator() with many to many require 3 - $db_type");

  ok(!defined $o->{'colors'}, "get_objects_iterator() with many to many require 4 - $db_type");

  $nicks = $o->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects_iterator() with many to many require 5 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects_iterator() with many to many require 6 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects_iterator() with many to many require 7 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects_iterator() with many to many require 8 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects_iterator() with many to many require 9 - $db_type");

  $fo1 = $o->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects_iterator() with many to many require 10 - $db_type");

  $fo1 = $o->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects_iterator() with many to many require 11 - $db_type"); 

  $o = $iterator->next;
  is($o->name, 'Fred', "get_objects_iterator() with many to many require 12 - $db_type");
  is($o->id, 2, "get_objects_iterator() with many to many require 13 - $db_type");

  $colors = $o->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects_iterator() with many to many require 14 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many require 15 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many require 16 - $db_type");

  $fo1 = $o->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'two', "get_objects_iterator() with many to many require 17 - $db_type");

  $fo1 = $o->{'other_obj'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'Foo 2', "get_objects_iterator() with many to many require 18 - $db_type");

  ok(!defined $o->{'bb2'}, "get_objects_iterator() with many to many require 19 - $db_type");

  $o = $iterator->next;
  is($o, 0, "get_objects_iterator() with many to many require 20 - $db_type");
  is($iterator->total, 2, "get_objects_iterator() with many to many require 21 - $db_type");

  # End "many to many" tests
}

#
# Informix
#

SKIP: foreach my $db_type (qw(informix))
{
  skip("Informix tests", 342)  unless($HAVE_INFORMIX);

  Rose::DB->default_type($db_type);

  my $o = MyInformixObject->new(id         => 1,
                                name       => 'John',  
                                flag       => 't',
                                flag2      => 'f',
                                fkone      => 2,
                                status     => 'active',
                                bits       => '00001',
                                start      => '2001-01-02',
                                save_col   => 5,     
                                nums       => [ 1, 2, 3 ],
                                last_modified => 'now',
                                date_created  => '2004-03-30 12:34:56');

  ok($o->save, "object save() 1 - $db_type");

  my $objs = 
    MyInformixObject->get_objectz(
      share_db     => 1,
      query        =>
      [
        id         => { ge => 1 },
        name       => 'John',  
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        or         => [ and => [ '!bits' => '00001', bits => { ne => '11111' } ],
                        and => [ bits => { lt => '10101' }, '!bits' => '10000' ] ],
        start      => '01/02/2001',
        save_col   => [ 1, 5 ],
        nums       => 'SET{1,2,3}',
        fk1        => 2,
        last_modified => { le => $o->db->format_timestamp($o->db->parse_timestamp('now')) },
        date_created  => '2004-03-30 12:34:56',
        date_created  => { le => 'current' },
        date_created  => [ 'current', '2004-03-30 12:34:56' ],
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() 2 - $db_type");

  my $o2 = $o->clone;
  $o2->id(2);
  $o2->name('Fred');

  ok($o2->save, "object save() 2 - $db_type");

  my $o3 = $o2->clone;
  $o3->id(3);
  $o3->name('Sue');

  ok($o3->save, "object save() 3 - $db_type");

  my $o4 = $o3->clone;
  $o4->id(4);
  $o4->name('Bob');

  ok($o4->save, "object save() 4 - $db_type");

  $objs = 
    MyInformixObjectManager->get_objectz(
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        start      => '01/02/2001',
        save_col   => [ 1, 5 ],
        nums       => 'SET{1,2,3}',
        last_modified => { le => $o->db->format_timestamp($o->db->parse_timestamp('now')) },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name DESC');

  is(ref $objs, 'ARRAY', "get_objects() 3 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 2, "get_objects() 4 - $db_type");
  is($objs->[0]->id, 3, "get_objects() 5 - $db_type");
  is($objs->[1]->id, 2, "get_objects() 6 - $db_type");

  my $count =
    MyInformixObject->get_objectz_count(
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        start      => '01/02/2001',
        save_col   => [ 1, 5 ],
        nums       => 'SET{1,2,3}',
        last_modified => { le => $o->db->format_timestamp($o->db->parse_timestamp('now')) },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name DESC');

  is($count, 2, "get_objects_count() 1 - $db_type");

  my $save_o = $o;

  my $iterator = 
    MyInformixObjectManager->get_objectz_iterator(
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        start      => '01/02/2001',
        save_col   => [ 1, 5 ],
        nums       => 'SET{1,2,3}',
        last_modified => { le => $o->db->format_timestamp($o->db->parse_timestamp('now')) },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name');

  is(ref $iterator, 'Rose::DB::Object::Iterator', "get_objects_iterator() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator next() 1 - $db_type");
  is($o->id, 2, "iterator next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Sue', "iterator next() 3 - $db_type");
  is($o->id, 3, "iterator next() 4 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator next() 5 - $db_type");
  is($iterator->total, 2, "iterator total() - $db_type");

  $iterator = 
    MyInformixObject->get_objectz_iterator(
      share_db     => 1,
      skip_first   => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        start      => '01/02/2001',
        save_col   => [ 1, 5 ],
        nums       => 'SET{1,2,3}',
        last_modified => { le => $save_o->db->format_timestamp($save_o->db->parse_timestamp('now')) },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name');

  $o = $iterator->next;
  is($o->name, 'Sue', "iterator skip_first next() 1 - $db_type");
  is($o->id, 3, "iterator skip_first next() 2 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator skip_first next() 3 - $db_type");
  is($iterator->total, 1, "iterator total() - $db_type");

  my $fo = MyInformixOtherObject->new(name => 'Foo 1',
                                      k1   => 1,
                                      k2   => 2,
                                      k3   => 3);

  ok($fo->save, "object save() 5 - $db_type");

  $fo = MyInformixOtherObject->new(name => 'Foo 2',
                                   k1   => 2,
                                   k2   => 3,
                                   k3   => 4);

  ok($fo->save, "object save() 6 - $db_type");

  $fo = MyInformixBB->new(id   => 1,
                          name => 'one');
  ok($fo->save, "bb object save() 1 - $db_type");

  $fo = MyInformixBB->new(id   => 2,
                          name => 'two');
  ok($fo->save, "bb object save() 2 - $db_type");

  $fo = MyInformixBB->new(id   => 3,
                          name => 'three');
  ok($fo->save, "bb object save() 3 - $db_type");

  $fo = MyInformixBB->new(id   => 4,
                          name => 'four');
  ok($fo->save, "bb object save() 4 - $db_type");

  my $o5 = MyInformixObject->new(id         => 5,
                                 name       => 'Betty',  
                                 flag       => 'f',
                                 flag2      => 't',
                                 status     => 'with',
                                 bits       => '10101',
                                 start      => '2002-05-20',
                                 save_col   => 123,
                                 nums       => [ 4, 5, 6 ],
                                 fkone      => 1,
                                 fk2        => 2,
                                 fk3        => 3,
                                 b1         => 2,
                                 b2         => 4,
                                 last_modified => '2001-01-10 20:34:56',
                                 date_created  => '2002-05-10 10:34:56');

  ok($o5->save, "object save() 7 - $db_type");

  my $fo1 = $o5->other_obj;

  ok($fo1 && ref $fo1 && $fo1->k1 == 1 && $fo1->k2 == 2 && $fo1->k3 == 3,
     "foreign object 1 - $db_type");

  $fo1 = $o5->bb1;
  ok($fo1 && ref $fo1 && $fo1->id == 2, "bb foreign object 1 - $db_type");

  $fo1 = $o5->bb2;
  ok($fo1 && ref $fo1 && $fo1->id == 4, "bb foreign object 2 - $db_type");

  $objs = 
    MyInformixObjectManager->get_objectz(
      share_db     => 1,
      query        =>
      [
        't1.id'    => { ge => 2 },
        't1.name'  => { like => '%tt%' },
      ],
      require_objects => [ 'other_obj' ]);

  ok(ref $objs->[0]->{'other_obj'} eq 'MyInformixOtherObject', "foreign object 2 - $db_type");
  is($objs->[0]->other_obj->k2, 2, "foreign object 3 - $db_type");

  is($objs->[0]->bb1->name, 'two', "bb foreign object 3 - $db_type");
  is($objs->[0]->bb2->name, 'four', "bb foreign object 4 - $db_type");

  # Start "one to many" tests

  $fo = MyInformixNick->new(id   => 1,
                         o_id => 5,
                         nick => 'none');
  ok($fo->save, "nick object save() 1 - $db_type");

  $fo = MyInformixNick->new(id   => 2,
                         o_id => 2,
                         nick => 'ntwo');
  ok($fo->save, "nick object save() 2 - $db_type");

  $fo = MyInformixNick->new(id   => 3,
                         o_id => 5,
                         nick => 'nthree');
  ok($fo->save, "nick object save() 3 - $db_type");

  $fo = MyInformixNick->new(id   => 4,
                         o_id => 2,
                         nick => 'nfour');
  ok($fo->save, "nick object save() 4 - $db_type");

  $fo = MyInformixNick->new(id   => 5,
                         o_id => 5,
                         nick => 'nfive');
  ok($fo->save, "nick object save() 5 - $db_type");

  $fo = MyInformixNick->new(id   => 6,
                         o_id => 5,
                         nick => 'nsix');
  ok($fo->save, "nick object save() 6 - $db_type");

  #local $Rose::DB::Object::Manager::Debug = 1;

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyInformixObject',
      share_db     => 1,
      with_objects => [ 'nicks' ],
      query        =>
      [
        't1.id'    => { ge => 1 },
        't1.name'  => 'Betty',  
        flag       => 'f',
        flag2      => 1,
        bits       => '10101',
        't2.nick'  => { like => 'n%' },
        start      => '5/20/2002',
        '!start'   => { gt => DateTime->new(year  => '2005', 
                                            month => 12,
                                            day   => 1) },
        '!rose_db_object_test.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 12,
                              day   => 2)
        },

        '!t1.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 12,
                              day   => 3)
        },

        save_col   => [ 1, 5, 123 ],
        nums       => [ 4, 5, 6 ],
        fk1        => 1,
        last_modified => { le => '6/6/2020' }, # XXX: breaks in 2020!
        date_created  => '5/10/2002 10:34:56 am'
      ],
      clauses => [ "LOWER(status) LIKE 'w%'" ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() with many 2 - $db_type");

  my $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many 3 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many 4 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many 5 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many 6 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many 7 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyInformixObject',
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks', 'bb1' ],
      query        =>
      [
        't1.id'    => { ge => 1 },
        't1.name'  => 'Betty',  
        flag       => 'f',
        flag2      => 1,
        bits       => '10101',
        't3.nick'  => { like => 'n%' },
        start      => '5/20/2002',
        '!start'   => { gt => DateTime->new(year  => '2005', 
                                            month => 12,
                                            day   => 1) },
        '!rose_db_object_test.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 12,
                              day   => 2)
        },

        '!t1.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 12,
                              day   => 3)
        },

        save_col   => [ 1, 5, 123 ],
        nums       => [ 4, 5, 6 ],
        fk1        => 1,
        last_modified => { le => '6/6/2020' }, # XXX: breaks in 2020!
        date_created  => '5/10/2002 10:34:56 am'
      ],
      clauses => [ "LOWER(status) LIKE 'w%'" ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 8 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() with many 9 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many 10 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many 11 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many 12 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many 13 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many 14 - $db_type");

  $fo1 = $objs->[0]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects() with many bb1 1 - $db_type");

  $fo1 = $objs->[0]->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects() with many bb2 2 - $db_type");

  $iterator = 
    MyInformixObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name');

  is(ref $iterator, 'Rose::DB::Object::Iterator', "get_objects_iterator() 1 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Betty', "iterator many next() 1 - $db_type");
  is($o->id, 5, "iterator many next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Bob', "iterator many next() 3 - $db_type");
  is($o->id, 4, "iterator many next() 4 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator many next() 5 - $db_type");
  is($o->id, 2, "iterator many next() 6 - $db_type");
  is(scalar @{$o->{'nicks'}}, 2, "iterator many sub-object 1 - $db_type");
  is($o->{'nicks'}[0]{'nick'}, 'ntwo', "iterator many sub-object 2 - $db_type");
  is($o->{'nicks'}[1]{'nick'}, 'nfour', "iterator many sub-object 3 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Sue', "iterator many next() 7 - $db_type");
  is($o->id, 3, "iterator many next() 8 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator many next() 9 - $db_type");
  is($iterator->total, 4, "iterator many total() - $db_type");

  $iterator = 
    MyInformixObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 2);

  $o = $iterator->next;
  is($o->name, 'Betty', "iterator limit 2 many next() 1 - $db_type");
  is($o->id, 5, "iterator limit 2 many next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Bob', "iterator limit 2 many next() 3 - $db_type");
  is($o->id, 4, "iterator limit 2 many next() 4 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator limit 2 many next() 5 - $db_type");
  is($iterator->total, 2, "iterator limit 2 many total() - $db_type");

  $iterator = 
    MyInformixObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 3);

  $o = $iterator->next;
  is($o->name, 'Betty', "iterator limit 3 many next() 1 - $db_type");
  is($o->id, 5, "iterator limit 3 many next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Bob', "iterator limit 3 many next() 3 - $db_type");
  is($o->id, 4, "iterator limit 3 many next() 4 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator limit 3 many next() 5 - $db_type");
  is($o->id, 2, "iterator limit 3 many next() 6 - $db_type");
  is(scalar @{$o->{'nicks'}}, 2, "iterator limit 3 many sub-object 1 - $db_type");
  is($o->{'nicks'}[0]{'nick'}, 'ntwo', "iterator limit 3 many sub-object 2 - $db_type");
  is($o->{'nicks'}[1]{'nick'}, 'nfour', "iterator limit 3 many sub-object 3 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator limit 3 many next() 7 - $db_type");
  is($iterator->total, 3, "iterator limit 3 many total() - $db_type");

  $objs = 
    MyInformixObjectManager->get_objectz(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 2);

  ok(ref $objs && @$objs == 2, "get_objects() limit 2 many 1 - $db_type");
  is($objs->[0]->name, 'Betty', "get_objects() limit 2 many 2 - $db_type");
  is($objs->[0]->id, 5, "get_objects() limit 2 many 3 - $db_type");

  is($objs->[1]->name, 'Bob', "get_objects() limit 2 many 4 - $db_type");
  is($objs->[1]->id, 4, "get_objects() limit 2 many 5 - $db_type");

  $objs = 
    MyInformixObjectManager->get_objectz(
      share_db     => 1,
      with_objects => [ 'nicks', 'bb2' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 3);

  ok(ref $objs && @$objs == 3, "get_objects() limit 3 many 1 - $db_type");
  is($objs->[0]->name, 'Betty', "get_objects() limit 3 many 2 - $db_type");
  is($objs->[0]->id, 5, "get_objects() limit 3 many 3 - $db_type");

  is($objs->[1]->name, 'Bob', "get_objects() limit 3 many 4 - $db_type");
  is($objs->[1]->id, 4, "get_objects() limit 3 many 5 - $db_type");

  is($objs->[2]->name, 'Fred', "get_objects() limit 3 many 6 - $db_type");
  is($objs->[2]->id, 2, "get_objects() limit 3 many 7 - $db_type");
  is(scalar @{$objs->[2]->{'nicks'}}, 2, 'get_objects() limit 3 many sub-object 1');
  is($objs->[2]->{'nicks'}[0]{'nick'}, 'ntwo', 'get_objects() limit 3 many sub-object 2');
  is($objs->[2]->{'nicks'}[1]{'nick'}, 'nfour', 'get_objects() limit 3 many sub-object 3');

  $iterator = 
    MyInformixObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 2,
      offset  => 1);

  $o = $iterator->next;
  is($o->name, 'Bob', "iterator limit 2 offset 1 many next() 1 - $db_type");
  is($o->id, 4, "iterator limit 2 offset 1 many next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator limit 2 offset 1 many next() 3 - $db_type");
  is($o->id, 2, "iterator limit 2 offset 1 many next() 4 - $db_type");
  is(scalar @{$o->{'nicks'}}, 2, 'iterator limit 2 offset 1 many sub-object 1');
  is($o->{'nicks'}[0]{'nick'}, 'ntwo', 'iterator limit 2 offset 1 many sub-object 2');
  is($o->{'nicks'}[1]{'nick'}, 'nfour', 'iterator limit 2 offset 1 many sub-object 3');

  $o = $iterator->next;
  is($o, 0, "iterator limit 2 offset 1 many next() 5 - $db_type");
  is($iterator->total, 2, "iterator limit 2 offset 1 many total() - $db_type");

  $iterator = 
    MyInformixObjectManager->get_objectz_iterator(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 3,
      offset  => 2);

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator limit 3 offset 2 many next() 1 - $db_type");
  is($o->id, 2, "iterator limit 3 offset 2 many next() 2 - $db_type");
  is(scalar @{$o->{'nicks'}}, 2, 'iterator limit 3 offset 2 many sub-object 1');
  is($o->{'nicks'}[0]{'nick'}, 'ntwo', 'iterator limit 3 offset 2 many sub-object 2');
  is($o->{'nicks'}[1]{'nick'}, 'nfour', 'iterator limit 3 offset 2 many sub-object 3');

  $o = $iterator->next;
  is($o->name, 'Sue', "iterator limit 3 offset 2 many next() 3 - $db_type");
  is($o->id, 3, "iterator limit 3 offset 2 many next() 4 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator limit 3 offset 2 many next() 5 - $db_type");
  is($iterator->total, 2, "iterator limit 3 offset 2 many total() - $db_type");

  $objs = 
    MyInformixObjectManager->get_objectz(
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 2,
      offset  => 1);

  ok(ref $objs && @$objs == 2, "get_objects() limit 2 offset 1 many 1 - $db_type");
  is($objs->[0]->name, 'Bob', "get_objects() limit 2 offset 1 many 2 - $db_type");
  is($objs->[0]->id, 4, "get_objects() limit 2 offset 1 many 3 - $db_type");

  is($objs->[1]->name, 'Fred', "get_objects() limit 2 offset 1 many 4 - $db_type");
  is($objs->[1]->id, 2, "get_objects() limit 2 offset 1 many 5 - $db_type");
  is(scalar @{$objs->[1]->{'nicks'}}, 2, 'get_objects() limit 2 offset 1 many sub-object 1');
  is($objs->[1]->{'nicks'}[0]{'nick'}, 'ntwo', 'get_objects() limit 2 offset 1 many sub-object 2');
  is($objs->[1]->{'nicks'}[1]{'nick'}, 'nfour', 'get_objects() limit 2 offset 1 many sub-object 3');

  $objs = 
    MyInformixObjectManager->get_objectz(
      share_db     => 1,
      with_objects => [ 'nicks', 'bb2' ],
      query        =>
      [
        't1.id'  => { ge => 2 },
      ],
      sort_by => 't1.name',
      limit   => 3,
      offset  => 2);

  ok(ref $objs && @$objs == 2, "get_objects() limit 3 offset 2 many 1 - $db_type");

  is($objs->[0]->name, 'Fred', "get_objects() limit 3 offset 2 many 2 - $db_type");
  is($objs->[0]->id, 2, "get_objects() limit 3 offset 2 many 3 - $db_type");
  is(scalar @{$objs->[0]->{'nicks'}}, 2, 'get_objects() limit 3 offset 2 many sub-object 1');
  is($objs->[0]->{'nicks'}[0]{'nick'}, 'ntwo', 'get_objects() limit 3 offset 2 many sub-object 2');
  is($objs->[0]->{'nicks'}[1]{'nick'}, 'nfour', 'get_objects() limit 3 offset 2 many sub-object 3');

  is($objs->[1]->name, 'Sue', "get_objects() limit 3 offset 2 many 4 - $db_type");
  is($objs->[1]->id, 3, "get_objects() limit 3 offset 2 many 5 - $db_type");

  my $o6 = $o2->clone;
  $o6->id(60);
  $o6->fkone(undef);
  $o6->fk2(undef);
  $o6->fk3(undef);
  $o6->b1(undef);
  $o6->b2(2);
  $o6->name('Ted');

  ok($o6->save, "object save() 8 - $db_type");

  my $o7 = $o2->clone;
  $o7->id(70);
  $o7->b1(3);
  $o7->b2(undef);
  $o7->name('Joe');

  ok($o7->save, "object save() 9 - $db_type");

  my $o8 = $o2->clone;
  $o8->id(80);
  $o8->b1(undef);
  $o8->b2(undef);
  $o8->name('Pete');

  ok($o8->save, "object save() 10 - $db_type");

  ok($fo->save, "object save() 10 - $db_type");

  $fo = MyInformixNick->new(id   => 7,
                         o_id => 60,
                         nick => 'nseven');

  ok($fo->save, "nick object save() 7 - $db_type");

  $fo = MyInformixNick->new(id   => 8,
                         o_id => 60,
                         nick => 'neight');

  ok($fo->save, "nick object save() 8 - $db_type");

  $fo = MyInformixNick->new(id   => 9,
                         o_id => 60,
                         nick => 'neight');

  ok($fo->save, "nick object save() 8 - $db_type");

  $fo = MyInformixNick2->new(id    => 1,
                          o_id  => 5,
                          nick2 => 'n2one');

  ok($fo->save, "nick2 object save() 1 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyInformixObject',
      share_db     => 1,
      require_objects => [ 'bb2', 'bb1' ],
      query        => [ '!t1.id' => 5 ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 15 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 0, "get_objects() with many 16 - $db_type");

  $count = 
    Rose::DB::Object::Manager->get_objects_count(
      object_class => 'MyInformixObject',
      share_db     => 1,
      require_objects => [ 'bb2', 'bb1' ],
      with_objects    => [ 'nicks' ],
      query        => [ ],
      sort_by => 't1.id');

  is($count, 1, "get_objects_count() require 1 - $db_type"); 

  #local $Rose::DB::Object::Manager::Debug = 1;  
  #$DB::single = 1;

  $count = 
    Rose::DB::Object::Manager->get_objects_count(
      object_class => 'MyInformixObject',
      share_db     => 1,
      require_objects => [ 'bb2' ],
      with_objects    => [ 'nicks' ],
      query        => [ ],
      sort_by => 't1.id');

  is($count, 2, "get_objects_count() require 2 - $db_type"); 

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyInformixObject',
      share_db     => 1,
      require_objects => [ 'bb2', 'bb1' ],
      with_objects    => [ 'nicks' ],
      query        => [ ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 17 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() with many 18 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with many 19 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many 20 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many 21 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many 22 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many 23 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many 24 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyInformixObject',
      share_db     => 1,
      require_objects => [ 'bb1', 'bb2' ],
      with_objects    => [ 'nicks2', 'nicks' ],
      multi_many_ok   => 1,
      query        => [ ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with multi many 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() with multi many 2 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with multi many 3 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with multi many 4 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with multi many 5 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with multi many 6 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with multi many 7 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with multi many 8 - $db_type");

  is($objs->[0]->{'nicks2'}[0]{'nick2'}, 'n2one', "get_objects() with multi many 9 - $db_type");

  $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class => 'MyInformixObject',
      share_db     => 1,
      require_objects => [ 'bb1', 'bb2' ],
      with_objects    => [ 'nicks2', 'nicks' ],
      multi_many_ok   => 1,
      query        => [ ],
      sort_by => 't1.id');

  $o = $iterator->next;
  is($o->name, 'Betty', "iterator with and require 1 - $db_type");
  is($o->id, 5, "iterator with and require 2 - $db_type");

  $nicks = $o->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "iterator with and require 3 - $db_type");
  is($nicks->[0]->nick, 'nthree', "iterator with and require 4 - $db_type");
  is($nicks->[1]->nick, 'nsix', "iterator with and require 5 - $db_type");
  is($nicks->[2]->nick, 'none', "iterator with and require 6 - $db_type");
  is($nicks->[3]->nick, 'nfive', "iterator with and require 7 - $db_type");

  is($o->{'nicks2'}[0]{'nick2'}, 'n2one', "iterator with and require 8 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator with and require 9 - $db_type");
  is($iterator->total, 1, "iterator with and require 10 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyInformixObject',
      share_db     => 1,
      with_objects => [ 'bb2', 'nicks', 'bb1' ],
      query        => [ ],
      sort_by => 't1.id');

  is(ref $objs, 'ARRAY', "get_objects() with many 25 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 8, "get_objects() with many 26 - $db_type");

  my $ids = join(',', map { $_->id } @$objs);

  is($ids, '1,2,3,4,5,60,70,80', "get_objects() with many 27 - $db_type");

  $nicks = $objs->[4]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many 28 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many 29 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many 30 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many 31 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many 32 - $db_type");

  is($objs->[6]->{'bb1'}->{'name'}, 'three', "get_objects() with many 33 - $db_type");
  ok(!defined $objs->[6]->{'bb2'}, "get_objects() with many 34 - $db_type");
  ok(!defined $objs->[6]->{'nicks'}, "get_objects() with many 35 - $db_type");

  ok(!defined $objs->[7]->{'bb1'}, "get_objects() with many 36 - $db_type");
  ok(!defined $objs->[7]->{'bb1'}, "get_objects() with many 37 - $db_type");
  ok(!defined $objs->[7]->{'nicks'}, "get_objects() with many 38 - $db_type");

  local $Rose::DB::Object::Manager::Debug = 0;

  $fo = MyInformixNick->new(id => 7);
  ok($fo->delete, "with many clean-up 1 - $db_type");

  $fo = MyInformixNick->new(id => 8);
  ok($fo->delete, "with many clean-up 2 - $db_type");

  $fo = MyInformixNick->new(id => 9);
  ok($fo->delete, "with many clean-up 3 - $db_type");

  ok($o6->delete, "with many clean-up 4 - $db_type");
  ok($o7->delete, "with many clean-up 5 - $db_type");
  ok($o8->delete, "with many clean-up 6 - $db_type");

  $fo = MyInformixNick2->new(id => 1);
  ok($fo->delete, "with many clean-up 7 - $db_type");

  # End "one to many" tests

  $iterator =
    MyInformixObject->get_objectz_iterator(
      share_db     => 1,
      query        =>
      [
        't1.id'    => { ge => 2 },
        't1.name'  => { like => '%tt%' },
      ],
      require_objects => [ 'other_obj' ]);

  $o = $iterator->next;

  ok(ref $o->{'other_obj'} eq 'MyInformixOtherObject', "foreign object 4 - $db_type");
  is($o->other_obj->k2, 2, "foreign object 5 - $db_type");

  is($o->bb1->name, 'two', "bb foreign object 5 - $db_type");
  is($o->bb2->name, 'four', "bb foreign object 6 - $db_type");

  $objs = 
    MyInformixObjectManager->get_objectz(
      share_db     => 1,
      query        =>
      [
        id         => { ge => 1 },
        name       => 'John',  
        flag       => 1,
        flag2      => 0,
        status     => 'active',
        bits       => '1',
        start      => '1/2/2001',
        '!start'   => { gt => DateTime->new(year  => '2005', 
                                            month => 1,
                                            day   => 1) },
        '!rose_db_object_test.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 2,
                              day   => 2)
        },

        '!t1.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 3,
                              day   => 3)
        },

        save_col   => [ 1, 5 ],
        nums       => [ 1, 2, 3 ],
        fk1        => 2,
        fk1        => { lt => 99 },
        fk1        => { lt => 100 },
        or         => [ nums => { in_set => [ 2, 22, 222 ] }, 
                        fk1 => { lt => 777 },
                        last_modified => '6/6/2020' ],
        nums       => { any_in_set => [ 1, 99, 100 ] },
        nums       => { in_set => [ 2, 22, 222 ] },
        nums       => { in_set => 2 },
        nums       => { all_in_set => [ 1, 2, 3 ] },
        last_modified => { le => '6/6/2020' }, # XXX: test breaks in 2020!
        date_created  => '3/30/2004 12:34:56 pm'
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() 7 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() 8 - $db_type");

  $objs = 
    MyInformixObject->get_objectz(
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        k1         => { lt => 900 },
        or         => [ k1 => { ne => 99 }, k1 => 100 ],
        or         => [ and => [ id => { ne => 123 }, id => { lt => 100  } ],
                        and => [ id => { ne => 456 }, id => { lt => 300  } ] ],
        '!k2'      => { gt => 999 },
        '!t2.name' => 'z',
        start      => { lt => DateTime->new(year => '2005', month => 1, day => 1) },
        '!start'   => { gt => DateTime->new(year => '2005', month => 1, day => 1) },
        'rose_db_object_test.name'   => { like => '%tt%' },
        '!rose_db_object_other.name' => 'q',
        '!rose_db_object_other.name' => [ 'x', 'y' ],
      ],
      require_objects => [ 'other_obj' ]);

  ok(ref $objs->[0]->{'other_obj'} eq 'MyInformixOtherObject', "foreign object 6 - $db_type");
  is($objs->[0]->other_obj->k2, 2, "foreign object 7 - $db_type");

  #local $Rose::DB::Object::Manager::Debug = 1;

  $objs = 
    MyInformixObjectManager->get_objectz(
      share_db     => 1,
      queryis_sql  => 1,
      query        =>
      [
        id         => { ge => 1 },
        name       => 'John',  
        nums       => { any_in_set => [ 1, 99, 100 ] },
        nums       => { in_set => [ 2, 22, 222 ] },
        nums       => { in_set => 2 },
        nums       => { all_in_set => [ 1, 2, 3 ] },
      ],
      limit   => 5,
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() 9 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() 10 - $db_type");

  # Test limit with offset

  foreach my $id (6 .. 20)
  {
    my $o = $o5->clone;
    $o->id($id);
    $o->name("Clone $id");

    ok($o->save, "object save() clone $id - $db_type");
  }

  $objs = 
    MyInformixObject->get_objectz(
      sort_by      => 'id DESC',
      limit        => 2,
      offset       => 8);

  ok(ref $objs eq 'ARRAY' && @$objs == 2 && 
     $objs->[0]->id == 12 && $objs->[1]->id == 11,
     "get_objects() with offset - $db_type");

  #local $Rose::DB::Object::Manager::Debug = 1;

  $objs = 
    MyInformixObjectManager->get_objectz(
      sort_by      => 'id DESC',
      require_objects => [ 'other_obj' ],
      limit        => 2,
      offset       => 8);

  ok(ref $objs eq 'ARRAY' && @$objs == 2 && 
     $objs->[0]->id == 12 && $objs->[1]->id == 11,
     "get_objects() with objects and offset - $db_type");

  $iterator = 
    MyInformixObject->get_objectz_iterator(
      sort_by      => 'id DESC',
      limit        => 2,
      offset       => 8);

  $o = $iterator->next;
  is($o->id, 12, "get_objects_iterator() with offset 1 - $db_type");

  $o = $iterator->next;
  is($o->id, 11, "get_objects_iterator() with offset 2 - $db_type");

  is($iterator->next, 0, "get_objects_iterator() with offset 3 - $db_type");

  eval
  {
    $objs = 
      MyInformixObjectManager->get_objectz(
        object_class => 'MyInformixObject',
        sort_by      => 'id DESC',
        offset       => 8)
  };

  ok($@ =~ /invalid without a limit/, "get_objects() missing offset - $db_type");

  eval
  {
    $iterator = 
      MyInformixObject->get_objectz_iterator(
        object_class => 'MyInformixObject',
        sort_by      => 'id DESC',
        offset       => 8);
  };

  ok($@ =~ /invalid without a limit/, "get_objects_iterator() missing offset - $db_type");

  # Start *_sql comparison tests

  $o6->fk2(99);
  $o6->fk3(99);
  $o6->save;

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyInformixObject',
      query        => [ 'fk2' => { eq_sql => 'fk3' } ],
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() eq_sql 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() eq_sql 2 - $db_type");

  is($objs->[0]->id, 60, "get_objects() eq_sql 3 - $db_type");

  # End *_sql comparison tests

  # Start "many to many" tests

  $fo = MyInformixColor->new(id => 1, name => 'Red');
  $fo->save;

  $fo = MyInformixColor->new(id => 2, name => 'Green');
  $fo->save;

  $fo = MyInformixColor->new(id => 3, name => 'Blue');
  $fo->save;

  $fo = MyInformixColorMap->new(id => 1, object_id => $o2->id, color_id => 1);
  $fo->save;

  $fo = MyInformixColorMap->new(id => 2, object_id => $o2->id, color_id => 3);
  $fo->save;

  $o2->b1(4);
  $o2->b1(2);
  $o2->fkone(2);
  $o2->fk2(3);
  $o2->fk3(4);
  $o2->save;

  my @colors = $o2->colors;
  ok(@colors == 2 && $colors[0]->name eq 'Red' &&
     $colors[1]->name eq 'Blue', "Fetch many to many 1 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class  => 'MyInformixObject',
      share_db      => 1,
      with_objects  => [ 'other_obj', 'bb2', 'nicks', 'bb1', 'colors' ],
      multi_many_ok => 1,
      query         => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by       => 't1.name');

  is(ref $objs, 'ARRAY', "get_objects() with many to many 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 3, "get_objects() with many to many 2 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with many to many 3 - $db_type");
  is($objs->[1]->id, 2, "get_objects() with many to many 4 - $db_type");
  is($objs->[2]->id, 1, "get_objects() with many to many 5 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many to many 6 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many to many 7 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many to many 8 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many to many 9 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many to many 10 - $db_type");

  $fo1 = $objs->[0]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects() with many to many 11 - $db_type");

  $fo1 = $objs->[0]->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects() with many to many 12 - $db_type");

  my $colors = $objs->[1]->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects() with many to many 13 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects() with many to many 14 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects() with many to many 15 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class  => 'MyInformixObject',
      share_db      => 1,
      with_objects  => [ 'bb1', 'nicks', 'other_obj', 'colors', 'bb2' ],
      multi_many_ok => 1,
      query         => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by       => 't1.name');

  is(ref $objs, 'ARRAY', "get_objects() with many to many (reorder) 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 3, "get_objects() with many to many (reorder) 2 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with many to many (reorder) 3 - $db_type");
  is($objs->[1]->id, 2, "get_objects() with many to many (reorder) 4 - $db_type");
  is($objs->[2]->id, 1, "get_objects() with many to many (reorder) 5 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many to many (reorder) 6 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many to many (reorder) 7 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many to many (reorder) 8 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many to many (reorder) 9 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many to many (reorder) 10 - $db_type");

  $fo1 = $objs->[0]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects() with many to many (reorder) 11 - $db_type");

  $fo1 = $objs->[0]->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects() with many to many (reorder) 12 - $db_type");

  $colors = $objs->[1]->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects() with many to many (reorder) 13 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects() with many to many (reorder) 14 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects() with many to many (reorder) 15 - $db_type");

  #local $Rose::DB::Object::Manager::Debug = 1;
  #$DB::single = 1;

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class    => 'MyInformixObject',
      share_db        => 1,
      with_objects    => [ 'nicks', 'colors', 'bb2' ],
      multi_many_ok   => 1,
      require_objects => [ 'bb1', 'other_obj' ],
      query           => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by         => 't1.name');

  is(ref $objs, 'ARRAY', "get_objects() with many to many require with 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 2, "get_objects() with many to many require with 2 - $db_type");

  is($objs->[0]->id, 5, "get_objects() with many to many require with 3 - $db_type");
  is($objs->[1]->id, 2, "get_objects() with many to many require with 4 - $db_type");

  $nicks = $objs->[0]->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects() with many to many require with 6 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects() with many to many 7 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects() with many to many 8 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects() with many to many 9 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects() with many to many 10 - $db_type");

  $fo1 = $objs->[0]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects() with many to many require with 11 - $db_type");

  $fo1 = $objs->[0]->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects() with many to many require with 12 - $db_type");

  $colors = $objs->[1]->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects() with many to many require with 13 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects() with many to many require with 14 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects() with many to many require with 15 - $db_type");

  $fo1 = $objs->[1]->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'two', "get_objects() with many to many require with 16 - $db_type");

  $fo1 = $objs->[0]->{'other_obj'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'Foo 1', "get_objects() with many to many require with 17 - $db_type");

  $fo1 = $objs->[1]->{'other_obj'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'Foo 2', "get_objects() with many to many require with 18 - $db_type");

  ok(!defined $objs->[0]->{'colors'}, "get_objects() with many to many require with 19 - $db_type");
  ok(!defined $objs->[1]->{'bb2'}, "get_objects() with many to many require with 20 - $db_type");

  #local $Rose::DB::Object::Manager::Debug = 1;
  #$DB::single = 1;

  $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class  => 'MyInformixObject',
      share_db      => 1,
      with_objects  => [ 'other_obj', 'bb2', 'nicks', 'bb1', 'colors' ],
      multi_many_ok => 1,
      query         => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by       => 't1.name');

  $o = $iterator->next;
  is($o->name, 'Betty', "get_objects_iterator() with many to many 1 - $db_type");
  is($o->id, 5, "get_objects_iterator() with many to many 2 - $db_type");

  $nicks = $o->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects_iterator() with many to many 3 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects_iterator() with many to many 4 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects_iterator() with many to many 5 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects_iterator() with many to many 6 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects_iterator() with many to many 7 - $db_type");

  $fo1 = $o->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects_iterator() with many to many 8 - $db_type");

  $fo1 = $o->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects_iterator() with many to many 9 - $db_type"); 

  $o = $iterator->next;
  is($o->name, 'Fred', "get_objects_iterator() with many to many 10 - $db_type");
  is($o->id, 2, "get_objects_iterator() with many to many 11 - $db_type");

  $colors = $o->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects_iterator() with many to many 12 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many 13 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many 14 - $db_type");

  $o = $iterator->next;
  is($o->name, 'John', "get_objects_iterator() with many to many 15 - $db_type");
  is($o->id, 1, "get_objects_iterator() with many to many 16 - $db_type");

  $o = $iterator->next;
  is($o, 0, "get_objects_iterator() with many to many 17 - $db_type");
  is($iterator->total, 3, "get_objects_iterator() with many to many 18 - $db_type");

  $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class  => 'MyInformixObject',
      share_db      => 1,
      with_objects  => [ 'bb1', 'nicks', 'other_obj', 'colors', 'bb2' ],
      multi_many_ok => 1,
      query         => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by       => 't1.name');

  $o = $iterator->next;
  is($o->name, 'Betty', "get_objects_iterator() with many to many 19 - $db_type");
  is($o->id, 5, "get_objects_iterator() with many to many 20 - $db_type");

  $nicks = $o->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects_iterator() with many to many 21 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects_iterator() with many to many 22 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects_iterator() with many to many 23 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects_iterator() with many to many 24 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects_iterator() with many to many 25 - $db_type");

  $fo1 = $o->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects_iterator() with many to many 26 - $db_type");

  $fo1 = $o->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects_iterator() with many to many 27 - $db_type"); 

  $o = $iterator->next;
  is($o->name, 'Fred', "get_objects_iterator() with many to many 28 - $db_type");
  is($o->id, 2, "get_objects_iterator() with many to many 29 - $db_type");

  $colors = $o->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects_iterator() with many to many 30 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many 31 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many 32 - $db_type");

  $o = $iterator->next;
  is($o->name, 'John', "get_objects_iterator() with many to many 33 - $db_type");
  is($o->id, 1, "get_objects_iterator() with many to many 34 - $db_type");

  $o = $iterator->next;
  is($o, 0, "get_objects_iterator() with many to many 35 - $db_type");
  is($iterator->total, 3, "get_objects_iterator() with many to many 36 - $db_type");

  $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class    => 'MyInformixObject',
      share_db        => 1,
      with_objects    => [ 'nicks', 'colors', 'bb2' ],
      multi_many_ok   => 1,
      require_objects => [ 'bb1', 'other_obj' ],
      query           => [ 't1.id' => [ 1, 2, 5 ] ],
      sort_by         => 't1.name');

  $o = $iterator->next;
  is($o->name, 'Betty', "get_objects_iterator() with many to many require 1 - $db_type");
  is($o->id, 5, "get_objects_iterator() with many to many require 2 - $db_type");

  $fo1 = $o->{'other_obj'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'Foo 1', "get_objects_iterator() with many to many require 3 - $db_type");

  ok(!defined $o->{'colors'}, "get_objects_iterator() with many to many require 4 - $db_type");

  $nicks = $o->{'nicks'}; # make sure this isn't hitting the db

  is(scalar @$nicks, 4, "get_objects_iterator() with many to many require 5 - $db_type");
  is($nicks->[0]->nick, 'nthree', "get_objects_iterator() with many to many require 6 - $db_type");
  is($nicks->[1]->nick, 'nsix', "get_objects_iterator() with many to many require 7 - $db_type");
  is($nicks->[2]->nick, 'none', "get_objects_iterator() with many to many require 8 - $db_type");
  is($nicks->[3]->nick, 'nfive', "get_objects_iterator() with many to many require 9 - $db_type");

  $fo1 = $o->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 2, "get_objects_iterator() with many to many require 10 - $db_type");

  $fo1 = $o->{'bb2'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->id == 4, "get_objects_iterator() with many to many require 11 - $db_type"); 

  $o = $iterator->next;
  is($o->name, 'Fred', "get_objects_iterator() with many to many require 12 - $db_type");
  is($o->id, 2, "get_objects_iterator() with many to many require 13 - $db_type");

  $colors = $o->{'colors'}; # make sure this isn't hitting the db
  ok($colors && ref $colors && @$colors == 2, "get_objects_iterator() with many to many require 14 - $db_type");
  ok($colors->[0]->id == 1 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many require 15 - $db_type");
  ok($colors->[1]->id == 3 && $colors->[0]->name eq 'Red', "get_objects_iterator() with many to many require 16 - $db_type");

  $fo1 = $o->{'bb1'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'two', "get_objects_iterator() with many to many require 17 - $db_type");

  $fo1 = $o->{'other_obj'}; # make sure this isn't hitting the db
  ok($fo1 && ref $fo1 && $fo1->name eq 'Foo 2', "get_objects_iterator() with many to many require 18 - $db_type");

  ok(!defined $o->{'bb2'}, "get_objects_iterator() with many to many require 19 - $db_type");

  $o = $iterator->next;
  is($o, 0, "get_objects_iterator() with many to many require 20 - $db_type");
  is($iterator->total, 2, "get_objects_iterator() with many to many require 21 - $db_type");

  # End "many to many" tests
}

BEGIN
{
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
    our $HAVE_PG = 1;

    Rose::DB->default_type('pg');

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_color_map');
      $dbh->do('DROP TABLE rose_db_object_colors');
      $dbh->do('DROP TABLE rose_db_object_nicks');
      $dbh->do('DROP TABLE rose_db_object_nicks2');
      $dbh->do('DROP TABLE rose_db_object_test');
      $dbh->do('DROP TABLE rose_db_object_other');
      $dbh->do('DROP TABLE rose_db_object_bb');
      $dbh->do('DROP TABLE rose_db_object_chkpass_test');
    }

    eval
    {
      local $dbh->{'RaiseError'} = 1;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('CREATE TABLE rose_db_object_chkpass_test (pass CHKPASS)');
      $dbh->do('DROP TABLE rose_db_object_chkpass_test');
    };

    our $PG_HAS_CHKPASS = 1  unless($@);

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_other
(
  k1    INT NOT NULL,
  k2    INT NOT NULL,
  k3    INT NOT NULL,
  name  VARCHAR(32),

  UNIQUE(k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_bb
(
  id    INT NOT NULL PRIMARY KEY,
  name  VARCHAR(32)
)
EOF

    # Create test foreign subclasses

    package MyPgOtherObject;

    our @ISA = qw(Rose::DB::Object);

    MyPgOtherObject->meta->table('rose_db_object_other');

    MyPgOtherObject->meta->columns
    (
      name => { type => 'varchar'},
      k1   => { type => 'int' },
      k2   => { type => 'int' },
      k3   => { type => 'int' },
    );

    MyPgOtherObject->meta->primary_key_columns(qw(k1 k2 k3));

    MyPgOtherObject->meta->initialize;

    package MyPgBB;

    our @ISA = qw(Rose::DB::Object);

    MyPgBB->meta->table('rose_db_object_bb');

    MyPgBB->meta->columns
    (
      id   => { type => 'int', primary_key => 1 },
      name => { type => 'varchar'},
    );

    MyPgBB->meta->initialize;

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id             INT NOT NULL PRIMARY KEY,
  @{[ $PG_HAS_CHKPASS ? 'password CHKPASS,' : '' ]}
  name           VARCHAR(32) NOT NULL,
  flag           BOOLEAN NOT NULL,
  flag2          BOOLEAN,
  status         VARCHAR(32) DEFAULT 'active',
  bits           BIT(5) NOT NULL DEFAULT B'00101',
  start          DATE,
  save           INT,
  nums           INT[],
  fk1            INT,
  fk2            INT,
  fk3            INT,
  b1             INT REFERENCES rose_db_object_bb (id),
  b2             INT REFERENCES rose_db_object_bb (id),
  last_modified  TIMESTAMP,
  date_created   TIMESTAMP,

  FOREIGN KEY (fk1, fk2, fk3) REFERENCES rose_db_object_other (k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_nicks
(
  id    SERIAL NOT NULL PRIMARY KEY,
  o_id  INT NOT NULL REFERENCES rose_db_object_test (id),
  nick  VARCHAR(32)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_nicks2
(
  id     SERIAL NOT NULL PRIMARY KEY,
  o_id   INT NOT NULL REFERENCES rose_db_object_test (id),
  nick2  VARCHAR(32)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_colors
(
  id     SERIAL NOT NULL PRIMARY KEY,
  name   VARCHAR(32) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_color_map
(
  id         SERIAL NOT NULL PRIMARY KEY,
  object_id  INT NOT NULL REFERENCES rose_db_object_test (id),
  color_id   INT NOT NULL REFERENCES rose_db_object_colors (id)
)
EOF

    $dbh->disconnect;

    package MyPgNick;

    our @ISA = qw(Rose::DB::Object);

    MyPgNick->meta->table('rose_db_object_nicks');

    MyPgNick->meta->columns
    (
      id   => { type => 'serial', primary_key => 1 },
      o_id => { type => 'int' },
      nick => { type => 'varchar'},
    );

    MyPgNick->meta->foreign_keys
    (
      obj =>
      {
        class => 'MyPgObject',
        key_columns => { o_id => 'id' },
      },
    );

    MyPgNick->meta->initialize;

    package MyPgNick2;

    our @ISA = qw(Rose::DB::Object);

    MyPgNick2->meta->table('rose_db_object_nicks2');

    MyPgNick2->meta->columns
    (
      id    => { type => 'serial', primary_key => 1 },
      o_id  => { type => 'int' },
      nick2 => { type => 'varchar'},
    );

    MyPgNick2->meta->foreign_keys
    (
      obj =>
      {
        class => 'MyPgObject',
        key_columns => { o_id => 'id' },
      },
    );

    MyPgNick2->meta->initialize;

    package MyPgColor;

    our @ISA = qw(Rose::DB::Object);

    MyPgColor->meta->table('rose_db_object_colors');

    MyPgColor->meta->columns
    (
      id   => { type => 'serial', primary_key => 1 },
      name => { type => 'varchar', not_null => 1 },
    );

    MyPgColor->meta->relationships
    (
      objects =>
      {
        type      => 'many to many',
        map_class => 'MyPgColorMap',
      },
    );

    MyPgColor->meta->initialize;

    package MyPgColorMap;

    our @ISA = qw(Rose::DB::Object);

    MyPgColorMap->meta->table('rose_db_object_color_map');

    MyPgColorMap->meta->columns
    (
      id        => { type => 'serial', primary_key => 1 },
      object_id => { type => 'int', not_null => 1 },
      color_id  => { type => 'int', not_null => 1 },
    );

    MyPgColorMap->meta->foreign_keys
    (
      color =>
      {
        class => 'MyPgColor',
        key_columns => { color_id => 'id' },
      },

      object =>
      {
        class => 'MyPgObject',
        key_columns => { object_id => 'id' },
      },
    );

    MyPgColorMap->meta->initialize;

    # Create test subclass

    package MyPgObject;

    our @ISA = qw(Rose::DB::Object);

    MyPgObject->meta->table('rose_db_object_test');

    MyPgObject->meta->columns
    (
      'name',
      id       => { primary_key => 1 },
      ($PG_HAS_CHKPASS ? (password => { type => 'chkpass' }) : ()),
      flag     => { type => 'boolean', default => 1 },
      flag2    => { type => 'boolean' },
      status   => { default => 'active' },
      start    => { type => 'date', default => '12/24/1980' },
      save     => { type => 'scalar' },
      nums     => { type => 'array' },
      bits     => { type => 'bitfield', bits => 5, default => 101 },
      fk1      => { type => 'int' },
      fk2      => { type => 'int' },
      fk3      => { type => 'int' },
      b1       => { type => 'int' },
      b2       => { type => 'int' },
      last_modified => { type => 'timestamp' },
      date_created  => { type => 'timestamp' },
    );

    MyPgObject->meta->foreign_keys
    (
      other_obj =>
      {
        class => 'MyPgOtherObject',
        key_columns =>
        {
          fk1 => 'k1',
          fk2 => 'k2',
          fk3 => 'k3',
        }
      },

      bb1 =>
      {
        class => 'MyPgBB',
        key_columns => { b1 => 'id' },
      },

      bb2 =>
      {
        class => 'MyPgBB',
        key_columns => { b2 => 'id' },
      },
    );

    MyPgObject->meta->relationships
    (
      nicks =>
      {
        type  => 'one to many',
        class => 'MyPgNick',
        column_map => { id => 'o_id' },
        manager_args => { sort_by => 'nick DESC' },
      },

      nicks2 =>
      {
        type  => 'one to many',
        class => 'MyPgNick2',
        column_map => { id => 'o_id' },
        manager_args => { sort_by => 'nick2 DESC' },
      },

      colors =>
      {
        type      => 'many to many',
        map_class => 'MyPgColorMap',
        manager_args => { sort_by => MyPgColor->meta->table . '.name DESC' },
      },
    );

    MyPgObject->meta->alias_column(fk1 => 'fkone');

    eval { MyPgObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() reserved method - pg');

    MyPgObject->meta->alias_column(save => 'save_col');
    MyPgObject->meta->initialize(preserve_existing => 1);

    Rose::DB::Object::Manager->make_manager_methods(base_name => 'objectz');

    eval { Rose::DB::Object::Manager->make_manager_methods('objectz') };
    Test::More::ok($@, 'make_manager_methods clash - pg');

    package MyPgObjectManager;
    our @ISA = qw(Rose::DB::Object::Manager);

    MyPgObjectManager->make_manager_methods(object_class => 'MyPgObject',
                                            methods =>
                                            {
                                              objectz => [ qw(objects iterator) ],
                                              'object_count()' => 'count'
                                            });
  }

  #
  # MySQL
  #

  eval 
  {
    $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    our $HAVE_MYSQL = 1;

    Rose::DB->default_type('mysql');

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_color_map');
      $dbh->do('DROP TABLE rose_db_object_colors');
      $dbh->do('DROP TABLE rose_db_object_nicks');
      $dbh->do('DROP TABLE rose_db_object_nicks2');
      $dbh->do('DROP TABLE rose_db_object_test');
      $dbh->do('DROP TABLE rose_db_object_bb');
      $dbh->do('DROP TABLE rose_db_object_other');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_other
(
  k1    INT NOT NULL,
  k2    INT NOT NULL,
  k3    INT NOT NULL,
  name  VARCHAR(32),

  KEY(k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_bb
(
  id    INT NOT NULL PRIMARY KEY,
  name  VARCHAR(32)
)
EOF

    # Create test foreign subclasses

    package MyMySQLOtherObject;

    our @ISA = qw(Rose::DB::Object);

    MyMySQLOtherObject->meta->table('rose_db_object_other');

    MyMySQLOtherObject->meta->columns
    (
      name => { type => 'varchar'},
      k1   => { type => 'int' },
      k2   => { type => 'int' },
      k3   => { type => 'int' },
    );

    MyMySQLOtherObject->meta->primary_key_columns([ qw(k1 k2 k3) ]);

    MyMySQLOtherObject->meta->initialize;

    package MyMySQLBB;

    our @ISA = qw(Rose::DB::Object);

    MyMySQLBB->meta->table('rose_db_object_bb');

    MyMySQLBB->meta->columns
    (
      id   => { type => 'int', primary_key => 1 },
      name => { type => 'varchar'},
    );

    MyMySQLBB->meta->initialize;

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name           VARCHAR(32) NOT NULL,
  flag           TINYINT(1) NOT NULL,
  flag2          TINYINT(1),
  status         VARCHAR(32) DEFAULT 'active',
  bits           VARCHAR(5) NOT NULL DEFAULT '00101',
  nums           VARCHAR(255),
  start          DATE,
  save           INT,
  fk1            INT,
  fk2            INT,
  fk3            INT,
  b1             INT,
  b2             INT,
  last_modified  TIMESTAMP,
  date_created   DATETIME
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_nicks
(
  id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  o_id  INT UNSIGNED NOT NULL REFERENCES rose_db_object_test (id),
  nick  VARCHAR(32)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_nicks2
(
  id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  o_id   INT UNSIGNED NOT NULL REFERENCES rose_db_object_test (id),
  nick2  VARCHAR(32)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_colors
(
  id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name   VARCHAR(32) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_color_map
(
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  object_id  INT UNSIGNED NOT NULL REFERENCES rose_db_object_test (id),
  color_id   INT UNSIGNED NOT NULL REFERENCES rose_db_object_colors (id)
)
EOF

    $dbh->disconnect;

    package MyMySQLNick;

    our @ISA = qw(Rose::DB::Object);

    MyMySQLNick->meta->table('rose_db_object_nicks');

    MyMySQLNick->meta->columns
    (
      id   => { type => 'int', primary_key => 1 },
      o_id => { type => 'int' },
      nick => { type => 'varchar'},
    );

    MyMySQLNick->meta->foreign_keys
    (
      obj =>
      {
        class => 'MyMySQLObject',
        key_columns => { o_id => 'id' },
      },
    );

    MyMySQLNick->meta->initialize;

    package MyMySQLNick2;

    our @ISA = qw(Rose::DB::Object);

    MyMySQLNick2->meta->table('rose_db_object_nicks2');

    MyMySQLNick2->meta->columns
    (
      id    => { type => 'int', primary_key => 1 },
      o_id  => { type => 'int' },
      nick2 => { type => 'varchar'},
    );

    MyMySQLNick2->meta->foreign_keys
    (
      obj =>
      {
        class => 'MyMySQLObject',
        key_columns => { o_id => 'id' },
      },
    );

    MyMySQLNick2->meta->initialize;

    package MyMySQLColor;

    our @ISA = qw(Rose::DB::Object);

    MyMySQLColor->meta->table('rose_db_object_colors');

    MyMySQLColor->meta->columns
    (
      id   => { type => 'serial', primary_key => 1 },
      name => { type => 'varchar', not_null => 1 },
    );

    MyMySQLColor->meta->relationships
    (
      objects =>
      {
        type      => 'many to many',
        map_class => 'MyMySQLColorMap',
      },
    );

    MyMySQLColor->meta->initialize;

    package MyMySQLColorMap;

    our @ISA = qw(Rose::DB::Object);

    MyMySQLColorMap->meta->table('rose_db_object_color_map');

    MyMySQLColorMap->meta->columns
    (
      id        => { type => 'serial', primary_key => 1 },
      object_id => { type => 'int', not_null => 1 },
      color_id  => { type => 'int', not_null => 1 },
    );

    MyMySQLColorMap->meta->foreign_keys
    (
      color =>
      {
        class => 'MyMySQLColor',
        key_columns => { color_id => 'id' },
      },

      object =>
      {
        class => 'MyMySQLObject',
        key_columns => { object_id => 'id' },
      },
    );

    MyMySQLColorMap->meta->initialize;

    # Create test subclass

    package MyMySQLObject;

    our @ISA = qw(Rose::DB::Object);

    MyMySQLObject->meta->table('rose_db_object_test');

    MyMySQLObject->meta->columns
    (
      'name',
      id       => { primary_key => 1 },
      flag     => { type => 'boolean', default => 1 },
      flag2    => { type => 'boolean' },
      status   => { default => 'active' },
      start    => { type => 'date', default => '12/24/1980' },
      save     => { type => 'scalar' },
      bits     => { type => 'bitfield', bits => 5, default => 101 },
      nums     => { type => 'array' },
      fk1      => { type => 'int' },
      fk2      => { type => 'int' },
      fk3      => { type => 'int' },
      b1       => { type => 'int' },
      b2       => { type => 'int' },
      last_modified => { type => 'timestamp' },
      date_created  => { type => 'datetime' },
    );

    MyMySQLObject->meta->foreign_keys
    (
      other_obj =>
      {
        class => 'MyMySQLOtherObject',
        key_columns =>
        {
          fk1 => 'k1',
          fk2 => 'k2',
          fk3 => 'k3',
        }
      },

      bb1 =>
      {
        class => 'MyMySQLBB',
        key_columns => { b1 => 'id' },
      },

      bb2 =>
      {
        class => 'MyMySQLBB',
        key_columns => { b2 => 'id' },
      },
    );

    MyMySQLObject->meta->relationships
    (
      nicks =>
      {
        type  => 'one to many',
        class => 'MyMySQLNick',
        column_map => { id => 'o_id' },
        manager_args => { sort_by => 'nick DESC' },
      },

      nicks2 =>
      {
        type  => 'one to many',
        class => 'MyMySQLNick2',
        column_map => { id => 'o_id' },
        manager_args => { sort_by => 'nick2 DESC' },
      },

      colors =>
      {
        type      => 'many to many',
        map_class => 'MyMySQLColorMap',
        manager_args => { sort_by => MyMySQLColor->meta->table . '.name DESC' },
      },
    );

    MyMySQLObject->meta->alias_column(fk1 => 'fkone');

    eval { MyMySQLObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() reserved method - mysql');

    MyMySQLObject->meta->alias_column(save => 'save_col');
    MyMySQLObject->meta->initialize(preserve_existing => 1);

    Rose::DB::Object::Manager->make_manager_methods('objectz');

    eval { Rose::DB::Object::Manager->make_manager_methods('objectz') };
    Test::More::ok($@, 'make_manager_methods clash - mysql');

    package MyMySQLObjectManager;
    our @ISA = qw(Rose::DB::Object::Manager);

    sub object_class { 'MyMySQLObject' }
    Rose::DB::Object::Manager->make_manager_methods('objectz');

    eval
    {
      Rose::DB::Object::Manager->make_manager_methods(object_class => 'MyMySQLObject',
                                                      base_name    => 'objectz',
                                                      methods      => {})
    };

    Test::More::ok($@ =~ /not both/, 'make_manager_methods params clash - mysql');
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
    our $HAVE_INFORMIX = 1;

    Rose::DB->default_type('informix');

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_color_map');
      $dbh->do('DROP TABLE rose_db_object_colors');
      $dbh->do('DROP TABLE rose_db_object_nicks');
      $dbh->do('DROP TABLE rose_db_object_nicks2');
      $dbh->do('DROP TABLE rose_db_object_test');
      $dbh->do('DROP TABLE rose_db_object_other');
      $dbh->do('DROP TABLE rose_db_object_bb');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_other
(
  k1    INT NOT NULL,
  k2    INT NOT NULL,
  k3    INT NOT NULL,
  name  VARCHAR(32),

  UNIQUE(k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_bb
(
  id    INT NOT NULL PRIMARY KEY,
  name  VARCHAR(32)
)
EOF

    # Create test foreign subclasses

    package MyInformixOtherObject;

    our @ISA = qw(Rose::DB::Object);

    MyInformixOtherObject->meta->table('rose_db_object_other');

    MyInformixOtherObject->meta->columns
    (
      name => { type => 'varchar'},
      k1   => { type => 'int' },
      k2   => { type => 'int' },
      k3   => { type => 'int' },
    );

    MyInformixOtherObject->meta->primary_key_columns([ qw(k1 k2 k3) ]);

    MyInformixOtherObject->meta->initialize;

    package MyInformixBB;

    our @ISA = qw(Rose::DB::Object);

    MyInformixBB->meta->table('rose_db_object_bb');

    MyInformixBB->meta->columns
    (
      id   => { type => 'int', primary_key => 1 },
      name => { type => 'varchar'},
    );

    MyInformixBB->meta->initialize;

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id             INT NOT NULL PRIMARY KEY,
  name           VARCHAR(32) NOT NULL,
  flag           BOOLEAN NOT NULL,
  flag2          BOOLEAN,
  status         VARCHAR(32) DEFAULT 'active',
  bits           VARCHAR(5) DEFAULT '00101' NOT NULL,
  start          DATE,
  save           INT,
  nums           SET(INT NOT NULL),
  fk1            INT,
  fk2            INT,
  fk3            INT,
  b1             INT REFERENCES rose_db_object_bb (id),
  b2             INT REFERENCES rose_db_object_bb (id),
  last_modified  DATETIME YEAR TO FRACTION(5),
  date_created   DATETIME YEAR TO FRACTION(5),

  FOREIGN KEY (fk1, fk2, fk3) REFERENCES rose_db_object_other (k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_nicks
(
  id    SERIAL NOT NULL PRIMARY KEY,
  o_id  INT NOT NULL REFERENCES rose_db_object_test (id),
  nick  VARCHAR(32)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_nicks2
(
  id     SERIAL NOT NULL PRIMARY KEY,
  o_id   INT NOT NULL REFERENCES rose_db_object_test (id),
  nick2  VARCHAR(32)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_colors
(
  id     SERIAL NOT NULL PRIMARY KEY,
  name   VARCHAR(32) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_color_map
(
  id         SERIAL NOT NULL PRIMARY KEY,
  object_id  INT NOT NULL REFERENCES rose_db_object_test (id),
  color_id   INT NOT NULL REFERENCES rose_db_object_colors (id)
)
EOF

    $dbh->commit;
    $dbh->disconnect;

    package MyInformixNick;

    our @ISA = qw(Rose::DB::Object);

    MyInformixNick->meta->table('rose_db_object_nicks');

    MyInformixNick->meta->columns
    (
      id   => { type => 'serial', primary_key => 1 },
      o_id => { type => 'int' },
      nick => { type => 'varchar'},
    );

    MyInformixNick->meta->foreign_keys
    (
      obj =>
      {
        class => 'MyInformixObject',
        key_columns => { o_id => 'id' },
      },
    );

    MyInformixNick->meta->initialize;

    package MyInformixNick2;

    our @ISA = qw(Rose::DB::Object);

    MyInformixNick2->meta->table('rose_db_object_nicks2');

    MyInformixNick2->meta->columns
    (
      id    => { type => 'serial', primary_key => 1 },
      o_id  => { type => 'int' },
      nick2 => { type => 'varchar'},
    );

    MyInformixNick2->meta->foreign_keys
    (
      obj =>
      {
        class => 'MyInformixObject',
        key_columns => { o_id => 'id' },
      },
    );

    MyInformixNick2->meta->initialize;

    package MyInformixColor;

    our @ISA = qw(Rose::DB::Object);

    MyInformixColor->meta->table('rose_db_object_colors');

    MyInformixColor->meta->columns
    (
      id   => { type => 'serial', primary_key => 1 },
      name => { type => 'varchar', not_null => 1 },
    );

    MyInformixColor->meta->relationships
    (
      objects =>
      {
        type      => 'many to many',
        map_class => 'MyInformixColorMap',
      },
    );

    MyInformixColor->meta->initialize;

    package MyInformixColorMap;

    our @ISA = qw(Rose::DB::Object);

    MyInformixColorMap->meta->table('rose_db_object_color_map');

    MyInformixColorMap->meta->columns
    (
      id        => { type => 'serial', primary_key => 1 },
      object_id => { type => 'int', not_null => 1 },
      color_id  => { type => 'int', not_null => 1 },
    );

    MyInformixColorMap->meta->foreign_keys
    (
      color =>
      {
        class => 'MyInformixColor',
        key_columns => { color_id => 'id' },
      },

      object =>
      {
        class => 'MyInformixObject',
        key_columns => { object_id => 'id' },
      },
    );

    MyInformixColorMap->meta->initialize;

    # Create test subclass

    package MyInformixObject;

    our @ISA = qw(Rose::DB::Object);

    MyInformixObject->meta->table('rose_db_object_test');

    MyInformixObject->meta->columns
    (
      'name',
      id       => { primary_key => 1 },
      flag     => { type => 'boolean', default => 1 },
      flag2    => { type => 'boolean' },
      status   => { default => 'active' },
      start    => { type => 'date', default => '12/24/1980' },
      save     => { type => 'scalar' },
      nums     => { type => 'set' },
      bits     => { type => 'bitfield', bits => 5, default => 101 },
      fk1      => { type => 'int' },
      fk2      => { type => 'int' },
      fk3      => { type => 'int' },
      b1       => { type => 'int' },
      b2       => { type => 'int' },
      last_modified => { type => 'timestamp' },
      date_created  => { type => 'timestamp' },
    );

    MyInformixObject->meta->foreign_keys
    (
      other_obj =>
      {
        class => 'MyInformixOtherObject',
        key_columns =>
        {
          fk1 => 'k1',
          fk2 => 'k2',
          fk3 => 'k3',
        }
      },

      bb1 =>
      {
        class => 'MyInformixBB',
        key_columns => { b1 => 'id' },
      },

      bb2 =>
      {
        class => 'MyInformixBB',
        key_columns => { b2 => 'id' },
      },
    );

    MyInformixObject->meta->relationships
    (
      nicks =>
      {
        type  => 'one to many',
        class => 'MyInformixNick',
        column_map => { id => 'o_id' },
        manager_args => { sort_by => 'nick DESC' },
      },

      nicks2 =>
      {
        type  => 'one to many',
        class => 'MyInformixNick2',
        column_map => { id => 'o_id' },
        manager_args => { sort_by => 'nick2 DESC' },
      },

      colors =>
      {
        type      => 'many to many',
        map_class => 'MyInformixColorMap',
        manager_args => { sort_by => MyInformixColor->meta->table . '.name DESC' },
      },
    );

    MyInformixObject->meta->alias_column(fk1 => 'fkone');

    eval { MyInformixObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() reserved method - informix');

    MyInformixObject->meta->alias_column(save => 'save_col');
    MyInformixObject->meta->initialize(preserve_existing => 1);

    Rose::DB::Object::Manager->make_manager_methods('objectz');

    eval { Rose::DB::Object::Manager->make_manager_methods('objectz') };
    Test::More::ok($@, 'make_manager_methods clash - informix');

    package MyInformixObjectManager;
    our @ISA = qw(Rose::DB::Object::Manager);

    Rose::DB::Object::Manager->make_manager_methods(object_class => 'MyInformixObject',
                                                    base_name    => 'objectz');
  }
}

END
{
  # Delete test table

  if($HAVE_PG)
  {
    # Postgres
    my $dbh = Rose::DB->new('pg_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_color_map');
    $dbh->do('DROP TABLE rose_db_object_colors');
    $dbh->do('DROP TABLE rose_db_object_nicks');
    $dbh->do('DROP TABLE rose_db_object_nicks2');
    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->do('DROP TABLE rose_db_object_other');
    $dbh->do('DROP TABLE rose_db_object_bb');

    $dbh->disconnect;
  }

  if($HAVE_MYSQL)
  {
    # MySQL
    my $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_color_map');
    $dbh->do('DROP TABLE rose_db_object_colors');
    $dbh->do('DROP TABLE rose_db_object_nicks');
    $dbh->do('DROP TABLE rose_db_object_nicks2');
    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->do('DROP TABLE rose_db_object_other');
    $dbh->do('DROP TABLE rose_db_object_bb');

    $dbh->disconnect;
  }

  if($HAVE_INFORMIX)
  {
    # Informix
    my $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_color_map');
    $dbh->do('DROP TABLE rose_db_object_colors');
    $dbh->do('DROP TABLE rose_db_object_nicks');
    $dbh->do('DROP TABLE rose_db_object_nicks2');
    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->do('DROP TABLE rose_db_object_other');
    $dbh->do('DROP TABLE rose_db_object_bb');

    $dbh->disconnect;
  }
}
