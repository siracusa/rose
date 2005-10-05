package Rose::DB::Object::Metadata;

use strict;

use Carp();

use Rose::Object;
our @ISA = qw(Rose::Object);

use Rose::DB::Object::Constants qw(PRIVATE_PREFIX);

use Rose::DB::Object::Metadata::PrimaryKey;
use Rose::DB::Object::Metadata::UniqueKey;
use Rose::DB::Object::Metadata::ForeignKey;
use Rose::DB::Object::Metadata::Column::Scalar;
use Rose::DB::Object::Metadata::Relationship::OneToOne;

our $VERSION = '0.062';

our $Debug = 0;

use Rose::Object::MakeMethods::Generic
(
  scalar => 
  [
    'class',
  ],

  'scalar --get_set_init' =>
  [
    'db',
    'primary_key',
    'column_name_to_method_name_mapper',
  ],

  boolean => 
  [
    allow_inline_column_values => { default => 0 },
    is_initialized => { default => 0 },
  ],
);

use Rose::Class::MakeMethods::Generic
(
  inheritable_hash =>
  [
    column_type_classes => { interface => 'get_set_all' },
    column_type_class   => { interface => 'get_set', hash_key => 'column_type_classes' },
    delete_column_type_class => { interface => 'delete', hash_key => 'column_type_classes' },

    auto_helper_classes      => { interface => 'get_set_all' },
    delete_auto_helper_class => { interface => 'delete', hash_key => 'auto_helper_classes' },

    relationship_type_classes => { interface => 'get_set_all' },
    relationship_type_class   => { interface => 'get_set', hash_key => 'relationship_type_classes' },
    delete_relationship_type_class => { interface => 'delete', hash_key => 'relationship_type_classes' },

    class_registry => => { interface => 'get_set_all' },
  ],
);

__PACKAGE__->class_registry({});

__PACKAGE__->auto_helper_classes
(
  'Informix' => 'Rose::DB::Object::Metadata::Auto::Informix',
  'Pg'       => 'Rose::DB::Object::Metadata::Auto::Pg',
  'mysql'    => 'Rose::DB::Object::Metadata::Auto::MySQL',
);

__PACKAGE__->column_type_classes
(
  'scalar'    => 'Rose::DB::Object::Metadata::Column::Scalar',

  'char'      => 'Rose::DB::Object::Metadata::Column::Character',
  'character' => 'Rose::DB::Object::Metadata::Column::Character',
  'varchar'   => 'Rose::DB::Object::Metadata::Column::Varchar',
  'string'    => 'Rose::DB::Object::Metadata::Column::Varchar',

  'text'      => 'Rose::DB::Object::Metadata::Column::Text',
  'blob'      => 'Rose::DB::Object::Metadata::Column::Blob',

  'bits'      => 'Rose::DB::Object::Metadata::Column::Bitfield',
  'bitfield'  => 'Rose::DB::Object::Metadata::Column::Bitfield',

  'bool'      => 'Rose::DB::Object::Metadata::Column::Boolean',
  'boolean'   => 'Rose::DB::Object::Metadata::Column::Boolean',

  'int'       => 'Rose::DB::Object::Metadata::Column::Integer',
  'integer'   => 'Rose::DB::Object::Metadata::Column::Integer',

  'serial'    => 'Rose::DB::Object::Metadata::Column::Serial',

  'num'       => 'Rose::DB::Object::Metadata::Column::Numeric',
  'numeric'   => 'Rose::DB::Object::Metadata::Column::Numeric',
  'decimal'   => 'Rose::DB::Object::Metadata::Column::Numeric',
  'float'     => 'Rose::DB::Object::Metadata::Column::Float',

  'date'      => 'Rose::DB::Object::Metadata::Column::Date',
  'datetime'  => 'Rose::DB::Object::Metadata::Column::Datetime',
  'timestamp' => 'Rose::DB::Object::Metadata::Column::Timestamp',

  'timestamp with time zone'    => 'Rose::DB::Object::Metadata::Column::Timestamp',
  'timestamp without time zone' => 'Rose::DB::Object::Metadata::Column::Timestamp',

  'datetime year to fraction'    => 'Rose::DB::Object::Metadata::Column::DatetimeYearToFraction',
  'datetime year to fraction(1)' => 'Rose::DB::Object::Metadata::Column::DatetimeYearToFraction1',
  'datetime year to fraction(2)' => 'Rose::DB::Object::Metadata::Column::DatetimeYearToFraction2',
  'datetime year to fraction(3)' => 'Rose::DB::Object::Metadata::Column::DatetimeYearToFraction3',
  'datetime year to fraction(4)' => 'Rose::DB::Object::Metadata::Column::DatetimeYearToFraction4',
  'datetime year to fraction(5)' => 'Rose::DB::Object::Metadata::Column::DatetimeYearToFraction5',

  'datetime year to second' => 'Rose::DB::Object::Metadata::Column::DatetimeYearToSecond',
  'datetime year to minute' => 'Rose::DB::Object::Metadata::Column::DatetimeYearToMinute',

  'array'     => 'Rose::DB::Object::Metadata::Column::Array',
  'set'       => 'Rose::DB::Object::Metadata::Column::Set',

  'chkpass'   => 'Rose::DB::Object::Metadata::Column::Pg::Chkpass',
);

__PACKAGE__->relationship_type_classes
(
  'one to one'   => 'Rose::DB::Object::Metadata::Relationship::OneToOne',
  'one to many'  => 'Rose::DB::Object::Metadata::Relationship::OneToMany',
  'many to one'  => 'Rose::DB::Object::Metadata::Relationship::ManyToOne',
  'many to many' => 'Rose::DB::Object::Metadata::Relationship::ManyToMany',
);

sub init_column_name_to_method_name_mapper() { 0 }

our %Objects;

sub new
{
  my($this_class, %args) = @_;
  my $class = $args{'class'} or Carp::croak "Missing required 'class' parameter";
  return $Objects{$class} ||= shift->SUPER::new(@_);
}

sub for_class
{
  return $Objects{$_[1]} ||= $_[0]->new(class => $_[1]);
}

sub error_mode
{
  return $_[0]->{'error_mode'} ||= $_[0]->init_error_mode
    unless(@_ > 1);

  my($self, $mode) = @_;

  unless($mode =~ /^(?:return|carp|croak|cluck|confess|fatal)$/)
  {
    Carp::croak "Invalid error mode: '$mode'";
  }

  return $self->{'error_mode'} = $mode;
}

sub init_error_mode { 'fatal' }

sub handle_error
{
  my($self, $object) = @_;

  my $mode = $self->error_mode;

  return  if($mode eq 'return');

  my $level =  $Carp::CarpLevel;
  local $Carp::CarpLevel = $level + 1;

  if($mode eq 'croak' || $mode eq 'fatal')
  {
    Carp::croak $object->error;
  }
  elsif($mode eq 'carp')
  {
    Carp::carp $object->error;
  }
  elsif($mode eq 'cluck')
  {
    Carp::croak $object->error;
  }
  elsif($mode eq 'confess')
  {
    Carp::confess $object->error;
  }
  else
  {
    Carp::croak "(Invalid error mode set: '$mode') - ", $object->error;
  }

  return 1;
}

sub init_db
{
  my($self) = shift;

  my $class = $self->class or die "Missing class!";

  return $self->class->init_db or 
    Carp::croak "Could not init_db() for class $class - are you sure that ",         
                "Rose::DB's data sources are set up?";
}

sub init_with_db
{
  my($self, $db) = @_;

  # XXX: I'm cheating like crazy in this method for performance reasons,
  # XXX: directly accessing hash keys.  I'll "fix" it if/when I have to...

  my $catalog = $db->{'catalog'};
  my $schema  = $db->{'schema'};
  my $changed = 0;

  UNDEF_IS_OK: # Avoid undef string comparison warnings
  {
    no warnings 'uninitialized';
    if($catalog ne $self->{'catalog'})
    {
      $self->{'catalog'} = $catalog;
      $changed++;
    }

    if($schema ne $self->{'schema'})
    {
      $self->{'schema'} = $schema;
      $changed++;
    }
  }

  if($changed)
  {
    $self->_clear_table_generated_values;
  }

  UNDEF_IS_OK: # Avoid undef string comparison warnings
  {
    no warnings 'uninitialized';
    # If necessary, also clear the select few column-generated values that
    # depend on the database driver.
    if($db->{'driver'} ne $self->{'db_driver'})
    {
      # This is a call to _clear_db_generated_values() that
      # has been inlined for speed.
      $self->{'column_names_string_sql'} = undef;
      $self->{'column_names_sql'} = undef;
    }
  }

  $self->{'db_driver'} = $db->{'driver'};

  return;
}

# Code borrowed from Cache::Cache
my %Expiration_Units =
(
  map(($_,            1), qw(s sec secs second seconds)),
  map(($_,           60), qw(m min mins minute minutes)),
  map(($_,        60*60), qw(h hr hrs hour hours)),
  map(($_,     60*60*24), qw(d day days)),
  map(($_,   60*60*24*7), qw(w wk wks week weeks)),
  map(($_, 60*60*24*365), qw(y yr yrs year years))
);

sub cached_objects_expire_in
{
  my($self) = shift;

  my $class = $self->class;

  no strict 'refs';
  return ${"${class}::Cache_Expires"} ||= 0  unless(@_);

  my $arg = shift;

  my $secs;

  if($arg =~ /^now$/i)
  {
    $class->forget_all;
    $secs = 0;
  }
  elsif($arg =~ /^never$/)
  {
    $secs = 0;
  }
  elsif($arg =~ /^\s*([+-]?(?:\d+|\d*\.\d*))\s*$/)
  {
    $secs = $arg;
  }
  elsif($arg =~ /^\s*([+-]?(?:\d+|\d*\.\d*))\s*(\w*)\s*$/ && exists $Expiration_Units{$2})
  {
    $secs = $Expiration_Units{$2} * $1;
  }
  else
  {
    Carp::croak("Invalid cache expiration time: '$arg'");
  }

  return ${"${class}::Cache_Expires"} = $secs;
}

sub clear_object_cache
{
  my($self) = shift;

  my $class = $self->class;

  no strict 'refs';
  %{"${class}::Objects_By_Id"}  = ();
  %{"${class}::Objects_By_Key"} = ();
  %{"${class}::Objects_Keys"}   = ();

  return 1;
}

sub prepare_select_options 
{
  @_ > 1 ? $_[0]->{'prepare_select_options'} = $_[1] : 
           $_[0]->{'prepare_select_options'} ||= {}
}

sub prepare_insert_options
{
  @_ > 1 ? $_[0]->{'prepare_insert_options'} = $_[1] : 
           $_[0]->{'prepare_insert_options'} ||= {}
}

sub prepare_update_options
{
  @_ > 1 ? $_[0]->{'prepare_update_options'} = $_[1] : 
           $_[0]->{'prepare_update_options'} ||= {}
}

sub prepare_delete_options
{
  @_ > 1 ? $_[0]->{'prepare_delete_options'} = $_[1] : 
           $_[0]->{'prepare_delete_options'} ||= {}
}

sub prepare_bulk_delete_options
{
  @_ > 1 ? $_[0]->{'prepare_bulk_delete_options'} = $_[1] : 
           $_[0]->{'prepare_bulk_delete_options'} ||= 
           $_[0]->prepare_delete_options;
}

sub prepare_bulk_update_options
{
  @_ > 1 ? $_[0]->{'prepare_bulk_update_options'} = $_[1] : 
           $_[0]->{'prepare_bulk_update_options'} ||= 
           $_[0]->prepare_update_options;
}

sub prepare_options
{
  my($self, $options) = @_;

  Carp::croak "Missing required hash ref argument to prepare_options()"
    unless(ref $options eq 'HASH');

  $self->prepare_select_options({ %$options });
  $self->prepare_insert_options({ %$options });
  $self->prepare_update_options({ %$options });
  $self->prepare_delete_options({ %$options });
}

sub table
{
  return $_[0]->{'table'}  unless(@_ > 1);
  $_[0]->_clear_table_generated_values;
  return $_[0]->{'table'} = $_[1];
}

sub catalog
{
  return $_[0]->{'catalog'}  unless(@_ > 1);
  $_[0]->_clear_table_generated_values;
  return $_[0]->{'catalog'} = $_[1];
}

sub schema
{
  return $_[0]->{'schema'}  unless(@_ > 1);
  $_[0]->_clear_table_generated_values;
  return $_[0]->{'schema'} = $_[1];
}

sub init_primary_key
{
  Rose::DB::Object::Metadata::PrimaryKey->new(parent => shift);
}

sub primary_key_generator    { shift->primary_key->generator(@_)    }
sub primary_key_columns      { shift->primary_key->columns(@_)      }
sub primary_key_column_names { shift->primary_key->column_names(@_) }

sub init_primary_key_column_info
{
  my($self) = shift;

  my $pk_position = 0; 

  foreach my $col_name ($self->primary_key_column_names)
  {
    $pk_position++;
    my $column = $self->column($col_name) or next;
    $column->is_primary_key_member(1);
    $column->primary_key_position($pk_position);
  }

  return;
}

sub add_primary_key_columns
{
  my($self) = shift;

  $self->primary_key->add_columns(@_);
  $self->init_primary_key_column_info;

  return;
}

*add_primary_key_column = \&add_primary_key_columns;

sub add_unique_keys
{
  my($self) = shift;

  if(@_ == 1 && ref $_[0] eq 'ARRAY')
  {
    push @{$self->{'unique_keys'}}, 
         Rose::DB::Object::Metadata::UniqueKey->new(parent => $self, columns => $_[0]);
  }
  else
  {
    push @{$self->{'unique_keys'}}, map
    {
      UNIVERSAL::isa($_, 'Rose::DB::Object::Metadata::UniqueKey') ?
      ($_->parent($self), $_) : 
      Rose::DB::Object::Metadata::UniqueKey->new(parent => $self, columns => $_)
    }
    @_;
  }

  return;
}

*add_unique_key = \&add_unique_keys;

sub delete_unique_keys { $_[0]->{'unique_keys'} = [] }

sub unique_keys
{
  my($self) = shift;

  if(@_)
  {
    $self->delete_unique_keys;
    $self->add_unique_keys(@_);
  }

  wantarray ? @{$self->{'unique_keys'} ||= []} : ($self->{'unique_keys'} ||= []);
}

sub unique_keys_column_names
{
  wantarray ?   map { scalar $_->column_names } @{shift->{'unique_keys'} ||= []} :
              [ map { scalar $_->column_names } @{shift->{'unique_keys'} ||= []} ];
}

sub delete_column
{
  my($self, $name) = @_;
  delete $self->{'columns'}{$name};
  return;
}

sub delete_columns
{
  my($self, $name) = @_;
  $self->{'columns'} = {};
  return;
}

sub sync_keys_to_columns
{
  my($self) = shift;

  $self->_clear_column_generated_values;

  my %columns = map { $_->name => 1 } $self->columns;

  foreach my $col_name ($self->primary_key_column_names)
  {
    unless($columns{$col_name})
    {
      $self->primary_key(undef);
      last;
    }
  }

  my @valid_uks;

  UK: foreach my $uk ($self->unique_keys)
  {
    foreach my $col_name ($uk->column_names)
    {
      next UK  unless($columns{$col_name});
    }

    push(@valid_uks, $uk);
  }

  $self->unique_keys(@valid_uks);

  return;
}


