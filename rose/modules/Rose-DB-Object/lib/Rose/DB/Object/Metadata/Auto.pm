package Rose::DB::Object::Metadata::Auto;

use strict;

use Carp();

use Rose::DB::Object::Metadata::Column::Scalar;
use Rose::DB::Object::Metadata::ForeignKey;

use Rose::DB::Object::Metadata;
our @ISA = qw(Rose::DB::Object::Metadata);

our $VERSION = '0.02';

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar => 
  [
    'default_perl_indent',
    'default_perl_braces',
    'default_perl_unique_key_style',
  ],
);

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => 
  [
    'column_alias_generator',
    'foreign_key_name_generator',
  ],
);

__PACKAGE__->default_perl_indent(4);
__PACKAGE__->default_perl_braces('k&r');
__PACKAGE__->default_perl_unique_key_style('array');

sub auto_generate_columns
{
  my($self) = shift;

  my($class, %columns, $schema, $table);

  eval
  {
    $class = $self->class or die "Missing class!";

    my $db  = $self->db;
    my $dbh = $db->dbh or die $db->error;

    $table = ($db->driver eq 'mysql') ? $self->table : lc $self->table;

    $schema = $self->schema;
    $schema = $db->default_implicit_schema  unless(defined $schema);

    my $sth = $dbh->column_info($self->catalog, $schema, $table, '%');

    unless(defined $sth)
    {
      no warnings; # undef strings okay
      die "No column information found for catalog '", $self->catalog,
          "' schema '", $schema, "' table '", $table, "'";
    }

    COLUMN: while(my $col_info = $sth->fetchrow_hashref)
    {
      CHECK_TABLE: # Make sure this column is from the right table
      {
        no warnings; # Allow undef coercion to empty string

        next COLUMN unless($col_info->{'TABLE_CAT'}   eq $self->catalog &&
                           $col_info->{'TABLE_SCHEM'} eq $schema &&
                           $col_info->{'TABLE_NAME'}  eq $table);
      }

      unless(defined $col_info->{'COLUMN_NAME'})
      {
        Carp::croak "Could not extract column name from DBI column_info()";
      }

      $columns{$col_info->{'COLUMN_NAME'}} = 
        $self->auto_generate_column($col_info->{'COLUMN_NAME'}, $col_info);
    }
  };

  if($@ || !keys %columns)
  {
    no warnings; # undef strings okay
    Carp::croak "Could not auto-generate columns for class $class - ",
                ($@ || "no column info found for catalog '" . $self->catalog .
                "' schema '" . $schema . "' table '$table'");
  }

  $self->auto_alias_columns(values %columns);

  return wantarray ? values %columns : \%columns;
}

sub auto_alias_columns
{
  my($self) = shift;

  foreach my $column (@_ == 1 && ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_)
  {
    # Auto-alias the column if there will be any conflicts
    foreach my $type ($column->auto_method_types)
    {
      my $method = $self->method_name_from_column($column, $type);

      if($self->method_name_is_reserved($method, $self->class))
      {
        $self->auto_alias_column($column);
        last; # just alias the column once
      }
    }

    # Re-check: errors are fatal this time
    foreach my $type ($column->auto_method_types)
    {
      my $method = $self->method_name_from_column($column, $type);

      if($self->method_name_is_reserved($method, $self->class))
      {
        Carp::croak "Cannot create '$type' method named '$method' for ",
                    "column '$column' - method name is reserved";
      }
    }
  }

}
sub auto_generate_column
{
  my($self, $name, $col_info) = @_;

  my $db = $self->db or Carp::confess "Could not get db";

  $db->refine_dbi_column_info($col_info);

  my $type = $col_info->{'TYPE_NAME'};

  my $column_class = 
    $self->column_type_class($type) || $self->column_type_class('scalar')
      or Carp::croak "No column class set for column types '$type' or 'scalar'";

  unless($self->column_class_is_loaded($column_class))
  {
    $self->load_column_class($column_class);
  }

  my $column = $column_class->new(name => $name, parent => $self);

  $column->init_with_dbi_column_info($col_info);

  return $column;
}

sub init_column_alias_generator { sub { $_[1] . '_col' } }

