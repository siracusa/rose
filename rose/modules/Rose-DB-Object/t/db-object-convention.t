#!/usr/bin/perl -w

use strict;

use Test::More tests => 129;

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object');
  use_ok('Rose::DB::Object::Manager');
}

#
# auto_table
#

my %Expect_Table =
(
  'OtherObject'          => 'other_objects',
  'My::OtherObject'      => 'other_objects',
  'My::Other::Object'    => 'objects',
  'Other123Object'       => 'other123_objects',
  'My::Other123Object'   => 'other123_objects',
  'My::Other::123Object' => '123_objects',
  'Mess'                 => 'messes',
  'My::Mess'             => 'messes',
  'My::Other::Mess'      => 'messes',
  'Box'                  => 'boxes',
  'My::Box'              => 'boxes',
  'My::Other::Box'       => 'boxes',
);

foreach my $pkg (sort keys %Expect_Table)
{
  no strict 'refs';
  @{"${pkg}::ISA"} = qw(Rose::DB::Object);
  *{"${pkg}::init_db"} = sub { Rose::DB->new('pg') };
  is($pkg->meta->table, $Expect_Table{$pkg}, "auto_table $pkg");
}

My::OtherObject->meta->columns
(
  name => { type => 'varchar'},
  k1   => { type => 'int' },
  k2   => { type => 'int' },
  k3   => { type => 'int' },
);

My::OtherObject->meta->primary_key_columns([ qw(k1 k2 k3) ]);

My::OtherObject->meta->initialize;

#
# auto_primary_key_columns
#

PK_ID:
{
  package My::PKClass1;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }

  __PACKAGE__->meta->columns
  (
    'name',
    'id',
    'object_id',
  );

  my @columns = __PACKAGE__->meta->primary_key_column_names;
  Test::More::ok(@columns == 1 && $columns[0] eq 'id', 'auto_primary_key_column_names id');
}

PK_OBJECT_ID:
{
  package My::PK::OtherObject;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }

  __PACKAGE__->meta->columns
  (
    'name',
    'other_object_id',
  );

  my @columns = __PACKAGE__->meta->primary_key_column_names;
  Test::More::ok(@columns == 1 && $columns[0] eq 'other_object_id', 'auto_primary_key_column_names other_object_id');
}

PK_SERIAL_ID:
{
  package My::PKSerial::OtherObject;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }

  __PACKAGE__->meta->columns
  (
    'pk'  => { type => 'serial' },
    'roo' => { type => 'serial' },
    'foo',
  );

  my @columns = __PACKAGE__->meta->primary_key_column_names;
  Test::More::ok(@columns == 1 && $columns[0] eq 'pk', 'auto_primary_key_column_names pk');
}

#
# auto_foreign_key
#

FK1:
{
  package My::FK1::OtherObject;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id name));
  __PACKAGE__->meta->initialize;

  package My::FK1::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id other_object_id));  
  __PACKAGE__->meta->foreign_keys(qw(other_object));
  __PACKAGE__->meta->initialize;
}

my $fk = My::FK1::Object->meta->foreign_key('other_object');
ok($fk, 'auto_foreign_key 1');
is($fk->class, 'My::FK1::OtherObject', 'auto_foreign_key 2');
my $kc = $fk->key_columns;
is(scalar keys %$kc, 1, 'auto_foreign_key 3');
is($kc->{'other_object_id'}, 'id', 'auto_foreign_key 4');

FK2:
{
  package My::FK2::OtherObj;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id name));
  __PACKAGE__->meta->initialize;

  package My::FK2::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id other_object_id));  
  __PACKAGE__->meta->foreign_keys
  (
    other_object =>
    {
      class => 'My::FK2::OtherObj',
    }
  );

  __PACKAGE__->meta->initialize;
}

$fk = My::FK2::Object->meta->foreign_key('other_object');
ok($fk, 'auto_foreign_key 5');
is($fk->class, 'My::FK2::OtherObj', 'auto_foreign_key 6');
$kc = $fk->key_columns;
is(scalar keys %$kc, 1, 'auto_foreign_key 7');
is($kc->{'other_object_id'}, 'id', 'auto_foreign_key 8');

