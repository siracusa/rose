#!/usr/bin/perl -w

use strict;

use Test::More tests => 29;

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
my $kc = $fk->key_columns;
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
  __PACKAGE__->meta->columns(qw(id other_obj_id));  
  __PACKAGE__->meta->foreign_keys
  (
    other_obj =>
    {
      key_columns => { other_obj_id => 'eyedee' },
    }
  );

  __PACKAGE__->meta->initialize;
}

$fk = My::FK3::Object->meta->foreign_key('other_obj');
ok($fk, 'auto_foreign_key 9');
is($fk->class, 'My::FK3::OtherObj', 'auto_foreign_key 10');
my $kc = $fk->key_columns;
is(scalar keys %$kc, 1, 'auto_foreign_key 11');
is($kc->{'other_obj_id'}, 'eyedee', 'auto_foreign_key 12');

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