sub column
{
  my($self, $name) = (shift, shift);

  if(@_)
  {
    $self->delete_column($name);
    $self->add_column($name => @_);
  }

  return $self->{'columns'}{$name}  if($self->{'columns'}{$name});
  return undef;
}

sub columns
{
  my($self) = shift;

  if(@_)
  {
    $self->delete_columns;
    $self->add_columns(@_);
  }

  return wantarray ?
    (sort { $a->name cmp $b->name } values %{$self->{'columns'} ||= {}}) :
    [ sort { $a->name cmp $b->name } values %{$self->{'columns'} ||= {}} ];
}

sub add_columns
{
  my($self) = shift;

  my $class = ref $self;

  $self->_clear_column_generated_values;

  ARG: while(@_)
  {
    my $name = shift;

    if(UNIVERSAL::isa($name, 'Rose::DB::Object::Metadata::Column'))
    {
      my $column = $name;

      Carp::croak "Relationship $column lacks a name()"
        unless($column->name =~ /\S/);

      $column->parent($self);
      $self->{'columns'}{$column->name} = $column;
      next;
    }

    unless(ref $_[0])
    {
      my $column_class = $class->column_type_class('scalar')
        or Carp::croak "No column class set for column type 'scalar'";

      $Debug && warn $self->class, " - adding scalar column $name\n";
      $self->{'columns'}{$name} = $column_class->new(name => $name, parent => $self);
      next;
    }

    if(UNIVERSAL::isa($_[0], 'Rose::DB::Object::Metadata::Column'))
    {
      my $column = $_[0];
      $column->name($name);
      $column->parent($self);
      $self->{'columns'}{$name} = $column;
    }
    elsif(ref $_[0] eq 'HASH')
    {
      my $info = shift;

      my $alias = $info->{'alias'};

      if($info->{'primary_key'})
      {
        $Debug && warn $self->class, " - adding primary key column $name\n";
        $self->add_primary_key_column($name);
      }

      my $methods     = delete $info->{'methods'};
      my $add_methods = delete $info->{'add_methods'};

      if($methods && $add_methods)
      {
        Carp::croak "Cannot specify both 'methods' and 'add_methods' - ",
                    "pick one or the other";
      }

      my $type = $info->{'type'} ||= 'scalar';

      my $column_class = $class->column_type_class($type)
        or Carp::croak "No column class set for column type '$type'";

      unless($self->column_class_is_loaded($column_class))
      {
        $self->load_column_class($column_class);
      }

      $Debug && warn $self->class, " - adding $name $column_class\n";
      my $column = $self->{'columns'}{$name} = 
        $column_class->new(%$info, name => $name, parent => $self);

      # Set or add auto-created method names
      if($methods || $add_methods)
      {
        my $auto_method_name = 
          $methods ? 'auto_method_types' : 'add_auto_method_types';

        my $methods_arg = $methods || $add_methods;

        if(ref $methods_arg eq 'HASH')
        {
          $methods = [ keys %$methods_arg ];

          while(my($type, $name) = each(%$methods_arg))
          {
            next  unless(defined $name);
            $column->method_name($type => $name);
          }
        }
        else
        {
          $methods = $methods_arg;
        }

        $column->$auto_method_name($methods);      
      }

      if(defined $alias)
      {
        $column->alias($alias);
        $self->alias_column($name, $alias);
      }
    }
    else
    {
      Carp::croak "Invalid column name or specification: $_[0]";
    }
  }
}

*add_column = \&add_columns;

sub relationship
{
  my($self, $name) = (shift, shift);

  if(@_)
  {
    $self->delete_relationship($name);
    $self->add_relationship($name => @_);
  }

  return $self->{'relationships'}{$name}  if($self->{'relationships'}{$name});
  return undef;
}

sub delete_relationship
{
  my($self, $name) = @_;
  delete $self->{'relationships'}{$name};
  return;
}

sub relationships
{
  my($self) = shift;

  if(@_)
  {
    $self->delete_relationships;
    $self->add_relationships(@_);
  }

  return wantarray ?
    (sort { $a->name cmp $b->name } values %{$self->{'relationships'} ||= {}}) :
    [ sort { $a->name cmp $b->name } values %{$self->{'relationships'} ||= {}} ];
}

sub delete_relationships
{
  my($self, $name) = @_;
  $self->{'relationships'} = {};
  return;
}

sub add_relationships
{
  my($self) = shift;

  my $class = ref $self;

  ARG: while(@_)
  {
    my $name = shift;

    if(UNIVERSAL::isa($name, 'Rose::DB::Object::Metadata::Relationship'))
    {
      my $relationship = $name;

      Carp::croak "Relationship $relationship lacks a name()"
        unless($relationship->name =~ /\S/);

      if(defined $self->{'relationships'}{$relationship->name})
      {
        Carp::croak $self->class, " already has a relationship named '", 
                    $relationship->name, "'";
      }

      $relationship->parent($self);
      $self->{'relationships'}{$relationship->name} = $relationship;
      next;
    }

    unless(ref $_[0])
    {
      Carp::croak "No relationship specificaton found for relationship name '$name'";
    }

    if(UNIVERSAL::isa($_[0], 'Rose::DB::Object::Metadata::Relationship'))
    {
      my $relationship = $_[0];
      $relationship->name($name);
      $relationship->parent($self);
      $self->{'relationships'}{$name} = $relationship;
    }
    elsif(ref $_[0] eq 'HASH')
    {
      my $info = shift;

      if(defined $self->{'relationships'}{$name})
      {
        Carp::croak $self->class, " already has a relationship named '$name'";
      }

      my $methods     = delete $info->{'methods'};
      my $add_methods = delete $info->{'add_methods'};

      if($methods && $add_methods)
      {
        Carp::croak "Cannot specify both 'methods' and 'add_methods' - ",
                    "pick one or the other";
      }

      my $type = $info->{'type'} or 
        Carp::croak "Missing type parameter for relationship '$name'";

      my $relationship_class = $class->relationship_type_class($type)
        or Carp::croak "No relationship class set for relationship type '$type'";

      unless($self->relationship_class_is_loaded($relationship_class))
      {
        $self->load_relationship_class($relationship_class);
      }

      $Debug && warn $self->class, " - adding $name $relationship_class\n";
      my $relationship = $self->{'relationships'}{$name} = 
        $relationship_class->new(%$info, name => $name, parent => $self);

      # Set or add auto-created method names
      if($methods || $add_methods)
      {
        my $auto_method_name = 
          $methods ? 'auto_method_types' : 'add_auto_method_types';

        my $methods_arg = $methods || $add_methods;

        if(ref $methods_arg eq 'HASH')
        {
          $methods = [ keys %$methods_arg ];

          while(my($type, $name) = each(%$methods_arg))
          {
            next  unless(defined $name);
            $relationship->method_name($type => $name);
          }
        }
        else
        {
          $methods = $methods_arg;
        }

        $relationship->$auto_method_name($methods);      
      }
    }
    else
    {
      Carp::croak "Invalid relationship name or specification: $_[0]";
    }
  }
}

*add_relationship = \&add_relationships;

my %Class_Loaded;

sub load_column_class
{
  my($self, $column_class) = @_;

  eval "require $column_class";

  Carp::croak "Could not load column class '$column_class' - $@"
    if($@);

  $Class_Loaded{$column_class}++;
}

sub column_class_is_loaded { $Class_Loaded{$_[1]} }

sub load_relationship_class
{
  my($self, $relationship_class) = @_;

  eval "require $relationship_class";

  Carp::croak "Could not load relationship class '$relationship_class' - $@"
    if($@);

  $Class_Loaded{$relationship_class}++;
}

sub relationship_class_is_loaded { $Class_Loaded{$_[1]} }

sub add_foreign_keys
{
  my($self) = shift;

  ARG: while(@_)
  {
    my $name = shift;

    if(UNIVERSAL::isa($name, 'Rose::DB::Object::Metadata::ForeignKey'))
    {
      my $fk = $name;

      Carp::croak "Foreign key $fk lacks a name()"
        unless($fk->name =~ /\S/);

      if(defined $self->{'foreign_keys'}{$fk->name})
      {
        Carp::croak $self->class, " already has a foreign key named '", 
                    $fk->name, "'";
      }

      $fk->parent($self);

      $self->{'foreign_keys'}{$fk->name} = $fk;

      unless(defined $self->relationship($fk->name))
      {
        $self->add_relationship(
          $self->relationship_type_class($fk->relationship_type)->new(
            parent      => $self,
            name        => $fk->name, 
            class       => $fk->class,
            foreign_key => $fk));
      }

      next ARG;
    }

    if(ref $_[0] eq 'HASH')
    {
      my $info = shift;

      if(defined $self->{'foreign_keys'}{$name})
      {
        Carp::croak $self->class, " already has a foreign key named '$name'";
      }

      my $methods     = delete $info->{'methods'};
      my $add_methods = delete $info->{'add_methods'};

      if($methods && $add_methods)
      {
        Carp::croak "Cannot specify both 'methods' and 'add_methods' - ",
                    "pick one or the other";
      }

      $Debug && warn $self->class, " - adding $name foreign key\n";
      my $fk = $self->{'foreign_keys'}{$name} = 
        Rose::DB::Object::Metadata::ForeignKey->new(%$info, name => $name, parent => $self);

      # Set or add auto-created method names
      if($methods || $add_methods)
      {
        my $auto_method_name = 
          $methods ? 'auto_method_types' : 'add_auto_method_types';

        my $methods_arg = $methods || $add_methods;

        if(ref $methods_arg eq 'HASH')
        {
          $methods = [ keys %$methods_arg ];

          while(my($type, $name) = each(%$methods_arg))
          {
            next  unless(defined $name);
            $fk->method_name($type => $name);
          }
        }
        else
        {
          $methods = $methods_arg;
        }

        $fk->$auto_method_name($methods);      
      }

      unless(defined $self->relationship($name))
      {
        $self->add_relationship(
          $self->relationship_type_class($fk->relationship_type)->new(
            name        => $name,
            class       => $fk->class,
            foreign_key => $fk));
      }
    }
    else
    {
      Carp::croak "Invalid foreign key specification: $_[0]";
    }
  }
}

*add_foreign_key = \&add_foreign_keys;

sub foreign_key
{
  my($self, $name) = (shift, shift);

  if(@_)
  {
    $self->delete_foreign_key($name);
    $self->add_foreign_key($name => @_);
  }

  return $self->{'foreign_keys'}{$name}  if($self->{'foreign_keys'}{$name});
  return undef;
}

sub delete_foreign_key
{
  my($self, $name) = @_;
  delete $self->{'foreign_keys'}{$name};
  return;
}

sub foreign_keys
{
  my($self) = shift;

  if(@_)
  {
    $self->{'foreign_keys'} = {};
    $self->add_foreign_keys(@_);
  }

  return wantarray ?
    (sort { $a->name cmp $b->name } values %{$self->{'foreign_keys'} ||= {}}) :
    [ sort { $a->name cmp $b->name } values %{$self->{'foreign_keys'} ||= {}} ];
}

sub initialize
{
  my($self) = shift;

  $Debug && warn $self->class, " - initialize\n";

  my $class = $self->class
    or Carp::croak "Missing class for metadata object $self";

  $self->sync_keys_to_columns;

  my $table = $self->table;
  Carp::croak "$class - Missing table name" 
    unless(defined $table && $table =~ /\S/);

  my @pk = $self->primary_key_column_names;
  Carp::croak "$class - Missing primary key for table '$table'"  unless(@pk);

  $self->init_primary_key_column_info;

  my @column_names = $self->column_names;
  Carp::croak "$class - No columns defined for for table '$table'"
    unless(@column_names);

  $self->make_methods(@_);

  $self->register_class;

  $self->db(undef); # make sure to ditch any db we may have retained

  $self->is_initialized(1);

  $Debug && warn $self->class, " - initialized\n";

  return;
}

use constant NULL_CATALOG => "\0";
use constant NULL_SCHEMA  => "\0";

sub register_class
{
  my($self) = shift;

  my $class = $self->class 
    or Carp::croak "Missing class for metadata object $self";

  my $db = $self->db;

  my $catalog = $self->catalog;
  my $schema  = $self->schema;

  $catalog  = NULL_CATALOG  unless(defined $catalog);
  $schema   = NULL_SCHEMA   unless(defined $schema);

  my $table = $self->table 
    or Carp::croak "Missing table for metadata object $self";

  my $reg = $self->class_registry;

  # Combine keys using $;, which is "\034" (0x1C) by default. But just to
  # make sure, I'll localize it.  What I'm looking for is a value that
  # won't show up in a catalog, schema, or table name, so I'm guarding
  # against someone changing it to "-" (or whatever) elsewhere in the code.
  local $; = "\034";

   # Register with all available information
  $reg->{'catalog-schema-table',$catalog,$schema,$table} =
    $reg->{'schema-table',$schema,$table}  =
    $reg->{'catalog-table',$catalog,$table} =
    $reg->{'table',$table} = $class;

  return;
}

sub class_for
{
  my($self, %args) = @_;

  my $db = $self->db;

  my $catalog = $args{'catalog'};
  my $schema  = $args{'schema'};

  $catalog = NULL_CATALOG  unless(defined $catalog);
  $schema  = NULL_SCHEMA   unless(defined $schema);

  my $table = $args{'table'} 
    or Carp::croak "Missing required table parameter";

  my $reg = $self->class_registry;

  # Combine keys using $;, which is "\034" (0x1C) by default. But just to
  # make sure, we'll localize it.  What we're looking for is a value that
  # wont' show up in a catalog, schema, or table name, so I'm guarding
  # against someone changing it to "-" elsewhere in the code or whatever.
  local $; = "\034";

  return 
    $reg->{'catalog-schema-table',$catalog,$schema,$table} ||
    $reg->{'catalog-schema-table',$catalog,$db->default_implicit_schema,$table} ||
    $reg->{'schema-table',$schema,$table}  ||
    $reg->{'catalog-table',$catalog,$table} ||
    $reg->{'table',$table};
}

#sub made_method_for_column 
#{
#  (@_ > 2) ? ($_[0]->{'made_methods'}{$_[1]} = $_[2]) :
#             $_[0]->{'made_methods'}{$_[1]};
#}

