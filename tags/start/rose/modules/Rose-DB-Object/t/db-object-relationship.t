#!/usr/bin/perl -w

use strict;

use Test::More tests => 189;

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object');
}

our($PG_HAS_CHKPASS, $HAVE_PG, $HAVE_MYSQL, $HAVE_INFORMIX);

#
# Postgres
#

SKIP: foreach my $db_type ('pg')
{
  skip("Postgres tests", 74)  unless($HAVE_PG);

  Rose::DB->default_type($db_type);

  my $o = MyPgObject->new(name => 'John');

  ok(ref $o && $o->isa('MyPgObject'), "new() 1 - $db_type");

  $o->flag2('true');
  $o->date_created('now');
  $o->last_modified($o->date_created);
  $o->save_col(7);

  ok($o->save, "save() 1 - $db_type");
  ok($o->load, "load() 1 - $db_type");

  my $o_x = MyPgObject->new(id => 99, name => 'John X', flag => 0);
  $o_x->save;

  my $o2 = MyPgObject->new(id => $o->id);

  ok(ref $o2 && $o2->isa('MyPgObject'), "new() 2 - $db_type");

  is($o2->bits->to_Bin, '00101', "bits() (bitfield default value) - $db_type");

  ok($o2->load, "load() 2 - $db_type");
  ok(!$o2->not_found, "not_found() 1 - $db_type");

  is($o2->name, $o->name, "load() verify 1 - $db_type");
  is($o2->date_created, $o->date_created, "load() verify 2 - $db_type");
  is($o2->last_modified, $o->last_modified, "load() verify 3 - $db_type");
  is($o2->status, 'active', "load() verify 4 (default value) - $db_type");
  is($o2->flag, 1, "load() verify 5 (default boolean value) - $db_type");
  is($o2->flag2, 1, "load() verify 6 (boolean value) - $db_type");
  is($o2->save_col, 7, "load() verify 7 (aliased column) - $db_type");
  is($o2->start->ymd, '1980-12-24', "load() verify 8 (date value) - $db_type");

  is($o2->bits->to_Bin, '00101', "load() verify 9 (bitfield value) - $db_type");

  $o2->name('John 2');
  $o2->start('5/24/2001');

  sleep(1); # keep the last modified dates from being the same

  $o2->last_modified('now');
  ok($o2->save, "save() 2 - $db_type");
  ok($o2->load, "load() 3 - $db_type");

  is($o2->date_created, $o->date_created, "save() verify 1 - $db_type");
  ok($o2->last_modified ne $o->last_modified, "save() verify 2 - $db_type");
  is($o2->start->ymd, '2001-05-24', "save() verify 3 (date value) - $db_type");

  my $o3 = MyPgObject->new();

  my $db = $o3->db or die $o3->error;

  ok(ref $db && $db->isa('Rose::DB'), "db() - $db_type");

  is($db->dbh, $o3->dbh, "dbh() - $db_type");

  my $o4 = MyPgObject->new(id => 999);
  ok(!$o4->load(speculative => 1), "load() nonexistent - $db_type");
  ok($o4->not_found, "not_found() 2 - $db_type");

  ok($o->load, "load() 4 - $db_type");

  SKIP:
  {
    if($PG_HAS_CHKPASS)
    {
      $o->{'password_encrypted'} = ':8R1Kf2nOS0bRE';

      ok($o->password_is('xyzzy'), "chkpass() 1 - $db_type");
      is($o->password, 'xyzzy', "chkpass() 2 - $db_type");

      $o->password('foobar');

      ok($o->password_is('foobar'), "chkpass() 3 - $db_type");
      is($o->password, 'foobar', "chkpass() 4 - $db_type");

      ok($o->save, "save() 3 - $db_type");
    }
    else
    {
      skip("chkpass tests", 5);
    }
  }

  my $o5 = MyPgObject->new(id => $o->id);

  ok($o5->load, "load() 5 - $db_type");

  SKIP:
  {
    if($PG_HAS_CHKPASS)
    {
      ok($o5->password_is('foobar'), "chkpass() 5 - $db_type");
      is($o5->password, 'foobar', "chkpass() 6 - $db_type"); 
    }
    else
    {
      skip("chkpass tests", 2);
    }
  }

  $o5->nums([ 4, 5, 6 ]);
  ok($o5->save, "save() 4 - $db_type");
  ok($o->load, "load() 6 - $db_type");

  is($o5->nums->[0], 4, "load() verify 10 (array value) - $db_type");
  is($o5->nums->[1], 5, "load() verify 11 (array value) - $db_type");
  is($o5->nums->[2], 6, "load() verify 12 (array value) - $db_type");

  my @a = $o5->nums;

  is($a[0], 4, "load() verify 13 (array value) - $db_type");
  is($a[1], 5, "load() verify 14 (array value) - $db_type");
  is($a[2], 6, "load() verify 15 (array value) - $db_type");
  is(@a, 3, "load() verify 16 (array value) - $db_type");

  my $oo1 = MyPgOtherObject->new(k1 => 1, k2 => 2, k3 => 3, name => 'one');
  ok($oo1->save, 'other object save() 1');

  my $oo2 = MyPgOtherObject->new(k1 => 11, k2 => 12, k3 => 13, name => 'two');
  ok($oo2->save, 'other object save() 2');

  is($o->other_obj, undef, 'other_obj() 1');

  $o->fkone(1);
  $o->fk2(2);
  $o->fk3(3);

  my $obj = $o->other_obj or warn "# ", $o->error, "\n";

  is(ref $obj, 'MyPgOtherObject', 'other_obj() 2');
  is($obj->name, 'one', 'other_obj() 3');
  is($obj->db, $o->db, 'share_db (default true)');

  $o->other_obj(undef);
  $o->fkone(11);
  $o->fk2(12);
  $o->fk3(13);

  $obj = $o->other_obj or warn "# ", $o->error, "\n";

  is(ref $obj, 'MyPgOtherObject', 'other_obj() 4');
  is($obj->name, 'two', 'other_obj() 5');

  my $oo21 = MyPgOtherObject2->new(id => 1, name => 'one', pid => $o->id);
  ok($oo21->save, 'other object 2 save() 1');

  my $oo22 = MyPgOtherObject2->new(id => 2, name => 'two', pid => $o->id);
  ok($oo22->save, 'other object 2 save() 2');

  my $oo23 = MyPgOtherObject2->new(id => 3, name => 'three', pid => $o_x->id);
  ok($oo23->save, 'other object 2 save() 3');

  my $o2s = $o->other2_objs;

  ok(ref $o2s eq 'ARRAY' && @$o2s == 2 && 
     $o2s->[0]->name eq 'two' && $o2s->[1]->name eq 'one',
     'other objects 1');

  my @o2s = $o->other2_objs;

  ok(@o2s == 2 && $o2s[0]->name eq 'two' && $o2s[1]->name eq 'one',
     'other objects 2');

  my $color = MyPgColor->new(id => 1, name => 'red');
  ok($color->save, "save color 1 - $db_type");
  
  $color = MyPgColor->new(id => 2, name => 'green');
  ok($color->save, "save color 2 - $db_type");

  $color = MyPgColor->new(id => 3, name => 'blue');
  ok($color->save, "save color 3 - $db_type");

  $color = MyPgColor->new(id => 4, name => 'pink');
  ok($color->save, "save color 4 - $db_type");

  my $map1 = MyPgColorMap->new(obj_id => 1, color_id => 1);
  ok($map1->save, "save color map record 1 - $db_type");

  my $map2 = MyPgColorMap->new(obj_id => 1, color_id => 3);
  ok($map2->save, "save color map record 2 - $db_type");

  my $map3 = MyPgColorMap->new(obj_id => 99, color_id => 4);
  ok($map3->save, "save color map record 3 - $db_type");

  my $colors = $o->colors;

  ok(ref $colors eq 'ARRAY' && @$colors == 2 && 
     $colors->[0]->name eq 'red' && $colors->[1]->name eq 'blue',
     "colors 1 - $db_type");

  my @colors = $o->colors;

  ok(@colors == 2 && $colors[0]->name eq 'red' && $colors[1]->name eq 'blue',
     "colors 2 - $db_type");

  $colors = $o_x->colors;

  ok(ref $colors eq 'ARRAY' && @$colors == 1 && $colors->[0]->name eq 'pink',
     "colors 3 - $db_type");

  @colors = $o_x->colors;

  ok(@colors == 1 && $colors[0]->name eq 'pink', "colors 4 - $db_type");

  ok($map1->delete, 'delete color map record 1');
  ok($map2->delete, 'delete color map record 2');
  ok($map3->delete, 'delete color map record 3');

  foreach my $obj ($o->colors)
  {
    $obj->delete;
  }

  foreach my $obj ($o->other2_objs)
  {
    $obj->delete;
  }

  ok($o->delete, "delete() - $db_type");

  eval { $o->meta->alias_column(nonesuch => 'foo') };
  ok($@, 'alias_column() nonesuch');
}

