package Rose::DB::Object::Manager;

use strict;

use Carp();

use Rose::DB::Object::Iterator;
use Rose::DB::Object::QueryBuilder qw(build_select);

use Rose::DB::Object::Constants qw(STATE_LOADING STATE_IN_DB);

# XXX: A value that is unlikely to exist in a primary key column value
use constant PK_JOIN => "\0\2,\3\0";

our $VERSION = '0.071';

our $Debug = 0;

#
# Class data
#

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar => [ 'error', 'total', 'error_mode' ],
);

__PACKAGE__->error_mode('fatal');

sub handle_error
{
  my($class, $object) = @_;

  my $mode = $class->error_mode;

  return  if($mode eq 'return');

  my $level = $Carp::CarpLevel;
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

sub object_class { }

sub default_manager_method_types { qw(objects iterator count delete update) }

sub make_manager_methods
{
  my($class) = shift;

  if(@_ == 1)
  {
    @_ = (methods => { $_[0] => [ $class->default_manager_method_types ] });
  }
  else
  {
    Carp::croak "make_manager_methods() called with an odd number of arguments"  
      unless(@_ % 2 == 0);
  }

  my %args = @_;

  my $calling_class  = ($class eq __PACKAGE__) ? (caller)[0] : $class;
  my $target_class   = $args{'target_class'} || $calling_class;
  my $object_class   = $args{'object_class'};
  my $class_invocant = UNIVERSAL::isa($target_class, __PACKAGE__) ? 
                         $target_class : __PACKAGE__;

  unless($object_class)
  {
    if(UNIVERSAL::isa($target_class, 'Rose::DB::Object::Manager'))
    {
      $object_class = $target_class->object_class;
    }

    if(!$object_class && UNIVERSAL::isa($target_class, 'Rose::DB::Object'))
    {
      $object_class = $target_class;
    }
  }

  unless($object_class)
  {
    Carp::croak "Could not determine object class.  Please pass a value for ",
                "the object_class parameter", 
                (UNIVERSAL::isa($target_class, 'Rose::DB::Object::Manager') ?
                 " or override the object_class() method in $target_class" : '');
  }

  if(!$args{'methods'})
  {
    unless($args{'base_name'})
    {
      Carp::croak "Missing methods parameter and base_name parameter. ",
                  "You must supply one or the other";
    }

    $args{'methods'} = 
    { 
      $args{'base_name'} => [ $class->default_manager_method_types ] 
    };
  }
  elsif($args{'base_name'})
  {
    Carp::croak "Please pass the methods parameter OR the base_name parameter, not both";
  }

  Carp::croak "Invalid 'methods' parameter - should be a hash ref"
    unless(ref $args{'methods'} eq 'HASH');

  while(my($name, $types) = each %{$args{'methods'}})
  {
    my $have_full_name = ($name =~ s/\(\)$//) ? 1 : 0;

    Carp::croak "Invalid value for the '$name' parameter"
      if(ref $types && ref $types ne 'ARRAY');

    if($have_full_name && ref $types && @$types > 1)
    {
      Carp::croak "Cannot use explicit method name $name() with more ",
                  "than one method type";
    }

    foreach my $type ((ref $types ? @$types : ($types)))
    {
      no strict 'refs';

      if($type eq 'objects')
      {
        my $method_name = 
          $have_full_name ? $name : "${target_class}::get_$name";

        foreach my $class ($target_class, $class_invocant)
        {
          my $method = "${class}::get_$name";
          Carp::croak "A $method method already exists"
            if(defined &{$method});
        }

        *{$method_name} = sub
        {
          shift;
          $class_invocant->get_objects(@_, object_class => $object_class);
        };
      }
      elsif($type eq 'count')
      {
        my $method_name =
          $have_full_name ? $name : "${target_class}::get_${name}_count";

        foreach my $class ($target_class, $class_invocant)
        {
          my $method = "${class}::get_${name}_count";
          Carp::croak "A $method method already exists"
            if(defined &{$method});
        }

        *{$method_name} = sub
        {
          shift;
          $class_invocant->get_objects(
            @_, count_only => 1, object_class => $object_class)
        };
      }
      elsif($type eq 'iterator')
      {
        my $method_name =
          $have_full_name ? $name : "${target_class}::get_${name}_iterator";

        foreach my $class ($target_class, $class_invocant)
        {
          my $method = "${class}::get_${name}_iterator";
          Carp::croak "A $method method already exists"
            if(defined &{$method});
        }

        *{$method_name} = sub
        {
          shift;
          $class_invocant->get_objects(
            @_, return_iterator => 1, object_class => $object_class)
        };
      }
      elsif($type eq 'delete')
      {
        my $method_name = 
          $have_full_name ? $name : "${target_class}::delete_$name";

        foreach my $class ($target_class, $class_invocant)
        {
          my $method = "${class}::delete_$name";
          Carp::croak "A $method method already exists"
            if(defined &{$method});
        }

        *{$method_name} = sub
        {
          shift;
          $class_invocant->delete_objects(@_, object_class => $object_class);
        };
      }
      elsif($type eq 'update')
      {
        my $method_name = 
          $have_full_name ? $name : "${target_class}::update_$name";

        foreach my $class ($target_class, $class_invocant)
        {
          my $method = "${class}::update_$name";
          Carp::croak "A $method method already exists"
            if(defined &{$method});
        }

        *{$method_name} = sub
        {
          shift;
          $class_invocant->update_objects(@_, object_class => $object_class);
        };
      }
      else
      {
        Carp::croak "Invalid method type: $type";
      }
    }
  }
}

sub get_objects_count
{
  my($class) = shift;
  $class->get_objects(@_, count_only => 1);
}

sub get_objects_iterator { shift->get_objects(@_, return_iterator => 1) }
sub get_objects_sql      { shift->get_objects(@_, return_sql => 1) }

sub get_objects
{
  my($class, %args) = @_;

  $class->error(undef);

  my $return_sql      = delete $args{'return_sql'};
  my $return_iterator = delete $args{'return_iterator'};
  my $object_class    = delete $args{'object_class'} or Carp::croak "Missing object class argument";
  my $count_only      = delete $args{'count_only'};
  my $require_objects = delete $args{'require_objects'};
  my $with_objects    = !$count_only ? delete $args{'with_objects'} : undef;
  my $skip_first      = delete $args{'skip_first'} || 0;
  my $distinct        = delete $args{'distinct'};
  my $fetch           = delete $args{'fetch_only'};
  my %fetch;

  my $db  = delete $args{'db'} || $object_class->init_db;
  my $dbh = delete $args{'dbh'};
  my $dbh_retained = 0;

  unless($dbh)
  {
    unless($dbh = $db->retain_dbh)
    {
      $class->error($db->error);
      $class->handle_error($class);
      return undef;
    }

    $dbh_retained = 1;
  }

  my $outer_joins_only = ($with_objects && !$require_objects) ? 1 : 0;

  my($num_required_objects, %required_object, 
     $num_with_objects, %with_objects);

  my $use_redundant_join_conditions = delete $args{'redundant_join_conditions'};

  if($with_objects)
  {
    unless(defined $use_redundant_join_conditions)
    {
      $use_redundant_join_conditions = $db->likes_redundant_join_conditions;
    }

    # Don't honor the with_objects parameter when counting, since the
    # count is of the rows from the "main" table (t1) only.
    if($count_only)
    {
      $with_objects = undef;
    }
    else
    {
      if(ref $with_objects) # copy argument (shallow copy)
      {
        $with_objects = [ @$with_objects ];
      }
      else
      {
        $with_objects = [ $with_objects ];
      }

      $num_with_objects = @$with_objects;
      %with_objects = map { $_ => 1 } @$with_objects;
    }
  }

  if($require_objects)
  {
    if(ref $require_objects) # copy argument (shallow copy)
    {
      $require_objects = [ @$require_objects ];
    }
    else
    {
      $require_objects = [ $require_objects ];
    }

    $num_required_objects = @$require_objects;
    %required_object = map { $_ => 1 } @$require_objects;
    push(@$with_objects, @$require_objects)
  }

  my %object_args = (ref $args{'object_args'} eq 'HASH') ? %{$args{'object_args'}} : ();
  my %subobject_args;

  $args{'share_db'} = 1  unless(exists $args{'share_db'});

  if(delete $args{'share_db'})
  {
    $object_args{'db'}    = $db;
    $subobject_args{'db'} = $db;
  }

  my $meta = $object_class->meta;

  my($fields, $fields_string, $table);

  my @tables  = ($meta->fq_table_sql);
  my %columns = ($tables[0] => scalar $meta->columns);#_names);
  my %classes = ($tables[0] => $object_class);
  my %methods = ($tables[0] => scalar $meta->column_mutator_method_names);
  my @classes = ($object_class);
  my %meta    = ($object_class => $meta);

  my @table_names = ($meta->table);

  my(@joins, @subobject_methods, $clauses);

  my $handle_dups = 0;
  my @has_dups;

  my $manual_limit = 0;

  my $num_subtables = $with_objects ? @$with_objects : 0;

  if($distinct || $fetch)
  {
    if($fetch && ref $distinct)
    {
      Carp::croak "The 'distinct' and 'fetch' parameters cannot be used ",
                  "together if they both contain lists of tables";
    }

    $args{'distinct'} = 1  if($distinct);

    %fetch = (t1 => 1, $tables[0] => 1, $meta->table => 1);

    if(ref $fetch || ref $distinct)
    {
      foreach my $arg (ref $distinct ? @$distinct : @$fetch)
      {
        $fetch{$arg} = 1;
      }
    }
  }

  if($with_objects)
  {
    # Copy clauses arg
    $clauses = $args{'clauses'} ? [ @{$args{'clauses'}} ] : [];

    my $i = 1;

    # Sanity check with_objects arguments, and determine if we're going to
    # have to handle duplicate data from multiple joins.  If so, note
    # which with_objects arguments refer to relationships that may return
    # more than one object.
    foreach my $name (@$with_objects)
    {
      my $key = $meta->foreign_key($name) || $meta->relationship($name);

      unless($key)
      {
        Carp::confess "$class - no foreign key or relationship named '$name'";
      }

      my $rel_type = $key->type;

      if(index($rel_type, 'many') >= 0)
      {
        $handle_dups  = 1;
        $has_dups[$i] = 1;

        # "many to many" relationships have an extra table (the mapping table)
        if($rel_type eq 'many to many')
        {
          $i++;
          $has_dups[$i] = 1;
          # $num_subtables will be incremented elsewhere (below)
        }

        if($args{'limit'})
        {
          $manual_limit = delete $args{'limit'};
        }

        # This restriction seems unnecessary now
        #if($required_object{$name} && $num_required_objects > 1 && $num_subtables > 1)
        #{
        #  Carp::croak 
        #    qq(The "require_objects" parameter cannot be used with ),
        #    qq(a "... to many" relationship ("$name" in this case) ),
        #    qq(unless that relationship is the only one listed and ),
        #    qq(the "with_objects" parameter is not used);
        #}
      }

      $i++;
    }

    unless($args{'multi_many_ok'})
    {
      if(scalar(grep { defined $_ } @has_dups) > 1)
      {
        Carp::carp
          qq(WARNING: Fetching sub-objects via more than one ),
          qq("one to many" relationship in a single query may ),
          qq(produce many redundant rows, and the query may be ),
          qq(slow.  If you're sure you want to do this, you can ),
          qq(silence this warning by using the "multi_many_ok" ),
          qq(parameter);
      }
    }

    $i = 1; # reset iterator for second pass through with_objects

    # Build lists of columns, classes, methods, and join conditions for all
    # of the with_objects and/or require_objects arguments.
    foreach my $name (@$with_objects)
    {
      my $rel = $meta->foreign_key($name) || $meta->relationship($name);

      my $rel_type = $rel->type;

      if($rel_type eq 'foreign key' || $rel_type eq 'one to one' ||
         $rel_type eq 'one to many')
      {
        my $ft_class = $rel->class 
          or Carp::confess "$class - Missing foreign object class for '$name'";

        my $ft_columns = $rel->key_columns 
          or Carp::confess "$class - Missing key columns for '$name'";

        my $ft_meta = $ft_class->meta; 

        $meta{$ft_class} = $ft_meta;

        push(@tables, $ft_meta->fq_table_sql);
        push(@table_names, $ft_meta->table);
        push(@classes, $ft_class);

        # Iterator will be the tN value: the first sub-table is t2, and so on
        $i++;

        $columns{$tables[-1]} = $ft_meta->columns;#_names;
        $classes{$tables[-1]} = $ft_class;
        $methods{$tables[-1]} = $ft_meta->column_mutator_method_names;

        $subobject_methods[$i - 1] = 
          $rel->method_name('get_set') ||
          $rel->method_name('get_set_now') ||
          $rel->method_name('get_set_on_save') ||
          Carp::confess "No 'get_set', 'get_set_now', or 'get_set_on_save' ",
                        "method found for relationship '$name' in class ",
                        "$class";

        # Reset each() iterator
        keys(%$ft_columns);

        my(@redundant, @redundant_null);

        # Add join condition(s)
        while(my($local_column, $foreign_column) = each(%$ft_columns))
        {
          # Use outer joins to handle duplicate or optional information.
          # Foreign keys that have all non-null columns are never outer-
          # joined, however.
          if(!($rel_type eq 'foreign key' && $rel->is_required) &&
             ($outer_joins_only || $with_objects{$name}))
          {
            # Aliased table names
            push(@{$joins[$i]{'conditions'}}, "t1.$local_column = t$i.$foreign_column");

            # Fully-qualified table names
            #push(@{$joins[$i]{'conditions'}}, "$tables[0].$local_column = $tables[-1].$foreign_column");

            $joins[$i]{'type'} = 'LEFT OUTER JOIN';

            # MySQL is stupid about using its indexes when "JOIN ... ON (...)"
            # conditions are the only ones given, so the code below adds some
            # redundant WHERE conditions.  They should not change the meaning
            # of the query, but should nudge MySQL into using its indexes. 
            # The clauses: "((<ON conditions>) OR (<any columns are null>))"
            # We build the two clauses separately in the loop below, then
            # combine it all after the loop is done.
            if($use_redundant_join_conditions)
            {
              # Aliased table names
              push(@redundant, "t1.$local_column = t$i.$foreign_column");
              push(@redundant_null, ($has_dups[$i - 1] ?
                   "t$i.$foreign_column IS NULL" :
                   "t1.$local_column IS NULL"));

              # Fully-qualified table names
              #push(@redundant, "$tables[0].$local_column = $tables[-1].$foreign_column");
              #push(@redundant_null, ($has_dups[$i - 1] ?
              #     "$tables[-1].$foreign_column IS NULL" :
              #     "$tables[0].$local_column IS NULL"));
            }
          }
          else
          {
            # Aliased table names
            push(@$clauses, "t1.$local_column = t$i.$foreign_column");

            # Fully-qualified table names
            #push(@$clauses, "$tables[0].$local_column = $tables[-1].$foreign_column");
          }
        }

        if(@redundant)
        {
          push(@$clauses, '((' . join(' AND ', @redundant) . ') OR (' .
                          join(' OR ', @redundant_null) . '))');
        }

        # Add sub-object sort conditions
        if($rel->can('manager_args') && (my $mgr_args = $rel->manager_args))
        {
          # Don't bother sorting by columns if we're not even selecting them
          if($mgr_args->{'sort_by'} && (!%fetch || 
             ($fetch{$tables[-1]} && !$fetch{$table_names[-1]})))
          {
            if($args{'sort_by'})
            {
              $args{'sort_by'} .= ", $mgr_args->{'sort_by'}";
            }
            else
            {
              $args{'sort_by'} = $mgr_args->{'sort_by'};
            }
          }
        }
      }
      elsif($rel_type eq 'many to many')
      {
        #
        # First add table, columns, and clauses for the map table itself
        #

        my $map_class = $rel->map_class 
          or Carp::confess "$class - Missing map class for '$name'";

        my $map_meta = $map_class->meta; 

        $meta{$map_class} = $map_meta;

        push(@tables, $map_meta->fq_table_sql);
        push(@table_names, $map_meta->table);
        push(@classes, $map_class);

        $columns{$tables[-1]} = []; #$map_meta->columns;#_names;
        $classes{$tables[-1]} = $map_class;
        $methods{$tables[-1]} = []; #$map_meta->column_mutator_method_names;

        my $column_map = $rel->column_map;

        # Iterator will be the tN value: the first sub-table is t2, and so on.
        # Increase once for map table.
        $i++;

        # Add join condition(s)
        while(my($local_column, $foreign_column) = each(%$column_map))
        {
          # Use outer joins to handle duplicate or optional information.
          if($outer_joins_only || $with_objects{$name})
          {
            # Aliased table names
            push(@{$joins[$i]{'conditions'}}, "t$i.$local_column = t1.$foreign_column");

            # Fully-qualified table names
            #push(@{$joins[$i]{'conditions'}}, "$tables[-1].$local_column = $tables[0].$foreign_column");

            $joins[$i]{'type'} = 'LEFT OUTER JOIN';
          }
          else
          {
            # Aliased table names
            push(@$clauses, "t$i.$local_column = t1.$foreign_column");

            # Fully-qualified table names
            #push(@$clauses, "$tables[-1].$local_column = $tables[0].$foreign_column");
          }
        }

        #
        # Now add table, columns, and clauses for the foreign object
        #

        $num_subtables++; # Account for the extra table

        my $ft_class = $rel->foreign_class 
          or Carp::confess "$class - Missing foreign class for '$name'";

        my $ft_meta = $ft_class->meta; 
        $meta{$ft_class} = $ft_meta;

        my $map_to = $rel->map_to 
          or Carp::confess "Missing map_to value for relationship '$name' ",
                           "in clas $class";

        my $foreign_rel = 
          $map_meta->foreign_key($map_to)  || $map_meta->relationship($map_to) ||
            Carp::confess "No foreign key or relationship named '$map_to' ",
                          "found in $map_class";        

        my $ft_columns = $foreign_rel->key_columns 
          or Carp::confess "$ft_class - Missing key columns for '$map_to'";

        push(@tables, $ft_meta->fq_table_sql);
        push(@table_names, $ft_meta->table);
        push(@classes, $ft_class);

        $columns{$tables[-1]} = $ft_meta->columns;#_names;
        $classes{$tables[-1]} = $ft_class;
        $methods{$tables[-1]} = $ft_meta->column_mutator_method_names;

        # Iterator will be the tN value: the first sub-table is t2, and so on.
        # Increase again for foreign table.
        $i++;

        $subobject_methods[$i - 1] =
          $rel->method_name('get_set') ||
          $rel->method_name('get_set_now') ||
          $rel->method_name('get_set_on_save') ||
          Carp::confess "No 'get_set', 'get_set_now', or 'get_set_on_save' ",
                        "method found for relationship '$name' in class ",
                        "$class";

        # Reset each() iterator
        keys(%$ft_columns);

        # Add join condition(s)
        while(my($local_column, $foreign_column) = each(%$ft_columns))
        {
          # Use left joins if the map table used an outer join above
          if($outer_joins_only || $with_objects{$name})
          {
            # Aliased table names
            push(@{$joins[$i]{'conditions'}}, 't' . ($i - 1) . ".$local_column = t$i.$foreign_column");

            # Fully-qualified table names
            #push(@{$joins[$i]{'conditions'}}, "$tables[-2].$local_column = $tables[-1].$foreign_column");

            $joins[$i]{'type'} = 'LEFT JOIN';
          }
          else
          {
            # Aliased table names
            push(@$clauses, 't' . ($i - 1) . ".$local_column = t$i.$foreign_column");

            # Fully-qualified table names
            #push(@$clauses, "$tables[-2].$local_column = $tables[-1].$foreign_column");
          }
        }

        # Add sub-object sort conditions
        if($rel->can('manager_args') && (my $mgr_args = $rel->manager_args))
        {
          # Don't bother sorting by columns if we're not even selecting them
          if($mgr_args->{'sort_by'} && (!%fetch || 
             ($fetch{$tables[-1]} && !$fetch{$table_names[-1]})))
          {
            if($args{'sort_by'})
            {
              $args{'sort_by'} .= ", $mgr_args->{'sort_by'}";
            }
            else
            {
              $args{'sort_by'} = $mgr_args->{'sort_by'};
            }
          }
        }
      }
      else
      {
        Carp::croak "Don't know how to auto-join relationship '$name' of type '$rel_type'";
      }
    }

    $args{'clauses'} = $clauses; # restore clauses arg
  }

  # Flesh out list of fetch tables and cull columns for those tables
  if(%fetch)
  {
    foreach my $i (1 .. $#tables) # skip first table, which is always selected
    {
      unless($fetch{'t' . ($i + 1)} || $fetch{$tables[$i]} || $fetch{$table_names[$i]})
      {
        $columns{$tables[$i]} = [];
        $methods{$tables[$i]} = [];
      }
    }
  }

  if($count_only)
  {
    delete $args{'limit'};
    delete $args{'offset'};
    delete $args{'sort_by'};
          
    my($sql, $bind);

    my $use_distinct = 0; # Do we have to use DISTINCT to count?

    if($require_objects)
    {
      foreach my $name (@$require_objects)
      {
        # Ignore error here since it'll be caught and handled later anyway
        my $key = 
          $meta->foreign_key($name) || $meta->relationship($name) || next;

        my $rel_type = $key->type;

        if(index($key->type, 'many') >= 0)
        {
          $use_distinct = 1;
          last;
        }
      }
    }

    BUILD_SQL:
    {
      my $select = $use_distinct ? 'COUNT(DISTINCT ' .
        join(', ', map { "t1.$_" } $meta->primary_key_column_names) . ')' :
        'COUNT(*)';

      local $Carp::CarpLevel = $Carp::CarpLevel + 1;

      ($sql, $bind) =
        build_select(dbh     => $dbh,
                     select  => $select,
                     tables  => \@tables,
                     columns => \%columns,
                     classes => \%classes,
                     meta    => \%meta,
                     db      => $db,
                     pretty  => $Debug,
                     %args);
    }

    if($return_sql)
    {
      $db->release_dbh  if($dbh_retained);
      return wantarray ? ($sql, $bind) : $sql;
    }

    my $count = 0;

    eval
    {
      local $dbh->{'RaiseError'} = 1;
      $Debug && warn "$sql\n";
      my $sth = $dbh->prepare($sql, $meta->prepare_select_options) or die $dbh->errstr;
      $sth->execute(@$bind);
      $count = $sth->fetchrow_array;
      $sth->finish;
    };

    if($@)
    {
      $class->total(undef);
      $class->error("get_objects() - $@");
      $class->handle_error($class);
      return undef;
    }

    $class->total($count);
    return $count;
  }

  # Alter sort_by SQL, replacing table names with aliases.  This is to
  # prevent databases like Postgres from "adding missing FROM clause"s.
  # See: http://sql-info.de/postgresql/postgres-gotchas.html#1_5
  if((my $sort = $args{'sort_by'}) && $num_subtables > 0)
  {
    my $i = 0;

    foreach my $table (@tables)
    {
      $i++; # Table aliases are 1-based            
      $sort =~ s/\b$table\./t$i./g;
    }

    $args{'sort_by'} = $sort;
  }

  if(defined $args{'offset'})
  {
    Carp::croak "Offset argument is invalid without a limit argument"
      unless($args{'limit'} || $manual_limit);

    if($db->supports_limit_with_offset && !$manual_limit)
    {
      $args{'limit'} = $db->format_limit_with_offset($args{'limit'}, $args{'offset'});
      delete $args{'offset'};
      $skip_first = 0;
    }
    elsif($manual_limit)
    {
      $skip_first += delete $args{'offset'};
    }
    else
    {
      $skip_first += delete $args{'offset'};
      $args{'limit'} += $skip_first;
      $args{'limit'} = $db->format_limit_with_offset($args{'limit'});
    }
  }
  elsif($args{'limit'})
  {
    $args{'limit'} = $db->format_limit_with_offset($args{'limit'});
  }

  my($count, @objects, $iterator);

  my($sql, $bind);

  BUILD_SQL:
  {
    local $Carp::CarpLevel = $Carp::CarpLevel + 1;

    ($sql, $bind) =
      build_select(dbh     => $dbh,
                   tables  => \@tables,
                   columns => \%columns,
                   classes => \%classes,
                   joins   => \@joins,
                   meta    => \%meta,
                   db      => $db,
                   pretty  => $Debug,
                   %args);
  }

  if($return_sql)
  {
    $db->release_dbh  if($dbh_retained);
    return wantarray ? ($sql, $bind) : $sql;
  }

  eval
  {
    local $dbh->{'RaiseError'} = 1;

    $Debug && warn "$sql (", join(', ', @$bind), ")\n";
    my $sth = $dbh->prepare($sql, $meta->prepare_select_options) or die $dbh->errstr;

    $sth->{'RaiseError'} = 1;

    $sth->execute(@$bind);

    my %row;

    my $col_num   = 1;
    my $table_num = 0;

    foreach my $table (@tables)
    {
      my $class = $classes{$table};

      foreach my $column (@{$methods{$table}})
      {
        $sth->bind_col($col_num++, \$row{$class,$table_num}{$column});
      }

      $table_num++;
    }

    if($return_iterator)
    {
      $iterator = Rose::DB::Object::Iterator->new(active => 1);

      my $count = 0;

      # More trading of code duplication for performance: build custom
      # subroutines depending on how much work needs to be done for
      # each iteration.

      if($with_objects)
      {
        # Ug, we have to handle duplicate data due to "...to many" relationships
        # fetched via outer joins.
        if($handle_dups)
        {
          my(@seen, @sub_objects);

          my @pk_columns = $meta->primary_key_column_names;

          # Get list of primary key columns for each sub-table
          my @sub_pk_columns;

          foreach my $i (1 .. $num_subtables)
          {
            $sub_pk_columns[$i + 1] = [ $classes[$i]->meta->primary_key_column_names ];
          }

          my $last_object;

          $iterator->_next_code(sub
          {
            my($self) = shift;

            my $object = 0;
            my $object_is_ready = 0;
            my @objects;

            eval
            {
              ROW: for(;;)
              {
                last ROW  unless($sth);

                while($sth->fetch)
                {
                  my $pk = join(PK_JOIN, map { $row{$object_class,0}{$_} } @pk_columns);

                  # If this is a new main (t1) table row that we haven't seen before
                  unless($seen[0]{$pk}++)
                  {
                    # First, finish building the last object, if it exists
                    if($last_object)
                    {
                      #$Debug && warn "Finish $object_class $last_object->{'id'}\n";

                      foreach my $i (1 .. $num_subtables)
                      {
                        # We only need to assign to the attributes that can have N objects
                        # since we assigned the one-to-one object attributes earlier.
                        if($has_dups[$i])
                        {
                          # Mapping tables will have no subobject methods, so skip them
                          my $method = $subobject_methods[$i] or next;
                          local $last_object->{STATE_LOADING()} = 1;
                          $last_object->$method($sub_objects[$i]);
                        }
                      }

                      # Add the object to the final list of objects that we'll return
                      push(@objects, $last_object);

                      $object_is_ready = 1;
                    }

                    #$Debug && warn "Make $object_class $pk\n";

                    # Now, create the object from this new main table row
                    $object = $object_class->new(%object_args);

                    local $object->{STATE_LOADING()} = 1;
                    $object->init(%{$row{$object_class,0}});
                    $object->{STATE_IN_DB()} = 1;

                    $last_object = $object; # This is the "last object" from now on
                    @sub_objects = ();      # The list of sub-objects is per-object
                    splice(@seen, 1);       # Sub-objects seen is also per-object,
                                            # so trim it, but leave the t1 table info
                  }

                  $object ||= $last_object or die "Missing object for primary key '$pk'";

                  foreach my $i (1 .. $num_subtables)
                  {
                    my $class  = $classes[$i];
                    my $tn = $i + 1;

                    # Null primary key columns are not allowed
                    my $sub_pk = join(PK_JOIN, grep { defined } map { $row{$class,$i}{$_} } @{$sub_pk_columns[$tn]});
                    next  unless(length $sub_pk);

                    # Skip if we've already seen this sub-object
                    next  if($seen[$i]{$sub_pk}++);

                    # Make sub-object
                    my $subobject = $class->new(%subobject_args);
                    local $subobject->{STATE_LOADING()} = 1;
                    $subobject->init(%{$row{$class,$i}});
                    $subobject->{STATE_IN_DB()} = 1;

                    # If this object belongs to an attribute that can have more
                    # than one object then just save it for later in the
                    # per-object sub-objects list.
                    if($has_dups[$i])
                    {
                      push(@{$sub_objects[$i]}, $subobject);
                    }
                    else # Otherwise, just assign it
                    {
                      my $method = $subobject_methods[$i];
                      local $object->{STATE_LOADING()} = 1;
                      $object->$method($subobject);
                    }
                  }

                  if($skip_first)
                  {
                    next ROW  if($seen[0]{$pk} > 1);
                    ++$count  if($seen[0]{$pk} == 1);
                    next ROW  if($count <= $skip_first);

                    $skip_first = 0;
                    @objects = ();        # Discard all skipped objects...
                    $object_is_ready = 0; # ...so none are ready now
                    next ROW;
                  }

                  if($object_is_ready)
                  {
                    $self->{'_count'}++;
                    last ROW;
                  }

                  no warnings;
                  if($manual_limit && $self->{'_count'} == $manual_limit)
                  {
                    $iterator->finish;
                    last ROW;
                  }
                }

                # Handle the left-over "last object" that needs to be finished and
                # added to the final list of objects to return.
                if($last_object && !$object_is_ready)
                {
                  #$Debug && warn "Finish straggler $object_class $last_object->{'id'}\n";

                  foreach my $i (1 .. $num_subtables)
                  {
                    if($has_dups[$i])
                    {
                      # Mapping tables will have no subobject methods, so skip them
                      my $method = $subobject_methods[$i] or next;
                      local $last_object->{STATE_LOADING()} = 1;
                      $last_object->$method($sub_objects[$i]);
                    }
                  }

                  push(@objects, $last_object);

                  # Set everything up to return this object, then be done
                  $last_object = undef;
                  $self->{'_count'}++;
                  $sth = undef;
                  last ROW;
                }
                
                last ROW;
              }
            };

            if($@)
            {
              $self->error("next() - $@");
              $class->handle_error($self);
              return undef;
            }

            @objects = ()  if($skip_first);

            if(@objects)
            {
              no warnings; # undef count okay
              if($manual_limit && $self->{'_count'} == $manual_limit)
              {
                $self->total($self->{'_count'});
                $iterator->finish;
              }

              #$Debug && warn "Return $object_class $objects[-1]{'id'}\n";
              return shift(@objects);
            }

            $self->total($self->{'_count'});

            #$Debug && warn "Return 0\n";
            return 0;
          });

        }
        else # no duplicate rows to handle
        {
          $iterator->_next_code(sub
          {
            my($self) = shift;

            my $object = 0;

            eval
            {
              ROW: for(;;)
              {
                unless($sth->fetch)
                {
                  $self->total($self->{'_count'});
                  return 0;
                }

                next ROW  if($skip_first && ++$count <= $skip_first);

                $object = $object_class->new(%object_args);

                local $object->{STATE_LOADING()} = 1;
                $object->init(%{$row{$object_class,0}});
                $object->{STATE_IN_DB()} = 1;

                if($with_objects)
                {
                  foreach my $i (1 .. $num_subtables)
                  {
                    my $method = $subobject_methods[$i];
                    my $class  = $classes[$i];

                    my $subobject = $class->new(%subobject_args);
                    local $subobject->{STATE_LOADING()} = 1;
                    $subobject->init(%{$row{$class,$i}});
                    $subobject->{STATE_IN_DB()} = 1;

                    $object->$method($subobject);
                  }
                }

                $skip_first = 0;
                $self->{'_count'}++;
                last ROW;
              }
            };

            if($@)
            {
              $self->error("next() - $@");
              $class->handle_error($self);
              return undef;
            }

            return $skip_first ? undef : $object;
          });
        }
      }
      else # no sub-objects at all
      {
        $iterator->_next_code(sub
        {
          my($self) = shift;

          my $object = 0;

          eval
          {
            ROW: for(;;)
            {
              unless($sth->fetch)
              {
                $self->total($self->{'_count'});
                return 0;
              }

              next ROW  if($skip_first && ++$count <= $skip_first);

              $object = $object_class->new(%object_args);

              local $object->{STATE_LOADING()} = 1;
              $object->init(%{$row{$object_class,0}});
              $object->{STATE_IN_DB()} = 1;

              $skip_first = 0;
              $self->{'_count'}++;
              last ROW;
            }
          };

          if($@)
          {
            $self->error("next() - $@");
            $class->handle_error($self);
            return undef;
          }

          return $object;
        });
      }

      $iterator->_finish_code(sub
      {
        $sth->finish      if($sth);
        $db->release_dbh  if($dbh_retained);
        $sth = undef;
      });

      return $iterator;
    }

    $count = 0;

    if($with_objects)
    {
      # This "if" clause is a totally separate code path for handling
      # duplicates rows.  I'm doing this for performance reasons.
      if($handle_dups)
      {
        my(@seen, @sub_objects);

        my @pk_columns = $meta->primary_key_column_names;

        # Get list of primary key columns for each sub-table
        my @sub_pk_columns;

        foreach my $i (1 .. $num_subtables)
        {
          $sub_pk_columns[$i + 1] = [ $classes[$i]->meta->primary_key_column_names ];
        }

        my $last_object;

        ROW: while($sth->fetch)
        {
          my $pk = join(PK_JOIN, map { $row{$object_class,0}{$_} } @pk_columns);

          my $object;

          # If this is a new main (t1) table row that we haven't seen before
          unless($seen[0]{$pk}++)
          {
            # First, finish building the last object, if it exists
            if($last_object)
            {
              foreach my $i (1 .. $num_subtables)
              {
                # We only need to assign to the attributes that can have N objects
                # since we assigned the one-to-one object attributes earlier.
                if($has_dups[$i])
                {
                  # Mapping tables will have no subobject methods, so skip them
                  my $method = $subobject_methods[$i] or next;
                  local $last_object->{STATE_LOADING()} = 1;
                  $last_object->$method($sub_objects[$i]);
                }
              }

              # Add the object to the final list of objects that we'll return
              push(@objects, $last_object);

              if(!$skip_first && $manual_limit && @objects == $manual_limit)
              {
                last ROW;
              }
            }

            # Now, create the object from this new main table row
            $object = $object_class->new(%object_args);

            local $object->{STATE_LOADING()} = 1;
            $object->init(%{$row{$object_class,0}});
            $object->{STATE_IN_DB()} = 1;

            $last_object = $object; # This is the "last object" from now on
            @sub_objects = ();      # The list of sub-objects is per-object
            splice(@seen, 1);       # Sub-objects seen is also per-object,
                                    # so trim it, but leave the t1 table info
          }

          $object ||= $last_object or die "Missing object for primary key '$pk'";

          foreach my $i (1 .. $num_subtables)
          {
            my $class  = $classes[$i];
            my $tn = $i + 1;

            # Null primary key columns are not allowed
            my $sub_pk = join(PK_JOIN, grep { defined } map { $row{$class,$i}{$_} } @{$sub_pk_columns[$tn]});
            next  unless(length $sub_pk);

            # Skip if we've already seen this sub-object
            next  if($seen[$i]{$sub_pk}++);

            # Make sub-object
            my $subobject = $class->new(%subobject_args);
            local $subobject->{STATE_LOADING()} = 1;
            $subobject->init(%{$row{$class,$i}});
            $subobject->{STATE_IN_DB()} = 1;

            # If this object belongs to an attribute that can have more
            # than one object then just save it for later in the
            # per-object sub-objects list.
            if($has_dups[$i])
            {
              push(@{$sub_objects[$i]}, $subobject);
            }
            else # Otherwise, just assign it
            {
              my $method = $subobject_methods[$i];
              local $object->{STATE_LOADING()} = 1;
              $object->$method($subobject);
            }
          }

          if($skip_first)
          {
            next ROW  if($seen[0]{$pk} > 1);
            next ROW  if(@objects < $skip_first);

            $skip_first = 0;
            @objects = (); # Discard all skipped objects
            next ROW;
          }
        }

        # Handle the left-over "last object" that needs to be finished and
        # added to the final list of objects to return.
        if($last_object && !$skip_first)
        {
          foreach my $i (1 .. $num_subtables)
          {
            if($has_dups[$i])
            {
              # Mapping tables will have no subobject methods, so skip them
              my $method = $subobject_methods[$i] or next;
              local $last_object->{STATE_LOADING()} = 1;
              $last_object->$method($sub_objects[$i]);
            }
          }

          unless($manual_limit && @objects >= $manual_limit)
          {
            push(@objects, $last_object);
          }
        }
        
        @objects = ()  if($skip_first);
      }
      else # simple sub-objects case: nothing worse than one-to-one relationships
      {
        if($skip_first)
        {
          while($sth->fetch)
          {
            next  if(++$count < $skip_first);
            last;
          }
        }

        while($sth->fetch)
        {
          my $object = $object_class->new(%object_args);

          local $object->{STATE_LOADING()} = 1;
          $object->init(%{$row{$object_class,0}});
          $object->{STATE_IN_DB()} = 1;

          foreach my $i (1 .. $num_subtables)
          {
            my $method = $subobject_methods[$i];
            my $class  = $classes[$i];

            my $subobject = $class->new(%subobject_args);
            local $subobject->{STATE_LOADING()} = 1;
            $subobject->init(%{$row{$class,$i}});
            $subobject->{STATE_IN_DB()} = 1;

            $object->$method($subobject);
          }

          push(@objects, $object);
        }
      }
    }
    else # even simpler: no sub-objects at all
    {
      if($skip_first)
      {
        while($sth->fetch)
        {
          next  if(++$count < $skip_first);
          last;
        }
      }

      while($sth->fetch)
      {
        my $object = $object_class->new(%object_args);

        local $object->{STATE_LOADING()} = 1;
        $object->init(%{$row{$object_class,0}});
        $object->{STATE_IN_DB()} = 1;

        push(@objects, $object);
      }
    }

    $sth->finish;
  };

  return $iterator  if($iterator);

  $db->release_dbh  if($dbh_retained);

  if($@)
  {
    $class->error("get_objects() - $@");
    $class->handle_error($class);
    return undef;
  }

  return \@objects;
}

sub _map_action
{
  my($class, $action, @objects) = @_;

  $class->error(undef);

  foreach my $object (@objects)
  {
    unless($object->$action())
    {
      $class->error($object->error);
      $class->handle_error($class);
      return;
    }
  }

  return 1;
}

sub save_objects   { shift->_map_action('save', @_)   }

sub delete_objects
{
  my($class, %args) = @_;

  $class->error(undef);

  $args{'query'} = delete $args{'where'};

  my $object_class = $args{'object_class'} or Carp::croak "Missing object class argument";

  unless(($args{'query'} && @{$args{'query'}}) || delete $args{'all'})
  {
    Carp::croak "$class - Refusing to delete all rows from the table '",
                $object_class->meta->fq_table_sql, "' without an explict ",
                "'all => 1' parameter";
  }

  if($args{'query'} && @{$args{'query'}} && $args{'all'})
  {
    Carp::croak "Illegal use of the 'where' and 'all' parameters in the same call";
  }

  my $db  = $args{'db'} || $object_class->init_db;
  my $dbh = $args{'dbh'};
  my $dbh_retained = 0;

  unless($dbh)
  {
    unless($dbh = $db->retain_dbh)
    {
      $class->error($db->error);
      $class->handle_error($class);
      return undef;
    }

    $args{'dbh'} = $dbh;
    $dbh_retained = 1;
  }

  my $meta = $object_class->meta;

  # Yes, I'm re-using get_objects() code like crazy, and often
  # in weird ways.  Shhhh, it's a secret.

  my($where, $bind) = 
    $class->get_objects(%args, return_sql => 1, where_only => 1);

  my $sql = 'DELETE FROM ' . $meta->fq_table_sql .
            ($where ? " WHERE\n$where" : '');

  my $count;

  eval
  {
    local $dbh->{'RaiseError'} = 1;  
    $Debug && warn "$sql - bind params: ", join(', ', @$bind), "\n";

    my $sth = $dbh->prepare($sql, $meta->prepare_bulk_delete_options) 
      or die $dbh->errstr;

    $sth->execute(@$bind);
    $count = $sth->rows || 0;
  };

  if($@)
  {
    $class->error("delete_objects() - $@");
    $class->handle_error($class);
    return undef;
  }

  return $count;
}

sub update_objects
{
  my($class, %args) = @_;

  $class->error(undef);

  my $object_class = $args{'object_class'} 
    or Carp::croak "Missing object class argument";

  unless(($args{'where'} && @{$args{'where'}}) || delete $args{'all'})
  {
    Carp::croak "$class - Refusing to update all rows in the table '",
                $object_class->meta->fq_table_sql, "' without an explict ",
                "'all => 1' parameter";
  }

  if($args{'where'} && @{$args{'where'}} && $args{'all'})
  {
    Carp::croak "Illegal use of the 'where' and 'all' parameters in the same call";
  }

  my $where = delete $args{'where'};
  my $set   = delete $args{'set'} 
    or Carp::croak "Missing requires 'set' parameter";

  $set = [ %$set ]  if(ref $set eq 'HASH');

  my $db  = $args{'db'} || $object_class->init_db;
  my $dbh = $args{'dbh'};
  my $dbh_retained = 0;

  unless($dbh)
  {
    unless($dbh = $db->retain_dbh)
    {
      $class->error($db->error);
      $class->handle_error($class);
      return undef;
    }

    $args{'dbh'} = $dbh;
    $dbh_retained = 1;
  }

  my $meta = $object_class->meta;

  # Yes, I'm re-using get_objects() code like crazy, and often
  # in weird ways.  Shhhh, it's a secret.

  $args{'query'} = $set;

  my($set_sql, $set_bind) = 
    $class->get_objects(%args, return_sql => 1, where_only => 1, logic => ',', set => 1);

  my $sql;

  my $where_bind = [];

  if($args{'query'} = $where)
  {
    my $where_sql;

    ($where_sql, $where_bind) = 
      $class->get_objects(%args, return_sql => 1, where_only => 1);

    $sql = 'UPDATE ' . $meta->fq_table_sql . 
           "\nSET\n$set_sql\nWHERE\n$where_sql";
  }
  else
  {
    $sql = 'UPDATE ' . $meta->fq_table_sql . "\nSET\n$set_sql";
  }

  my $count;

  eval
  {
    local $dbh->{'RaiseError'} = 1;  
    $Debug && warn "$sql\n";

    my $sth = $dbh->prepare($sql, $meta->prepare_bulk_update_options) 
      or die $dbh->errstr;

    $sth->execute(@$set_bind, @$where_bind);
    $count = $sth->rows || 0;
  };

  if($@)
  {
    $class->error("update_objects() - $@");
    $class->handle_error($class);
    return undef;
  }

  return $count;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Manager - Fetch multiple Rose::DB::Object-derived objects from the database using complex queries.

=head1 SYNOPSIS

  ##
  ## Given the following Rose::DB::Object-derived classes...
  ##

  package Category;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  __PACKAGE__->meta->table('categories');

  __PACKAGE__->meta->columns
  (
    id          => { type => 'int', primary_key => 1 },
    name        => { type => 'varchar', length => 255 },
    description => { type => 'text' },
  );

  __PACKAGE__->meta->add_unique_key('name');
  __PACKAGE__->meta->initialize;

  ...

  package CodeName;

  use Product;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  __PACKAGE__->meta->table('code_names');

  __PACKAGE__->meta->columns
  (
    id          => { type => 'int', primary_key => 1 },
    product_id  => { type => 'int' },
    name        => { type => 'varchar', length => 255 },
    applied     => { type => 'date', not_null => 1 },
  );

  __PACKAGE__->foreign_keys
  (
    product =>
    {
      class       => 'Product',
      key_columns => { product_id => 'id' },
    },
  );

  __PACKAGE__->meta->initialize;

  ...

  package Product;

  use Category;
  use CodeName;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  __PACKAGE__->meta->table('products');

  __PACKAGE__->meta->columns
  (
    id          => { type => 'int', primary_key => 1 },
    name        => { type => 'varchar', length => 255 },
    description => { type => 'text' },
    category_id => { type => 'int' },
    region_num  => { type => 'int' },

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

  __PACKAGE__->meta->add_unique_key('name');

  __PACKAGE__->meta->foreign_keys
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

  __PACKAGE__->meta->relationships
  (
    code_names =>
    {
      type  => 'one to many',
      class => 'CodeName',
      column_map   => { id => 'product_id' },
      manager_args => 
      {
        sort_by => CodeName->meta->table . '.applied DESC',
      },
    }
  );

  __PACKAGE__->meta->initialize;

  ...

  ##
  ## Create a manager class
  ##

  package Product::Manager;

  use Rose::DB::Object::Manager;
  our @ISA = qw(Rose::DB::Object::Manager);

  sub object_class { 'Product' }

  __PACKAGE__->make_manager_methods('products');

  # The call above creates the methods shown below.  (The actual 
  # method bodies vary slightly, but this is the gist of it...)
  #
  # sub get_products
  # {
  #   shift->get_objects(@_, object_class => 'Product');
  # }
  #
  # sub get_products_iterator
  # {
  #   shift->get_objects_iterator(@_, object_class => 'Product');
  # }
  #
  # sub get_products_count
  # {
  #   shift->get_objects_count(@_, object_class => 'Product');
  # }
  #
  # sub update_products
  # {
  #   shift->update_objects(@_, object_class => 'Product');
  # }
  #
  # sub delete_products
  # {
  #   shift->delete_objects(@_, object_class => 'Product');
  # }

  ...

  ##
  ## Use the manager class
  ##

  #
  # Get a reference to an array of objects
  #

  $products = 
    Product::Manager->get_products
    (
      query =>
      [
        category_id => [ 5, 7, 22 ],
        status      => 'active',
        start_date  => { lt => '15/12/2005 6:30 p.m.' },
        name        => { like => [ '%foo%', '%bar%' ] },
      ],
      sort_by => 'category_id, start_date DESC',
      limit   => 100,
      offset  => 80,
    );

  foreach my $product (@$products)
  {
    print $product->id, ' ', $product->name, "\n";
  }

  #
  # Get objects iterator
  #

  $iterator = 
    Product::Manager->get_products_iterator
    (
      query =>
      [
        category_id => [ 5, 7, 22 ],
        status      => 'active',
        start_date  => { lt => '15/12/2005 6:30 p.m.' },
        name        => { like => [ '%foo%', '%bar%' ] },
      ],
      sort_by => 'category_id, start_date DESC',
      limit   => 100,
      offset  => 80,
    );

  while($product = $iterator->next)
  {
    print $product->id, ' ', $product->name, "\n";
  }

  print $iterator->total;

  #
  # Get objects count
  #

  $count =
    Product::Manager->get_products_count
    (
      query =>
      [
        category_id => [ 5, 7, 22 ],
        status      => 'active',
        start_date  => { lt => '15/12/2005 6:30 p.m.' },
        name        => { like => [ '%foo%', '%bar%' ] },
      ],
    ); 

   die Product::Manager->error  unless(defined $count);

  print $count; # or Product::Manager->total()

  #
  # Get objects and sub-objects in a single query
  #

  $products = 
    Product::Manager->get_products
    (
      with_objects => [ 'category', 'code_names' ],
      query =>
      [
        category_id => [ 5, 7, 22 ],
        status      => 'active',
        start_date  => { lt => '15/12/2005 6:30 p.m.' },

        # We need to disambiguate the "name" column below since it
        # appears in more than one table referenced by this query. 
        # When more than one table is queried, the tables have numbered
        # aliases starting from the "main" table ("products").  The
        # "products" table is t1, "categories" is t2, and "code_names"
        # is t3.  You can read more about automatic table aliasing in
        # the documentation for the get_objects() method below.

        't1.name'   => { like => [ '%foo%', '%bar%' ] },
      ],
      sort_by => 'category_id, start_date DESC',
      limit   => 100,
      offset  => 80,
    );

  foreach my $product (@$products)
  {
    # The call to $product->category does not hit the database
    print $product->name, ': ', $product->category->name, "\n";

    # The call to $product->code_names does not hit the database
    foreach my $code_name ($product->code_names)
    {
      # This call doesn't hit the database either
      print $code_name->name, "\n";
    }
  }

  #
  # Update objects
  #

  $num_rows_updated =
    Product::Manager->update_products(
      set =>
      {
        end_date   => DateTime->now,
        region_num => { sql => 'region_num * -1' }
        status     => 'defunct',
      },
      where =>
      [
        start_date => { lt => '1/1/1980' },
        status     => [ 'active', 'pending' ],
      ]);

  #
  # Delete objects
  #

  $num_rows_deleted =
    Product::Manager->delete_products(
      where =>
      [
        status  => [ 'stale', 'old' ],
        name    => { like => 'Wax%' }
        or =>
        [
          start_date => { gt => '2008-12-30' },
          end_date   => { gt => 'now' },
        ],
      ]);

=head1 DESCRIPTION

C<Rose::DB::Object::Manager> is a base class for classes that select rows from tables fronted by L<Rose::DB::Object>-derived classes.  Each row in the table(s) queried is converted into the equivalent L<Rose::DB::Object>-derived object.

Class methods are provided for fetching objects all at once, one at a time through the use of an iterator, or just getting the object count.  Subclasses are expected to create syntactically pleasing wrappers for C<Rose::DB::Object::Manager> class methods, either manually or with the L<make_manager_methods|/make_manager_methods> method.  A very minimal example is shown in the L<synopsis|/SYNOPSIS> above.

=head1 CLASS METHODS

=over 4

=item B<delete_objects [PARAMS]>

Delete rows from a table fronted by a L<Rose::DB::Object>-derived class based on PARAMS, where PARAMS are name/value pairs.  Returns the number of rows deleted, or undef if there was an error.

Valid parameters are:

=over 4

=item C<all BOOL>

If set to a true value, this parameter indicates an explicit request to delete all rows from the table.  If both the C<all> and the C<where> parameters are passed, a fatal error will occur.

=item C<db DB>

A L<Rose::DB>-derived object used to access the database.  If omitted, one will be created by calling the L<init_db|Rose::DB::Object/init_db> object method of the C<object_class>.

=item C<object_class CLASS>

The name of the L<Rose::DB::Object>-derived class that fronts the table from which rows are to be deleted.  This parameter is required; a fatal error will occur if it is omitted.

=item C<where PARAMS>

The query parameters, passed as a reference to an array of name/value pairs.  These PARAMS are used to formulate the "where" clause of the SQL query that is used to delete the rows from the table.  Arbitrarily nested boolean logic is supported.

For the complete list of valid parameter names and values, see the documentation for the C<query> parameter of the L<build_select|Rose::DB::Object::QueryBuilder/build_select> function in the L<Rose::DB::Object::QueryBuilder> module.

If this parameter is omitted, this method will refuse to delete all rows from the table and a fatal error will occur.  To delete all rows from a table, you must pass the C<all> parameter with a true value.  If both the C<all> and the C<where> parameters are passed, a fatal error will occur.

=back

=item B<error>

Returns the text message associated with the last error, or false if there was no error.

=item B<error_mode [MODE]>

Get or set the error mode for this class.  The error mode determines what happens when a method of this class encounters an error.  The default setting is "fatal", which means that methods will L<croak|Carp/croak> if they encounter an error.

B<PLEASE NOTE:> The error return values described in the method documentation in the rest of this document are only relevant when the error mode is set to something "non-fatal."  In other words, if an error occurs, you'll never see any of those return values if the selected error mode L<die|perlfunc/die>s or L<croak|Carp/croak>s or otherwise throws an exception when an error occurs.

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

Return a value that indicates that an error has occurred, as described in the documentation for each method.

=back

In all cases, the class's C<error> attribute will also contain the error message.

=item B<get_objects [PARAMS]>

Get L<Rose::DB::Object>-derived objects based on PARAMS, where PARAMS are name/value pairs.  Returns a reference to a (possibly empty) array in scalar context, a list of objects in list context, or undef if there was an error.  

Note that naively calling this method in list context may result in a list containing a single undef element if there was an error.  Example:

    # If there is an error, you'll get: @objects = (undef)
    @objects = Rose::DB::Object::Manager->get_objects(...);

If you want to avoid this, feel free to change the behavior in your wrapper method, or just call it in scalar context (which is more efficient anyway for long lists of objects).

Each table that participates in the query will be aliased.  Each alias is in the form "tN" where "N" is an ascending number starting with 1.  The tables are numbered as follows.

=over 4

=item * The primary table is always "t1"

=item * The table(s) that correspond to each relationship or foreign key named in the C<with_objects> parameter are numbered in order, starting with "t2"

=item * The table(s) that correspond to each relationship or foreign key named in the C<require_objects> parameter are numbered in order, starting where the C<with_objects> table aliases left off.

=back

"Many to many" relationships have two corresponding tables, and therefore will use two "tN" numbers.  All other supported of relationship types only have just one table and will therefore use a single "tN" number.

For example, imagine that the C<Product> class shown in the L<synopsis|/SYNOPSIS> also has a "many to many" relationship named "colors."  Now consider this call:

    $products = 
      Product::Manager->get_products(
        require_objects => [ 'category' ],
        with_objects    => [ 'code_names', 'colors' ],
        multi_many_ok   => 1,
        query           => [ status => 'defunct' ],
        sort_by         => 't1.name');

The "products" table is "t1" since it's the primary table--the table behind the C<Product> class that C<Product::Manager> manages.  Next, the C<with_objects> tables are aliased.  The "code_names" table is "t2".  Since "colors" is a "many to many" relationship, it gets two numbers: "t3" and "t4".  Finally, the C<require_objects> tables are numbered: the table behind the foreign key "category" is "t5".  Here's an annotated version of the example above:

    # Table aliases in the comments
    $products = 
      Product::Manager->get_products(
                           # t5
        require_objects => [ 'category' ],
                           # t2            t3, t4
        with_objects    => [ 'code_names', 'colors' ],
        multi_many_ok   => 1,
        query           => [ status => 'defunct' ],
        sort_by         => 't1.name'); # "products" is "t1"

Also note that the C<multi_many_ok> parameter was used in order to supress the warning that occurs when more than one "... to many" relationship is included in the combination of C<require_objects> and C<with_objects> ("code_names" (one to many) and "colors" (many to many) in this case).  See the documentation for C<multi_many_ok> below.

The "tN" table aliases are for convenience, and to isolate end-user code from the actual table names.  Ideally, the actual table names should only exist in one place in the entire codebase: in the class definitions for each L<Rose::DB::OBject>-derived class.

That said, when using L<Rose::DB::Object::Manager>, the actual table names can be used as well.  But be aware that some databases don't like a mix of table aliases and real table names in some kinds of queries.

Valid parameters to C<get_objects()> are:

=over 4

=item C<db DB>

A L<Rose::DB>-derived object used to access the database.  If omitted, one will be created by calling the L<init_db|Rose::DB::Object/init_db> object method of the C<object_class>.

=item C<distinct [BOOL|ARRAYREF]>

If set to any kind of true value, then the "DISTINCT" SQL keyword will be added to the "SELECT" statement.  Specific values trigger the behaviors described below.

If set to a simple scalar value that is true, then only the columns in the primary table ("t1") are fetched from the database.

If set to a reference to an array of table names or "tN" table aliases, then only the columns from those tables will be fetched.  Columns from the primary table ("t1") are always selected, regardless of whether or not it appears in the list.

This parameter conflicts with the C<fetch_only> parameter in the case where both provide a list of table names or aliases.  In this case, if the value of the C<distinct> parameter is also reference to an array table names or aliases, then a fatal error will occur.

=item C<fetch_only [ARRAYREF]>

ARRAYREF should be a reference to an array of table names or "tN" table aliases. Only the columns from those tables will be fetched.  Columns from the primary table ("t1") are always selected, regardless of whether or not it appears in the list.

This parameter conflicts with the C<distinct> parameter in the case where both provide a list of table names or aliases.  In this case, then a fatal error will occur.

=item C<limit NUM>

Return a maximum of NUM objects.

=item C<multi_many_ok BOOL>

If true, do not print a warning when attempting to do multiple LEFT OUTER JOINs against tables related by "... to many" relationships.  See the documentation for the C<with_objects> parameter for more information.

=item C<object_args HASHREF>

A reference to a hash of name/value pairs to be passed to the constructor of each C<object_class> object fetched, in addition to the values from the database.

=item C<object_class CLASS>

The name of the L<Rose::DB::Object>-derived objects to be fetched.  This parameter is required; a fatal error will occur if it is omitted.

=item C<offset NUM>

Skip the first NUM rows.  If the database supports some sort of "limit with offset" syntax (e.g., "LIMIT 10 OFFSET 20") then it will be used.  Otherwise, the first NUM rows will be fetched and then discarded.

This parameter can only be used along with the C<limit> parameter, otherwise a fatal error will occur.

=item C<require_objects OBJECTS>

Only fetch rows from the primary table that have all of the associated sub-objects listed in OBJECTS, where OBJECTS is a reference to an array of L<foreign key|Rose::DB::Object::Metadata/foreign_keys> or L<relationship|Rose::DB::Object::Metadata/relationships> names defined for C<object_class>.  The supported relationship types are "L<one to one|Rose::DB::Object::Metadata::Relationship::OneToOne>," "L<one to many|Rose::DB::Object::Metadata::Relationship::OneToMany>," and  "L<many to many|Rose::DB::Object::Metadata::Relationship::ManyToMany>".

For each foreign key or relationship listed in OBJECTS, another table will be added to the query via an implicit inner join.  The join conditions will be constructed automatically based on the foreign key or relationship definitions.  Note that each related table must have a L<Rose::DB::Object>-derived class fronting it.

B<Note:> the C<require_objects> list currently cannot be used to simultaneously fetch two objects that both front the same database table, I<but are of different classes>.  One workaround is to make one class use a synonym or alias for one of the tables.  Another option is to make one table a trivial view of the other.  The objective is to get the table names to be different for each different class (even if it's just a matter of letter case, if your database is not case-sensitive when it comes to table names).

=item C<share_db BOOL>

If true, C<db> will be passed to each L<Rose::DB::Object>-derived object when it is constructed.  Defaults to true.

=item C<with_objects OBJECTS>

Also fetch sub-objects (if any) associated with rows in the primary table, where OBJECTS is a reference to an array of L<foreign key|Rose::DB::Object::Metadata/foreign_keys> or L<relationship|Rose::DB::Object::Metadata/relationships> names defined for C<object_class>.  The supported relationship types are "L<one to one|Rose::DB::Object::Metadata::Relationship::OneToOne>," "L<one to many|Rose::DB::Object::Metadata::Relationship::OneToMany>," and  "L<many to many|Rose::DB::Object::Metadata::Relationship::ManyToMany>".

For each foreign key or relationship listed in OBJECTS, another table will be added to the query via an explicit LEFT OUTER JOIN.  (Foreign keys whose columns are all NOT NULL are the exception, however.  They are always fetched via inner joins.)   The join conditions will be constructed automatically based on the foreign key or relationship definitions.  Note that each related table must have a L<Rose::DB::Object>-derived class fronting it.  See the L<synopsis|/SYNOPSIS> for an example.

"Many to many" relationships are a special case.  They will add two tables to the query (the "map" table plus the table with the actual data), which will offset the 

B<Warning:> there may be a geometric explosion of redundant data returned by the database if you include more than one "... to many" relationship in OBJECTS.  Sometimes this may still be more efficient than making additional queries to fetch these sub-objects, but that all depends on the actual data.  A warning will be emitted (via L<Carp::cluck|Carp/cluck>) if you you include more than one "... to many" relationship in OBJECTS.  If you're sure you know what you're doing, you can silence this warning by passing the C<multi_many_ok> parameter with a true value.

B<Note:> the C<with_objects> list currently cannot be used to simultaneously fetch two objects that both front the same database table, I<but are of different classes>.  One workaround is to make one class use a synonym or alias for one of the tables.  Another option is to make one table a trivial view of the other.  The objective is to get the table names to be different for each different class (even if it's just a matter of letter case, if your database is not case-sensitive when it comes to table names).

=item C<query PARAMS>

The query parameters, passed as a reference to an array of name/value pairs.  These PARAMS are used to formulate the "where" clause of the SQL query that, in turn, is used to fetch the objects from the database.  Arbitrarily nested boolean logic is supported.

For the complete list of valid parameter names and values, see the documentation for the C<query> parameter of the L<build_select|Rose::DB::Object::QueryBuilder/build_select> function in the L<Rose::DB::Object::QueryBuilder> module.

=back

=item B<get_objects_count [PARAMS]>

Accepts the same arguments as C<get_objects()>, but just returns the number of objects that would have been fetched, or undef if there was an error.

Note that the C<with_objects> parameter is ignored by this method, since it counts the number of primary objects, irrespective of how many sub-objects exist for each primary object.  If you want to count the number of primary objects that have sub-objects matching certain criteria, use the C<require_objects> parameter instead.

=item B<get_objects_iterator [PARAMS]>

Accepts any valid C<get_objects()> argument, but return a L<Rose::DB::Object::Iterator> object which can be used to fetch the objects one at a time, or undef if there was an error.

=item B<get_objects_sql [PARAMS]>

Accepts the same arguments as C<get_objects()>, but return the SQL query string that would have been used to fetch the objects (in scalar context), or the SQL query string and a reference to an array of bind values (in list context).

=item B<make_manager_methods PARAMS>

Create convenience wrappers for L<Rose::DB::Object::Manager>'s L<get_objects|/get_objects>, L<get_objects_iterator|/get_objects_iterator>, and L<get_objects_count|/get_objects_count> class methods in the target class.  These wrapper methods will not overwrite any existing methods in the target class.  If there is an existing method with the same name, a fatal error will occur.

PARAMS can take several forms, depending on the calling context.  For a call to L<make_manager_methods|/make_manager_methods> to succeed, the following information must be determined:

=over 4

=item * B<object class>

The class of the L<Rose::DB::Object>-derived objects to be fetched or counted.

=item * B<base name> or B<method name>

The base name is a string used as the basis of the method names.  For example, the base name "products" would be used to create methods named "get_B<products>", "get_B<products>_count", "get_B<products>_iterator", "delete_B<products>", and "update_B<products>".

In the absence of a base name, an explicit method name may be provided instead.  The method name will be used as is.

=item * B<method types>

The types of methods that should be generated.  Each method type is a wrapper for a L<Rose::DB::Object::Manager> class method.  The mapping of method type names to actual L<Rose::DB::Object::Manager> class methods is as follows:

    Type        Method
    --------    ----------------------
    objects     get_objects()
    iterator    get_objects_iterator()
    count       get_objects_count()
    delete      delete_objects()
    update      update_objects()

=item * B<target class>

The class that the methods should be installed in.

=back

Here are all of the different ways that each of those pieces of information can be provided, either implicitly or explicitly as part of PARAMS.

=over 4

=item * B<object class>

If an C<object_class> parameter is passed in PARAMS, then its value is used as the object class.  Example:

    $class->make_manager_methods(object_class => 'Product', ...);

If the C<object_class> parameter is not passed, and if the B<target class> inherits from L<Rose::DB::Object::Manager> and has also defined an C<object_class> method, then the return value of that method is used as the object class.  Example:

  package Product::Manager;

  use Rose::DB::Object::Manager;
  our @ISA = qw(Rose::DB::Object::Manager);

  sub object_class { 'Product' }

  # Assume object_class parameter is not part of the ... below
  __PACKAGE__->make_manager_methods(...);

In this case, the object class would be C<Product>.

Finally, if none of the above conditions are met, one final option is considered.  If the B<target class> inherits from L<Rose::DB::Object>, then the object class is set to the B<target class>.

If the object class cannot be determined in one of the ways described above, then a fatal error will occur.

=item * B<base name> or B<method name>

If a C<base_name> parameter is passed in PARAMS, then its value is used as the base name for the generated methods.  Example:

    $class->make_manager_methods(base_name => 'products', ...);

If the C<base_name> parameter is not passed, and if there is only one argument passed to the method, then the lone argument is used as the base name.  Example:

    $class->make_manager_methods('products');

(Note that, since the B<object class> must be derived somehow, this will only work in one of the situations (described above) where the B<object class> can be derived from the calling context or class.)

If a C<methods> parameter is passed with a hash ref value, then each key of the hash is used as the base name for the method types listed in the corresponding value.  (See B<method types> below for more information.)

If a key of the C<methods> hash ends in "()", then it is taken as the method name and is used as is.  For example, the key "foo" will be used as a base name, but the key "foo()" will be used as a method name.

If the base name cannot be determined in one of the ways described above, then a fatal error will occur.

=item * B<method types>

If a B<base name> is passed to the method, either as the value of the C<base_name> parameter or as the sole argument to the method call, then all of the method types are created: C<objects>, C<iterator>, and C<count>.  Example:

    # Base name is "products", all method types created
    $class->make_manager_methods('products');

    # Base name is "products", all method types created
    $class->make_manager_methods(base_name => products', ...);

(Again, note that the B<object class> must be derived somehow.)

If a C<methods> parameter is passed, then its value must be a reference to a hash whose keys are base names or method names, and whose values are method types or references to arrays of method types.

If a key ends in "()", then it is taken as a method name and is used as is.  Otherwise, it is used as a base name.  For example, the key "foo" will be used as a base name, but the key "foo()" will be used as a method name.

If a key is a method name and its value specifies more than one method type, then a fatal error will occur.  (It's impossible to have more than one method with the same name.)

Example:

    # Make the following methods:
    #
    # * Base name: products; method types: objects, iterators
    #
    #     get_products()
    #     get_products_iterator()
    #
    # * Method name: product_count; method type: count
    #
    #     product_count()
    #
    $class->make_manager_methods(...,
      methods =>
      {
        'products'        => [ qw(objects iterator) ],
        'product_count()' => 'count'
      });

If the value of the C<methods> parameter is not a reference to a hash, or if both (or neither of) the C<methods> and C<base_name> parameters are passed, then a fatal error will occur.

=item * B<target class>

If a C<target_class> parameter is passed in PARAMS, then its value is used as the target class.  Example:

    $class->make_manager_methods(target_class => 'Product', ...);

If a C<target_class> parameter is not passed, and if the calling class is not L<Rose::DB::Object::Manager>, then the calling class is used as the target class.  Otherwise, the class from which the method was called is used as the target class.  Examples:

    # Target class is Product, regardless of the calling
    # context or the value of $class
    $class->make_manager_methods(target_class => 'Product', ...);

    package Foo;

    # Target class is Foo: no target_class parameter is passed
    # and the calling class is Rose::DB::Object::Manager, so 
    # the class from which the method was called (Foo) is used.
    Rose::DB::Object::Manager->make_manager_methods(
      object_class => 'Bar',
      base_name    => 'Baz');

    package Bar;

    # Target class is Foo: no target_class parameter is passed 
    # and the calling class is not Rose::DB::Object::Manager,
    # so the calling class (Foo) is used.
    Foo->make_manager_methods(object_class => 'Bar',
                              base_name    => 'Baz');

=back

There's a lot of flexibility in this method's arguments (although some might use the word "confusion" instead), but the examples can be pared down to a few common usage scenarios.

The first is the recommended technique, as seen in the L<synopsis|/SYNOPSIS>. Create a separate manager class that inherits from L<Rose::DB::Object::Manager>, override the C<object_class> method to specify the class of the objects being fetched, and then pass a lone base name argument to the call to L<make_manager_methods|/make_manager_methods>.

  package Product::Manager;

  use Rose::DB::Object::Manager;
  our @ISA = qw(Rose::DB::Object::Manager);

  sub object_class { 'Product' }

  __PACKAGE__->make_manager_methods('products');

The second example is used to install object manager methods directly into a L<Rose::DB::Object>-derived class.  I do not recommend this practice; I consider it "semantically impure" for the class that represents a single object to also be the class that's used to fetch multiple objects.  Inevitably, classes grow, and I'd like the "object manager" class to be separate from the object class itself so they can grow happily in isolation, with no potential clashes.

Also, keep in mind that L<Rose::DB::Object> and L<Rose::DB::Object::Manager> have separate L<error_mode|/error_mode> settings which must be synchronized or otherwise dealt with.  Another advantage of using a separate L<Rose::DB::Object::Manager> subclass (as described earlier) is that you can override the L<error_mode|Rose::DB::Object::Manager/error_mode> in your L<Rose::DB::Object::Manager> subclass only, rather than overriding the base class L<Rose::DB::Object::Manager error_mode|Rose::DB::Object::Manager/error_mode>, which may affect other classes.

If none of that dissuades you, here's how to do it:

  package Product;

  use Rose::DB::Object:;
  our @ISA = qw(Rose::DB::Object);

  __PACKAGE__->make_manager_methods('products');

Finally, sometimes you don't want or need to use L<make_manager_methods|/make_manager_methods> at all.  In fact, this method did not exist in earlier versions of this module.  The formerly recommended way to use this class is  still perfectly valid: subclass it and then call through to the base class methods.

  package Product::Manager;

  use Rose::DB::Object::Manager;
  our @ISA = qw(Rose::DB::Object::Manager);

  sub get_products
  {
    shift->get_objects(object_class => 'Product', @_);
  }

  sub get_products_iterator
  {
    shift->get_objects_iterator(object_class => 'Product', @_);
  }

  sub get_products_count
  {
    shift->get_objects_count(object_class => 'Product', @_);
  }

  sub delete_products
  {
    shift->delete_objects(object_class => 'Product', @_);
  }

  sub update_products
  {
    shift->update_objects(object_class => 'Product', @_);
  }

Of course, these methods will all look very similar in each L<Rose::DB::Object::Manager>-derived class.  Creating these identically structured methods is exactly what L<make_manager_methods|/make_manager_methods> automates for you.  

But sometimes you want to customize these methods, in which case the "longhand" technique above becomes essential.  For example, imagine that we want to extend the code in the L<synopsis|/SYNOPSIS>, adding support for a C<with_categories> parameter to the C<get_products()> method.  

  Product::Manager->get_products(date_created    => '10/21/2001', 
                                 with_categories => 1);

  ...

  sub get_products
  {
    my($class, %args) @_;

    if(delete $args{'with_categories'}) # boolean flag
    {
      push(@{$args{'with_objects'}}, 'category');
    }

    Rose::DB::Object::Manager->get_objects(
      %args, object_class => 'Product')
  }

Here we've coerced the caller-friendly C<with_categories> boolean flag parameter into the C<with_objects =E<gt> [ 'category' ]> pair that L<Rose::DB::Object::Manager>'s L<get_objects|/get_objects> method can understand.

This is the typical evolution of an object manager method.  It starts out as being auto-generated by L<make_manager_methods|/make_manager_methods>, then becomes customized as new arguments are added.

=item B<update_objects [PARAMS]>

Update rows in a table fronted by a L<Rose::DB::Object>-derived class based on PARAMS, where PARAMS are name/value pairs.  Returns the number of rows updated, or undef if there was an error.

Valid parameters are:

=over 4

=item C<all BOOL>

If set to a true value, this parameter indicates an explicit request to update all rows in the table.  If both the C<all> and the C<where> parameters are passed, a fatal error will occur.

=item C<db DB>

A L<Rose::DB>-derived object used to access the database.  If omitted, one will be created by calling the L<init_db|Rose::DB::Object/init_db> object method of the C<object_class>.

=item C<object_class CLASS>

The class name of the L<Rose::DB::Object>-derived class that fronts the table whose rows will to be updated.  This parameter is required; a fatal error will occur if it is omitted.

=item C<set PARAMS>

The names and values of the columns to be updated.  PARAMS should be a reference to a hash.  Each key of the hash should be a column name or column get/set method name.  If a value is a simple scalar, then it is passed through the get/set method that services the column before being incorporated into the SQL query.

If a value is a reference to a hash, then it must contain a single key named "sql" and a corresponding value that will be incorporated into the SQL query as-is.  For example, this method call:

  $num_rows_updated =
    Product::Manager->update_products(
      set =>
      {
        end_date   => DateTime->now,
        region_num => { sql => 'region_num * -1' }
        status     => 'defunct',
      },
      where =>
      [
        status  => [ 'stale', 'old' ],
        name    => { like => 'Wax%' }
        or =>
        [
          start_date => { gt => '2008-12-30' },
          end_date   => { gt => 'now' },
        ],
      ]);

would produce the an SQL statement something like this (depending on the database vendor, and assuming the current date was September 20th, 2005):

    UPDATE products SET
      end_date   = '2005-09-20',
      region_num = region_num * -1,
      status     = 'defunct'
    WHERE
      status IN ('stale', 'old') AND
      name LIKE 'Wax%' AND
      (
        start_date > '2008-12-30' OR
        end_date   > '2005-09-20'
      )

=item C<where PARAMS>

The query parameters, passed as a reference to an array of name/value pairs.  These PARAMS are used to formulate the "where" clause of the SQL query that is used to update the rows in the table.  Arbitrarily nested boolean logic is supported.

For the complete list of valid parameter names and values, see the documentation for the C<query> parameter of the L<build_select|Rose::DB::Object::QueryBuilder/build_select> function in the L<Rose::DB::Object::QueryBuilder> module.

If this parameter is omitted, this method will refuse to update all rows in the table and a fatal error will occur.  To update all rows in a table, you must pass the C<all> parameter with a true value.  If both the C<all> and the C<where> parameters are passed, a fatal error will occur.

=back

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
