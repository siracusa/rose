package Rose::DB::Object::Manager;

use strict;

use Carp();

use Rose::DB::Object::Iterator;
use Rose::DB::Object::QueryBuilder qw(build_select);

use Rose::DB::Object::Constants qw(STATE_LOADING);

our $VERSION = '0.05';

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

sub make_manager_methods
{
  my($class) = shift;

  if(@_ == 1)
  {
    @_ = (methods => { $_[0] => [ qw(objects iterator count) ] });
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

    $args{'methods'} = { $args{'base_name'} => [ qw(objects iterator count) ] };
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
  my $with_objects    = delete $args{'with_objects'};
  my $skip_first      = delete $args{'skip_first'} || 0;
  my $count_only      = delete $args{'count_only'};

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

  if($with_objects)
  {
    my $clauses = $args{'clauses'} ||= [];

    my $i = 1;

    $with_objects = [ $with_objects ]  unless(ref $with_objects);

    foreach my $name (@$with_objects)
    {
      my $key = $meta->foreign_key($name);
      
      unless($key)
      {
        $key = $meta->relationship($name);

        unless($key && $key->isa('Rose::DB::Object::Metadata::Relationship') &&
           $key->type eq 'one to one')
        {
          $key = undef;
        }
      }
      
      unless($key)
      {
        Carp::confess "$class - no foreign key or one to one relationship named '$name'";
      }

      my $fk_class = $key->class or 
        Carp::confess "$class - Missing foreign object class for '$name'";

      my $fk_columns = $key->key_columns or 
        Carp::confess "$class - Missing key columns for '$name'";

      my $fk_meta = $fk_class->meta; 

      $meta{$fk_class} = $fk_meta;

      push(@tables, $fk_meta->fq_table_sql);
      push(@classes, $fk_class);
      $i++;

      $columns{$tables[-1]} = $fk_meta->columns;#_names;
      $classes{$tables[-1]} = $fk_class;
      $methods{$tables[-1]} = $fk_meta->column_mutator_method_names;

      # Add join condition(s)
      while(my($local_column, $foreign_column) = each(%$fk_columns))
      {
        # Aliased table names
        push(@$clauses, "t1.$local_column = t$i.$foreign_column");

        # Fully-qualified table names
        #push(@$clauses, "$tables[0].$local_column = $tables[-1].$foreign_column");
      }
    }
  }

  if($count_only)
  {
    delete $args{'limit'};
    delete $args{'offset'};
    delete $args{'sort_by'};

    my($sql, $bind) =
      build_select(dbh     => $dbh,
                   select  => 'COUNT(*)',
                   tables  => \@tables,
                   columns => \%columns,
                   classes => \%classes,
                   meta    => \%meta,
                   db      => $db,
                   pretty  => $Debug,
                   %args);

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

  if($args{'offset'})
  {
    Carp::croak "Offset argument is invalid without a limit argument"
      unless($args{'limit'});

    if($db->supports_limit_with_offset)
    {
      $args{'limit'} = $db->format_limit_with_offset($args{'limit'}, $args{'offset'});
      delete $args{'offset'};
      $skip_first = 0;
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

  my($sql, $bind) =
    build_select(dbh     => $dbh,
                 tables  => \@tables,
                 columns => \%columns,
                 classes => \%classes,
                 meta    => \%meta,
                 db      => $db,
                 pretty  => $Debug,
                 %args);

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
      my $class     = $classes{$table};

      foreach my $column (@{$methods{$table}})
      {
        $sth->bind_col($col_num++, \$row{$class,$table_num}{$column});
      }

      $table_num++;
    }

    if($return_iterator)
    {
      $iterator = Rose::DB::Object::Iterator->new(active => 1);

      my $num_subtables = $with_objects ? @$with_objects : 0;

      my $count = 0;

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

            if($with_objects)
            {
              foreach my $i (1 .. $num_subtables)
              {
                my $method = $with_objects->[$i - 1];
                my $class  = $classes[$i];

                my $subobject = $class->new(%subobject_args);
                local $subobject->{STATE_LOADING()} = 1;
                $subobject->init(%{$row{$class,$i}});

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

        return $object;
      });

      $iterator->_finish_code(sub
      {
        $sth->finish;
        $db->release_dbh  if($dbh_retained);
      });

      return $iterator;
    }

    $count = 0;

    if($with_objects)
    {
      my $num_subtables = @$with_objects;

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

        foreach my $i (1 .. $num_subtables)
        {
          my $method = $with_objects->[$i - 1];
          my $class  = $classes[$i];

          my $subobject = $class->new(%subobject_args);
          local $subobject->{STATE_LOADING()} = 1;
          $subobject->init(%{$row{$class,$i}});

          $object->$method($subobject);
        }

        push(@objects, $object);
      }
    }
    else
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
sub delete_objects { shift->_map_action('delete', @_) }

1;

__END__

=head1 NAME

Rose::DB::Object::Manager - Fetch multiple Rose::DB::Object-derived objects from the database.

=head1 SYNOPSIS

  ##
  ## Given the following example Rose::DB::Object-derived classes...
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

  package Product;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  __PACKAGE__->meta->table('products');

  __PACKAGE__->meta->columns
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
      with_objects => [ 'category' ],
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
    # The call to $product->category does not hit the database
    print $product->name, ': ', $product->category->name, "\n";
  }

=head1 DESCRIPTION

C<Rose::DB::Object::Manager> is a base class for classes that select rows from tables fronted by L<Rose::DB::Object>-derived classes.  Each row in the table(s) queried is converted into the equivalent L<Rose::DB::Object>-derived object.

Class methods are provided for fetching objects all at once, one at a time through the use of an iterator, or just getting the object count.  Subclasses are expected to create syntactically pleasing wrappers for C<Rose::DB::Object::Manager> class methods.  A very minimal example is shown in the L<synopsis|/SYNOPSIS> above.

=head1 CLASS METHODS

=over 4

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

Get L<Rose::DB::Object>-derived objects based on PARAMS, where PARAMS are name/value pairs.  Returns a  reference to a (possibly empty) array in scalar context, a list of objects in list context, or undef if there was an error.  

Note that naively calling this method in list context may result in a list containing a single undef element if there was an error.  Example:

    # If there is an error, you'll get: @objects = (undef)
    @objects = Rose::DB::Object::Manager->get_objects(...);

If you want to avoid this, feel free to change the behavior in your wrapper method, or just call it in scalar context (which is more efficient anyway for long lists of objects).

Valid parameters are:

=over 4

=item C<db DB>

A L<Rose::DB>-derived object used to access the database.  If omitted, one will be created by calling the C<init_db()> object method of the C<object_class>.

=item C<limit NUM>

Return a maximum of NUM objects.

=item C<object_args HASHREF>

A reference to a hash of name/value pairs to be passed to the constructor of each C<object_class> object fetched, in addition to the values from the database.

=item C<object_class CLASS>

The class name of the L<Rose::DB::Object>-derived objects to be fetched.  This parameter is required; a fatal error will occur if it is omitted.

=item C<offset NUM>

Skip the first NUM rows.  If the database supports some sort of "limit with offset" syntax (e.g., "LIMIT 10 OFFSET 20") then it will be used.  Otherwise, the first NUM rows will be fetched and then discarded.

This parameter can only be used along with the C<limit> parameter, otherwise a fatal error will occur.

=item C<share_db BOOL>

If true, C<db> will be passed to each L<Rose::DB::Object>-derived object when it is constructed.  Defaults to true.

=item C<with_object OBJECTS>

Also fetch sub-objects associated with foreign keys in the primary table, where OBJECTS is a reference to an array of foreign key names, as defined by the L<Rose::DB::Object::Metadata> object for C<object_class>.

Another table will be added to the query for each foreign key listed.  The "join" clauses will be added automatically based on the foreign key definitions.  Note that (obviously) each foreign key table has to have a L<Rose::DB::Object>-derived class fronting it.  See the L<synopsis|/SYNOPSIS> for a simple example.

B<Note:> the C<with_objects> list currently cannot be used to simultaneously fetch two objects that both front the same database table, but are of different classes.  One workaround is to make one class use a synonym or alias for one of the tables.  Another option is to make one table a trivial view of the other.  The objective is to get the table names to be different for each different class (even if it's just a matter of letter case, if your database is not case-sensitive when it comes to table names).

=item C<query PARAMS>

The query parameters, passed as a reference to an array of name/value pairs.  These PARAMS are used to formulate the "where" clause of the SQL query that, in turn, is used to fetch the objects from the database.  Arbitrarily nested boolean logic is supported.

For the complete list of valid parameter names and values, see the L<build_select|Rose::DB::Object::QueryBuilder/build_select> function of the L<Rose::DB::Object::QueryBuilder> module.

=back

=item B<get_objects_count [PARAMS]>

Accepts the same arguments as C<get_objects()>, but just returns the number of rows that would have been fetched, or undef if there was an error.

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

The base name is a string used as the basis of the method names.  For example, the base name "products" would be used to create methods named "get_B<products>", "get_B<products>_count", and "get_B<products>_iterator"

In the absence of a base name, an explicit method name may be provided instead.  The method name will be used as is.

=item * B<method types>

The types of methods that should be generated.  Each method type is a wrapper for a L<Rose::DB::Object::Manager> class method.  The mapping of method type names to actual L<Rose::DB::Object::Manager> class methods is as follows:

    Type        Method
    --------    ----------------------
    objects     get_objects()
    iterator    get_objects_iterator()
    count       get_objects_count()

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

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