#
# MySQL
#

SKIP: foreach my $db_type ('mysql')
{
  skip("MySQL tests", 48)  unless($HAVE_MYSQL);

  Rose::DB->default_type($db_type);

  my $o = MyMySQLObject->new(name => 'John');

  ok(ref $o && $o->isa('MyMySQLObject'), "new() 1 - $db_type");

  $o->flag2('true');
  $o->date_created('now');
  $o->last_modified($o->date_created);
  $o->save_col(22);

  ok($o->save, "save() 1 - $db_type");
  ok($o->load, "load() 1 - $db_type");

  my $o_x = MyMySQLObject->new(id => 99, name => 'John X', flag => 0);
  $o_x->save;

  my $o2 = MyMySQLObject->new(id => $o->id);

  ok(ref $o2 && $o2->isa('MyMySQLObject'), "new() 2 - $db_type");

  is($o2->bits->to_Bin, '00101', "bits() (bitfield default value) - $db_type");

  ok($o2->load, "load() 2 - $db_type");
  ok(!$o2->not_found, "not_found() 1 - $db_type");

  is($o2->name, $o->name, "load() verify 1 - $db_type");
  is($o2->date_created, $o->date_created, "load() verify 2 - $db_type");
  is($o2->last_modified, $o->last_modified, "load() verify 3 - $db_type");
  is($o2->status, 'active', "load() verify 4 (default value) - $db_type");
  is($o2->flag, 1, "load() verify 5 (default boolean value) - $db_type");
  is($o2->flag2, 1, "load() verify 6 (boolean value) - $db_type");
  is($o2->save_col, 22, "load() verify 7 (aliased column) - $db_type");
  is($o2->start->ymd, '1980-12-24', "load() verify 8 (date value) - $db_type");

  is($o2->bits->to_Bin, '00101', "load() verify 9 (bitfield value) - $db_type");

  $o2->name('John 2');
  $o2->start('5/24/2001');

  sleep(1); # keep the last modified dates from being the same

  $o2->last_modified('now');
  ok($o2->save, "save() 2 - $db_type");
  ok($o2->load, "load() 3 - $db_type");

  is($o2->date_created, $o->date_created, "save() verify 1 - $db_type");
  ok($o2->last_modified ne $o->last_modified, "save() verify 2 - $db_type");
  is($o2->start->ymd, '2001-05-24', "save() verify 3 (date value) - $db_type");

  my $o3 = MyMySQLObject->new();

  my $db = $o3->db or die $o3->error;

  ok(ref $db && $db->isa('Rose::DB'), "db() - $db_type");

  is($db->dbh, $o3->dbh, "dbh() - $db_type");

  my $o4 = MyMySQLObject->new(id => 999);
  ok(!$o4->load(speculative => 1), "load() nonexistent - $db_type");
  ok($o4->not_found, "not_found() 2 - $db_type");

  my $oo21 = MyMySQLOtherObject2->new(id => 1, name => 'one', pid => $o->id);
  ok($oo21->save, 'other object 2 save() 1');

  my $oo22 = MyMySQLOtherObject2->new(id => 2, name => 'two', pid => $o->id);
  ok($oo22->save, 'other object 2 save() 2');

  my $oo23 = MyMySQLOtherObject2->new(id => 3, name => 'three', pid => $o_x->id);
  ok($oo23->save, 'other object 2 save() 3');

  my $o2s = $o->other2_objs;

  ok(ref $o2s eq 'ARRAY' && @$o2s == 2 && 
     $o2s->[0]->name eq 'two' && $o2s->[1]->name eq 'one',
     'other objects 1');

  my @o2s = $o->other2_objs;

  ok(@o2s == 2 && $o2s[0]->name eq 'two' && $o2s[1]->name eq 'one',
     'other objects 2');

  my $color = MyMySQLColor->new(id => 1, name => 'red');
  ok($color->save, "save color 1 - $db_type");
  
  $color = MyMySQLColor->new(id => 2, name => 'green');
  ok($color->save, "save color 2 - $db_type");

  $color = MyMySQLColor->new(id => 3, name => 'blue');
  ok($color->save, "save color 3 - $db_type");

  $color = MyMySQLColor->new(id => 4, name => 'pink');
  ok($color->save, "save color 4 - $db_type");

  my $map1 = MyMySQLColorMap->new(obj_id => 1, color_id => 1);
  ok($map1->save, "save color map record 1 - $db_type");

  my $map2 = MyMySQLColorMap->new(obj_id => 1, color_id => 3);
  ok($map2->save, "save color map record 2 - $db_type");

  my $map3 = MyMySQLColorMap->new(obj_id => 99, color_id => 4);
  ok($map3->save, "save color map record 3 - $db_type");

  my $colors = $o->colors;

  ok(ref $colors eq 'ARRAY' && @$colors == 2 && 
     $colors->[0]->name eq 'red' && $colors->[1]->name eq 'blue',
     "colors 1 - $db_type");

  my @colors = $o->colors;

  ok(@colors == 2 && $colors[0]->name eq 'red' && $colors[1]->name eq 'blue',
     "colors 2 - $db_type");

  $colors = $o_x->colors;

  ok(ref $colors eq 'ARRAY' && @$colors == 1 && $colors->[0]->name eq 'pink',
     "colors 3 - $db_type");

  @colors = $o_x->colors;

  ok(@colors == 1 && $colors[0]->name eq 'pink', "colors 4 - $db_type");

  ok($map1->delete, 'delete color map record 1');
  ok($map2->delete, 'delete color map record 2');
  ok($map3->delete, 'delete color map record 3');

  foreach my $obj ($o->colors)
  {
    $obj->delete;
  }

  foreach my $obj (@o2s)
  {
    $obj->delete;
  }

  ok($o->delete, "delete() - $db_type");

  eval { $o->meta->alias_column(nonesuch => 'foo') };
  ok($@, 'alias_column() nonesuch');
}