FK3:
{
  package My::FK3::OtherObj;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(eyedee => { type => 'serial' },  'name');
  __PACKAGE__->meta->initialize;

  package My::FK3::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id other_obj_eyedee));  
  __PACKAGE__->meta->foreign_keys
  (
    other_obj =>
    {
      key_columns => { other_obj_eyedee => 'eyedee' },
    }
  );

  __PACKAGE__->meta->initialize;
}

$fk = My::FK3::Object->meta->foreign_key('other_obj');
ok($fk, 'auto_foreign_key 9');
is($fk->class, 'My::FK3::OtherObj', 'auto_foreign_key 10');
$kc = $fk->key_columns;
is(scalar keys %$kc, 1, 'auto_foreign_key 11');
is($kc->{'other_obj_eyedee'}, 'eyedee', 'auto_foreign_key 12');

FK4:
{
  package My::FK4::OtherObj;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(eyedee => { type => 'serial' },  'name');
  __PACKAGE__->meta->initialize;

  package My::FK4::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id other_obj_eyedee));  
  __PACKAGE__->meta->foreign_keys(qw(other_obj));
  __PACKAGE__->meta->initialize;
}

$fk = My::FK4::Object->meta->foreign_key('other_obj');
ok($fk, 'auto_foreign_key 13');
is($fk->class, 'My::FK4::OtherObj', 'auto_foreign_key 14');
$kc = $fk->key_columns;
is(scalar keys %$kc, 1, 'auto_foreign_key 15');
is($kc->{'other_obj_eyedee'}, 'eyedee', 'auto_foreign_key 16');

#
# auto_relationship
#

# one to one

OTO1:
{
  package My::OTO1::OtherObject;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id name));
  __PACKAGE__->meta->initialize;

  package My::OTO1::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id other_object_id));  
  __PACKAGE__->meta->relationships(other_object => 'one to one');
  __PACKAGE__->meta->initialize;
}

my $rel = My::OTO1::Object->meta->relationship('other_object');
ok($rel, 'auto_relationship one to one 1');
is($rel->class, 'My::OTO1::OtherObject', 'auto_relationship one to one 2');
my $cm = $rel->column_map;
is(scalar keys %$cm, 1, 'auto_relationship one to one 3');
is($cm->{'other_object_id'}, 'id', 'auto_relationship one to one 4');

OTO2:
{
  package My::OTO2::OtherObj;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id name));
  __PACKAGE__->meta->initialize;

  package My::OTO2::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id other_object_id));  
  __PACKAGE__->meta->relationships
  (
    other_object =>
    {
      type  => 'one to one',
      class => 'My::OTO2::OtherObj',
    }
  );

  __PACKAGE__->meta->initialize;
}

$rel = My::OTO2::Object->meta->relationship('other_object');
ok($rel, 'auto_relationship one to one 5');
is($rel->class, 'My::OTO2::OtherObj', 'auto_relationship one to one 6');
$cm = $rel->column_map;
is(scalar keys %$cm, 1, 'auto_relationship one to one 7');
is($cm->{'other_object_id'}, 'id', 'auto_relationship one to one 8');

OTO3:
{
  package My::OTO3::OtherObj;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(eyedee => { type => 'serial' },  'name');
  __PACKAGE__->meta->initialize;

  package My::OTO3::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id other_obj_id));  
  __PACKAGE__->meta->relationships
  (
    other_obj =>
    {
      type => 'one to one',
      column_map => { other_obj_id => 'eyedee' },
    }
  );

  __PACKAGE__->meta->initialize;
}

$rel = My::OTO3::Object->meta->relationship('other_obj');
ok($rel, 'auto_relationship one to one 9');
is($rel->class, 'My::OTO3::OtherObj', 'auto_relationship one to one 10');
$cm = $rel->column_map;
is(scalar keys %$cm, 1, 'auto_relationship one to one 11');
is($cm->{'other_obj_id'}, 'eyedee', 'auto_relationship one to one 12');

OTO4:
{
  package My::OTO4::OtherObj;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(eyedee => { type => 'serial' },  'name');
  __PACKAGE__->meta->initialize;

  package My::OTO4::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id other_obj_eyedee));  
  __PACKAGE__->meta->relationships
  (
    other_obj => { type => 'one to one' }
  );

  __PACKAGE__->meta->initialize;
}

