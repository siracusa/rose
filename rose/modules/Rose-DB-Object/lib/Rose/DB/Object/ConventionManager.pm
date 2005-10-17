package Rose::DB::Object::ConventionManager;

use strict;

use Carp();
use Scalar::Util();

use Rose::DB::Object::Metadata::ForeignKey;

use Rose::DB::Object::Metadata::Object;
our @ISA = qw(Rose::DB::Object::Metadata::Object);

our $VERSION = '0.01';

our $Debug = 0;

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' =>
  [
    'singular_to_plural_function',
  ],
);

*meta = \&Rose::DB::Object::Metadata::Object::parent;

sub class_to_table_singular
{
  my($self, $class) = @_;

  $class ||= $self->meta->class;

  $class =~ /(\w+)$/;
  my $table = $1;
  $table =~ s/([a-z]\d*|^\d+)([A-Z])/$1_$2/g;
  return lc $table;
}

sub class_to_table_plural
{
  my($self) = shift;
  $self->singular_to_plural($self->class_to_table_singular(@_));
}

sub table_to_class
{
  my($self, $table) = @_;
  $table =~ s/_(.)/\U$1/g;
  return ucfirst $table;
}

sub auto_table_name { shift->class_to_table_plural }

sub auto_primary_key_column_names
{
  my($self) = shift;

  my $meta = $self->meta;

  # 1. Column named "id"
  return [ 'id' ]  if($meta->column('id'));

  # 2. Column named <table singular>_id
  my $column = $self->class_to_table_singular . '_id';
  return [ $column ]  if($meta->column($column));

  # 3. The first serial column in the column list, alphabetically
  foreach my $column (sort { lc $a->name cmp lc $b->name } $meta->columns)
  {
    return [ $column->name ]  if($column->type eq 'serial');
  }

  return;
}

sub default_singular_to_plural
{
  my($word) = shift;
  
  if($word =~ /[sx]/)
  {
    return $word . 'es';
  }
  
  return $word . 's';
}

sub init_singular_to_plural_function { \&default_singular_to_plural }

sub singular_to_plural
{
  my($self, $word) = @_;
  
  if(my $code = $self->singular_to_plural_function)
  {
    return $code->($word);
  }
  
  return $word . 's';
}

sub auto_foreign_key
{
  my($self, $name, $spec) = @_;

  $spec ||= {};
  
  my $meta = $self->meta;

  unless($spec->{'class'})
  {
    my $class = $meta->class;

    # Get class prefix, if any
    $class =~ /^((?:\w+::)*)/;
    my $prefix = $1 || '';

    # Get class suffix from foreign key name
    my $table = $name;
    $table =~ s/_id$//;
    my $suffix = $self->table_to_class($table);
    my $fk_class = "$prefix$suffix";

    LOAD:
    {
      # Try to load class
      no strict 'refs';
      unless(UNIVERSAL::isa($fk_class, 'Rose::DB::Object'))
      {
        eval "require $fk_class";
        return  if($@);
      }
    }

    return  unless(UNIVERSAL::isa($fk_class, 'Rose::DB::Object'));
    
    $spec->{'class'} = $fk_class;
  }

  unless(defined $spec->{'key_columns'})
  {
    my @fpk_columns = $spec->{'class'}->meta->primary_key_column_names;
    return  unless(@fpk_columns == 1);

    my $aliases = $meta->column_aliases;
  
    if($meta->column($name) && $aliases->{$name} && $aliases->{$name} ne $name)
    {
      $spec->{'key_columns'} = { $name => $fpk_columns[0] };
    }
    elsif($meta->column("${name}_id"))
    {
      $spec->{'key_columns'} = { "${name}_id" => $fpk_columns[0] };
    }
    else { return }
  }
  
  return Rose::DB::Object::Metadata::ForeignKey->new(name => $name, %$spec);
}

sub auto_relationship
{
  my($self, $name, $rel_class, $spec) = @_;

  $spec ||= {};

  my $meta = $self->meta;

  unless($spec->{'class'})
  {
    my $class = $meta->class;

    # Get class prefix, if any
    $class =~ /^((?:\w+::)*)/;
    my $prefix = $1 || '';

    # Get class suffix from relationship name
    my $table = $name;
    $table =~ s/_id$//;
    my $suffix = $self->table_to_class($table);
    my $f_class = "$prefix$suffix";

    LOAD:
    {
      # Try to load class
      no strict 'refs';
      unless(UNIVERSAL::isa($f_class, 'Rose::DB::Object'))
      {
        eval "require $f_class";
        return  if($@);
      }
    }

    return  unless(UNIVERSAL::isa($f_class, 'Rose::DB::Object'));
    
    $spec->{'class'} = $f_class;
  }

  my $rel_type = $rel_class->type;

  if($rel_type eq 'one to one')
  {
    return $self->auto_relationship_one_to_one($name, $rel_class, $spec);
  }
  elsif($rel_type eq 'many to one')
  {
    return $self->auto_relationship_many_to_one($name, $rel_class, $spec);
  }
  elsif($rel_type eq 'one to many')
  {
    return $self->auto_relationship_one_to_many($name, $rel_class, $spec);
  }

  return;
}

sub auto_relationship_one_to_one
{
  my($self, $name, $rel_class, $spec) = @_;

  $spec ||= {};

  my $meta = $self->meta;

  unless(defined $spec->{'column_map'})
  {
    my @fpk_columns = $spec->{'class'}->meta->primary_key_column_names;
    return  unless(@fpk_columns == 1);

    my $aliases = $meta->column_aliases;    
  
    if($meta->column($name) && $aliases->{$name} && $aliases->{$name} ne $name)
    {
      $spec->{'column_map'} = { $name => $fpk_columns[0] };
    }
    elsif($meta->column("${name}_$fpk_columns[0]"))
    {
      $spec->{'column_map'} = { "${name}_$fpk_columns[0]" => $fpk_columns[0] };
    }
    elsif($meta->column("${name}_id"))
    {
      $spec->{'column_map'} = { "${name}_id" => $fpk_columns[0] };
    }
    else { return }
  }
  
  return $rel_class->new(name => $name, %$spec);
}

*auto_relationship_many_to_one = \&auto_relationship_one_to_one;

sub auto_relationship_one_to_many
{
  my($self, $name, $rel_class, $spec) = @_;
$DB::single = 1;
  $spec ||= {};

  my $meta = $self->meta;
  my $f_col_name = $self->class_to_table_singular;
    
  unless(defined $spec->{'column_map'})
  {
    my @pk_columns = $meta->primary_key_column_names;
    return  unless(@pk_columns == 1);

    my $f_meta = $spec->{'class'}->meta;

    my $aliases = $f_meta->column_aliases;
  
    if($f_meta->column($f_col_name) && $aliases->{$f_col_name} && $aliases->{$f_col_name} ne $f_col_name)
    {
      $spec->{'column_map'} = { $pk_columns[0] => $f_col_name };
    }
    elsif($f_meta->column("${f_col_name}_$pk_columns[0]"))
    {
      $spec->{'column_map'} = { $pk_columns[0] => "${f_col_name}_$pk_columns[0]" };
    }
    elsif($f_meta->column("${f_col_name}_id"))
    {
      $spec->{'column_map'} = { $pk_columns[0] => "${f_col_name}_id" };
    }
    else { return }
  }

  return $rel_class->new(name => $name, %$spec);
}

1;
