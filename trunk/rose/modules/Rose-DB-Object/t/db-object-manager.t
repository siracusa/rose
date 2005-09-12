#!/usr/bin/perl -w

use strict;

use Test::More tests => 303;

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
  skip("Postgres tests", 166)  unless($HAVE_PG);

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
      with_objects => [ 'other_obj', 'bb1', 'bb2' ]);

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
      with_objects => [ 'other_obj', 'bb1', 'bb2' ]);

  $o = $iterator->next;

  ok(ref $o->{'other_obj'} eq 'MyPgOtherObject', "foreign object 4 - $db_type");
  is($o->other_obj->k2, 2, "foreign object 5 - $db_type");

  is($o->bb1->name, 'two', "bb foreign object 5 - $db_type");
  is($o->bb2->name, 'four', "bb foreign object 6 - $db_type");

################XXXXXXXXXXXXXXXXXX

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

  is(ref $iterator, 'Rose::DB::Object::Iterator', "get_objects_iterator() 2 - $db_type");

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
  is($o->name, 'Bob', "iterator limit 2 many next() 2 - $db_type");
  is($o->id, 4, "iterator limit 2 many next() 3 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator limit 2 many next() 4 - $db_type");
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

###########XXXXXXXXXXX

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
      with_objects => [ 'other_obj' ]);

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
      with_objects => [ 'other_obj' ],
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
}

#
# MySQL
#

SKIP: foreach my $db_type ('mysql')
{
  skip("MySQL tests", 65)  unless($HAVE_MYSQL);

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
      with_objects => [ 'other_obj', 'bb1', 'bb2' ]);

  ok(ref $objs->[0]->{'other_obj'} eq 'MyMySQLOtherObject', "foreign object 2 - $db_type");
  is($objs->[0]->other_obj->k2, 2, "foreign object 3 - $db_type");

  is($objs->[0]->bb1->name, 'two', "bb foreign object 3 - $db_type");
  is($objs->[0]->bb2->name, 'four', "bb foreign object 4 - $db_type");

###########XXXXXXXXXXX

###########XXXXXXXXXXX

  $iterator =
    MyMySQLObjectManager->get_objectz_iterator(
      share_db     => 1,
      query        =>
      [
        't1.id'    => { ge => 2 },
        't1.name'  => { like => '%tt%' },
      ],
      with_objects => [ 'other_obj', 'bb1', 'bb2' ]);

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
      with_objects => [ 'other_obj' ]);

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
      with_objects => [ 'other_obj' ],
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
}

#
# Informix
#

SKIP: foreach my $db_type (qw(informix))
{
  skip("Informix tests", 70)  unless($HAVE_INFORMIX);

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

  #local $Rose::DB::Object::Manager::Debug = 1;

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

  is(ref $iterator, 'Rose::DB::Object::Iterator', "get_objects_iterator() 4 - $db_type");

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
      with_objects => [ 'other_obj' ]);

  ok(ref $objs->[0]->{'other_obj'} eq 'MyInformixOtherObject', "foreign object 2 - $db_type");
  is($objs->[0]->other_obj->k2, 2, "foreign object 3 - $db_type");

  is($objs->[0]->bb1->name, 'two', "bb foreign object 3 - $db_type");
  is($objs->[0]->bb2->name, 'four', "bb foreign object 4 - $db_type");

  $iterator =
    MyInformixObject->get_objectz_iterator(
      share_db     => 1,
      query        =>
      [
        't1.id'    => { ge => 2 },
        't1.name'  => { like => '%tt%' },
      ],
      with_objects => [ 'other_obj' ]);

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
      with_objects => [ 'other_obj' ]);

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
      with_objects => [ 'other_obj' ],
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
      $dbh->do('DROP TABLE rose_db_object_nicks');
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
  id    INT NOT NULL PRIMARY KEY,
  o_id  INT NOT NULL REFERENCES rose_db_object_test (id),
  nick  VARCHAR(32)
)
EOF

    $dbh->disconnect;

    package MyPgNick;

    our @ISA = qw(Rose::DB::Object);

    MyPgNick->meta->table('rose_db_object_nicks');

    MyPgNick->meta->columns
    (
      id   => { type => 'int', primary_key => 1 },
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
      }
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
      $dbh->do('DROP TABLE rose_db_object_nicks');
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
  id    INT NOT NULL PRIMARY KEY,
  o_id  INT NOT NULL REFERENCES rose_db_object_test (id),
  nick  VARCHAR(32)
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
      }
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

    $dbh->commit;
    $dbh->disconnect;

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

    $dbh->do('DROP TABLE rose_db_object_nicks');      
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

    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->do('DROP TABLE rose_db_object_other');

    $dbh->disconnect;
  }

  if($HAVE_INFORMIX)
  {
    # Informix
    my $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->do('DROP TABLE rose_db_object_other');

    $dbh->disconnect;
  }
}