DEFAULT_FK_NAME_GEN:
{
  my %Seen_FK_Name;

  sub default_foreign_key_name_generator
  {
    my($meta, $fk) = @_;

    my $class       = $meta->class;
    my $key_columns = $fk->key_columns;

    my $name;

    # No single column whose name we can steal and then
    # mangle to make the foreign key name, so we'll derive
    # the foreign key name from the foreign class name.
    if(keys %$key_columns > 1)
    {
      $name = $fk->class;
      $name =~ s/::/_/g;
      $name =~ s/([a-z])([A-Z])/$1_$2/g;
      $name = lc $name;
    }
    else
    {
      my($local_column, $foreign_column) = each(%$key_columns);

      # Try to lop off foreign column name.  Example:
      # my_foreign_object_id -> my_foreign_object
      if($local_column =~ s/_?$foreign_column$//)
      {
        $name = $local_column;
      }
      else
      {
        # Usually, the actual column name is taken by the column accessor,
        # but if it's not, we'll use it.
        if(!$meta->class->can($local_column))
        {
          $name = $local_column;
        }
        else # otherwise, append "_object"
        {
          $name = $local_column . '_object';
        }
      }
    }

    # Make sure the name's not taken, appending numbers until it's unique.
    # See, this is why you shouldn't rely on auto_init_* all the time.
    # You end up with lame method names.
    if($Seen_FK_Name{$class}{$name})
    {
      my $num = 2;
      my $new_name = $name;

      while($Seen_FK_Name{$class}{$new_name})
      {
        $new_name = $name . $num++;
      }

      $name = $new_name;
    }

    $Seen_FK_Name{$class}{$name}++;

    return $name;
  }
}

sub init_foreign_key_name_generator { \&default_foreign_key_name_generator }

sub auto_alias_column
{
  my($self, $column) = @_;

  my $code = $self->column_alias_generator;
  local $_ = $column->name;

  my $alias = $code->($self, $_);

  if($self->method_name_is_reserved($alias, $self->class))
  {
    Carp::croak "Called column_alias_generator() to alias column ",
                "'$_' but the value returned is a reserved method ",
                "name: $alias";
  }

  $column->alias($alias);

  return;
}

sub auto_retrieve_primary_key_column_names
{
  my($self) = shift;

  unless(defined wantarray)
  {
    Carp::croak "Useless call to auto_retrieve_primary_key_column_names() in void context";
  }

  my($class, @columns, $schema);

  eval
  {
    $class = $self->class or die "Missing class!";

    my $db  = $self->db;
    my $dbh = $db->dbh or die $db->error;

    my $table = lc $self->table;

    $schema = $self->schema;
    $schema = $db->default_implicit_schema  unless(defined $schema);

    my $sth = $dbh->primary_key_info($self->catalog, $schema, $table);

    unless(defined $sth)
    {
      no warnings; # undef strings okay
      die "No primary key information found for catalog '", $self->catalog,
          "' schema '", $schema, "' table '", $table, "'";
    }

    PK: while(my $pk_info = $sth->fetchrow_hashref)
    {
      CHECK_TABLE: # Make sure this column is from the right table
      {
        no warnings; # Allow undef coercion to empty string

        next PK  unless($pk_info->{'TABLE_CAT'}   eq $self->catalog &&
                        $pk_info->{'TABLE_SCHEM'} eq $schema &&
                        $pk_info->{'TABLE_NAME'}  eq $table);
      }

      unless(defined $pk_info->{'COLUMN_NAME'})
      {
        Carp::croak "Could not extract column name from DBI primary_key_info()";
      }

      push(@columns, $pk_info->{'COLUMN_NAME'});
    }
  };

  if($@ || !@columns)
  {
    $@ = 'no primary key coumns found'  unless(defined $@);
    Carp::croak "Could not auto-retrieve primary key columns for class $class - ",
                ($@ || "no primary key info found for catalog '" . $self->catalog .
                "' schema '" . $schema . "' table '" . lc $self->table, "'");
  }

  return wantarray ? @columns : \@columns;
}

sub auto_generate_foreign_keys
{
  my($self, %args) = @_;

  unless(defined wantarray)
  {
    Carp::croak "Useless call to auto_generate_foreign_keys() in void context";
  }

  my $no_warnings = $args{'no_warnings'};

  my($class, @foreign_keys);

  eval
  {
    $class = $self->class or die "Missing class!";

    my $db  = $self->db;
    my $dbh = $db->dbh or die $db->error;

    my $sth = $dbh->foreign_key_info(undef, undef, undef,
                                     $self->catalog, $self->schema, $self->table);

    # This happens when the table has no foreign keys
    return  unless(defined $sth);

    my(%fk, @fk_info);

    my $schema = $self->schema;
    $schema = $db->default_implicit_schema  unless(defined $schema);

    FK: while(my $fk_info = $sth->fetchrow_hashref)
    {
      CHECK_TABLE: # Make sure this column is from the right table
      {
        no warnings; # Allow undef coercion to empty string
        next FK  unless($fk_info->{'FK_TABLE_CAT'}   eq $self->catalog &&
                        $fk_info->{'FK_TABLE_SCHEM'} eq $schema &&
                        $fk_info->{'FK_TABLE_NAME'}  eq $self->table);
      }

      push(@fk_info, $fk_info);
    }

    # This step is important!  It ensures that foreign keys will be created
    # in a deterministic order, which in turn allows the "auto-naming" of
    # foreign keys to work in a predictible manner.  This exact sort order
    # (lowercase table name comparisons) is part of the API for foreign
    # key auto generation.
    @fk_info = 
      sort { lc $a->{'UK_TABLE_NAME'} cmp lc $b->{'UK_TABLE_NAME'} } @fk_info;

    my %warned;

    FK_INFO: foreach my $fk_info (@fk_info)
    {
      my $foreign_class = 
        $self->class_for(catalog => $fk_info->{'UK_TABLE_CAT'},
                         schema  => $fk_info->{'UK_TABLE_SCHEM'},
                         table   => $fk_info->{'UK_TABLE_NAME'});

      unless($foreign_class)
      {
        my $key = join($;, map { defined($_) ? $_ : '' } 
                       @$fk_info{qw(UK_TABLE_CAT UK_TABLE_NAME UK_TABLE_SCHEM)});

        unless($no_warnings || $warned{$key}++)
        {
          no warnings; # Allow undef coercion to empty string
          warn "No Rose::DB::Object-derived class found for catalog '",
                $fk_info->{'UK_TABLE_CAT'}, "' schema '", 
                $fk_info->{'UK_TABLE_SCHEM'}, "' table '", 
                $fk_info->{'UK_TABLE_NAME'}, "'";
        }

        next FK_INFO;
      }

      my $key_name       = $fk_info->{'UK_NAME'}; 
      my $local_column   = $fk_info->{'FK_COLUMN_NAME'};
      my $foreign_column = $fk_info->{'UK_COLUMN_NAME'};

      $fk{$key_name}{'class'} = $foreign_class;
      $fk{$key_name}{'key_columns'}{$local_column} = $foreign_column;
    }

    my %seen;

    foreach my $fk_info (@fk_info)
    {
      next  if($seen{$fk_info->{'UK_NAME'}}++);
      my $info = $fk{$fk_info->{'UK_NAME'}};
      my $fk   = Rose::DB::Object::Metadata::ForeignKey->new(%$info);

      next  unless(defined $fk->class);

      my $name = $self->foreign_key_name_generator->($self, $fk);

      unless(defined $name && $name =~ /^\w+$/)
      {
        die "Missing or invalid key name '$name' for foreign key ",
            "generated in $class for ", $fk->class;
      }

      $fk->name($name);

      push(@foreign_keys, $fk);
    }
  };

  if($@)
  {
    Carp::croak "Could not auto-generate foreign keys for class $class - $@";
  }

  @foreign_keys = sort { lc $a->name cmp lc $b->name } @foreign_keys;

  return wantarray ? @foreign_keys : \@foreign_keys;
}

sub auto_init_columns
{
  my($self, %args) = @_;

  my $auto_columns     = $self->auto_generate_columns;
  my $existing_columns = $self->columns;

  if(!$args{'replace_existing'} && keys %$auto_columns != @$existing_columns)
  {
    while(my($name, $column) = each(%$auto_columns))
    {
      next  if($self->column($name));
      $self->add_column($column);
    }
  }
  elsif($args{'replace_existing'} || !@$existing_columns)
  {
    $self->columns(values %$auto_columns);
  }

  return;
}

sub perl_columns_definition
{
  my($self, %args) = @_;

  $self->auto_init_columns;

  my $indent = defined $args{'indent'} ? $args{'indent'} : $self->default_perl_indent;
  my $braces = defined $args{'braces'} ? $args{'braces'} : $self->default_perl_braces;

  unless($indent =~ /^\d+$/)
  {
    Carp::croak 'Invalid ', (defined $args{'indent'} ? '' : 'default '),
                "indent size: '$braces'";
  }

  $indent = ' ' x $indent;

  my $def_start = "__PACKAGE__->meta->columns";

  if($braces eq 'bsd')
  {
    $def_start .= "\n(\n";
  }
  elsif($braces eq 'k&r')
  {
    $def_start .= "(\n";
  }
  else
  {
    Carp::croak 'Invalid ', (defined $args{'braces'} ? '' : 'default '),
                "brace style: '$braces'";
  }

  my $max_len = 0;
  my $min_len = -1;

  foreach my $name ($self->column_names)
  {
    $max_len = length($name)  if(length $name > $max_len);
    $min_len = length($name)  if(length $name < $min_len || $min_len < 0);
  }

  my @col_defs;

  foreach my $column ($self->columns)
  {
    push(@col_defs, $column->perl_hash_definition(inline       => 1, 
                                                  name_padding => $max_len));
  }

  return $def_start . join(",\n", map { "$indent$_" } @col_defs) . ",\n);\n";
}

sub perl_foreign_keys_definition
{
  my($self, %args) = @_;

  $self->auto_init_foreign_keys;

  my $indent = defined $args{'indent'} ? $args{'indent'} : $self->default_perl_indent;
  my $braces = defined $args{'braces'} ? $args{'braces'} : $self->default_perl_braces;

  unless($indent =~ /^\d+$/)
  {
    Carp::croak 'Invalid ', (defined $args{'indent'} ? '' : 'default '),
                "indent size: '$braces'";
  }

  my $indent_txt = ' ' x $indent;

  my $def = "__PACKAGE__->meta->foreign_keys";

  if($braces eq 'bsd')
  {
    $def .= "\n(\n";
  }
  elsif($braces eq 'k&r')
  {
    $def .= "(\n";
  }
  else
  {
    Carp::croak 'Invalid ', (defined $args{'braces'} ? '' : 'default '),
                "brace style: '$braces'";
  }

  my @fk_defs;

  foreach my $fk ($self->foreign_keys)
  {
    push(@fk_defs, $fk->perl_hash_definition(indent => $indent, braces => $braces));
  }

  return ''  unless(@fk_defs);

  foreach my $fk_def (@fk_defs)
  {
    $fk_def =~ s/^/$indent_txt/mg;
    $def .= "$fk_def,\n" . ($fk_def eq $fk_defs[-1] ? '' : "\n");
  }

  return $def . ");\n";
}

sub perl_unique_keys_definition
{
  my($self, %args) = @_;

  $self->auto_init_unique_keys;

  my $style  = defined $args{'style'}  ? $args{'style'}  : $self->default_perl_unique_key_style;
  my $indent = defined $args{'indent'} ? $args{'indent'} : $self->default_perl_indent;
  my $braces = defined $args{'braces'} ? $args{'braces'} : $self->default_perl_braces;

  unless($indent =~ /^\d+$/)
  {
    Carp::croak 'Invalid ', (defined $args{'indent'} ? '' : 'default '),
                "indent size: '$braces'";
  }

  $indent = ' ' x $indent;

  my $uk_perl_method;

  if($style eq 'array')
  {
    $uk_perl_method = 'perl_array_definition';
  }
  elsif($style eq 'object')
  {
    $uk_perl_method = 'perl_object_definition';
  }
  else
  {
    Carp::croak 'Invalid ', (defined $args{'style'} ? '' : 'default '),
                "unique key style: '$style'";
  }

  my @uk_defs;

  foreach my $uk ($self->unique_keys)
  {
    push(@uk_defs, $uk->$uk_perl_method());
  }

  return ''  unless(@uk_defs);

  my $def_start = "__PACKAGE__->meta->add_unique_keys";

  if(@uk_defs == 1)
  {
    $def_start .= '(';
  }
  elsif($braces eq 'bsd')
  {
    $def_start .= "\n(\n";
  }
  elsif($braces eq 'k&r')
  {
    $def_start .= "(\n";
  }
  else
  {
    Carp::croak 'Invalid ', (defined $args{'braces'} ? '' : 'default '),
                "brace style: '$braces'";
  }

  if(@uk_defs == 1)
  {
    return "$def_start$uk_defs[0]);\n";
  }
  else
  {
    return $def_start . join(",\n", map { "$indent$_" } @uk_defs) . ",\n);\n";
  }
}

sub perl_primary_key_columns_definition
{
  my($self, %args) = @_;

  $self->auto_init_primary_key_columns;

  my @pk_cols = $self->primary_key->column_names;

  Carp::croak "No primary key columns found for class ", ref($self)
    unless(@pk_cols);

  return '__PACKAGE__->meta->primary_key_columns(' .
         $self->primary_key->perl_array_definition . ");\n";
}

sub perl_class_definition
{
  my($self, %args) = @_;

  my $isa = delete $args{'isa'} || [ 'Rose::DB::Object' ];

  $isa = [ $isa ]  unless(ref $isa);

  return<<"EOF";
package @{[$self->class]};

use strict;

@{[join(";\n", map { "use $_" } @$isa)]}
our \@ISA = qw(@$isa);

__PACKAGE__->meta->table('@{[ $self->table ]}');

@{[join("\n", grep { /\S/ } $self->perl_columns_definition(%args),
                            $self->perl_primary_key_columns_definition(%args),
                            $self->perl_unique_keys_definition(%args),
                            $self->perl_foreign_keys_definition(%args))]}
__PACKAGE__->meta->initialize;

1;
EOF
}

sub auto_generate_unique_keys { die "Override in subclass" }

sub auto_init_unique_keys
{
  my($self, %args) = @_;

  my $pk_cols = join("\0", $self->primary_key_columns);

  unless(length $pk_cols)
  {
    $pk_cols = join("\0", $self->auto_retrieve_primary_key_column_names);
  }

  my $auto_unique_keys     = $self->auto_generate_unique_keys;
  my $existing_unique_keys = $self->unique_keys;

  if(!$args{'replace_existing'} && @$auto_unique_keys != @$existing_unique_keys)
  {
    KEY: foreach my $key (@$auto_unique_keys)
    {
      my $id = join("\0", sort map { lc } $key->column_names);

      foreach my $existing_key (@$existing_unique_keys)
      {
        next KEY  if($id eq join("\0", sort map { lc } $existing_key->column_names));
      }

      # Skip primary key
      next KEY  if($pk_cols eq join("\0", $key->column_names));

      $self->add_unique_key($key);
    }
  }
  elsif($args{'replace_existing'} || !@$existing_unique_keys)
  {
    $self->unique_keys(@$auto_unique_keys);
  }

  return;
}

sub auto_init_foreign_keys
{
  my($self, %args) = @_;

  my $auto_foreign_keys     = $self->auto_generate_foreign_keys(%args);
  my $existing_foreign_keys = $self->foreign_keys;

  if(!$args{'replace_existing'} && @$auto_foreign_keys != @$existing_foreign_keys)
  {
    KEY: foreach my $key (@$auto_foreign_keys)
    {
      my $id = $key->id; #__fk_key_to_id($key);

      foreach my $existing_key (@$existing_foreign_keys)
      {
        next KEY  if($id eq $existing_key->id);#__fk_key_to_id($existing_key));
      }

      $self->add_foreign_key($key);
    }
  }
  elsif($args{'replace_existing'} || !@$existing_foreign_keys)
  {
    $self->foreign_keys(@$auto_foreign_keys);
  }

  return;
}

sub __fk_key_to_id
{
  my($fk) = shift;

  my $key_columns = $fk->key_columns;

  return
    join("\0", map { join("\1", $_, $key_columns->{$_}) } sort keys %$key_columns);
}

sub auto_init_primary_key_columns
{
  my($self) = shift;

  my $primary_key_columns = $self->auto_retrieve_primary_key_column_names;

  unless(@$primary_key_columns)
  {
    Carp::croak "Could not retrieve primary key columns for class ", ref($self);
  }

  $self->primary_key_columns(@$primary_key_columns);

  return;
}

sub auto_initialize
{
  my($self) = shift;

  $self->auto_init_columns(@_);
  $self->auto_init_primary_key_columns;
  $self->auto_init_unique_keys(@_);
  $self->auto_init_foreign_keys(@_);
  $self->initialize;
}

1;

__END__

KNOWN BUGS:

MySQL:

CHAR(6) column shows up as VARCHAR(6)
BIT(5)  column shows up as TINYINT(1)
BOOLEAN column shows up as TINYINT(1)
No native support for array types in MySQL
