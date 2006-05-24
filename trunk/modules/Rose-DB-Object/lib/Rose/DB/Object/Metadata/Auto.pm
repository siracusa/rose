package Rose::DB::Object::Metadata::Auto;

use strict;

use Carp();

use Rose::DB::Object::Metadata::Column::Scalar;
use Rose::DB::Object::Metadata::ForeignKey;

use Rose::DB::Object::Metadata;
our @ISA = qw(Rose::DB::Object::Metadata);

our $Debug;

*Debug = \$Rose::DB::Object::Metadata::Debug;

our $VERSION = '0.726';

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar => 
  [
    'default_perl_indent',
    'default_perl_braces',
    'default_perl_unique_key_style',
  ],

  inheritable_hash =>
  [
    relationship_type_ranks => { interface => 'get_set_all' },
    relationship_type_rank   => { interface => 'get_set', hash_key => 'relationship_type_ranks' },
    delete_relationship_type_rank => { interface => 'delete', hash_key => 'relationship_type_ranks' },
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

__PACKAGE__->relationship_type_ranks
(
  'one to one'   => 1,
  'many to one'  => 2,
  'one to many'  => 3,
  'many to many' => 4,
);

__PACKAGE__->default_perl_indent(4);
__PACKAGE__->default_perl_braces('k&r');
__PACKAGE__->default_perl_unique_key_style('array');

sub auto_generate_columns
{
  my($self) = shift;

  my($db, $class, %columns, $catalog, $schema, $table);

  eval
  {
    $class = $self->class or die "Missing class!";

    $db = $self->db;
    my $dbh = $db->dbh or die $db->error;

    local $dbh->{'FetchHashKeyName'} = 'NAME';

    $table = $self->table;

    $table = lc $table  if($db->likes_lowercase_table_names);

    my $table_unquoted = $db->unquote_table_name($table);

    $catalog = $self->select_catalog($db);
    $schema  = $self->select_schema($db); 
    $schema  = $db->default_implicit_schema  unless(defined $schema);

    $schema  = lc $schema   if(defined $schema && $db->likes_lowercase_schema_names);
    $catalog = lc $catalog  if(defined $catalog && $db->likes_lowercase_catalog_names);

    my $sth = $dbh->column_info($catalog, $schema, $table_unquoted, '%');

    unless(defined $sth)
    {
      no warnings; # undef strings okay
      die "No column information found for catalog '", $catalog,
          "' schema '", $schema, "' table '", $table_unquoted, "'";
    }

    COLUMN: while(my $col_info = $sth->fetchrow_hashref)
    {
      CHECK_TABLE: # Make sure this column is from the right table
      {
        no warnings; # Allow undef coercion to empty string

        $col_info->{'TABLE_NAME'} = $db->unquote_table_name($col_info->{'TABLE_NAME'});

        next COLUMN unless($col_info->{'TABLE_CAT'}   eq $catalog &&
                           $col_info->{'TABLE_SCHEM'} eq $schema &&
                           $col_info->{'TABLE_NAME'}  eq $table_unquoted);
      }

      unless(defined $col_info->{'COLUMN_NAME'})
      {
        Carp::croak "Could not extract column name from DBI column_info()";
      }

      $db->refine_dbi_column_info($col_info, $self);

      $columns{$col_info->{'COLUMN_NAME'}} = 
        $self->auto_generate_column($col_info->{'COLUMN_NAME'}, $col_info);
    }
  };

  if($@ || !keys %columns)
  {
    no warnings; # undef strings okay
    Carp::croak "Could not auto-generate columns for class $class - ",
                ($@ || "no column info found for catalog '" . $catalog .
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

  my $type = $col_info->{'TYPE_NAME'};
  my $meta_class = $self->original_class;

  my $column_class = 
    $meta_class->column_type_class($type) || $meta_class->column_type_class('scalar')
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

    my $name = $fk->name;

    unless(defined $name && length $name)
    {
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

  my($db, $class, @columns, $catalog, $schema);

  eval
  {
    $class = $self->class or die "Missing class!";

    $db = $self->db;
    my $dbh = $db->dbh or die $db->error;

    local $dbh->{'FetchHashKeyName'} = 'NAME';

    my $table = lc $self->table;

    my $table_unquoted = $db->unquote_table_name($table);

    $catalog = $self->select_catalog($db);
    $schema = $self->select_schema($db);
    $schema = $db->default_implicit_schema  unless(defined $schema);

    $schema  = lc $schema   if(defined $schema && $db->likes_lowercase_schema_names);
    $catalog = lc $catalog  if(defined $catalog && $db->likes_lowercase_catalog_names);

    my $sth = $dbh->primary_key_info($catalog, $schema, $table_unquoted);

    unless(defined $sth)
    {
      no warnings; # undef strings okay
      die "No primary key information found for catalog '", $catalog,
          "' schema '", $schema, "' table '", $table, "'";
    }

    PK: while(my $pk_info = $sth->fetchrow_hashref)
    {
      CHECK_TABLE: # Make sure this column is from the right table
      {
        no warnings; # Allow undef coercion to empty string

        $pk_info->{'TABLE_NAME'} = $db->unquote_table_name($pk_info->{'TABLE_NAME'});

        next PK  unless($pk_info->{'TABLE_CAT'}   eq $catalog &&
                        $pk_info->{'TABLE_SCHEM'} eq $schema &&
                        $pk_info->{'TABLE_NAME'}  eq $table_unquoted);
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
    $@ = 'no primary key columns found'  unless(defined $@);
    Carp::croak "Could not auto-retrieve primary key columns for class $class - ",
                ($@ || "no primary key info found for catalog '" . $catalog .
                "' schema '" . $schema . "' table '" . lc $self->table, "'");
  }

  return wantarray ? @columns : \@columns;
}

my %Warned;

sub auto_generate_foreign_keys
{
  my($self, %args) = @_;

  unless(defined wantarray)
  {
    Carp::croak "Useless call to auto_generate_foreign_keys() in void context";
  }

  my $no_warnings = $args{'no_warnings'};

  my($class, @foreign_keys, $total_fks);

  eval
  {
    $class = $self->class or die "Missing class!";

    my $db  = $self->db;
    my $dbh = $db->dbh or die $db->error;

    local $dbh->{'FetchHashKeyName'} = 'NAME';

    my $catalog = $self->select_catalog($db);
    my $schema  = $self->select_schema($db); 
    $schema = $db->default_implicit_schema  unless(defined $schema);

    $schema  = lc $schema   if(defined $schema && $db->likes_lowercase_schema_names);
    $catalog = lc $catalog  if(defined $catalog && $db->likes_lowercase_catalog_names);

    my $table = $db->likes_lowercase_table_names ? lc $self->table : $self->table;

    my $sth = $dbh->foreign_key_info(undef, undef, undef,
                                     $catalog, $schema, $table);

    # This happens when the table has no foreign keys
    return  unless(defined $sth);

    my(%fk, @fk_info);

    FK: while(my $fk_info = $sth->fetchrow_hashref)
    {
      CHECK_TABLE: # Make sure this column is from the right table
      {
        no warnings; # Allow undef coercion to empty string
        next FK  unless($fk_info->{'FK_TABLE_CAT'}   eq $catalog &&
                        $fk_info->{'FK_TABLE_SCHEM'} eq $schema &&
                        $fk_info->{'FK_TABLE_NAME'}  eq $table);
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

    my $cm = $self->convention_manager;

    FK_INFO: foreach my $fk_info (@fk_info)
    {
      my $foreign_class = 
        $self->class_for(catalog => $fk_info->{'UK_TABLE_CAT'},
                         schema  => $fk_info->{'UK_TABLE_SCHEM'},
                         table   => $fk_info->{'UK_TABLE_NAME'});

      unless($foreign_class) # Give convention manager a chance
      {
        $foreign_class = 
          $self->convention_manager->related_table_to_class(
            $fk_info->{'UK_TABLE_NAME'}, $self->class);

        unless(UNIVERSAL::isa($foreign_class, 'Rose::DB::Object'))
        {
          # Null convention manager may return undef
          no warnings 'uninitialized'; 
          eval "require $foreign_class";
          $foreign_class = undef  if($@ || !UNIVERSAL::isa($foreign_class, 'Rose::DB::Object'));
        }
      }

      unless($foreign_class)
      {
        my $key = join($;, map { defined($_) ? $_ : "\034" } $self->class,
                       @$fk_info{qw(UK_TABLE_CAT UK_TABLE_SCHEM UK_TABLE_NAME)});

        # Add deferred task
        $self->add_deferred_task(
        {
          class  => $self->class, 
          method => 'auto_init_foreign_keys',
          args   => \%args,

          code   => sub
          {
            $self->auto_init_foreign_keys(%args);
            $self->make_foreign_key_methods(%args, preserve_existing => 1);
          },

          check => sub
          {
            my $fks = $self->foreign_keys;
            return @$fks == $total_fks ? 1 : 0;
          },
        });

        unless($no_warnings || $Warned{$key}++ || $self->allow_auto_initialization)
        {
          no warnings; # Allow undef coercion to empty string
          Carp::carp
            "No Rose::DB::Object-derived class found for catalog '",
            $fk_info->{'UK_TABLE_CAT'}, "' schema '", 
            $fk_info->{'UK_TABLE_SCHEM'}, "' table '", 
            $fk_info->{'UK_TABLE_NAME'}, "'";
        }

        $total_fks++;
        next FK_INFO;
      }

      my $key_name =
        $cm->auto_foreign_key_name($foreign_class, $fk_info->{'UK_NAME'});

      if(defined $key_name && length $key_name)
      {
        $fk{$fk_info->{'UK_NAME'}}{'name'} = $key_name;
      }

      my $local_column   = $fk_info->{'FK_COLUMN_NAME'};
      my $foreign_column = $fk_info->{'UK_COLUMN_NAME'};

      $fk{$fk_info->{'UK_NAME'}}{'class'} = $foreign_class;
      $fk{$fk_info->{'UK_NAME'}}{'key_columns'}{$local_column} = $foreign_column;

      $total_fks++;
    }

    my(%seen, %seen_name);

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

  $self->auto_init_columns  unless($self->was_auto_initialized);

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

  no warnings 'uninitialized'; # ordinal_position may be undef
  foreach my $column (sort __by_rank $self->columns)
  {
    push(@col_defs, $column->perl_hash_definition(inline       => 1, 
                                                  name_padding => $max_len));
  }

  return $def_start . join(",\n", map { "$indent$_" } @col_defs) . ",\n);\n";
}

sub __by_rank
{  
  my $pos1 = $a->ordinal_position;
  my $pos2 = $b->ordinal_position;

  if(defined $pos1 && defined $pos2)
  {
    return $pos1 <=> $pos2 || lc $a->name cmp lc $b->name;
  }

  return lc $a->name cmp lc $b->name;
}

sub perl_foreign_keys_definition
{
  my($self, %args) = @_;

  $self->auto_init_foreign_keys  unless($self->was_auto_initialized);

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

sub perl_relationships_definition
{
  my($self, %args) = @_;

  $self->auto_init_relationships  unless($self->was_auto_initialized);

  my $indent = defined $args{'indent'} ? $args{'indent'} : $self->default_perl_indent;
  my $braces = defined $args{'braces'} ? $args{'braces'} : $self->default_perl_braces;

  unless($indent =~ /^\d+$/)
  {
    Carp::croak 'Invalid ', (defined $args{'indent'} ? '' : 'default '),
                "indent size: '$braces'";
  }

  my $indent_txt = ' ' x $indent;

  my $def = "__PACKAGE__->meta->relationships";

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

  my @rel_defs;

  foreach my $rel ($self->relationships)
  {
    next  if($rel->can('foreign_key') && $rel->foreign_key);
    push(@rel_defs, $rel->perl_hash_definition(indent => $indent, braces => $braces));
  }

  return ''  unless(@rel_defs);

  foreach my $rel_def (@rel_defs)
  {
    $rel_def =~ s/^/$indent_txt/mg;
    $def .= "$rel_def,\n" . ($rel_def eq $rel_defs[-1] ? '' : "\n");
  }

  return $def . ");\n";
}

sub perl_unique_keys_definition
{
  my($self, %args) = @_;

  $self->auto_init_unique_keys  unless($self->was_auto_initialized);

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

  $self->auto_init_primary_key_columns  unless($self->was_auto_initialized);

  my @pk_cols = $self->primary_key->column_names;

  Carp::croak "No primary key columns found for class ", ref($self)
    unless(@pk_cols);

  return '__PACKAGE__->meta->primary_key_columns(' .
         $self->primary_key->perl_array_definition . ");\n";
}

sub perl_class_definition
{
  my($self, %args) = @_;

  my $class = $self->class;

  no strict 'refs';
  my $isa = delete $args{'isa'} || [ ${"${class}::ISA"}[0] || 'Rose::DB::Object' ];

  $isa = [ $isa ]  unless(ref $isa);

  my %use;

  foreach my $fk ($self->foreign_keys)
  {
    $use{$fk->class}++;
  }

  foreach my $rel ($self->relationships)
  {
    if($rel->can('map_class'))
    {
      $use{$rel->map_class}++;
    }
    else
    {
      $use{$rel->class}++;
    }
  }

  my $foreign_modules = '';

  if(%use)
  {
    $foreign_modules = "\n\n" . join("\n", map { "use $_;"} sort keys %use);
  }

  return<<"EOF";
package $class;

use strict;

use base qw(@$isa);$foreign_modules

__PACKAGE__->meta->table('@{[ $self->table ]}');

@{[join("\n", grep { /\S/ } $self->perl_columns_definition(%args),
                            $self->perl_primary_key_columns_definition(%args),
                            $self->perl_unique_keys_definition(%args),
                            $self->perl_foreign_keys_definition(%args),
                            $self->perl_relationships_definition(%args))]}
__PACKAGE__->meta->initialize;

1;
EOF
}

sub auto_generate_unique_keys { die "Override in subclass" }

sub auto_init_unique_keys
{
  my($self, %args) = @_;

  return  if(exists $args{'with_unique_keys'} && !$args{'with_unique_keys'});

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

  if(exists $args{'with_foreign_keys'} && !$args{'with_foreign_keys'})
  {
    $self->initialized_foreign_keys(1);
    return;
  }

  my $auto_foreign_keys     = $self->auto_generate_foreign_keys(%args);
  my $existing_foreign_keys = $self->foreign_keys;

  if(!$args{'replace_existing'} && @$auto_foreign_keys != @$existing_foreign_keys)
  {
    KEY: foreach my $key (@$auto_foreign_keys)
    {
      my $id = __fk_key_to_id($key); # $key->id; # might not have parent yet

      foreach my $existing_key (@$existing_foreign_keys)
      {
        next KEY  if($id eq __fk_key_to_id($existing_key)); # $existing_key->id
      }

      $self->add_foreign_key($key);
    }
  }
  elsif($args{'replace_existing'} || !@$existing_foreign_keys)
  {
    $self->foreign_keys(@$auto_foreign_keys);
  }

  $self->initialized_foreign_keys(1);

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

  # Wipe pk defaults because stupid MySQL adds them implicitly
  if($self->db->driver eq 'mysql')
  {
    foreach my $name (@$primary_key_columns)
    {
      my $column = $self->column($name) or next;
      $column->default(undef);
    }
  }

  $self->primary_key_columns(@$primary_key_columns);

  return;
}

my %Auto_Rel_Types;

sub auto_init_relationships
{
  my($self) = shift;
  my(%args) = @_;

  my $type_map  = $self->relationship_type_classes;
  my @all_types = keys %$type_map;

  my %types;

  if(delete $args{'restore_types'})
  {
    if(my $types = $Auto_Rel_Types{$self->class})
    {
      $args{'types'} = $types;
    }
  }

  if(exists $args{'relationship_types'} || 
     exists $args{'types'} || 
     exists $args{'with_relationships'})
  {
    my $types = exists $args{'relationship_types'} ? 
                delete $args{'relationship_types'} :
                exists $args{'types'} ?
                delete $args{'types'} :
                exists $args{'with_relationships'} ?
                delete $args{'with_relationships'} : 1;

    if(ref $types)
    {
      %types = map { $_ => 1 } @$types;
      $Auto_Rel_Types{$self->class} = $types;
    }
    elsif($types)
    {
      %types = map { $_ => 1 } @all_types;
    }
    else
    {
      $Auto_Rel_Types{$self->class} = [];
    }
  }
  else
  {
    %types = map { $_ => 1 } @all_types;
  }

  if(delete $args{'replace_existing'})
  {
    foreach my $rel ($self->relationships)
    {
      next  unless($types{$rel->type});
      $self->delete_relationship($rel->name);
    }
  }

  foreach my $type (sort { $self->sort_relationship_types($a, $b) } keys %types)
  {
    my $type_name = $type;

    for($type_name)
    {
      s/ /_/g;
      s/\W+//g;
    }

    my $method = 'auto_init_' . $type_name . '_relationships';

    if($self->can($method))
    {
      $self->$method(@_);
    }
  }

  return;
}

sub sort_relationship_types
{
  my($self, $a, $b) = @_;
  return $self->relationship_type_rank($a) <=> $self->relationship_type_rank($b);
}

sub auto_init_one_to_one_relationships { }
sub auto_init_many_to_one_relationships { }

sub auto_init_one_to_many_relationships 
{
  my($self, %args) = @_;

  my $class = $self->class;

  # For each foreign key in this class, try to make a "one to many"
  # relationship in the table that the foreign key points to.  But
  # don't do so if there's already a one to one relationship in that 
  # class that references all of the foreign key's columns.
  FK: foreach my $fk ($self->foreign_keys)
  {
    my $f_class = $fk->class;

    next  unless($f_class && UNIVERSAL::isa($f_class, 'Rose::DB::Object'));

    my $f_meta  = $f_class->meta;
    my $key_cols = $fk->key_columns;

    # Check for any one to one relationships that reference the foreign
    # key's columns.  If found, don't try to make the one to many rel.
    REL: foreach my $rel ($f_meta->relationships)
    {
      if($rel->type eq 'one to one' && !$rel->foreign_key)
      {
        my $skip = 1;

        my $col_map = $rel->column_map or next REL;

        foreach my $remote_col (values %$col_map)
        {
          $skip = 0  unless($key_cols->{$remote_col});
        }

        next FK  if($skip);
      }
    }

    my $cm = $self->convention_manager;

    # Also don't add add one to many relationships between a class
    # and one of its map classes
    if($cm->is_map_class($class))
    {
      $Debug && warn "$f_class - Refusing to make one to many relationship ",
                     "to map class to $class\n";
      next FK;
    }

    # XXX: skip of there's already a relationship with the same id

    # Add the one to many relationship to the foreign class
    my $name = $cm->auto_relationship_name_one_to_many($self->table, $class);

    unless($f_meta->relationship($name))
    {
      $Debug && warn "$f_class - Adding one to many relationship ",
                     "'$name' to $class\n";
      $f_meta->add_relationship($name =>
                                {
                                  type       => 'one to many',
                                  class      => $class,
                                  column_map => { reverse %$key_cols },
                                });
    }

    # Create the methods, preserving existing methods
    $f_meta->make_relationship_methods(name => $name, preserve_existing => 1);
  }

  return;
}

sub auto_init_many_to_many_relationships
{
  my($self, %args) = @_;

  my $class = $self->class;

  my $cm = $self->convention_manager;

  # Nevermind if this isn't a map class
  return  unless($cm->is_map_class($class));

  my @fks = $self->foreign_keys;

  # It's got to have just two foreign keys
  return  unless(@fks == 2);

  my $key_cols1 = $fks[0]->key_columns;
  my $key_cols2 = $fks[1]->key_columns;

  # Each foreign key must have key columns
  return  unless($key_cols1 && keys %$key_cols1 &&
                 $key_cols2 && keys %$key_cols2);

  my $map_class = $class;

  # Make many to many relationships in both foreign classes that go
  # through this map table
  PAIR: foreach my $pair ([ @fks ], [ reverse @fks ])
  {
    my($fk1, $fk2) = @$pair;

    my $class1 = $fk1->class;
    my $class2 = $fk2->class;

    # XXX: skip of there's already a relationship with the same id

    my $meta = $class1->meta;
    my $name = $cm->auto_foreign_key_to_relationship_name_plural($fk2);

    unless($meta->relationship($name))
    {
      $Debug && warn "$class1 - Adding many to many relationship '$name' ",
                     "through $map_class to $class2\n";
      $meta->add_relationship($name =>
                              {
                                type      => 'many to many',
                                map_class => $map_class,
                                map_from  => $fk1->name,
                                map_to    => $fk2->name,
                              });
    }

    # Create the methods, preserving existing methods
    $meta->make_relationship_methods(name => $name, preserve_existing => 1);
  }

  return;
}

sub auto_initialize
{
  my($self) = shift;
  my(%args) = @_;

  $self->allow_auto_initialization(1);

  $self->auto_init_columns(@_);
  $self->auto_init_primary_key_columns;
  $self->auto_init_unique_keys(@_);
  $self->auto_init_foreign_keys(@_);
  $self->auto_init_relationships(@_);
  $self->initialize;

  for(1 .. 2) # two passes are required to catch everything
  {
    $self->retry_deferred_foreign_keys;
    $self->retry_deferred_relationships;
    $self->retry_deferred_tasks;
  }

  unless($args{'stay_connected'})
  {
    my $meta_class = ref $self;
    $meta_class->clear_all_dbs;
  }

  $self->was_auto_initialized(1);

  return;
}

1;

__END__

KNOWN BUGS:

MySQL:

CHAR(6) column shows up as VARCHAR(6)
BIT(5)  column shows up as TINYINT(1) (MySQL 5.0.2 or earlier) 
BOOLEAN column shows up as TINYINT(1)
No native support for array types in MySQL