sub make_column_methods
{
  my($self) = shift;
  my(%args) = @_;

  my $class = $self->class;

  $args{'target_class'} = $class;

  my $aliases = $self->column_aliases;

  while(my($column_name, $alias) = each(%$aliases))
  {
    $self->column($column_name)->alias($alias);
  }

  foreach my $column ($self->columns)
  {
    my $name = $column->name;
    my $method;

    foreach my $type ($column->auto_method_types)
    {
      $method = $self->method_name_from_column_name($name, $type)
        or Carp::croak "No method name defined for column '$name' ",
                       "method type '$type'";

      if(my $reason = $self->method_name_is_reserved($method, $class))
      {
        Carp::croak "Cannot create method '$method' - $reason  ",
                    "Use alias_column() to map it to another name."
      }

      $column->method_name($type => $method);
    }

    $Debug && warn $self->class, " - make methods for column $name\n";

    $column->make_methods(%args);

    # Allow primary keys to be aliased
    #if($method ne $name)
    #{
    #  # Primary key columns can be aliased, but we make a column-named 
    #  # method anyway.
    #  foreach my $column ($self->primary_key_column_names)
    #  {
    #    if($name eq $column)
    #    {
    #      if(my $reason = $self->method_name_is_reserved($name, $class))
    #      {
    #        Carp::croak
    #          "Cannot create method for primary key column '$name' ",
    #          "- $reason  Although primary keys may be aliased, doing ",
    #          "so will not avoid conflicts with reserved method names ", 
    #          "because a method named after the primary key column ",
    #          "itself must also be created.";
    #      }
    #
    #      no strict 'refs';
    #      *{"${class}::$name"} = \&{"${class}::$method"};
    #    }
    #  }
    #}
  }

  # Initialize method name hashes
  $self->column_accessor_method_names;
  $self->column_mutator_method_names;
  $self->column_rw_method_names;

  # This rule is relaxed for now...
  # Must have an rw accessor for every column
  #my $columns = $self->columns;
  #
  #unless(keys %methods == @$columns)
  #{
  #  Carp::croak "Rose::DB::Object-derived objects are requiresd to have ",
  #              "a 'get_set' method for every column.  This class (",
  #              $self->class, ") has ", scalar @$columns, "column",
  #              (@$columns == 1 ? '' : 's'), " and ", scalar keys %methods,
  #              " method", (scalar keys %methods == 1 ? '' : 's');
  #}

  return;
}

sub make_foreign_key_methods
{
  my($self) = shift;
  my(%args) = @_;

  $self->retry_deferred_foreign_keys;

  my $class = $self->class;
  my $meta_class = ref $self;

  $args{'target_class'} = $class;

  foreach my $foreign_key ($self->foreign_keys)
  {
    foreach my $type ($foreign_key->auto_method_types)
    {
      my $method = 
        $foreign_key->method_name($type) || 
        $foreign_key->build_method_name_for_type($type) ||
        Carp::croak "No method name defined for foreign key '",
                    $foreign_key->name, "' method type '$type'";

      if(my $reason = $self->method_name_is_reserved($method, $class))
      {
        Carp::croak "Cannot create method '$method' - $reason  ",
                    "Choose a different foreign key name."
      }

      $foreign_key->method_name($type => $method);
    }

    # We may need to defer the creation of some foreign key methods until
    # all the required pieces are loaded.
    if($foreign_key->is_ready_to_make_methods)
    {
      $Debug && warn $self->class, " - make methods for foreign key ", 
                     $foreign_key->name, "\n";

      $foreign_key->make_methods(%args);
    }
    else
    {
      # Confirm that no info is missing.  This prevents an improperly
      # configured foreign_key from being deferred "forever"
      $foreign_key->sanity_check; 

      $Debug && warn $self->class, " - defer foreign key ", $foreign_key->name, "\n";

      $foreign_key->deferred_make_method_args(\%args);
      $meta_class->add_deferred_foreign_key($foreign_key);
    }

    # Keep foreign keys and their corresponding relationships in sync.
    my $fk_id       = $foreign_key->id;
    my $fk_rel_type = $foreign_key->relationship_type;
    
    foreach my $relationship ($self->relationships)
    {
      next  unless($relationship->type eq $fk_rel_type);

      if($fk_id eq $relationship->id)
      {
        $relationship->foreign_key($foreign_key);
      }
    }
  }

  $self->retry_deferred_foreign_keys;

  return;
}

our @Deferred_Foreign_Keys;

sub deferred_foreign_keys
{
  return wantarray ? @Deferred_Foreign_Keys : \@Deferred_Foreign_Keys;
}

sub add_deferred_foreign_keys
{
  my($class) = shift;  

  foreach my $arg (@_)
  {
    foreach my $fk (@Deferred_Foreign_Keys)
    {
      next  if($fk->id eq $arg->id);
    }

    push(@Deferred_Foreign_Keys, $arg);
  }
}

*add_deferred_foreign_key = \&add_deferred_foreign_keys;

sub retry_deferred_foreign_keys
{
  my($self) = shift;

  my $meta_class = ref $self;

  my @foreign_keys;

  # Check to see if any deferred foreign keys are ready now
  foreach my $foreign_key ($meta_class->deferred_foreign_keys)
  {
    if($foreign_key->is_ready_to_make_methods)
    {
      $Debug && warn $foreign_key->parent->class,
                     " - (Retry) make methods for foreign key ", 
                     $foreign_key->name, "\n";

      my $args = $foreign_key->deferred_make_method_args || {};
      $foreign_key->make_methods(%$args, preserve_existing => 1);
    }
    else
    {
      push(@foreign_keys, $foreign_key);
    }
  }

  if(@Deferred_Foreign_Keys != @foreign_keys)
  {
    @Deferred_Foreign_Keys = @foreign_keys;
  }
}

sub make_relationship_methods
{
  my($self) = shift;
  my(%args) = @_;

  $self->retry_deferred_relationships;

  my $meta_class = ref $self;
  my $class = $self->class;

  $args{'target_class'} = $class;

  my $preserve_existing_arg = $args{'preserve_existing'};

  REL: foreach my $relationship ($self->relationships)
  {
    foreach my $type ($relationship->auto_method_types)
    {
      my $method = 
        $relationship->method_name($type) || 
        $relationship->build_method_name_for_type($type) ||
        Carp::croak "No method name defined for relationship '",
                    $relationship->name, "' method type '$type'";

      if(my $reason = $self->method_name_is_reserved($method, $class))
      {
        Carp::croak "Cannot create method '$method' - $reason  ",
                    "Choose a different relationship name."
      }

      $relationship->method_name($type => $method);

      # Initialize/reset preserve_existing flag
      $args{'preserve_existing'} = $preserve_existing_arg;

      # If a corresponding foreign key exists, the preserve any existing
      # methods with the same names.  This is a crude way to ensure that we
      # can have a foreign key and a corresponding relationship without any 
      # method name clashes.
      if($relationship->can('id'))
      {
        my $rel_id = $relationship->id;
  
        FK: foreach my $fk ($self->foreign_keys)
        {
          if($rel_id eq $fk->id)
          {
            $args{'preserve_existing'} = 1;
            last FK;
          }
        }
      }
    }

    # We may need to defer the creation of some relationship methods until
    # all the required pieces are loaded.
    if($relationship->is_ready_to_make_methods)
    {
      $Debug && warn $self->class, " - make methods for relationship ", 
                     $relationship->name, "\n";

      $relationship->make_methods(%args);
    }
    else
    {
      # Confirm that no info is missing.  This prevents an improperly
      # configured relationship from being deferred "forever"
      $relationship->sanity_check; 

      $Debug && warn $self->class, " - defer relationship ", $relationship->name, "\n";

      $relationship->deferred_make_method_args(\%args);
      $meta_class->add_deferred_relationship($relationship);
    }
  }

  $self->retry_deferred_relationships;

  return;
}

our @Deferred_Relationships;

sub deferred_relationships
{
  return wantarray ? @Deferred_Relationships : \@Deferred_Relationships;
}

sub add_deferred_relationships
{
  my($class) = shift;

  foreach my $arg (@_)
  {
    foreach my $rel (@Deferred_Relationships)
    {
      next  if($rel->id eq $arg->id);
    }

    push(@Deferred_Relationships, $arg);
  }
}

*add_deferred_relationship = \&add_deferred_relationships;

sub retry_deferred_relationships
{
  my($self) = shift;

  my $meta_class = ref $self;

  my @relationships;

  # Check to see if any deferred relationships are ready now
  foreach my $relationship ($self->deferred_relationships)
  {
    if($relationship->is_ready_to_make_methods)
    {
      $Debug && warn $relationship->parent->class, 
                     " - (Retry) make methods for relationship ", 
                     $relationship->name, "\n";

      my $args = $relationship->deferred_make_method_args || {};
      $relationship->make_methods(%$args);
    }
    else
    {
      push(@relationships, $relationship);
    }
  }

  if(@Deferred_Relationships != @relationships)
  {
    @Deferred_Relationships = @relationships;
  }
}

sub make_methods
{
  my($self) = shift;

  $self->make_column_methods(@_);
  $self->make_foreign_key_methods(@_);
  $self->make_relationship_methods(@_);
}

sub generate_primary_key_values
{
  my($self, $db) = @_;

  if(my $code = $self->primary_key_generator)
  {
    return $code->($self, $db);
  }

  my $id;

  if(my $seq = $self->fq_primary_key_sequence_name(db => $db))
  {
    $id = $db->next_value_in_sequence($seq);

    unless($id)
    {
      $self->error("Could not generate primary key for ", $self->class, 
                   " by selecting the next value in the sequence '$seq' - $@");
      return undef;
    }

    return $id;
  }
  else
  {
    return $db->generate_primary_key_values(scalar @{$self->primary_key_column_names});
  }
}

*generate_primary_key_value = \&generate_primary_key_values;

sub generate_primary_key_placeholders
{
  my($self, $db) = @_;
  return $db->generate_primary_key_placeholders(scalar @{$self->primary_key_column_names});
}

sub fq_primary_key_sequence_name
{
  my($self) = shift;

  if(defined $self->{'fq_primary_key_sequence_name'})
  {
    return $self->{'fq_primary_key_sequence_name'};
  }

  if(my $seq = $self->primary_key_sequence_name(@_))
  {
    my %args = @_;

    my $db = $args{'db'} or
      die "Cannot generate fully-qualified primary key sequence name without db argument";

    return $self->{'fq_primary_key_sequence_name'} = 
      $db->quote_identifier($self->catalog, $self->schema, $seq);
  }

  return undef;
}

sub primary_key_sequence_name
{
  my($self) = shift;

  if(@_ == 1)
  {
    $self->{'fq_primary_key_sequence_name'} = undef;
    return $self->{'primary_key_sequence_name'} = shift;
  }

  if($self->{'primary_key_sequence_name'})
  {
    return $self->{'primary_key_sequence_name'};
  }

  my @pk_columns = $self->primary_key_column_names;

  return undef  if(@pk_columns > 1);

  my %args = @_;

  my $db = $args{'db'} or
    die "Cannot generate primary key sequence name without db argument";

  my $table = $self->table or 
    Carp::croak "Cannot generate primary key sequence name without table name";

  return $self->{'primary_key_sequence_name'} = 
    $db->auto_sequence_name(table => $table, column => $pk_columns[0]);    
}

sub column_names
{
  my($self) = shift;
  $self->{'column_names'} ||= [ sort { $a cmp $b } keys %{$self->{'columns'} ||= {}} ];
  return wantarray ? @{$self->{'column_names'}} : $self->{'column_names'};
}

sub column_names_string_sql
{
  my($self) = shift;

  return $self->{'column_names_string_sql'} ||= 
    join(', ', map { $_->name_sql } sort { $a->name cmp $b->name } $self->columns);
}

sub column_names_sql
{
  my($self) = shift;

  $self->{'column_names_sql'} ||= 
    [ map { $_->name_sql } sort { $a->name cmp $b->name } $self->columns ];

  return wantarray ? @{$self->{'column_names_sql'}} : $self->{'column_names_sql'};
}

sub method_column
{
  my($self, $method) = @_;

  unless(defined $self->{'method_columns'})
  {
    foreach my $column ($self->column_names)
    {
      foreach my $type ($column->defined_method_types)
      {
        if(my $method = $column->method_name($type))
        {
          $self->{'method_column'}{$method} = $column;
        }
      }
    }
  }

  return $self->{'method_column'}{$method};
}

sub column_rw_method_names
{
  my($self) = shift;

  $self->{'column_rw_method_names'} ||= 
    [ map { $self->column_rw_method_name($_) } $self->column_names ];

  return wantarray ? @{$self->{'column_rw_method_names'}} :
                     $self->{'column_rw_method_names'};
}

sub column_accessor_method_names
{
  my($self) = shift;

  $self->{'column_accessor_method_names'} ||= 
    [ map { $self->column_accessor_method_name($_) } $self->column_names ];

  return wantarray ? @{$self->{'column_accessor_method_names'}} :
                     $self->{'column_accessor_method_names'};
}

sub column_mutator_method_names
{
  my($self) = shift;

  $self->{'column_mutator_method_names'} ||= 
    [ map { $self->column_mutator_method_name($_) } $self->column_names ];

  return wantarray ? @{$self->{'column_mutator_method_names'}} :
                     $self->{'column_mutator_method_names'};
}

sub alias_column
{
  my($self, $name, $new_name) = @_;

  Carp::croak "Usage: alias_column(column name, new name)"
    unless(@_ == 3);

  Carp::croak "No such column '$name' in table ", $self->table
    unless($self->{'columns'}{$name});

  Carp::croak "Pointless alias for '$name' to '$new_name' for table ", $self->table
    unless($name ne $new_name);

  # We now allow this, but create a duplicate method using the real
  # column name anyway in make_column_methods().
  #foreach my $column ($self->primary_key_column_names)
  #{
  #  if($name eq $column)
  #  {
  #    Carp::croak "Cannot alias primary key column '$name'";
  #  }
  #}

  $self->_clear_column_generated_values;

  if(my $column = $self->column($name))
  {
    $column->method_name($new_name);
  }

  $self->{'column_aliases'}{$name} = $new_name;
}