#
# Informix
#

SKIP: foreach my $db_type ('informix')
{
  skip("Informix tests", 66)  unless($HAVE_INFORMIX);

  Rose::DB->default_type($db_type);

  my $o = MyInformixObject->new(name => 'John', id => 1);

  ok(ref $o && $o->isa('MyInformixObject'), "new() 1 - $db_type");

  $o->flag2('true');
  $o->date_created('now');
  $o->last_modified($o->date_created);
  $o->save_col(7);

  ok($o->save, "save() 1 - $db_type");
  ok($o->load, "load() 1 - $db_type");

  my $o_x = MyInformixObject->new(id => 99, name => 'John X', flag => 0);
  $o_x->save;

  my $o2 = MyInformixObject->new(id => $o->id);

  ok(ref $o2 && $o2->isa('MyInformixObject'), "new() 2 - $db_type");

  is($o2->bits->to_Bin, '00101', "bits() (bitfield default value) - $db_type");

  ok($o2->load, "load() 2 - $db_type");
  ok(!$o2->not_found, "not_found() 1 - $db_type");

  is($o2->name, $o->name, "load() verify 1 - $db_type");
  is($o2->date_created, $o->date_created, "load() verify 2 - $db_type");
  is($o2->last_modified, $o->last_modified, "load() verify 3 - $db_type");
  is($o2->status, 'active', "load() verify 4 (default value) - $db_type");
  is($o2->flag, 1, "load() verify 5 (default boolean value) - $db_type");
  is($o2->flag2, 1, "load() verify 6 (boolean value) - $db_type");
  is($o2->save_col, 7, "load() verify 7 (aliased column) - $db_type");
  is($o2->start->ymd, '1980-12-24', "load() verify 8 (date value) - $db_type");

  is($o2->bits->to_Bin, '00101', "load() verify 9 (bitfield value) - $db_type");

  $o2->name('John 2');
  $o2->start('5/24/2001');

  sleep(1); # keep the last modified dates from being the same

  $o2->last_modified('now');
  ok($o2->save, "save() 2 - $db_type");
  ok($o2->load, "load() 3 - $db_type");

  is($o2->date_created, $o->date_created, "save() verify 1 - $db_type");
  ok($o2->last_modified ne $o->last_modified, "save() verify 2 - $db_type");
  is($o2->start->ymd, '2001-05-24', "save() verify 3 (date value) - $db_type");

  my $o3 = MyInformixObject->new();

  my $db = $o3->db or die $o3->error;

  ok(ref $db && $db->isa('Rose::DB'), "db() - $db_type");

  is($db->dbh, $o3->dbh, "dbh() - $db_type");

  my $o4 = MyInformixObject->new(id => 999);
  ok(!$o4->load(speculative => 1), "load() nonexistent - $db_type");
  ok($o4->not_found, "not_found() 2 - $db_type");

  ok($o->load, "load() 4 - $db_type");

  my $o5 = MyInformixObject->new(id => $o->id);

  ok($o5->load, "load() 5 - $db_type");

  $o5->nums([ 4, 5, 6 ]);
  ok($o5->save, "save() 4 - $db_type");
  ok($o->load, "load() 6 - $db_type");

  is($o5->nums->[0], 4, "load() verify 10 (array value) - $db_type");
  is($o5->nums->[1], 5, "load() verify 11 (array value) - $db_type");
  is($o5->nums->[2], 6, "load() verify 12 (array value) - $db_type");

  my @a = $o5->nums;

  is($a[0], 4, "load() verify 13 (array value) - $db_type");
  is($a[1], 5, "load() verify 14 (array value) - $db_type");
  is($a[2], 6, "load() verify 15 (array value) - $db_type");
  is(@a, 3, "load() verify 16 (array value) - $db_type");

  my $oo1 = MyInformixOtherObject->new(k1 => 1, k2 => 2, k3 => 3, name => 'one');
  ok($oo1->save, 'other object save() 1');

  my $oo2 = MyInformixOtherObject->new(k1 => 11, k2 => 12, k3 => 13, name => 'two');
  ok($oo2->save, 'other object save() 2');

  is($o->other_obj, undef, 'other_obj() 1');

  $o->fkone(1);
  $o->fk2(2);
  $o->fk3(3);

  my $obj = $o->other_obj or warn "# ", $o->error, "\n";

  is(ref $obj, 'MyInformixOtherObject', 'other_obj() 2');
  is($obj->name, 'one', 'other_obj() 3');

  $o->other_obj(undef);
  $o->fkone(11);
  $o->fk2(12);
  $o->fk3(13);

  $obj = $o->other_obj or warn "# ", $o->error, "\n";

  is(ref $obj, 'MyInformixOtherObject', 'other_obj() 4');
  is($obj->name, 'two', 'other_obj() 5');

  my $oo21 = MyInformixOtherObject2->new(id => 1, name => 'one', pid => $o->id);
  ok($oo21->save, 'other object 2 save() 1');

  my $oo22 = MyInformixOtherObject2->new(id => 2, name => 'two', pid => $o->id);
  ok($oo22->save, 'other object 2 save() 2');

  my $oo23 = MyInformixOtherObject2->new(id => 3, name => 'three', pid => $o_x->id);
  ok($oo23->save, 'other object 2 save() 3');

  my $o2s = $o->other2_objs;

  ok(ref $o2s eq 'ARRAY' && @$o2s == 2 && 
     $o2s->[0]->name eq 'two' && $o2s->[1]->name eq 'one',
     'other objects 1');

  my @o2s = $o->other2_objs;

  ok(@o2s == 2 && $o2s[0]->name eq 'two' && $o2s[1]->name eq 'one',
     'other objects 2');

  my $color = MyInformixColor->new(id => 1, name => 'red');
  ok($color->save, "save color 1 - $db_type");
  
  $color = MyInformixColor->new(id => 2, name => 'green');
  ok($color->save, "save color 2 - $db_type");

  $color = MyInformixColor->new(id => 3, name => 'blue');
  ok($color->save, "save color 3 - $db_type");

  $color = MyInformixColor->new(id => 4, name => 'pink');
  ok($color->save, "save color 4 - $db_type");

  my $map1 = MyInformixColorMap->new(obj_id => 1, color_id => 1);
  ok($map1->save, "save color map record 1 - $db_type");

  my $map2 = MyInformixColorMap->new(obj_id => 1, color_id => 3);
  ok($map2->save, "save color map record 2 - $db_type");

  my $map3 = MyInformixColorMap->new(obj_id => 99, color_id => 4);
  ok($map3->save, "save color map record 3 - $db_type");

  my $colors = $o->colors;

  ok(ref $colors eq 'ARRAY' && @$colors == 2 && 
     $colors->[0]->name eq 'red' && $colors->[1]->name eq 'blue',
     "colors 1 - $db_type");

  my @colors = $o->colors;

  ok(@colors == 2 && $colors[0]->name eq 'red' && $colors[1]->name eq 'blue',
     "colors 2 - $db_type");

  $colors = $o_x->colors;

  ok(ref $colors eq 'ARRAY' && @$colors == 1 && $colors->[0]->name eq 'pink',
     "colors 3 - $db_type");

  @colors = $o_x->colors;

  ok(@colors == 1 && $colors[0]->name eq 'pink', "colors 4 - $db_type");

  ok($map1->delete, 'delete color map record 1');
  ok($map2->delete, 'delete color map record 2');
  ok($map3->delete, 'delete color map record 3');

  foreach my $obj ($o->colors)
  {
    $obj->delete;
  }


  foreach my $obj ($o->other2_objs)
  {
    $obj->delete;
  }

  ok($o->delete, "delete() - $db_type");

  eval { $o->meta->alias_column(nonesuch => 'foo') };
  ok($@, 'alias_column() nonesuch');
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

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_test CASCADE');
      $dbh->do('DROP TABLE rose_db_object_colors_map CASCADE');
      $dbh->do('DROP TABLE rose_db_object_colors');
      $dbh->do('DROP TABLE rose_db_object_other');
      $dbh->do('DROP TABLE rose_db_object_other2');
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
CREATE TABLE rose_db_object_test
(
  id             SERIAL PRIMARY KEY,
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
  last_modified  TIMESTAMP,
  date_created   TIMESTAMP,

  FOREIGN KEY (fk1, fk2, fk3) REFERENCES rose_db_object_other (k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_other2
(
  id    SERIAL PRIMARY KEY,
  name  VARCHAR(255),
  pid   INT NOT NULL REFERENCES rose_db_object_test (id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_colors
(
  id    SERIAL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_colors_map
(
  id        SERIAL PRIMARY KEY,
  obj_id    INT NOT NULL REFERENCES rose_db_object_test (id),
  color_id  INT NOT NULL REFERENCES rose_db_object_colors (id)
)
EOF

    $dbh->disconnect;

    # Create test subclasses

    package MyPgOtherObject;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('pg') }

    MyPgOtherObject->meta->table('rose_db_object_other');

    MyPgOtherObject->meta->columns
    (
      name => { type => 'varchar'},
      k1   => { type => 'int' },
      k2   => { type => 'int' },
      k3   => { type => 'int' },
    );

    MyPgOtherObject->meta->primary_key_columns([ qw(k1 k2 k3) ]);

    MyPgOtherObject->meta->initialize;

    package MyPgObject;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('pg') }

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
    );

    MyPgObject->meta->relationships
    (
      other_obj =>
      {
        type  => 'one to one',
        class => 'MyPgOtherObject',
        column_map =>
        {
          fk1 => 'k1',
          fk2 => 'k2',
          fk3 => 'k3',
        }
      },

      other2_objs =>
      {
        type  => 'one to many',
        class => 'MyPgOtherObject2',
        column_map => { id => 'pid' },
        manager_args => { sort_by => 'name DESC' },
      }
    );

    package MyPgOtherObject2;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('pg') }

    MyPgOtherObject2->meta->table('rose_db_object_other2');

    MyPgOtherObject2->meta->columns
    (
      id   => { type => 'serial', primary_key => 1 },
      name => { type => 'varchar'},
      pid  => { type => 'int' },
    );

    MyPgOtherObject2->meta->relationships
    (
      other_obj =>
      {
        type  => 'one to one',
        class => 'MyPgObject',
        column_map => { pid => 'id' },
      },
    );

    MyPgOtherObject2->meta->foreign_keys
    (
      other_obj =>
      {
        class => 'MyPgObject',
        key_columns => { pid => 'id' },
      },
    );

    MyPgOtherObject2->meta->initialize;

    package MyPgColor;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('pg') }

    MyPgColor->meta->table('rose_db_object_colors');

    MyPgColor->meta->columns
    (
      id   => { type => 'serial', primary_key => 1 },
      name => { type => 'varchar', not_null => 1 },
    );

    MyPgColor->meta->initialize;

    package MyPgColorMap;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('pg') }

    MyPgColorMap->meta->table('rose_db_object_colors_map');

    MyPgColorMap->meta->columns
    (
      id       => { type => 'serial', primary_key => 1 },
      obj_id   => { type => 'int', not_null => 1 },
      color_id => { type => 'int', not_null => 1 },
    );

    MyPgColorMap->meta->foreign_keys
    (
      object =>
      {
        class => 'MyPgObject',
        key_columns => { obj_id => 'id' },
      },

      color =>
      {
        class => 'MyPgColor',
        key_columns => { color_id => 'id' },
      },
    );

    MyPgColorMap->meta->initialize;

    # MyPgObject init delayed

    MyPgObject->meta->alias_column(fk1 => 'fkone');

    MyPgObject->meta->add_relationship
    (
      colors =>
      {
        type      => 'many to many',
        map_class => 'MyPgColorMap',
        #map_from  => 'object',
        #map_to    => 'color',
      },
    );

    eval { MyPgObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() reserved method - pg');

    MyPgObject->meta->alias_column(save => 'save_col');
    MyPgObject->meta->initialize(preserve_existing => 1);

    my $meta = MyPgObject->meta;

    Test::More::is($meta->relationship('other_obj')->foreign_key,
                   $meta->foreign_key('other_obj'),
                   'foreign key sync 1 - pg');
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

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_test CASCADE');
      $dbh->do('DROP TABLE rose_db_object_colors_map CASCADE');
      $dbh->do('DROP TABLE rose_db_object_colors');
      $dbh->do('DROP TABLE rose_db_object_other');
      $dbh->do('DROP TABLE rose_db_object_other2');
      $dbh->do('DROP TABLE rose_db_object_chkpass_test');
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
CREATE TABLE rose_db_object_test
(
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name           VARCHAR(32) NOT NULL,
  flag           TINYINT(1) NOT NULL,
  flag2          TINYINT(1),
  status         VARCHAR(32) DEFAULT 'active',
  bits           BIT(5) NOT NULL DEFAULT '00101',
  start          DATE,
  save           INT,
  last_modified  TIMESTAMP,
  date_created   DATETIME
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_other2
(
  id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(255),
  pid   INT UNSIGNED NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_colors
(
  id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(255) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_colors_map
(
  id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  obj_id    INT NOT NULL REFERENCES rose_db_object_test (id),
  color_id  INT NOT NULL REFERENCES rose_db_object_colors (id)
)
EOF

    $dbh->disconnect;

    # Create test subclasses

    package MyMySQLOtherObject;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('mysql') }

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

    package MyMySQLObject;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('mysql') }

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
      last_modified => { type => 'timestamp' },
      date_created  => { type => 'datetime' },
    );

    MyMySQLObject->meta->relationships
    (
      other_obj =>
      {
        type  => 'one to one',
        class => 'MyMySQLOtherObject',
        column_map =>
        {
          fk1 => 'k1',
          fk2 => 'k2',
          fk3 => 'k3',
        }
      }
    );

    MyMySQLObject->meta->add_relationship
    (
      other2_objs =>
      {
        type  => 'one to many',
        class => 'MyMySQLOtherObject2',
        column_map => { id => 'pid' },
        manager_args => { sort_by => 'name DESC' },
      }
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
    );

    package MyMySQLOtherObject2;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('mysql') }

    MyMySQLOtherObject2->meta->table('rose_db_object_other2');

    MyMySQLOtherObject2->meta->columns
    (
      id   => { type => 'serial', primary_key => 1 },
      name => { type => 'varchar'},
      pid  => { type => 'int' },
    );

    MyMySQLOtherObject2->meta->relationships
    (
      other_obj =>
      {
        type  => 'one to one',
        class => 'MyMySQLObject',
        column_map => { pid => 'id' },
      },
    );

    MyMySQLOtherObject2->meta->foreign_keys
    (
      other_obj =>
      {
        class => 'MyMySQLObject',
        key_columns => { pid => 'id' },
      },
    );

    MyMySQLOtherObject2->meta->initialize;

    package MyMySQLColor;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('mysql') }

    MyMySQLColor->meta->table('rose_db_object_colors');

    MyMySQLColor->meta->columns
    (
      id   => { type => 'serial', primary_key => 1 },
      name => { type => 'varchar', not_null => 1 },
    );

    MyMySQLColor->meta->initialize;

    package MyMySQLColorMap;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('mysql') }

    MyMySQLColorMap->meta->table('rose_db_object_colors_map');

    MyMySQLColorMap->meta->columns
    (
      id       => { type => 'serial', primary_key => 1 },
      obj_id   => { type => 'int', not_null => 1 },
      color_id => { type => 'int', not_null => 1 },
    );

    MyMySQLColorMap->meta->foreign_keys
    (
      object =>
      {
        class => 'MyMySQLObject',
        key_columns => { obj_id => 'id' },
      },

      color =>
      {
        class => 'MyMySQLColor',
        key_columns => { color_id => 'id' },
      },
    );

    MyMySQLColorMap->meta->initialize;
    
    # MyMySQLObject init delayed

    MyMySQLObject->meta->add_relationship
    (
      colors =>
      {
        type      => 'many to many',
        map_class => 'MyMySQLColorMap',
        map_from  => 'object',
        map_to    => 'color',
      },
    );

    eval { MyMySQLObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() reserved method');

    MyMySQLObject->meta->alias_column(save => 'save_col');
    MyMySQLObject->meta->initialize(preserve_existing => 1);

    my $meta = MyMySQLObject->meta;

    Test::More::is($meta->relationship('other_obj')->foreign_key,
                   $meta->foreign_key('other_obj'),
                   'foreign key sync 1 - mysql');
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

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_test CASCADE');
      $dbh->do('DROP TABLE rose_db_object_colors_map CASCADE');
      $dbh->do('DROP TABLE rose_db_object_colors');
      $dbh->do('DROP TABLE rose_db_object_other');
      $dbh->do('DROP TABLE rose_db_object_other2');
      $dbh->do('DROP TABLE rose_db_object_chkpass_test');
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
  nums           VARCHAR(255),
  fk1            INT,
  fk2            INT,
  fk3            INT,
  last_modified  DATETIME YEAR TO FRACTION(5),
  date_created   DATETIME YEAR TO FRACTION(5),

  FOREIGN KEY (fk1, fk2, fk3) REFERENCES rose_db_object_other (k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_other2
(
  id    INT NOT NULL PRIMARY KEY,
  name  VARCHAR(255),
  pid   INT NOT NULL REFERENCES rose_db_object_test (id)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_colors
(
  id    SERIAL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_colors_map
(
  id        SERIAL PRIMARY KEY,
  obj_id    INT NOT NULL REFERENCES rose_db_object_test (id),
  color_id  INT NOT NULL REFERENCES rose_db_object_colors (id)
)
EOF

    $dbh->commit;
    $dbh->disconnect;

    # Create test subclasses

    package MyInformixOtherObject;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('informix') }

    MyInformixOtherObject->meta->table('rose_db_object_other');

    MyInformixOtherObject->meta->columns
    (
      name => { type => 'varchar'},
      k1   => { type => 'int' },
      k2   => { type => 'int' },
      k3   => { type => 'int' },
    );

    MyInformixOtherObject->meta->primary_key_columns(qw(k1 k2 k3));

    MyInformixOtherObject->meta->initialize;

    package MyInformixObject;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('informix') }

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
      nums     => { type => 'array' },
      bits     => { type => 'bitfield', bits => 5, default => 101 },
      fk1      => { type => 'int' },
      fk2      => { type => 'int' },
      fk3      => { type => 'int' },
      last_modified => { type => 'timestamp' },
      date_created  => { type => 'timestamp' },
    );

    MyInformixObject->meta->add_foreign_keys
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
    );

    MyInformixObject->meta->add_relationship
    (
      other2_objs =>
      {
        type  => 'one to many',
        class => 'MyInformixOtherObject2',
        column_map => { id => 'pid' },
        manager_args => { sort_by => 'name DESC' },
      }
    );

    package MyInformixOtherObject2;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('informix') }

    MyInformixOtherObject2->meta->table('rose_db_object_other2');

    MyInformixOtherObject2->meta->columns
    (
      id   => { type => 'serial', primary_key => 1 },
      name => { type => 'varchar'},
      pid  => { type => 'int' },
    );

    MyInformixOtherObject2->meta->relationships
    (
      other_obj =>
      {
        type  => 'one to one',
        class => 'MyInformixObject',
        column_map => { pid => 'id' },
      },
    );

    MyInformixOtherObject2->meta->foreign_keys
    (
      other_obj =>
      {
        class => 'MyInformixObject',
        key_columns => { pid => 'id' },
      },
    );

    MyInformixOtherObject2->meta->initialize;

    package MyInformixColor;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('informix') }

    MyInformixColor->meta->table('rose_db_object_colors');

    MyInformixColor->meta->columns
    (
      id   => { type => 'serial', primary_key => 1 },
      name => { type => 'varchar', not_null => 1 },
    );

    MyInformixColor->meta->initialize;

    package MyInformixColorMap;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('informix') }

    MyInformixColorMap->meta->table('rose_db_object_colors_map');

    MyInformixColorMap->meta->columns
    (
      id       => { type => 'serial', primary_key => 1 },
      obj_id   => { type => 'int', not_null => 1 },
      color_id => { type => 'int', not_null => 1 },
    );

    MyInformixColorMap->meta->foreign_keys
    (
      object =>
      {
        class => 'MyInformixObject',
        key_columns => { obj_id => 'id' },
      },

      color =>
      {
        class => 'MyInformixColor',
        key_columns => { color_id => 'id' },
      },
    );

    MyInformixColorMap->meta->initialize;
    
    # MyInformixObject init delayed

    MyInformixObject->meta->alias_column(fk1 => 'fkone');

    MyInformixObject->meta->add_relationship
    (
      colors =>
      {
        type      => 'many to many',
        map_class => 'MyInformixColorMap',
        #map_from  => 'object',
        #map_to    => 'color',
      },
    );

    eval { MyInformixObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() reserved method');

    MyInformixObject->meta->alias_column(save => 'save_col');
    MyInformixObject->meta->initialize(preserve_existing => 1);

    my $meta = MyInformixObject->meta;

    Test::More::is($meta->relationship('other_obj')->foreign_key,
                   $meta->foreign_key('other_obj'),
                   'foreign key sync 1 - pg');
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

    $dbh->do('DROP TABLE rose_db_object_test CASCADE');
    $dbh->do('DROP TABLE rose_db_object_colors_map CASCADE');
    $dbh->do('DROP TABLE rose_db_object_colors');
    $dbh->do('DROP TABLE rose_db_object_other');
    $dbh->do('DROP TABLE rose_db_object_other2');
    

    $dbh->disconnect;
  }

  if($HAVE_MYSQL)
  {
    # MySQL
    my $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test CASCADE');
    $dbh->do('DROP TABLE rose_db_object_colors_map CASCADE');
    $dbh->do('DROP TABLE rose_db_object_colors');
    $dbh->do('DROP TABLE rose_db_object_other');
    $dbh->do('DROP TABLE rose_db_object_other2');

    $dbh->disconnect;
  }

  if($HAVE_INFORMIX)
  {
    # Informix
    my $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test CASCADE');
    $dbh->do('DROP TABLE rose_db_object_colors_map CASCADE');
    $dbh->do('DROP TABLE rose_db_object_colors');
    $dbh->do('DROP TABLE rose_db_object_other');
    $dbh->do('DROP TABLE rose_db_object_other2');

    $dbh->disconnect;
  }
}