$rel = My::OTO4::Object->meta->relationship('other_obj');
ok($rel, 'auto_relationship one to one 13');
is($rel->class, 'My::OTO4::OtherObj', 'auto_relationship one to one 14');
$cm = $rel->column_map;
is(scalar keys %$cm, 1, 'auto_relationship one to one 15');
is($cm->{'other_obj_eyedee'}, 'eyedee', 'auto_relationship one to one 16');

# many to one

MTO1:
{
  package My::MTO1::OtherObject;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id name));
  __PACKAGE__->meta->initialize;

  package My::MTO1::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id other_object_id));  
  __PACKAGE__->meta->relationships(other_object => 'many to one');
  __PACKAGE__->meta->initialize;
}

$rel = My::MTO1::Object->meta->relationship('other_object');
ok($rel, 'auto_relationship many to one 1');
is($rel->class, 'My::MTO1::OtherObject', 'auto_relationship many to one 2');
$cm = $rel->column_map;
is(scalar keys %$cm, 1, 'auto_relationship many to one 3');
is($cm->{'other_object_id'}, 'id', 'auto_relationship many to one 4');

MTO2:
{
  package My::MTO2::OtherObj;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id name));
  __PACKAGE__->meta->initialize;

  package My::MTO2::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id other_object_id));  
  __PACKAGE__->meta->relationships
  (
    other_object =>
    {
      type  => 'many to one',
      class => 'My::MTO2::OtherObj',
    }
  );

  __PACKAGE__->meta->initialize;
}

$rel = My::MTO2::Object->meta->relationship('other_object');
ok($rel, 'auto_relationship many to one 5');
is($rel->class, 'My::MTO2::OtherObj', 'auto_relationship many to one 6');
$cm = $rel->column_map;
is(scalar keys %$cm, 1, 'auto_relationship many to one 7');
is($cm->{'other_object_id'}, 'id', 'auto_relationship many to one 8');

MTO3:
{
  package My::MTO3::OtherObj;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(eyedee => { type => 'serial' },  'name');
  __PACKAGE__->meta->initialize;

  package My::MTO3::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id other_obj_id));  
  __PACKAGE__->meta->relationships
  (
    other_obj =>
    {
      type => 'many to one',
      column_map => { other_obj_id => 'eyedee' },
    }
  );

  __PACKAGE__->meta->initialize;
}

$rel = My::MTO3::Object->meta->relationship('other_obj');
ok($rel, 'auto_relationship many to one 9');
is($rel->class, 'My::MTO3::OtherObj', 'auto_relationship many to one 10');
$cm = $rel->column_map;
is(scalar keys %$cm, 1, 'auto_relationship many to one 11');
is($cm->{'other_obj_id'}, 'eyedee', 'auto_relationship many to one 12');

MTO4:
{
  package My::MTO4::OtherObj;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(eyedee => { type => 'serial' },  'name');
  __PACKAGE__->meta->initialize;

  package My::MTO4::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id other_obj_eyedee));  
  __PACKAGE__->meta->relationships
  (
    other_obj => { type => 'many to one' }
  );

  __PACKAGE__->meta->initialize;
}

$rel = My::MTO4::Object->meta->relationship('other_obj');
ok($rel, 'auto_relationship many to one 13');
is($rel->class, 'My::MTO4::OtherObj', 'auto_relationship many to one 14');
$cm = $rel->column_map;
is(scalar keys %$cm, 1, 'auto_relationship many to one 15');
is($cm->{'other_obj_eyedee'}, 'eyedee', 'auto_relationship many to one 16');

# one to many

OTM1:
{
  package My::OTM1::OtherObject;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id name object_id));
  __PACKAGE__->meta->initialize;

  package My::OTM1::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id name));  
  __PACKAGE__->meta->relationships(other_objects => 'one to many');
  __PACKAGE__->meta->initialize;
}

$rel = My::OTM1::Object->meta->relationship('other_objects');
ok($rel, 'auto_relationship one to many 1');
is($rel->class, 'My::OTM1::OtherObject', 'auto_relationship one to many 2');
$cm = $rel->column_map;
is(scalar keys %$cm, 1, 'auto_relationship one to many 3');
is($cm->{'id'}, 'object_id', 'auto_relationship one to many 4');