sub column_aliases
{
  return $_[0]->{'column_aliases'}  unless(@_ > 1);
  return $_[0]->{'column_aliases'} = (ref $_[1] eq 'HASH') ? $_[1] : { @_[1 .. $#_] };
}

sub column_accessor_method_name
{
  $_[0]->{'column_accessor_method'}{$_[1]} ||= 
    $_[0]->column($_[1])->accessor_method_name;
}

sub column_accessor_method_names_hash { shift->{'column_accessor_method'} }

sub column_mutator_method_name
{
  $_[0]->{'column_mutator_method'}{$_[1]} ||= 
    $_[0]->column($_[1])->mutator_method_name;
}

sub column_mutator_method_names_hash { shift->{'column_mutator_method'} }

sub column_rw_method_name
{
  $_[0]->{'column_rw_method'}{$_[1]} ||= 
    $_[0]->column($_[1])->rw_method_name;
}

sub column_rw_method_names_hash { shift->{'column_rw_method'} }

sub fq_table_sql
{
  my($self) = shift;
  return $self->{'fq_table_sql'} ||= 
    join('.', grep { defined } ($self->catalog, $self->schema, $self->table));
}

sub load_sql
{
  my($self, $key_columns) = @_;

  $key_columns ||= $self->primary_key_column_names;

  no warnings;
  return $self->{'load_sql'}{join("\0", @$key_columns)} ||= 
    'SELECT ' . $self->column_names_string_sql . ' FROM ' .
    $self->fq_table_sql . ' WHERE ' .
    join(' AND ',  map { "$_ = ?" } @$key_columns);
}

sub load_sql_with_null_key
{
  my($self, $key_columns, $key_values) = @_;

  my $i = 0;

  no warnings;
  return 
    'SELECT ' . $self->column_names_string_sql . ' FROM ' .
    $self->fq_table_sql . ' WHERE ' .
    join(' AND ',  map { defined $key_values->[$i++] ? "$_ = ?" : "$_ IS NULL" }
    @$key_columns);
}

sub update_sql
{
  my($self, $key_columns) = @_;

  $key_columns ||= $self->primary_key_column_names;

  my $cache_key = join("\0", @$key_columns);

  return $self->{'update_sql'}{$cache_key}
    if($self->{'update_sql'}{$cache_key});

  my %key = map { ($_ => 1) } @$key_columns;

  no warnings;
  return $self->{'update_sql'}{$cache_key} = 
    'UPDATE ' . $self->fq_table_sql . " SET \n" .
    join(",\n", map { '    ' . $self->column($_)->name_sql . ' = ?' } 
                grep { !$key{$_} } $self->column_names) .
    "\nWHERE " . 
    join(' AND ', map { $self->column($_)->name_sql . ' = ?' } @$key_columns);
}

# This is nonsensical right now because the primary key always has to be
# non-null, and any update will use the primary key instead of a unique
# key. But I'll leave the code here (commented out) just in case.
#
# sub update_sql_with_null_key
# {
#   my($self, $key_columns, $key_values) = @_;
# 
#   my %key = map { ($_ => 1) } @$key_columns;
#   my $i = 0;
# 
#   no warnings;
#   return
#     'UPDATE ' . $self->fq_table_sql . " SET \n" .
#     join(",\n", map { '    ' . $self->column($_)->name_sql . ' = ?' } 
#                 grep { !$key{$_} } $self->column_names) .
#     "\nWHERE " . join(' AND ', map { defined $key_values->[$i++] ? "$_ = ?" : "$_ IS NULL" }
#     map { $self->column($_)->name_sql } @$key_columns);
# }
#
# Ditto for this version of update_sql_with_inlining which handles null keys
#
# sub update_sql_with_inlining
# {
#   my($self, $obj, $key_columns, $key_values) = @_;
# 
#   my $db = $obj->db or Carp::croak "Missing db";
# 
#   $key_columns ||= $self->primary_key_column_names;
#   
#   my %key = map { ($_ => 1) } @$key_columns;
# 
#   my @bind;
#   my @updates;
# 
#   foreach my $column (grep { !$key{$_} } $self->columns)
#   {
#     my $method = $self->column_method($column->name);
#     my $value  = $obj->$method();
#     
#     if($column->should_inline_value($db, $value))
#     {
#       push(@updates, '  ' . $column->name_sql . " = $value");
#     }
#     else
#     {
#       push(@updates, '  ' . $column->name_sql . ' = ?');
#       push(@bind, $value);
#     }
#   }
# 
#   my $i = 0;
# 
#   no warnings;
#   return 
#   (
#     ($self->{'update_sql_with_inlining_start'} ||= 
#      'UPDATE ' . $self->fq_table_sql . " SET \n") .
#     join(",\n", @updates) . "\nWHERE " . 
#     join(' AND ', map { defined $key_values->[$i++] ? "$_ = ?" : "$_ IS NULL" }
#                   map { $self->column($_)->name_sql } @$key_columns),
#     \@bind
#   );
# }

sub update_sql_with_inlining
{
  my($self, $obj, $key_columns) = @_;

  my $db = $obj->db or Carp::croak "Missing db";

  $key_columns ||= $self->primary_key_column_names;

  my %key = map { ($_ => 1) } @$key_columns;

  my @bind;
  my @updates;

  foreach my $column (grep { !$key{$_} } $self->columns)
  {
    my $method = $self->column_accessor_method_name($column->name);
    my $value  = $obj->$method();

    if($column->should_inline_value($db, $value))
    {
      push(@updates, '  ' . $column->name_sql . " = $value");
    }
    else
    {
      push(@updates, '  ' . $column->name_sql . ' = ?');
      push(@bind, $value);
    }
  }

  my $i = 0;

  no warnings;
  return 
  (
    ($self->{'update_sql_with_inlining_start'} ||= 
     'UPDATE ' . $self->fq_table_sql . " SET \n") .
    join(",\n", @updates) . "\nWHERE " . 
    join(' AND ', map { $self->column($_)->name_sql . ' = ?' } @$key_columns),
    \@bind
  );
}

sub insert_sql
{
  my($self) = shift;

  no warnings;
  return $self->{'insert_sql'} ||= 
    'INSERT INTO ' . $self->fq_table_sql . "\n(\n" .
    join(",\n", map { "  $_" } $self->column_names_sql) .
    "\n)\nVALUES\n(\n" . join(",\n", map { "  ?" } $self->column_names) .
    "\n)";
}

sub insert_sql_with_inlining
{
  my($self, $obj) = @_;

  unless(@_ > 1)
  {
    Carp::croak 'Missing required object argument to ',
                __PACKAGE__, '::insert_sql_with_inlining()'
  }

  my $db = $obj->db or Carp::croak "Missing db";

  my @bind;
  my @places;

  foreach my $column ($self->columns)
  {
    my $method = $self->column_accessor_method_name($column->name);
    my $value  = $obj->$method();

    if($column->should_inline_value($db, $value))
    {
      push(@places, "  $value");
    }
    else
    {
      push(@places, "  ?");
      push(@bind, $value);
    }
  }

  return 
  (
    ($self->{'insert_sql_with_inlining_start'} ||=
    'INSERT INTO ' . $self->fq_table_sql . "\n(\n" .
    join(",\n", map { "  $_" } $self->column_names_sql) .
    "\n)\nVALUES\n(\n") . join(",\n", @places) . "\n)",
    \@bind
  );
}

sub delete_sql
{
  my($self) = shift;
  return $self->{'delete_sql'} ||= 
    'DELETE FROM ' . $self->fq_table_sql . ' WHERE ' .
    join(' AND ', map {  $self->column($_)->name_sql . ' = ?' } 
                  $self->primary_key_column_names);
}

sub _clear_table_generated_values
{
  my($self) = shift;

  $self->{'fq_table_sql'} = undef;
  $self->{'load_sql'}     = undef;
  $self->{'update_sql'}   = undef;
  $self->{'insert_sql'}   = undef;
  $self->{'delete_sql'}   = undef;
  $self->{'fq_primary_key_sequence_name'} = undef;
  $self->{'primary_key_sequence_name'} = undef;
}

sub _clear_column_generated_values
{
  my($self) = shift;

  $self->{'fq_table_sql'}        = undef;
  $self->{'column_names'}        = undef;
  $self->{'columns_names_sql'}   = undef;
  $self->{'column_names_string_sql'} = undef;
  $self->{'column_rw_method_names'} = undef;
  $self->{'column_accessor_method_names'} = undef;
  $self->{'column_mutator_method_names'} = undef;
  $self->{'method_columns'}      = undef;
  $self->{'column_accessor_method'} = undef;
  $self->{'column_mutator_method'} = undef;
  $self->{'column_rw_method'} = undef;
  $self->{'load_sql'}   = undef;
  $self->{'update_sql'} = undef;
  $self->{'update_sql_with_inlining_start'} = undef;
  $self->{'insert_sql'} = undef;
  $self->{'insert_sql_with_inlining_start'} = undef;
  $self->{'delete_sql'} = undef;
}

sub _clear_db_generated_values
{
  my($self) = shift;

  $self->{'column_names_string_sql'} = undef;
  $self->{'column_names_sql'} = undef;
}

sub method_name_is_reserved
{
  my($self, $name, $class) = @_;

  if(!defined $class && UNIVERSAL::isa($self, __PACKAGE__))
  {
    $class ||= $self->class or die "Missing class!";
  }

  Carp::confess "Missing method name argument in call to method_name_is_reserved()"
    unless(defined $name);

  if(index($name, PRIVATE_PREFIX) == 0)
  {
    return "The method prefix '", PRIVATE_PREFIX, "' is reserved."
  }
  elsif($name =~ /^(?:meta|dbh?|_?init_db|error|not_found|load|save|update|insert|delete|DESTROY)$/ ||
        ($class->isa('Rose::DB::Object::Cached') && $name =~ /^(?:remember|forget(?:_all)?)$/))
  {
    return "This method name is reserved for use by the $class API."
  }

  return 0;
}

sub method_name_from_column_name
{
  my($self, $column_name, $method_type) = @_;

  my $column = $self->column($column_name)
    or Carp::confess "No such column: $column_name";

  return $self->method_name_from_column($column, $method_type);
}

sub method_name_from_column
{
  my($self, $column, $method_type) = @_;

  my $method_name = 
    $column->method_name($method_type) ||
    $column->build_method_name_for_type($method_type);

  if(my $code = $self->column_name_to_method_name_mapper)
  {
    my $column_name = $column->name;
    local $_ = $method_name;
    $method_name = $code->($self, $column_name, $method_type, $method_name);

    unless(defined $method_name)
    {
      Carp::croak "column_name_to_method_name_mapper() returned undef ",
                  "for column name '$column_name' method type '$method_type'"
    }
  }

  return $method_name;
}

#
# Automatic metadata setup
#

our $AUTOLOAD;

sub DESTROY { }

sub AUTOLOAD
{
  if($AUTOLOAD =~ /::((?:auto_(?!helper)|(?:default_)?perl_)\w*)$/)
  {
    my $method = $1;
    my $self = shift;
    $self->init_auto_helper;

    unless($self->can($method))
    {
      Carp::croak "No such method '$method' in class ", ref($self);
    }

    return $self->$method(@_);
  }

  Carp::confess "No such method: $AUTOLOAD";
}

sub auto_helper_class 
{
  my($self) = shift;

  if(@_)
  {
    my $driver = shift;
    return $self->auto_helper_classes->{$driver} = shift  if(@_);
    return $self->auto_helper_classes->{$driver};
  }
  else
  {
    my $db = $self->db or die "Missing db";
    return $self->auto_helper_classes->{$db->driver};
  }
}

sub init_auto_helper
{
  my($self) = shift;

  unless($self->isa($self->auto_helper_class))
  {
    my $class = ref($self) || $self;

    eval 'use ' . $self->auto_helper_class;

    Carp::croak "Could not load ", $self->auto_helper_class, " - $@"  if($@);

    bless $self, $self->auto_helper_class;
  }

  return 1;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata - Database object metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata;

  $meta = Rose::DB::Object::Metadata->new(class => 'Product');
  # ...or...
  $meta = Rose::DB::Object::Metadata->for_class('Product');

  #
  # Auto-initialization
  #

  $meta->table('products');

  $meta->auto_initialize;

  #
  # ...or manual setup and initialization
  #

  $meta->columns
  (
    id          => { type => 'int', primary_key => 1 },
    name        => { type => 'varchar', length => 255 },
    description => { type => 'text' },
    category_id => { type => 'int' },

    status => 
    {
      type      => 'varchar', 
      check_in  => [ 'active', 'inactive' ],
      default   => 'inactive',
    },

    start_date  => { type => 'datetime' },
    end_date    => { type => 'datetime' },

    date_created  => { type => 'timestamp', default => 'now' },  
    last_modified => { type => 'timestamp', default => 'now' },
  );

  $meta->add_unique_key('name');

  $meta->foreign_keys
  (
    category =>
    {
      class       => 'Category',
      key_columns =>
      {
        category_id => 'id',
      }
    },
  );

  # This part cannot be done automatically
  $meta->add_relationship
  (
    prices =>
    {
      type       => 'one to many',
      class      => 'Price',
      column_map => { id => 'id_product' },
    },
  );

  ...

=head1 DESCRIPTION

L<Rose::DB::Object::Metadata> objects store information about a single table in a database: the name of the table, the names and types of columns, any foreign or unique keys, etc.  These metadata objects are also responsible for supplying information to, and creating object methods for, the L<Rose::DB::Object>-derived objects to which they belong.

L<Rose::DB::Object::Metadata> objects also store information about the L<Rose::DB::Object>s that front the database tables they describe.  What might normally be thought of as "class data" for the L<Rose::DB::Object> is stored in the metadata object instead, in order to keep the method namespace of the L<Rose::DB::Object>-derived class uncluttered.

L<Rose::DB::Object::Metadata> objects objects are per-class singletons; there is one L<Rose::DB::Object::Metadata> object for each L<Rose::DB::Object>-derived class.  Metadata objects are almost never explicitly instantiated.  Rather, there are automatically created and accessed through L<Rose::DB::Object>-derived objects' L<meta|Rose::DB::Object/meta> method.

Once created, metadata objects can be populated manually or automatically.  Both techniques are shown in the L<synopsis|/SYNOPSIS> above.  The automatic mode works by asking the database itself for the information.  There are some caveats to this approach.  See the L<auto-initialization|/"AUTO-INITIALIZATION"> section for more information.

L<Rose::DB::Object::Metadata> objects contain three categories of objects that are responsible for creating object methods in L<Rose::DB::Object>-derived classes: columns, foreign keys, and relationships.

Column objects are subclasses of L<Rose::DB::Object::Metadata::Column>.  They are intended to store as much information as possible about each column.  The particular class of the column object created for a database column is determined by a L<mapping table|/column_type_classes>.   The column class, in turn, is responsible for creating the accessor/mutator method(s) for the column.  When it creates these methods, the column class can use (or ignore) any information stored in the column object.

Foreign key objects are of the class L<Rose::DB::Object::Metadata::ForeignKey>.  They store information about columns that refer to columns in other tables that are fronted by their own L<Rose::DB::Object>-derived classes.  A foreign key object is responsible for creating accessor method(s) to fetch the foreign object from the foreign table.

Relationship objects are subclasses of L<Rose::DB::Object::Metadata::Relationship>.  They store information about a table's relationship to other tables that are fronted by their own L<Rose::DB::Object>-derived classes.  The particular class of the relationship object created for each relationship is determined by a L<mapping table|/relationship_type_classes>.   A relationship object is responsible for creating accessor method(s) to fetch the foreign objects from the foreign table.

=head1 AUTO-INITIALIZATION

Manual population of metadata objects can be tedious and repetitive.  Nearly all of the information stored in a L<Rose::DB::Object::Metadata> object exists in the database in some form.  It's reasonable to consider simply extracting this information from the database itself, rather than entering it all manually.  This automatic metadata extraction and subsequent L<Rose::DB::Object::Metadata> object population is called "auto-initialization."

The example of auto-initialization in the L<synopsis|/SYNOPSIS> above is the most succinct variant:

    $meta->auto_initialize;

As you can read in the documentation for the L<auto_initialize|/auto_initialize> method, that's shorthand for individually auto-initializing each part of the metadata object: columns, the primary key, unique keys, and foreign keys.  But this brevity comes at a price.  There are many caveats to auto-initialization.

=head2 Caveats

=head3 Start-Up Cost

In order to retrieve the information required for auto-initialization, a database connection must be opened and queries must be run.  Sometimes these queries include complex joins.  All of these queries must be successfully completed before the L<Rose::DB::Object>-derived objects that the L<Rose::DB::Object::Metadata> is associated with can be used.

In an environment like L<mod_perl>, server start-up time is precisely when you want to any expensive operations.  But in a command-line script or other short-lived process, the overhead of auto-initializing many metadata objects may become prohibitive.

Also, don't forget that auto-initialization requires a database connection.  L<Rose::DB::Object>-derived objects can sometimes be useful even without a database connection (e.g., to temporarily store information that will never go into the database, or to synthesize data using object methods that have no corresponding database column).  When using auto-initialization, this is not possible because the  L<Rose::DB::Object>-derived class won't even load if auto-initialization fails because it could not connect to the database.

=head3 Detail

First, auto-initialization cannot generate information that exists only in the mind of the programmer.  The most common example is a relationship between two database tables that is either ambiguous or totally unexpressed by the database itself.  

For example, if a foreign key constraint does not exist, the relationship between rows in two different tables cannot be extracted from the database, and therefore cannot be auto-initialized.

Similarly, in the L<synopsis|/SYNOPSIS> above, the "one to many" relationship between the C<Product> and C<Price> classes cannot be auto-initialized because it lacks an unambiguous analog within the database.  Even assuming that the "prices" table (fronted by the C<Price>) class has a foreign key that points to the "products" table, the lack of a corresponding foreign key in the "products" table that points back to the "prices" table does not necessarily mean that the relationship is "one product to many prices."  It could be that the relationship is really "one product to one price" and the foreign key constraint was omitted from the "products" table for performance reasons (to give just one example).

As it turns out, the relationship really is "one product to many prices", but this is something that only the programmer knows for sure.  Therefore, this information must be specified manually, as shown near the bottom of the L<synopsis|/SYNOPSIS>.

Even within the realm of information that, by all rights, should be available in the database, there are limitations.  Although there is a handy L<DBI> API for extracting metadata from databases, unfortunately, very few DBI drivers support it fully.  Some don't support it at all.  In almost all cases, some manual work is required to (often painfully) extract information from the database's "system tables" or "catalog."

More troublingly, databases do not always provide all the metadata that a human could extract from the series of SQL statement that created the table in the first place.  Sometimes, the information just isn't in the database to be extracted, having been lost in the process of table creation.  Here's just one example.  Consider this MySQL table definition:

    CREATE TABLE mytable
    (
      id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      code  CHAR(6),
      flag  BOOLEAN NOT NULL DEFAULT 1,
      bits  BIT(5) NOT NULL DEFAULT '00101',
      name  VARCHAR(64)
    );

Now look at the metadata that MySQL stores internally for this table:

    mysql> describe mytable;
    +-------+------------------+------+-----+---------+----------------+
    | Field | Type             | Null | Key | Default | Extra          |
    +-------+------------------+------+-----+---------+----------------+
    | id    | int(10) unsigned |      | PRI | NULL    | auto_increment |
    | code  | varchar(6)       | YES  |     | NULL    |                |
    | flag  | tinyint(1)       |      |     | 1       |                |
    | bits  | tinyint(1)       |      |     | 101     |                |
    | name  | varchar(64)      | YES  |     | NULL    |                |
    +-------+------------------+------+-----+---------+----------------+

Note the following divergences from the "CREATE TABLE" statement.

=over 4

=item * B<The "code" column has changed from CHAR(6) to VARCHAR(6).>  This is troublesome if you want the traditional semantics of a CHAR type, namely the padding with spaces of values that are less than the column length.

=item * B<The "flag" column has changed from BOOLEAN to TINYINT(1).>  The default accessor method created for boolean columns has value coercion and formatting properties that are important to this data type.  The default accessor created for integer columns lacks these constraints.  The metadata object has no way of knowing that "flag" was supposed to be a boolean column, and thus makes the wrong kind of accessor method.  It is thus possible to store, say, a value of "7" in the "flag" column.  Oops.

=item * B<The "bits" column has changed from BIT(5) to TINYINT(1).>  As in the case of the "flag" column above, this type change prevents the correct accessor method from being created.  The default bitfield accessor method auto-inflates column values into L<Bit::Vector> objects, which provide convenient methods for bit manipulation.  The default accessor created for integer columns does no such thing.

=back

Remember that the auto-initialization process can only consider the metadata actually stored in the database.  It has no access to the original "create table" statement.  Thus, the semantics implied by the original table definition are effectively lost.

Again, this is just one example of the kind of detail that can be lost in the process of converting your table definition into metadata that is stored in the database.  Admittedly, MySQL is perhaps the worst case-scenario, having a well-deserved reputation for disregarding the wishes of table definitions.  (The use of implicit default values for "NOT NULL" columns is yet another example.)

Thankfully, there is a solution to this dilemma.  Remember that auto-initialization is actually a multi-step process hiding behind that single call to the L<auto_initialize|/auto_initialize> method.  To correct the sins of the database, simply break the auto-initialization process into its components.  For example, here's how to correctly auto-initialize the "mytable" example above:

    # Make a first pass at column setup
    $meta->auto_init_columns;

    # Account for inaccuracies in DBD::mysql's column info by
    # replacing incorrect column definitions with new ones.

    # Fix CHAR(6) column that shows up as VARCHAR(6) 
    $meta->column(code => { type => 'char', length => 6 });

    # Fix BIT(5) column that shows up as TINYINT(1)
    $meta->column(bits => { type => 'bits', bits => 5, default => 101 });

    # Fix BOOLEAN column that shows up as TINYINT(1)
    $meta->column(flag => { type => 'boolean', default => 1 });

    # Do everything else
    $meta->auto_initialize;

Note that L<auto_initialize|/auto_initialize> was called at the end.  Without the C<replace_existing> parameter, this call will preserve any existing metadata, rather than overwriting it, so our "corrections" are safe.

=head3 Maintenance

The price of auto-initialization is eternal vigilance.  "What does that mean?  Isn't auto-initialization supposed to save time and effort?"  Well, yes, but at a cost.  In addition to the caveats described above, consider what happens when a table definition changes.

"Ah ha!" you say, "My existing class will automatically pick up the changes the next time it's loaded!  Auto-initialization at its finest!"  But is it?  What if you added a "NOT NULL" column with no default value?  Yes, your existing auto-initialized class will pick up the change, but your existing code will no longer be able to L<save|Rose::DB::Object/save> one these objects.  Or what if you're using MySQL and your newly added column is one of the types described above that requires manual tweaking in order to get the desired semantics.  Will you always remember to make this change?

Auto-initialization is not a panacea.  Every time you make a change to your database schema, you must also revisit each affected L<Rose::DB::Object>-derived class to at least consider whether or not the metadata needs to be corrected or updated.

The trade-off may be well worth it, but it's still something to think about.  There is, however, a hybrid solution that might be even better.  Continue on to the next section to learn more.

=head2 Code Generation

As described in the L<section above|/Caveats>, auto-initializing metadata at runtime by querying the database has many caveats.  An alternate approach is to query the database for metadata just once, and then generate the equivalent Perl code which can be pasted directly into the class definition in place of the call to L<auto_initialize|/auto_initialize>.

Like the auto-initialization process itself, perl code generation has a convenient wrapper method as well as separate methods for the individual parts.  All of the perl code generation methods begin with "perl_", and they support some rudimentary code formatting options to help the code conform to you preferred style.  Examples can be found with the documentation for each perl_* method.

This hybrid approach to metadata population strikes a good balance between upfront effort and ongoing maintenance.  Auto-generating the Perl code for the initial class definition saves a lot of tedious typing.  From that point on, manually correcting and maintaining the definition is a small price to pay for the decreased start-up cost, the ability to use the class in the absence of a database connection, and the piece of mind that comes from knowing that your class is stable, and won't change behind your back in response to an "action at a distance" (i.e., a database schema update).

=head1 CLASS METHODS

=over 4

=item B<column_type_class TYPE>

Given the column type string TYPE, return the name of the L<Rose::DB::Object::Metadata::Column>-derived class used to store metadata and create the accessor method(s) for columns of that type.

=item B<column_type_classes [MAP]>

Get or set the hash that maps column type strings to the names of the L<Rose::DB::Object::Metadata::Column>-derived classes used to store metadata  and create accessor method(s) for columns of that type.

This hash is class data.  If you want to modify it, I suggest making your own subclass of L<Rose::DB::Object::Metadata> and then setting that as the L<meta_class|Rose::DB::Object/meta_class> of your L<Rose::DB::Object> subclass.

If passed MAP (a list of type/class pairs or a reference to a hash of the same) then MAP replaces the current column type mapping.  Returns a list of type/class pairs (in list context) or a reference to the hash of type/class mappings (in scalar context).

The default mapping of type names to class names is:

  scalar    => Rose::DB::Object::Metadata::Column::Scalar

  char      => Rose::DB::Object::Metadata::Column::Character
  character => Rose::DB::Object::Metadata::Column::Character
  varchar   => Rose::DB::Object::Metadata::Column::Varchar
  string    => Rose::DB::Object::Metadata::Column::Varchar

  text      => Rose::DB::Object::Metadata::Column::Text
  blob      => Rose::DB::Object::Metadata::Column::Blob

  bits      => Rose::DB::Object::Metadata::Column::Bitfield
  bitfield  => Rose::DB::Object::Metadata::Column::Bitfield

  bool      => Rose::DB::Object::Metadata::Column::Boolean
  boolean   => Rose::DB::Object::Metadata::Column::Boolean

  int       => Rose::DB::Object::Metadata::Column::Integer
  integer   => Rose::DB::Object::Metadata::Column::Integer

  serial    => Rose::DB::Object::Metadata::Column::Serial

  num       => Rose::DB::Object::Metadata::Column::Numeric
  numeric   => Rose::DB::Object::Metadata::Column::Numeric
  decimal   => Rose::DB::Object::Metadata::Column::Numeric
  float     => Rose::DB::Object::Metadata::Column::Float

  date      => Rose::DB::Object::Metadata::Column::Date
  datetime  => Rose::DB::Object::Metadata::Column::Datetime
  timestamp => Rose::DB::Object::Metadata::Column::Timestamp

  'datetime year to fraction' => 
    Rose::DB::Object::Metadata::Column::DatetimeYearToFraction

  'datetime year to fraction(1)' =>
    Rose::DB::Object::Metadata::Column::DatetimeYearToFraction1

  'datetime year to fraction(2)' =>
    Rose::DB::Object::Metadata::Column::DatetimeYearToFraction2

  'datetime year to fraction(3)' =>
    Rose::DB::Object::Metadata::Column::DatetimeYearToFraction3

  'datetime year to fraction(4)' =>
    Rose::DB::Object::Metadata::Column::DatetimeYearToFraction4

  'datetime year to fraction(5)' =>
    Rose::DB::Object::Metadata::Column::DatetimeYearToFraction5

  'timestamp with time zone' =>
    Rose::DB::Object::Metadata::Column::Timestamp

  'timestamp without time zone' =>
    Rose::DB::Object::Metadata::Column::Timestamp

  'datetime year to second' =>
    Rose::DB::Object::Metadata::Column::DatetimeYearToSecond

  'datetime year to minute' =>
    Rose::DB::Object::Metadata::Column::DatetimeYearToMinute

  array     => Rose::DB::Object::Metadata::Column::Array
  set       => Rose::DB::Object::Metadata::Column::Set

  chkpass   => Rose::DB::Object::Metadata::Column::Pg::Chkpass

=item B<for_class CLASS>

Returns (or creates, if needed) the single L<Rose::DB::Object::Metadata> object associated with CLASS, where CLASS is the name of a L<Rose::DB::Object>-derived class.

=item B<init_column_name_to_method_name_mapper>

This class method should return a reference to a subroutine that maps column names to method names, or false if it does not want to do any custom mapping.  The default implementation returns zero (0).

If defined, the subroutine should take four arguments: the metadata object, the column name, the column method type, and the method name that would be used if the mapper subroutine did not exist.  It should return a method name.

=item B<relationship_type_class TYPE>

Given the relationship type string TYPE, return the name of the L<Rose::DB::Object::Metadata::Relationship>-derived class used to store metadata and create the accessor method(s) for relationships of that type.

=item B<relationship_type_classes [MAP]>

Get or set the hash that maps relationship type strings to the names of the L<Rose::DB::Object::Metadata::Relationship>-derived classes used to store metadata and create object methods fetch and/or manipulate objects from foreign tables.

This hash is class data.  If you want to modify it, I suggest making your own subclass of L<Rose::DB::Object::Metadata> and then setting that as the L<meta_class|Rose::DB::Object/meta_class> of your L<Rose::DB::Object> subclass.

If passed MAP (a list of type/class pairs or a reference to a hash of the same) then MAP replaces the current relationship type mapping.  Returns a list of type/class pairs (in list context) or a reference to the hash of type/class mappings (in scalar context).

The default mapping of type names to class names is:

  'one to one'   => Rose::DB::Object::Metadata::Relationship::OneToOne
  'one to many'  => Rose::DB::Object::Metadata::Relationship::OneToMany
  'many to one'  => Rose::DB::Object::Metadata::Relationship::ManyToOne
  'many to many' => Rose::DB::Object::Metadata::Relationship::ManyToMany

=back

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Returns (or creates, if needed) the single L<Rose::DB::Object::Metadata> associated with a particular L<Rose::DB::Object>-derived class, modifying or initializing it according to PARAMS, where PARAMS are name/value pairs.

Any object method is a valid parameter name, but PARAMS I<must> include a value for the C<class> parameter, since that's how L<Rose::DB::Object::Metadata> objects are mapped to their corresponding L<Rose::DB::Object>-derived class.

=back

=head1 OBJECT METHODS

=over 4

=item B<add_column ARGS>

This is an alias for the L<add_columns|/add_columns> method.

=item B<add_columns ARGS>

Add the columns specified by ARGS to the list of columns for the table.  Columns can be specified in ARGS in several ways.

If an argument is a subclass of L<Rose::DB::Object::Metadata::Column>, it is added as-is.

If an argument is a plain scalar, it is taken as the name of a scalar column.  A column object of the class returned by the method call C<$obj-E<gt>column_type_class('scalar')> is constructed and then added.

Otherwise, only name/value pairs are considered, where the name is taken as the column name and the value must be a reference to a hash.

If the hash contains the key "primary_key" with a true value, then the column is marked as a L<primary_key_member|Rose::DB::Object::Metadata::Column/is_primary_key_member> and the column name is added to the list of primary key columns by calling the L<add_primary_key_column|/add_primary_key_column> method with the column name as its argument.

If the hash contains the key "alias", then the value of that key is used as the alias for the column.  This is a shorthand equivalent to explicitly calling the L<alias_column|/alias_column> column method.

If the hash contains the key "methods", then its value must be a reference to an array or a reference to a hash.  The L<auto_method_types|Rose::DB::Object::Metadata::Column/auto_method_types> of the column are then set to the values of the referenced array, or the keys of the referenced hash.  The values of the referenced hash are used to set the L<method_name|Rose::DB::Object::Metadata::Column/method_name> for their corresponding method types.

If the hash contains the key "add_methods", then its value must be a reference to an array or a reference to a hash.  The values of the referenced array or the keys of the referenced hash are added to the column's L<auto_method_types|Rose::DB::Object::Metadata::Column/auto_method_types>.  The values of the referenced hash are used to set the L<method_name|Rose::DB::Object::Metadata::Column/method_name> for their corresponding method types.

If the "methods" and "add_methods" keys are both set, a fatal error will occur.

Then the L<column_type_class|/column_type_class> method is called with the value of the "type" hash key as its argument (or "scalar" if that key is missing), returning the name of a column class.  Finally, a new column object of that class is constructed and is passed all the remaining pairs in the hash reference, along with the name and type of the column.  That column object is then added to the list of columns.

This is done until there are no more arguments to be processed, or until an argument does not conform to one of the required formats, in which case a fatal error occurs.

Example:

    $meta->add_columns
    (
      # Add a scalar column
      'name', 

      # which is roughly equivalent to:
      #
      # $class = $meta->column_type_class('scalar');
      # $col = $class->new(name => 'name');
      # (then add $col to the list of columns)

      # Add by name/hashref pair with explicit method types
      age => { type => 'int', default => 5, methods => [ 'get', 'set' ] },

      # which is roughly equivalent to:
      #
      # $class = $meta->column_type_class('int');
      # $col = $class->new(name    => 'age',
      #                    type    => 'int', 
      #                    default => 5);
      # $col->auto_method_types('get', 'set');
      # (then add $col to the list of columns)

      # Add by name/hashref pair with additional method type and name
      size => { type => 'int', add_methods => { 'set' => 'set_my_size' } },

      # which is roughly equivalent to:
      #
      # $class = $meta->column_type_class('int');
      # $col = $class->new(name    => 'size',
      #                    type    => 'int',);
      # $col->add_auto_method_types('set');
      # $col->method_name(set => 'set_my_size');
      # (then add $col to the list of columns)

      # Add a column object directly
      Rose::DB::Object::Metadata::Column::Date->new(
        name => 'start_date'),
    );

=item B<add_foreign_keys ARGS>

Add foreign keys as specified by ARGS.  Each foreign key must have a L<name|Rose::DB::Object::Metadata::ForeignKey/name> that is unique among all other foreign keys in this L<class|/class>.

Foreign keys can be specified in ARGS in several ways.

If an argument is a L<Rose::DB::Object::Metadata::ForeignKey> object (or subclass thereof), it is added as-is.

Otherwise, only name/value pairs are considered, where the name is taken as the foreign key name and the value must be a reference to a hash.

If the hash contains the key "methods", then its value must be a reference to an array or a reference to a hash.  The L<auto_method_types|Rose::DB::Object::Metadata::ForeignKey/auto_method_types> of the foreign key are then set to the values of the referenced array, or the keys of the referenced hash.  The values of the referenced hash are used to set the L<method_name|Rose::DB::Object::Metadata::ForeignKey/method_name> for their corresponding method types.

If the hash contains the key "add_methods", then its value must be a reference to an array or a reference to a hash.  The values of the referenced array or the keys of the referenced hash are added to the foreign key's L<auto_method_types|Rose::DB::Object::Metadata::ForeignKey/auto_method_types>.  The values of the referenced hash are used to set the L<method_name|Rose::DB::Object::Metadata::ForeignKey/method_name> for their corresponding method types.

If the "methods" and "add_methods" keys are both set, a fatal error will occur.

A new L<Rose::DB::Object::Metadata::ForeignKey> object is constructed and is passed all the remaining pairs in the hash reference, along with the name of the foreign key as the value of the "name" parameter.  That foreign key object is then added to the list of foreign keys.

This is done until there are no more arguments to be processed, or until an argument does not conform to one of the required formats, in which case a fatal error occurs.

Example:

    $meta->add_foreign_keys
    (      
      # Add by name/hashref pair with explicit method type
      category => 
      {
        class       => 'Category', 
        key_columns => { category_id => 'id' },
        methods => [ 'get' ],
      },

      # which is roughly equivalent to:
      #
      # $fk = Rose::DB::Object::Metadata::ForeignKey->new(
      #         class       => 'Category', 
      #         key_columns => { category_id => 'id' },
      #         name        => 'category');
      # $fk->auto_method_types('get');
      # (then add $fk to the list of foreign keys)

      # Add by name/hashref pair with additional method type and name
      color => 
      {
        class       => 'Color', 
        key_columns => { color_id => 'id' },
        add_methods => { set => 'set_my_color' },
      },

      # which is roughly equivalent to:
      #
      # $fk = Rose::DB::Object::Metadata::ForeignKey->new(
      #         class       => 'Color', 
      #         key_columns => { color_id => 'id' },
      #         name        => 'color');
      # $fk->add_auto_method_types('set');
      # $fk->method_name(set => 'set_my_color');
      # (then add $fk to the list of foreign keys)

      # Add a foreign key object directly
      Rose::DB::Object::Metadata::ForeignKey->new(...),
    );

For each foreign key added, a corresponding relationship with the same name is added if it does not already exist.  The relationship type is determined by the value o fthe foreign key object's L<relationship|Rose::DB::Object::Metadata::ForeignKey/relationship_type> attribute.  The default is "many to one".  The class of the relationship is chosen by calling L<relationship_type_class|/relationship_type_class> with the relationship type as an argument.

=item B<add_primary_key_column COLUMN>

This method is an alias for L<add_primary_key_columns|/add_primary_key_columns>.

=item B<add_primary_key_columns COLUMNS>

Add COLUMNS to the list of columns that make up the primary key.  COLUMNS can be a list or reference to an array of column names.

=item B<add_relationship ARGS>

This is an alias for the L<add_relationships|/add_relationships> method.

=item B<add_relationships ARGS>

Add relationships as specified by ARGS.  Each relationship must have a L<name|Rose::DB::Object::Metadata::Relationship/name> that is unique among all other relationships in this L<class|/class>.

Relationships can be specified in ARGS in several ways.

If an argument is a subclass of L<Rose::DB::Object::Metadata::Relationship>, it is added as-is.

Otherwise, only name/value pairs are considered, where the name is taken as the relationship name and the value must be a reference to a hash.

If the hash contains the key "methods", then its value must be a reference to an array or a reference to a hash.  The L<auto_method_types|Rose::DB::Object::Metadata::Relationship/auto_method_types> of the relationship are then set to the values of the referenced array, or the keys of the referenced hash.  The values of the referenced hash are used to set the L<method_name|Rose::DB::Object::Metadata::Relationship/method_name> for their corresponding method types.

If the hash contains the key "add_methods", then its value must be a reference to an array or a reference to a hash.  The values of the referenced array or the keys of the referenced hash are added to the relationship's L<auto_method_types|Rose::DB::Object::Metadata::Relationship/auto_method_types>.  The values of the referenced hash are used to set the L<method_name|Rose::DB::Object::Metadata::Relationship/method_name> for their corresponding method types.

If the "methods" and "add_methods" keys are both set, a fatal error will occur.

Then the L<relationship_type_class|/relationship_type_class> method is called with the value of the C<type> hash key as its argument, returning the name of a relationship class.

Finally, a new relationship object of that class is constructed and is passed all the remaining pairs in the hash reference, along with the name and type of the relationship.  That relationship object is then added to the list of relationships.

This is done until there are no more arguments to be processed, or until an argument does not conform to one of the required formats, in which case a fatal error occurs.

Example:

    $meta->add_relationships
    (      
      # Add by name/hashref pair with explicit method type
      category => 
      {
        type       => 'many to one',
        class      => 'Category', 
        column_map => { category_id => 'id' },
        methods    => [ 'get' ],
      },

      # which is roughly equivalent to:
      #
      # $class = $meta->relationship_type_class('many to one');
      # $rel = $class->new(class      => 'Category', 
      #                    column_map => { category_id => 'id' },
      #                    name       => 'category');
      # $rel->auto_method_types('get');
      # (then add $rel to the list of relationships)

      # Add by name/hashref pair with additional method type and name
      color => 
      {
        type        => 'many to one',
        class       => 'Color', 
        column_map  => { color_id => 'id' },
        add_methods => { set => 'set_my_color' },
      },

      # which is roughly equivalent to:
      #
      # $class = $meta->relationship_type_class('many to one');
      # $rel = $class->new(class      => 'Color', 
      #                    column_map => { color_id => 'id' },
      #                    name       => 'color');
      # $rel->add_auto_method_types('set');
      # $fk->method_name(set => 'set_my_color');
      # (rel add $fk to the list of foreign keys)

      # Add a relationship object directly
      Rose::DB::Object::Metadata::Relationship::OneToOne->new(...),
    );

=item B<add_unique_key KEY>

This method is an alias for L<add_unique_key|/add_unique_key>.

=item B<add_unique_keys KEYS>

Add new unique keys specified by KEYS.  Unique keys can be specified in KEYS in two ways.

If an argument is a L<Rose::DB::Object::Metadata::UniqueKey> object (or subclass thereof), then its L<parent|Rose::DB::Object::Metadata::UniqueKey/parent> is set to the metadata object itself, and it is added.

Otherwise, an argument must be a reference to an array of column names that make up a unique key.  A new L<Rose::DB::Object::Metadata::UniqueKey> is created, with its L<parent|Rose::DB::Object::Metadata::UniqueKey/parent> set to the metadata object itself, and then the unique key object is added to this list of unique keys for this L<class|/class>.

=item B<alias_column NAME, ALIAS>

Set the L<alias|Rose::DB::Object::Metadata::Column/alias> for the column named NAME to ALIAS.  It is sometimes necessary to use an alias for a column because the column name conflicts with an existing L<Rose::DB::Object> method name.

For example, imagine a column named "save".  The L<Rose::DB::Object> API already defines a method named L<save|Rose::DB::Object/save>, so obviously that name can't be used for the accessor method for the "save" column.  To solve this, make an alias:

    $meta->alias_column(save => 'save_flag');

See the L<Rose::DB::Object> documentation or call the L<method_name_is_reserved|/method_name_is_reserved> method to determine if a method name is reserved.

=item B<allow_inline_column_values [BOOL]>

Get or set the boolean flag that indicates whether or not the associated L<Rose::DB::Object>-derived class should try to inline column values that L<DBI> does not handle correctly when they are bound to placeholders using L<bind_columns|DBI/bind_columns>.  The default value is false.

Enabling this flag reduces the performance of the L<update|Rose::DB::Object/update> and L<insert|Rose::DB::Object/insert> operations on the L<Rose::DB::Object>-derived object.  But it is sometimes necessary to enable the flag because some L<DBI> drivers do not (or cannot) always do the right thing when binding values to placeholders in SQL statements.  For example, consider the following SQL for the Informix database:

    CREATE TABLE test (d DATETIME YEAR TO SECOND);
    INSERT INTO test (d) VALUES (CURRENT);

This is valid Informix SQL and will insert a row with the current date and time into the "test" table. 

Now consider the following attempt to do the same thing using L<DBI> placeholders (assume the table was already created as per the CREATE TABLE statement above):

    $sth = $dbh->prepare('INSERT INTO test (d) VALUES (?)');
    $sth->execute('CURRENT'); # Error!

What you'll end up with is an error like this:

    DBD::Informix::st execute failed: SQL: -1262: Non-numeric 
    character in datetime or interval.

In other words, L<DBD::Informix> has tried to quote the string "CURRENT", which has special meaning to Informix only when it is not quoted. 

In order to make this work, the value "CURRENT" must be "inlined" rather than bound to a placeholder when it is the value of a "DATETIME YEAR TO SECOND" column in an Informix database.

=item B<cached_objects_expire_in [DURATION]>

This method is only applicable if this metadata object is associated with a L<Rose::DB::Object::Cached>-derived class.  It controls the expiration cached objects.

If called with no arguments, the cache expiration limit in seconds is returned.  

If passed a DURATION, the cache expiration is set.  Valid formats for DURATION are in the form "NUMBER UNIT" where NUMBER is a positive number and UNIT is one of the following:

    s sec secs second seconds
    m min mins minute minutes
    h hr hrs hour hours
    d day days
    w wk wks week weeks
    y yr yrs year years

All formats of the DURATION argument are converted to seconds.  Days are exactly 24 hours, weeks are 7 days, and years are 365 days.

If an object was read from the database the specified number of seconds ago or earlier, it is purged from the cache and reloaded from the database the next time it is loaded.

A L<cached_objects_expire_in|/cached_objects_expire_in> value of undef or zero means that nothing will ever expire from the object cache for the L<Rose::DB::Object::Cached>-derived class associated with this metadata object.  This is the default.

=item B<catalog [CATALOG]>

Get or set the database catalog name.  This attribute is not applicable to any of the supported databases, as far as I know.

=item B<class [CLASS]>

Get or set the L<Rose::DB::object>-derived class associated with this metadata object.  This is the class where the accessor methods for each column will be created (by L<make_methods|/make_methods>).

=item B<class_for PARAMS>

Returns the name of the L<Rose::DB::Object>-derived class associated with the C<catalog>, C<schema>, and C<table> specified by the name/value paris in PARAMS.  Catalog and/or schema maybe omitted if unknown or inapplicable, and the "best" match will be returned.  Returns undef if there is no class name registered under the specified PARAMS.

=item B<clear_object_cache>

Clear the memory cache for all objects of the L<Rose::DB::Object::Cached>-derived class associated with this metadata object.

=item B<column NAME [, COLUMN | HASHREF]>

Get or set the column named NAME.  If just NAME is passed, the L<Rose::DB::Object::Metadata::Column>-derived column object for the column of that name is returned.  If no such column exists, undef is returned.

If both NAME and COLUMN are passed, then COLUMN must be a L<Rose::DB::Object::Metadata::Column>-derived object.  COLUMN has its L<name|Rose::DB::Object::Metadata::Column/name> set to NAME, and is then stored as the column metadata object for NAME, replacing any existing column.

If both NAME and HASHREF are passed, then the combination of NAME and HASHREF must form a name/value pair suitable for passing to the L<add_columns|/add_columns> method.  The new column specified by NAME and HASHREF replaces any existing column.

=item B<columns [ARGS]>

Get or set the full list of columns.  If ARGS are passed, the column list is cleared and then ARGS are passed to the L<add_columns|/add_columns> method.

Returns a list of column objects in list context, or a reference to an array of column objects in scalar context.

=item B<column_accessor_method_name NAME>

Returns the name of the "get" method for the column named NAME.  This is just a shortcut for C<$meta->column(NAME)-E<gt>accessor_method_name>.

=item B<column_accessor_method_names>

Returns a list (in list context) or a reference to the array (in scalar context) of the names of the "set" methods for all the columns, in the order that the columns are returned by L<column_names|/column_names>.

=item B<column_aliases [MAP]>

Get or set the hash that maps column names to their aliases.  If passed MAP (a list of name/value pairs or a reference to a hash) then MAP replaces the current alias mapping.  Returns a reference to the hash that maps column names to their aliases.

Note that modifying this map has no effect if L<initialize|/initialize>, L<make_methods|/make_methods>, or L<make_column_methods|/make_column_methods> has already been called for the current L<class|/class>.

=item B<column_mutator_method_name NAME>

Returns the name of the "set" method for the column named NAME.  This is just a shortcut for C<$meta->column(NAME)-E<gt>mutator_method_name>.

=item B<column_mutator_method_names>

Returns a list (in list context) or a reference to the array (in scalar context) of the names of the "set" methods for all the columns, in the order that the columns are returned by L<column_names|/column_names>.

=item B<column_names>

Returns a list (in list context) or a reference to an array (in scalar context) of column names.

=item B<column_name_to_method_name_mapper [CODEREF]>

Get or set the code reference to the subroutine used to map column names to  method names.  If undefined, then the L<init_column_name_to_method_name_mapper|/init_column_name_to_method_name_mapper> class method is called in order to initialize it.  If still undefined or false, then the "default" method name is used.

If defined, the subroutine should take four arguments: the metadata object, the column name, the column method type, and the method name that would be used if the mapper subroutine did not exist.  It should return a method name.

=item B<column_rw_method_name NAME>

Returns the name of the "get_set" method for the column named NAME.  This is just a shortcut for C<$meta->column(NAME)-E<gt>rw_method_name>.

=item B<column_rw_method_names>

Returns a list (in list context) or a reference to the array (in scalar context) of the names of the "get_set" methods for all the columns, in the order that the columns are returned by L<column_names|/column_names>.

=item B<db>

Returns the L<Rose::DB>-derived object associated with this metadata object's L<class|/class>.  A fatal error will occur if L<class|/class> is undefined or if the L<Rose::DB> object could not be created.

=item B<delete_column NAME>

Delete the column named NAME.

=item B<delete_columns>

Delete all of the columns.

=item B<delete_column_type_class TYPE>

Delete the type/class mapping entry for the column type TYPE.

=item B<delete_relationship NAME>

Delete the relationship named NAME.

=item B<delete_relationships>

Delete all of the relationships.

=item B<delete_relationship_type_class TYPE>

Delete the type/class mapping entry for the relationship type TYPE.

=item B<delete_unique_keys>

Delete all of the unique key definitions.

=item B<error_mode [MODE]>

Get or set the error mode of the L<Rose::DB::Object> that fronts the table described by this L<Rose::DB::Object::Metadata> object.  If the error mode is false, then it defaults to the return value of the C<init_error_mode> method, which is "fatal" by default.

The error mode determines what happens when a L<Rose::DB::Object> method encounters an error.  The "return" error mode causes the methods to behave as described in the L<Rose::DB::Object> documentation.  All other error modes cause an action to be performed before (possibly) returning as per the documentation (depending on whether or not the "action" is some variation on "throw an exception.")

Valid values of MODE are:

=over 4

=item carp

Call L<Carp::carp|Carp/carp> with the value of the object L<error|Rose::DB::Object/error> as an argument.

=item cluck

Call L<Carp::cluck|Carp/cluck> with the value of the object L<error|Rose::DB::Object/error> as an argument.

=item confess

Call L<Carp::confess|Carp/confess> with the value of the object L<error|Rose::DB::Object/error> as an argument.

=item croak

Call L<Carp::croak|Carp/croak> with the value of the object L<error|Rose::DB::Object/error> as an argument.

=item fatal

An alias for the "croak" mode.

=item return

Return a value that indicates that an error has occurred, as described in the L<documentation|Rose::DB::Object/"OBJECT METHODS"> for each method.

=back

In all cases, the object's L<error|Rose::DB::Object/error> attribute will also contain the error message.

=item B<foreign_key NAME [, FOREIGNKEY | HASHREF ]>

Get or set the foreign key named NAME.  NAME should be the name of the thing being referenced by the foreign key, I<not> the name of any of the columns that make up the foreign key.  If called with just a NAME argument, the foreign key stored under that name is returned.  Undef is returned if there is no such foreign key.

If both NAME and FOREIGNKEY are passed, then FOREIGNKEY must be a L<Rose::DB::Object::Metadata::ForeignKey>-derived object.  FOREIGNKEY has its L<name|Rose::DB::Object::Metadata::ForeignKey/name> set to NAME, and is then stored, replacing any existing foreign key with the same name.

If both NAME and HASHREF are passed, then the combination of NAME and HASHREF must form a name/value pair suitable for passing to the L<add_foreign_keys|/add_foreign_keys> method.  The new foreign key specified by NAME and HASHREF replaces any existing foreign key with the same name.

=item B<foreign_keys [ARGS]>

Get or set the full list of foreign keys.  If ARGS are passed, the foreign key list is cleared and then ARGS are passed to the L<add_foreign_keys|/add_foreign_keys> method.

Returns a list of foreign key objects in list context, or a reference to an array of foreign key objects in scalar context.

=item B<fq_table_sql>

Returns the fully-qualified table name in a form suitable for use in an SQL statement.

=item B<generate_primary_key_value DB>

This method is an alias for L<generate_primary_key_values|/generate_primary_key_values>.

=item B<generate_primary_key_values DB>

Given the L<Rose::DB>-derived object DB, generate a new primary key column value for the table described by this metadata object.  If a L<primary_key_generator|/primary_key_generator> is defined, it will be called (passed this metadata object and the DB) and its value returned.

If no L<primary_key_generator|/primary_key_generator> is defined, a new primary key value will be generated, if possible, using the native facilities of the current database.  Note that this may not be possible for databases that auto-generate such values only after an insertion.  In that case, undef will be returned.

=item B<initialize [ARGS]>

Initialize the L<Rose::DB::object>-derived class associated with this metadata object by creating accessor methods for each column and foreign key.  The L<table|/table> name and the L<primary_key_columns|/primary_key_columns> must be defined or a fatal error will occur.

If any column name in the primary key or any of the unique keys does not exist in the list of L<columns|/columns>, then that primary or unique key is deleted.  (As per the above, this will trigger a fatal error if any column in the primary key is not in the column list.)

ARGS, if any, are passed to the call to L<make_methods|/make_methods> that actually creates the methods.

=item B<make_methods [ARGS]>

Create object methods in L<class|/class> for each L<column|/columns>, L<foreign key|/foreign_keys>, and L<relationship|/relationship>.  This is done by calling L<make_column_methods|/make_column_methods>, L<make_foreign_key_methods|/make_foreign_key_methods>, and L<make_relationship_methods|/make_relationship_methods>, in that order.

ARGS are name/value pairs which are passed on to the other C<make_*_methods> calls.  They are all optional.  Valid ARGS are:

=over 4

=item * C<preserve_existing>

If set to a true value, a method will not be created if there is already an existing method with the same named.

=item * C<replace_existing>

If set to a true value, override any existing method with the same name.

=back

In the absence of one of these parameters, any method name that conflicts with an existing method name will cause a fatal error.

=item B<make_column_methods [ARGS]>

Create accessor/mutator methods in L<class|/class> for each L<column|/columns>.  ARGS are name/value pairs, and are all optional.  Valid ARGS are:

=over 4

=item * C<preserve_existing>

If set to a true value, a method will not be created if there is already an existing method with the same named.

=item * C<replace_existing>

If set to a true value, override any existing method with the same name.

=back

For each L<auto_method_type|Rose::DB::Object::Metadata::Column/auto_method_types> in each column, the method name is determined by passing the column name and the method type to L<method_name_from_column_name|/method_name_from_column_name>.  If the resulting method name is reserved (according to L<method_name_is_reserved|/method_name_is_reserved>, a fatal error will occur.  The object methods for each column are created by calling the column object's L<make_methods|Rose::DB::Object::Metadata::Column/make_methods> method.

=item B<make_foreign_key_methods [ARGS]>

Create object methods in L<class|/class> for each L<foreign key|/foreign_keys>.  ARGS are name/value pairs, and are all optional.  Valid ARGS are:

=over 4

=item * C<preserve_existing>

If set to a true value, a method will not be created if there is already an existing method with the same named.

=item * C<replace_existing>

If set to a true value, override any existing method with the same name.

=back

For each L<auto_method_type|Rose::DB::Object::Metadata::ForeignKey/auto_method_types> in each foreign key, the method name is determined by passing the method type to the L<method_name|Rose::DB::Object::Metadata::ForeignKey/method_name> method of the foreign key object, or the L<build_method_name_for_type|Rose::DB::Object::Metadata::ForeignKey/build_method_name_for_type> method if the L<method_name|Rose::DB::Object::Metadata::ForeignKey/method_name> call returns a false value.  If the method name is reserved (according to L<method_name_is_reserved|/method_name_is_reserved>), a fatal error will occur.  The object methods for each foreign key are created by calling the foreign key  object's L<make_methods|Rose::DB::Object::Metadata::ForeignKey/make_methods> method.

Foreign keys and relationships with the L<type|Rose::DB::Object::Metadata::Relationship/type> "one to one" or "many to one" both encapsulate essentially the same information.  They are kept in sync when this method is called by setting the L<foreign_key|Rose::DB::Object::Metadata::Relationship::ManyToOne/foreign_key> attribute of each "L<one to one|Rose::DB::Object::Metadata::Relationship::OneToOne>" or "L<many to one|Rose::DB::Object::Metadata::Relationship::ManyToOne>" relationship object to be the corresponding foreign key object.

=item B<make_relationship_methods [ARGS]>

Create object methods in L<class|/class> for each L<relationship|/relationships>.  ARGS are name/value pairs, and are all optional.  Valid ARGS are:

=over 4

=item * C<preserve_existing>

If set to a true value, a method will not be created if there is already an existing method with the same named.

=item * C<replace_existing>

If set to a true value, override any existing method with the same name.

=back

For each L<auto_method_type|Rose::DB::Object::Metadata::Relationship/auto_method_types> in each relationship, the method name is determined by passing the method type to the L<method_name|Rose::DB::Object::Metadata::Relationship/method_name> method of the relationship object, or the L<build_method_name_for_type|Rose::DB::Object::Metadata::Relationship/build_method_name_for_type> method if the L<method_name|Rose::DB::Object::Metadata::Relationship/method_name> call returns a false value.  If the method name is reserved (according to L<method_name_is_reserved|/method_name_is_reserved>), a fatal error will occur.  The object methods for each relationship are created by calling the relationship  object's L<make_methods|Rose::DB::Object::Metadata::Relationship/make_methods> method.

Foreign keys and relationships with the L<type|Rose::DB::Object::Metadata::Relationship/type> "one to one" or "many to one" both encapsulate essentially the same information.  They are kept in sync when this method is called by setting the L<foreign_key|Rose::DB::Object::Metadata::Relationship::ManyToOne/foreign_key> attribute of each "L<one to one|Rose::DB::Object::Metadata::Relationship::OneToOne>" or "L<many to one|Rose::DB::Object::Metadata::Relationship::ManyToOne>" relationship object to be the corresponding foreign key object.

If a relationship corresponds exactly to a foreign key, and that foreign key already made an object method, then the relationship is not asked to make its own method.

=item B<method_column METHOD>

Returns the name of the column manipulated by the method named METHOD.

=item B<method_name_from_column_name NAME, TYPE>

Looks up the column named NAME and calls L<method_name_from_column|/method_name_from_column> with the column and TYPE as argument.  If no such column exists, a fatal error will occur.

=item B<method_name_from_column COLUMN, TYPE>

Given the column object COLUMN and the method type TYPE, returns the corresponding method name that would be generated for it, either via the default rules or through a custom-defined L<column_name_to_method_name_mapper|/column_name_to_method_name_mapper>.

=item B<method_name_is_reserved NAME, CLASS>

Given the method name NAME and the class name CLASS, returns true if the method name is reserved (i.e., is used by the CLASS API), false otherwise.

=item B<primary_key [PK]>

Get or set the L<Rose::DB::Object::Metadata::PrimaryKey> object that stores the list of column names that make up the primary key for this table.

=item B<primary_key_columns [COLUMNS]>

Get or set the list of of columns that make up the primary key.  COLUMNS should be a list of column names or L<Rose::DB::Object::Metadata::Column>-derived objects.

Returns all of the columns that make up the primary key.  Each column is a L<Rose::DB::Object::Metadata::Column>-derived column object if a L<column|/column> object with the same name exists, or just the column name otherwise.  In scalar context, a reference to an array of columns is returned.  In list context, a list is returned.

This method is just a shortcut for the code:

    $meta->primary_key->columns(...);

See the L<primary_key|/primary_key> method and the L<Rose::DB::Object::Metadata::PrimaryKey> class for more information.

=item B<primary_key_column_names [NAMES]>

Get or set the names of the columns that make up the table's primary key.  NAMES should be a list or reference to an array of column names.

Returns the list of column names (in list context) or a reference to the array of column names (in scalar context).

This method is just a shortcut for the code:

    $meta->primary_key->column_names(...);

See the L<primary_key|/primary_key> method and the L<Rose::DB::Object::Metadata::PrimaryKey> class for more information.

=item B<primary_key_generator [CODEREF]>

Get or set the subroutine used to generate new primary key values for the primary key columns of this table.  The subroutine will be passed two arguments: the current metadata object and the L<Rose::DB>-derived object that points to the current database.

The subroutine is expected to return a list of values, one for each primary key column.  The values must be in the same order as the corresponding columns returned by L<primary_key_columns|/primary_key_columns>. (i.e., the first value belongs to the first column returned by L<primary_key_columns|/primary_key_columns>, the second value belongs to the second column, and so on.)

=item B<primary_key_sequence_name [NAME]>

Get or set the name of the sequence used to populate the primary key column.  This method is only applicable to single-column primary keys.  Multi-column keys must set a custom L<primary_key_generator|/primary_key_generator>.

If you do not set this value, it will be derived for you based on the name of the first primary key column.  In the common case, you do not need to be concerned about this method.  If you are using the built-in SERIAL or AUTO_INCREMENT type in your database for your single-column primary key, everything should just work.

=item B<relationship NAME [, RELATIONSHIP | HASHREF]>

Get or set the relationship named NAME.  If just NAME is passed, the L<Rose::DB::Object::Metadata::Relationship>-derived relationship object for that NAME is returned.  If no such relationship exists, undef is returned.

If both NAME and RELATIONSHIP are passed, then RELATIONSHIP must be a L<Rose::DB::Object::Metadata::Relationship>-derived object.  RELATIONSHIP has its L<name|Rose::DB::Object::Metadata::Relationship/name> set to NAME, and is then stored as the relationship metadata object for NAME, replacing any existing relationship.

If both NAME and HASHREF are passed, then the combination of NAME and HASHREF must form a name/value pair suitable for passing to the L<add_relationships|/add_relationships> method.  The new relationship specified by NAME and HASHREF replaces any existing relationship.

=item B<relationships [ARGS]>

Get or set the full list of relationships.  If ARGS are passed, the relationship list is cleared and then ARGS are passed to the L<add_relationships|/add_relationships> method.

Returns a list of relationship objects in list context, or a reference to an array of relationship objects in scalar context.

=item B<schema [SCHEMA]>

Get or set the database schema name.  This attribute is only applicable to PostgreSQL databases.

=item B<table [TABLE]>

Get or set the name of the database table.  The table name should not include any sort of prefix to indicate the L<schema|/schema> or L<catalog|/catalog>; there are separate attributes for those values.

=item B<unique_keys KEYS>

Get or set the list of unique keys for this table.  If KEYS is passed, any existing keys will be deleted and KEYS will be passed to the L<add_unique_keys|/add_unique_keys> method.

Returns the list (in list context) or reference to an array (in scalar context) of L<Rose::DB::Object::Metadata::UniqueKey> objects.

=item B<unique_keys_column_names>

Returns a list (in list context) or a reference to an array (in scalar context) or references to arrays of the column names that make up each unique key.  That is:

    # Example of a scalar context return value
    [ [ 'id', 'name' ], [ 'code' ] ]

    # Example of a list context return value
    ([ 'id', 'name' ], [ 'code' ])

=back

=head1 AUTO-INITIALIZATION METHODS

These methods are associated with the L<auto-initialization|/"AUTO-INITIALIZATION"> process.  Calling any of them will cause the auto-initialization code to be loaded, which costs memory.  This should be considered an implementation detail for now.

Regardless of the implementation details, you should still avoid calling any of these methods unless you plan to do some auto-initialization.  No matter how generic they may seem (e.g., L<default_perl_indent|/default_perl_indent>), rest assured that none of these methods are remotely useful I<unless> you are doing auto-initialization.

=head2 CLASS METHODS

=over 4

=item B<default_perl_braces [STYLE]>

Get or set the default brace style used in the Perl code generated by the perl_* object methods.  STYLE must be either "k&r" or "bsd".  The default value is "k&r".

=item B<default_perl_indent [INT]>

Get or set the default integer number of spaces used for each level of indenting in the Perl code generated by the perl_* object methods.  The default value is 4.

=item B<default_perl_unique_key_style [STYLE]>

Get or set the default style of the unique key initialization used in the Perl code generated by the L<perl_unique_keys_definition|/perl_unique_keys_definition> method.  STYLE must be "array" or "object".  The default value is "array".  See the L<perl_unique_keys_definition|/perl_unique_keys_definition> method for examples of the two styles.

=back

=head2 OBJECT METHODS

=over 4

=item B<auto_generate_columns>

Auto-generate L<Rose::DB::Object::Metadata::Column>-derived objects for each column in the table.  Note that this method does not modify the metadata object's list of L<columns|/columns>.  It simply returns a list of column objects.    Calling this method in void context will cause a fatal error.

Returns a list of column objects (in list context) or a reference to a hash of column objects, keyed by column name (in scalar context).  The hash reference return value is intended to allow easy modification of the auto-generated column objects.  Example:

    $columns = $meta->auto_generate_columns; # hash ref return value

    # Make some changes    
    $columns->{'name'}->length(10); # set different length
    $columns->{'age'}->default(5);  # set different default
    ...

    # Finally, set the column list
    $meta->columns(values %$columns);

If you do not want to modify the auto-generated columns, you should use the L<auto_init_columns|/auto_init_columns> method instead.

A fatal error will occur unless at least one column was auto-generated.

=item B<auto_generate_foreign_keys [PARAMS]>

Auto-generate L<Rose::DB::Object::Metadata::ForeignKey> objects for each foreign key in the table.  Note that this method does not modify the metadata object's list of L<foreign_keys|/foreign_keys>.  It simply returns a list of foreign key objects.  Calling this method in void context will cause a fatal error.  A warning will be issued if a foreign key could not be generated because no L<Rose::DB::Object>-derived class was found for the foreign table.

PARAMS are optional name/value pairs.  If a C<no_warnings> parameter is passed with a true value, then the warning described above will not be issued.

Returns a list of foreign key objects (in list context) or a reference to an array of foreign key objects (in scalar context).

If you do not want to inspect or modify the auto-generated foreign keys, but just want them to populate the metadata object's L<foreign_keys|/foreign_keys> list, you should use the L<auto_init_foreign_keys|/auto_init_foreign_keys> method instead.

B<Note:> This method works with MySQL only when using the InnoDB storage type.

=item B<auto_generate_unique_keys>

Auto-generate L<Rose::DB::Object::Metadata::UniqueKey> objects for each unique key in the table.  Note that this method does not modify the metadata object's list of L<unique_keys|/unique_keys>.  It simply returns a list of unique key objects.  Calling this method in void context will cause a fatal error.

Returns a list of unique key objects (in list context) or a reference to an array of unique key objects (in scalar context).

If you do not want to inspect or modify the auto-generated unique keys, but just want them to populate the metadata object's L<unique_keys|/unique_keys> list, you should use the L<auto_init_unique_keys|/auto_init_unique_keys> method instead.

=item B<auto_retrieve_primary_key_column_names>

Returns a list (in list context) or a reference to an array (in scalar context) of the names of the columns that make up the primary key for this table.  Note that this method does not modify the metadata object's L<primary_key|/primary_key>.  It simply returns a list of column names.  Calling this method in void context will cause a fatal error.

This method is rarely called explicitly.  Usually, you will use the L<auto_init_primary_key_columns|/auto_init_primary_key_columns> method instead.

A fatal error will occur unless at least one column name can be retrieved.

(This method uses the word "retrieve" instead of "generate" like its sibling methods above because it does not generate objects; it simply returns column names.)

=item B<auto_initialize [PARAMS]>

Auto-initialize the entire metadata object.  This is a wrapper for the individual "auto_init_*" methods, and is roughly equivalent to this:

  $meta->auto_init_columns(...);
  $meta->auto_init_primary_key_columns;
  $meta->auto_init_unique_keys(...);
  $meta->auto_init_foreign_keys(...);
  $meta->initialize;

PARAMS are optional name/value pairs.  If a C<replace_existing> parameter is passed with a true value, then the auto-generated columns, unique keys, and foreign keys entirely replace any existing columns, unique keys, and foreign keys, respectively.

During initialization, if one of the columns has a method name that clashes with a L<reserved method name|Rose::DB::Object/"RESERVED METHODS">, then the L<column_alias_generator|/column_alias_generator> will be called to remedy the situation by aliasing the column.  If the name still conflicts, then a fatal error will occur.

A fatal error will occur if auto-initialization fails.

=item B<auto_init_columns [PARAMS]>

Auto-generate L<Rose::DB::Object::Metadata::Column> objects for this table, then populate the list of L<columns|/columns>.  PARAMS are optional name/value pairs.  If a C<replace_existing> parameter is passed with a true value, then the auto-generated columns replace any existing columns.  Otherwise, any existing columns are left as-is.

=item B<auto_init_foreign_keys [PARAMS]>

Auto-generate L<Rose::DB::Object::Metadata::ForeignKey> objects for this table, then populate the list of L<foreign_keys|/foreign_keys>.  PARAMS are optional name/value pairs.  If a C<replace_existing> parameter is passed with a true value, then the auto-generated foreign keys replace any existing foreign keys.  Otherwise, any existing foreign keys are left as-is.

B<PLEASE NOTE:> In order for this method to work correctly, the L<Rose::DB::Object>-derived classes for all referenced tables must be loaded I<before> this method is called on behalf of the referring class.

B<Note:> This method works with MySQL only when using the InnoDB storage type.

=item B<auto_init_primary_key_columns>

Auto-retrieve the names of the columns that make up the primary key for this table, then populate the list of L<primary_key_column_names|/primary_key_column_names>.  A fatal error will occur unless at least one primary key column name could be retrieved.

=item B<auto_init_unique_keys [PARAMS]>

Auto-generate L<Rose::DB::Object::Metadata::UniqueKey> objects for this table, then populate the list of L<unique_keys|/unique_keys>.  PARAMS are name/value pairs.  If a C<replace_existing> parameter is passed with a true value, then the auto-generated unique keys replace any existing unique keys.  Otherwise, any existing unique keys are left as-is.

=item B<column_alias_generator [CODEREF]>

Get or set the code reference to the subroutine used to alias columns have, or would generate, one or more method names that clash with L<reserved method names|Rose::DB::Object/"RESERVED METHODS">.

The subroutine should take two arguments: the metadata object and the column name.  The C<$_> variable will also be set to the column name at the time of the call.  The subroutine should return an L<alias|Rose::DB::Object::Metadata::Column/alias> for the column.

The default column alias generator simply appends the string "_col" to the end of the column name and returns that as the alias.

=item B<foreign_key_name_generator [CODEREF]>

Get or set the code reference to the subroutine used to generate L<foreign key|Rose::DB::Object::Metadata::ForeignKey> names.  The subroutine should take two arguments: a metadata object and a L<Rose::DB::Object::Metadata::ForeignKey> object.  It should return a name for the foreign key.

Each foreign key must have a name that is unique within the class.  By default, this name will also be the name of the method generated to access the object referred to by the foreign key, so it must be unique among method names in the class as well.

The default foreign key name generator uses the following algorithm:

If the foreign key has only one column, and if the name of that column ends with an optional underscore and the name of the referenced column, then that part of the column name is removed and the remaining string is used as the foreign key name.  For example, given the following tables:

    CREATE TABLE categories
    (
      id  SERIAL PRIMARY KEY,
      ...
    );

    CREATE TABLE products
    (
      category_id  INT REFERENCES categories (id),
      ...
    );

The foreign key name would be "category", which is the name of the referring column ("category_id") with an underscore and the name of the referenced column ("_id") removed from the end of it.

If the foreign key has only one column, but it does not meet the criteria described above, then "_object" is appended to the name of the referring column and the resulting string is used as the foreign key name.

If the foreign key has more than one column, then the foreign key name is generated by replacing double colons and case-transitions in the referenced class name with underscores, and then converting to lowercase.  For example, if the referenced table is fronted by the class My::TableOfStuff, then the generated foreign key name would be "my_table_of_stuff".

In all of the scenarios above, if the generated foreign key name is still not unique within the class, then a number is appended to the end of the name.  That number is incremented until the name is unique.

In practice, rather than setting a custom foreign key name generator, it's usually easier to simply set the foreign key name(s) manually after auto-initializing the foreign keys (but I<before> calling L<initialize|/initialize> or L<auto_initialize|/auto_initialize>, of course).

=item B<perl_class_definition [PARAMS]>

Auto-initialize the columns, primary key, foreign keys, and unique keys, then return the Perl source code for a complete L<Rose::DB::Object>-derived class definition.  PARAMS are optional name/value pairs that may include the following:

=over 4

=item * braces STYLE

The brace style to use in the generated Perl code.  STYLE must be either "k&r" or "bsd".  The default value is determined by the return value of the L<default_perl_braces|/default_perl_braces> class method.

=item * indent INT

The integer number of spaces to use for each level of indenting in the generated Perl code.  The default value is determined by the return value of the L<default_perl_indent|/default_perl_indent> class method.

=item * isa CLASSES

The list of base classes to use in the generated class definition.  CLASSES should be a single class name, or a reference to an array of class names.  The default base class is L<Rose::DB::Object>.

=back

This method is simply a wrapper (with some glue) for the following methods: L<perl_columns_definition|/perl_columns_definition>, L<perl_primary_key_columns_definition|/perl_primary_key_columns_definition>, L<perl_unique_keys_definition|/perl_unique_keys_definition>, and L<perl_foreign_keys_definition|/perl_foreign_keys_definition>.  The "braces" and "indent" parameters are passed on to these other methods.

Here's a complete example, which also serves as an example of the individual "perl_*" methods that this method wraps.  First, the table definitions.

    CREATE TABLE categories
    (
      id    SERIAL PRIMARY KEY,
      name  VARCHAR(32)
    );

    CREATE TABLE codes
    (
      k1    INT NOT NULL,
      k2    INT NOT NULL,
      k3    INT NOT NULL,
      name  VARCHAR(32),

      PRIMARY KEY(k1, k2, k3)
    );

    CREATE TABLE products
    (
      id             SERIAL PRIMARY KEY,
      name           VARCHAR(32) NOT NULL,
      flag           BOOLEAN NOT NULL DEFAULT 't',
      status         VARCHAR(32) DEFAULT 'active',
      category_id    INT REFERENCES categories (id),
      fk1            INT,
      fk2            INT,
      fk3            INT,
      last_modified  TIMESTAMP,
      date_created   TIMESTAMP,

      FOREIGN KEY (fk1, fk2, fk3) REFERENCES codes (k1, k2, k3)
    );

We'll auto-initialize the first two classes so that we can skip right to generating the Perl code for the third class, which references them.

    package Category;
    our @ISA = qw(Rose::DB::Object);
    Category->meta->table('categories');
    Category->meta->auto_initialize;

    package Code;
    our @ISA = qw(Rose::DB::Object);
    Code->meta->table('codes');
    Code->meta->auto_initialize;

Finally, setup the last class and generate the Perl code.

    package Product;
    our @ISA = qw(Rose::DB::Object);
    my $meta = Product->meta;
    $meta->table('products');

    print $meta->perl_class_definition(braces => 'bsd', indent => 2);

The output looks like this:

 package Product;

 use strict;

 use Rose::DB::Object
 our @ISA = qw(Rose::DB::Object);

 __PACKAGE__->meta->table('products');

 __PACKAGE__->meta->columns
 (
   category_id   => { type => 'integer' },
   date_created  => { type => 'timestamp' },
   fk1           => { type => 'integer' },
   fk2           => { type => 'integer' },
   fk3           => { type => 'integer' },
   flag          => { type => 'boolean', default => 'true', not_null => 1 },
   id            => { type => 'integer', not_null => 1 },
   last_modified => { type => 'timestamp' },
   name          => { type => 'varchar', length => 32, not_null => 1 },
   status        => { type => 'varchar', default => 'active', length => 32 },
 );

 __PACKAGE__->meta->primary_key_columns([ 'id' ]);

 __PACKAGE__->meta->foreign_keys
 (
   category => 
   {
     class => 'Category',
     key_columns => 
     {
       category_id => 'id',
     },
   },

   code => 
   {
     class => 'Code',
     key_columns => 
     {
       fk1 => 'k1',
       fk2 => 'k2',
       fk3 => 'k3',
     },
   },
 );

 __PACKAGE__->meta->initialize;

 1;

See the L<auto-initialization|AUTO-INITIALIZATION> section for more discussion of Perl code generation.

=item B<perl_columns_definition [PARAMS]>

Auto-initialize the columns, then return the Perl source code that is equivalent to the auto-initialization.  PARAMS are optional name/value pairs that may include the following:

=over 4

=item * braces STYLE

The brace style to use in the generated Perl code.  STYLE must be either "k&r" or "bsd".  The default value is determined by the return value of the L<default_perl_braces|/default_perl_braces> class method.

=item * indent INT

The integer number of spaces to use for each level of indenting in the generated Perl code.  The default value is determined by the return value of the L<default_perl_indent|/default_perl_indent> class method.

=back

See the larger example in the documentation for the L<perl_class_definition|/perl_class_definition> method to see what the generated Perl code looks like.

=item B<perl_foreign_keys_definition [PARAMS]>

Auto-initialize the foreign keys, then return the Perl source code that is equivalent to the auto-initialization.  PARAMS are optional name/value pairs that may include the following:

=over 4

=item * braces STYLE

The brace style to use in the generated Perl code.  STYLE must be either "k&r" or "bsd".  The default value is determined by the return value of the L<default_perl_braces|/default_perl_braces> class method.

=item * indent INT

The integer number of spaces to use for each level of indenting in the generated Perl code.  The default value is determined by the return value of the L<default_perl_indent|/default_perl_indent> class method.

=back

See the larger example in the documentation for the L<perl_class_definition|/perl_class_definition> method to see what the generated Perl code looks like.

=item B<perl_primary_key_columns_definition>

Auto-initialize the primary key column names, then return the Perl source code that is equivalent to the auto-initialization.

See the larger example in the documentation for the L<perl_class_definition|/perl_class_definition> method to see what the generated Perl code looks like.

=item B<perl_unique_keys_definition [PARAMS]>

Auto-initialize the unique keys, then return the Perl source code that is equivalent to the auto-initialization.  PARAMS are optional name/value pairs that may include the following:

=over 4

=item * braces STYLE

The brace style to use in the generated Perl code.  STYLE must be either "k&r" or "bsd".  The default value is determined by the return value of the L<default_perl_braces|/default_perl_braces> class method.

=item * indent INT

The integer number of spaces to use for each level of indenting in the generated Perl code.  The default value is determined by the return value of the L<default_perl_indent|/default_perl_indent> class method.

=item * style STYLE

Determines the style the initialization used in the generated Perl code.  STYLE must be "array" or "object".  The default is determined by the return value of the class method L<default_perl_unique_key_style|/default_perl_unique_key_style>.

The "array" style passes references to arrays of column names:

  __PACKAGE__->meta->add_unique_keys
  (
    [ 'id', 'name' ],
    [ 'flag', 'status' ],
  );

The "object" style sets unique keys using calls to the L<Rose::DB::Object::Metadata::UniqueKey> constructor:

  __PACKAGE__->meta->add_unique_keys
  (
    Rose::DB::Object::Metadata::UniqueKey->new(
      name    => 'products_id_key', 
      columns => [ 'id', 'name' ]),

    Rose::DB::Object::Metadata::UniqueKey->new(
      name    => 'products_flag_key', 
      columns => [ 'flag', 'status' ]),
  );

=back

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
