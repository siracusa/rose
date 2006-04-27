#!/usr/bin/perl -w

use strict;

use Test::More tests => 19;

use Scalar::Util qw(isweak);

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object');
}

our %HAVE;

my $db_type = $HAVE{'sqlite'} ? 'sqlite' : (sort keys %HAVE)[0];

SKIP:
{
  skip("No db available", 117)  unless($db_type);

  package MyObject;
  use base 'Rose::DB::Object';
  __PACKAGE__->meta->table('objects');
  __PACKAGE__->meta->columns
  (
    id    => { type => 'int', primary_key => 1 },
    start => { type => 'scalar' },
  );
  __PACKAGE__->meta->initialize;
  sub init_db { Rose::DB->new($db_type) }

  package MySubObject;
  use base 'MyObject';
  __PACKAGE__->meta->column('id')->default(123);
  __PACKAGE__->meta->delete_column('start');
  __PACKAGE__->meta->add_column(start => { type => 'datetime' });
  __PACKAGE__->meta->initialize(replace_existing => 1);

  package MySubObject2;
  use base 'MyObject';
  __PACKAGE__->meta->table('s2objs');
  __PACKAGE__->meta->initialize(preserve_existing => 1);
  sub id 
  {
    my($self) = shift;
    return $self->{'id'} = shift  if(@_);
    return defined $self->{'id'} ? $self->{'id'} : 456;
  }

  package MySubObject3;
  use base 'MySubObject';
  __PACKAGE__->meta->initialize(preserve_existing => 1);

  package main;

  ok(MyObject->meta ne MySubObject->meta, "meta 1 - $db_type");
  ok(MyObject->meta ne MySubObject2->meta, "meta 2 - $db_type");
  ok(MySubObject->meta ne MySubObject2->meta, "meta 3 - $db_type");

  ok(isweak(MyObject->meta->column('id')->{'parent'}), "meta weakened 1 - $db_type");
  ok(isweak(MySubObject->meta->column('id')->{'parent'}), "meta weakened 2 - $db_type");
  ok(isweak(MySubObject2->meta->column('id')->{'parent'}), "meta weakened 3 - $db_type");

  my $o = MyObject->new;
  is(MyObject->meta->table, 'objects', "base class 1 - $db_type");
  ok(!defined $o->id, "base class 2 - $db_type");
  $o->start('1/2/2003');
  is($o->start, '1/2/2003', "base class 3 - $db_type");

  my $s = MySubObject->new;
  is(MyObject->meta->table, 'objects', "subclass 1.1 - $db_type");
  is($s->id, 123, "subclass 1.2 - $db_type");
  $s->start('1/2/2003');
  is($s->start->strftime('%B'), 'January', "subclass 1.3 - $db_type");

  my $t = MySubObject2->new;
  is(MySubObject2->meta->table, 's2objs', "subclass 2.1 - $db_type");
  is($t->id, 456, "subclass 2.2 - $db_type");
  $t->start('1/2/2003');
  is($t->start, '1/2/2003', "subclass 2.3 - $db_type");

  my $f = MySubObject3->new;
  is(MySubObject3->meta->table, 'objects', "subclass 3.1 - $db_type");
  is($f->id, 123, "subclass 3.2 - $db_type");
  $f->start('1/2/2003');
  is($f->start->strftime('%B'), 'January', "subclass 3.3 - $db_type");
}

BEGIN
{
  our %HAVE;

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
    $HAVE{'pg'} = 1;
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
    $HAVE{'mysql'} = 1;
  }

  #
  # SQLite
  #

  eval 
  {
    $dbh = Rose::DB->new('sqlite_admin')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    $HAVE{'sqlite'} = 1;
  }
}