OTM2:
{
  package My::OTM2::OtherObj;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id name object_id));
  __PACKAGE__->meta->initialize;

  package My::OTM2::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id name));  
  __PACKAGE__->meta->relationships
  (
    other_objects =>
    {
      type  => 'one to many',
      class => 'My::OTM2::OtherObj',
    }
  );

  __PACKAGE__->meta->initialize;
}

$rel = My::OTM2::Object->meta->relationship('other_objects');
ok($rel, 'auto_relationship one to many 5');
is($rel->class, 'My::OTM2::OtherObj', 'auto_relationship one to many 6');
$cm = $rel->column_map;
is(scalar keys %$cm, 1, 'auto_relationship one to many 7');
is($cm->{'id'}, 'object_id', 'auto_relationship one to many 8');

OTM3:
{
  package My::OTM3::OtherObj;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(meyedee => { type => 'serial' },  'name', 'object_eyedee');
  __PACKAGE__->meta->initialize;

  package My::OTM3::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(eyedee => { type => 'serial' }, 'name');  
  __PACKAGE__->meta->relationships
  (
    other_obj =>
    {
      type => 'one to many',
      column_map => { eyedee => 'object_eyedee' },
    }
  );

  __PACKAGE__->meta->initialize;
}

$rel = My::OTM3::Object->meta->relationship('other_obj');
ok($rel, 'auto_relationship one to many 9');
is($rel->class, 'My::OTM3::OtherObj', 'auto_relationship one to many 10');
$cm = $rel->column_map;
is(scalar keys %$cm, 1, 'auto_relationship one to many 11');
is($cm->{'eyedee'}, 'object_eyedee', 'auto_relationship one to many 12');

OTM4:
{
  package My::OTM4::OtherObj;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(meyedee => { type => 'serial' },  'name', 'object_eyedee');
  __PACKAGE__->meta->initialize;

  package My::OTM4::Object;
  our @ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(eyedee => { type => 'serial' }, 'name');
  __PACKAGE__->meta->relationships
  (
    other_objs => { type => 'one to many' }
  );

  __PACKAGE__->meta->initialize;
}

$rel = My::OTM4::Object->meta->relationship('other_objs');
ok($rel, 'auto_relationship many to one 13');
is($rel->class, 'My::OTM4::OtherObj', 'auto_relationship many to one 14');
$cm = $rel->column_map;
is(scalar keys %$cm, 1, 'auto_relationship many to one 15');
is($cm->{'eyedee'}, 'object_eyedee', 'auto_relationship many to one 16');

# many to many

my $i = 0;

my @map_classes =
qw(ObjectsOtherObjectsMap
   ObjectOtherObjectMap
   OtherObjectsObjectsMap
   OtherObjectObjectMap
   ObjectsOtherObjects
   ObjectOtherObjects
   OtherObjectsObjects
   OtherObjectObjects
   OtherObjectMap
   OtherObjectsMap
   ObjectMap
   ObjectsMap);

foreach my $class (@map_classes)
{
  $i++;

  my $defs=<<"EOF";
  package My::MTM${i}::$class;
  our \@ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id object_id other_object_id));
  
  package My::MTM${i}::OtherObject;
  our \@ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id name));
  __PACKAGE__->meta->initialize;
  
  package My::MTM${i}::Object;
  our \@ISA = qw(Rose::DB::Object);
  sub init_db { Rose::DB->new('pg') }
  __PACKAGE__->meta->columns(qw(id name));  
  
  My::MTM${i}::$class->meta->foreign_keys(qw(object other_object));
  My::MTM${i}::$class->meta->initialize;
  
  My::MTM${i}::Object->meta->relationships(other_objects => 'many to many');
  My::MTM${i}::Object->meta->initialize
EOF

  eval $defs;
  die $@  if($@);

  my $obj_class = "My::MTM${i}::Object";
  $rel = $obj_class->meta->relationship('other_objects');
  ok($rel, "auto_relationship many to many $i.1");
  is($rel->map_class, "My::MTM${i}::$class", "auto_relationship many to many $i.2");
  is($rel->map_from, 'object', "auto_relationship many to many $i.3");
  is($rel->map_to, 'other_object', "auto_relationship many to many $i.4");
}

__END__
  
package My::Object;

our @ISA = qw(Rose::DB::Object);

sub init_db { Rose::DB->new('pg') }

My::Object->meta->columns
(
  'name',
  id       => { type => 'serial' },
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

My::Object->meta->foreign_keys
(
  other_obj =>
  {
    class => 'My::OtherObject',
    rel_type => 'one to one',
    key_columns =>
    {
      fk1 => 'k1',
      fk2 => 'k2',
      fk3 => 'k3',
    },
    methods => 
    {
      get_set_now     => undef,
      get_set_on_save => 'other_obj_on_save',
      delete_now      => undef,
      delete_on_save  => 'del_other_obj_on_save',
    },
  },
);

My::Object->meta->relationships
(
  other_obj =>
  {
    type  => 'one to one',
    class => 'My::OtherObject',
    column_map =>
    {
      fk1 => 'k1',
      fk2 => 'k2',
      fk3 => 'k3',
    },
  },

  other2_objs =>
  {
    type  => 'one to many',
    class => 'My::OtherObject2',
    column_map => { id => 'pid' },
    manager_args => { sort_by => 'rose_db_object_other2.name DESC' },
    methods =>
    {
      get_set         => undef,
      get_set_now     => 'other2_objs_now',
      get_set_on_save => 'other2_objs_on_save',
      add_now         => 'add_other2_objs_now',
      add_on_save     => undef,
    },
  }
);

My::Object->meta->alias_column(fk1 => 'fkone');

My::Object->meta->add_relationship
(
  colors =>
  {
    type      => 'many to many',
    map_class => 'My::ColorMap',
    #map_from  => 'object',
    #map_to    => 'color',
    manager_args => { sort_by => 'rose_db_object_colors.name' },
    methods =>
    {
      get_set         => undef,
      get_set_now     => 'colors_now',
      get_set_on_save => 'colors_on_save',
      add_now         => undef,
      add_on_save     => 'add_colors_on_save',
    },
  },
);

eval { My::Object->meta->initialize };
Test::More::ok($@, 'meta->initialize() reserved method - pg');

My::Object->meta->alias_column(save => 'save_col');
My::Object->meta->initialize(preserve_existing => 1);

my $meta = My::Object->meta;

Test::More::is($meta->relationship('other_obj')->foreign_key,
               $meta->foreign_key('other_obj'),
               'foreign key sync 1 - pg');

package My::OtherObject2;

our @ISA = qw(Rose::DB::Object);

sub init_db { Rose::DB->new('pg') }

My::OtherObject2->meta->table('rose_db_object_other2');

My::OtherObject2->meta->columns
(
  id   => { type => 'serial', primary_key => 1 },
  name => { type => 'varchar'},
  pid  => { type => 'int' },
);

My::OtherObject2->meta->relationships
(
  other_obj =>
  {
    type  => 'one to one',
    class => 'My::Object',
    column_map => { pid => 'id' },
  },
);

My::OtherObject2->meta->foreign_keys
(
  other_obj =>
  {
    class => 'My::Object',
    relationship_type => 'one to one',
    key_columns => { pid => 'id' },
  },
);

My::OtherObject2->meta->initialize;

package My::Color;

our @ISA = qw(Rose::DB::Object);

sub init_db { Rose::DB->new('pg') }

My::Color->meta->table('rose_db_object_colors');

My::Color->meta->columns
(
  id   => { type => 'serial', primary_key => 1 },
  name => { type => 'varchar', not_null => 1 },
);

My::Color->meta->initialize;

package My::ColorMap;

our @ISA = qw(Rose::DB::Object);

sub init_db { Rose::DB->new('pg') }

My::ColorMap->meta->table('rose_db_object_colors_map');

My::ColorMap->meta->columns
(
  id       => { type => 'serial', primary_key => 1 },
  obj_id   => { type => 'int', not_null => 1 },
  color_id => { type => 'int', not_null => 1 },
);

My::ColorMap->meta->unique_keys([ 'obj_id', 'color_id' ]);

My::ColorMap->meta->foreign_keys
(
  object =>
  {
    class => 'My::Object',
    key_columns => { obj_id => 'id' },
  },

  color =>
  {
    class => 'My::Color',
    key_columns => { color_id => 'id' },
  },
);

My::ColorMap->meta->initialize;
