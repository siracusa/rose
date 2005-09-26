package Rose::DB::Object;

use strict;

use Carp();

use Rose::DB;
use Rose::DB::Object::Metadata;

use Rose::Object;
our @ISA = qw(Rose::Object);

use Rose::DB::Object::Manager;
use Rose::DB::Object::Constants qw(:all);
use Rose::DB::Constants qw(IN_TRANSACTION);
use Rose::DB::Object::Util qw(row_id);

our $VERSION = '0.076';

our $Debug = 0;

#
# Object data
#

use Rose::Object::MakeMethods::Generic
(
  'scalar'  => [ 'error', 'not_found' ],
  'boolean' =>
  [
    FLAG_DB_IS_PRIVATE,
    STATE_IN_DB,
    STATE_LOADING,
    STATE_SAVING,
  ],
);

#
# Class methods
#

sub meta_class { 'Rose::DB::Object::Metadata' }

sub meta
{  
  if(ref $_[0])
  {
    return $_[0]->{META_ATTR_NAME()} ||= $_[0]->meta_class->for_class(ref $_[0]);
  }

  return $_[0]->meta_class->for_class($_[0]);
}

#
# Object methods
#

sub db
{
  my($self) = shift;

  if(@_)
  {
    $self->{FLAG_DB_IS_PRIVATE()} = 0;
    $self->{'db'}  = shift;
    $self->{'dbh'} = undef;
    $self->meta->init_with_db($self->{'db'});

    return $self->{'db'};
  }

  return $self->{'db'} ||= $self->_init_db;
}

sub init_db { Rose::DB->new() }

sub _init_db
{
  my($self) = shift;

  my $db = $self->init_db;

  if($db->init_db_info)
  {
    $self->{FLAG_DB_IS_PRIVATE()} = 1;
    $self->meta->init_with_db($db);
    return $db;
  }

  $self->error($db->error);

  $self->meta->handle_error($self);
  return undef;
}

sub dbh
{
  my($self) = shift;

  return $self->{'dbh'}  if($self->{'dbh'});

  my $db = $self->db or return 0;

  if(my $dbh = $db->dbh)
  {
    return $self->{'dbh'} = $dbh;
  }
  else
  {
    $self->error($db->error);
    $self->meta->handle_error($self);
    return undef;
  }
}

sub load
{
  my($self) = shift;

  my %args = @_;

  my $db  = $self->db  or return 0;
  my $dbh = $self->dbh or return 0;

  my $meta = $self->meta;

  my @key_columns = $meta->primary_key_column_names;
  my @key_methods = map { $meta->column_accessor_method_name($_) } @key_columns;
  my @key_values  = grep { defined } map { $self->$_() } @key_methods;
  my $null_key  = 0;
  my $found_key = 0;

  unless(@key_values == @key_columns)
  {
    foreach my $cols ($meta->unique_keys_column_names)
    {
      my $defined = 0;
      @key_columns = @$cols;
      @key_methods = map { $meta->column_accessor_method_name($_) } @key_columns;
      @key_values  = map { $defined++ if(defined $_); $_ } 
                     map { $self->$_() } @key_methods;

      if($defined)
      {
        $found_key = 1;
        $null_key  = 1  unless($defined == @key_columns);
        last;
      }
    }

    unless($found_key)
    {
      @key_columns = $meta->primary_key_column_names;

      $self->error("Cannot load " . ref($self) . " without a primary key (" .
                   join(', ', @key_columns) . ') with ' .
                   (@key_columns > 1 ? 'non-null values in all columns' : 
                                       'a non-null value') .
                   ' or another unique key with at least one non-null value.');

      $self->meta->handle_error($self);
      return 0;
    }
  }

  my $rows = 0;

  my $column_names = $meta->column_names;

  $self->{'not_found'} = 0;

  eval
  {
    local $self->{STATE_LOADING()} = 1;
    local $dbh->{'RaiseError'} = 1;

    my($sql, $sth);

    if($null_key)
    {
      $sql = $meta->load_sql_with_null_key(\@key_columns, \@key_values);
      $sth = $dbh->prepare($sql, $meta->prepare_select_options);
    }
    else
    {
      $sql = $meta->load_sql(\@key_columns);

      # Was prepare_cached() but that can't be used across transactions
      $sth = $dbh->prepare($sql, $meta->prepare_select_options);
    }

    $Debug && warn "$sql - bind params: ", join(', ', grep { defined } @key_values), "\n";
    $sth->execute(grep { defined } @key_values);

    my %row;

    $sth->bind_columns(undef, \@row{@$column_names});

    $sth->fetch;

    $rows = $sth->rows;

    $sth->finish;

    if($rows > 0)
    {
      my $methods = $meta->column_mutator_method_names_hash;

      foreach my $name (@$column_names)
      {
        my $method = $methods->{$name};
        $self->$method($row{$name});
      }
    }
    else
    {
      no warnings;
      $self->error("No such " . ref($self) . ' where ' . 
                   join(', ', @key_columns) . ' = ' . join(', ', @key_values));
      $self->{'not_found'} = 1;
    }
  };

  if($@)
  {
    $self->error("load() - $@");
    $self->meta->handle_error($self);
    return undef;
  }

  unless($rows > 0)
  {
    unless($args{'speculative'})
    {
      $self->meta->handle_error($self);
    }

    return 0;
  }

  $self->{STATE_IN_DB()} = 1;
  return $self || 1;
}

sub save
{
  my($self, %args) = @_;

  # Keep trigger-encumberd code in separate code path
  if($self->{ON_SAVE_ATTR_NAME()})
  {
    my $db = $self->db or return 0;
    my $ret = $db->begin_work;

    unless($ret)
    {
      $self->error('Could not begin transaction before saving - ' . $db->error);
      return undef;
    }
    
    my $started_new_tx = ($ret == IN_TRANSACTION) ? 0 : 1;
  
    eval
    {
      my $meta = $self->meta;
      my %did_set;

      #
      # Do pre-save stuff
      #

      my $todo = $self->{ON_SAVE_ATTR_NAME()}{'pre'};

      foreach my $fk_name (keys %{$todo->{'fk'}})
      {
        my $fk = $meta->foreign_key($fk_name) 
          or Carp::confess "No foreign key named '$fk_name'";

        my $code   = $todo->{'fk'}{$fk_name}{'set'} or next;
        my $object = $code->();
        
        # Account for objects that evaluate to false to due overloading
        unless($object || ref $object)
        {
          die $self->error;
        }

        # Track which rows were set so we can avoid deleting
        # them later in the "delete on save" code
        $did_set{'fk'}{$fk_name}{row_id($object)} = 1;
      }

      #
      # Do the actual save
      #

      if(!$args{'insert'} && ($args{'update'} || $self->{STATE_IN_DB()}))
      {
        $ret = shift->update(@_);
      }
      else
      {
        $ret = shift->insert(@_);
      }

      #
      # Do post-save stuff
      #

      $todo = $self->{ON_SAVE_ATTR_NAME()}{'post'};

      # Foreign keys
      foreach my $fk_name (keys %{$todo->{'fk'}})
      {
        my $fk = $meta->foreign_key($fk_name) 
          or Carp::confess "No foreign key named '$fk_name'";

        foreach my $item (@{$todo->{'fk'}{$fk_name}{'delete'} || []})
        {
          my $code   = $item->{'code'};
          my $object = $item->{'object'};
          
          # Don't run the code to delete this object if we just set it above
          next  if($did_set{'fk'}{$fk_name}{row_id($object)});

          $code->() or die $self->error;
        }
      }

      # Relationships
      foreach my $rel_name (keys %{$todo->{'rel'}})
      {
        my $rel = $meta->relationship($rel_name) 
          or Carp::confess "No relationship named '$rel_name'";

        # Set value(s)
        my $code  = $todo->{'rel'}{$rel_name}{'set'} or next;
        $code->() or die $self->error;

        # Add value(s)
        $code  = $todo->{'rel'}{$rel_name}{'add'} or next;
        $code->() or die $self->error;
      }

      if($started_new_tx)
      {
        $db->commit or die $db->error;
      }
    };

    delete $self->{ON_SAVE_ATTR_NAME()};

    if($@)
    {
      $self->error($@);
      $db->rollback or warn $db->error  if($started_new_tx);
      $self->meta->handle_error($self);
      return 0;
    }
    
    return $ret;
  }
  else
  {
    if(!$args{'insert'} && ($args{'update'} || $self->{STATE_IN_DB()}))
    {
      return shift->update(@_);
    }
  
    return shift->insert(@_);
  }
}

sub update
{
  my($self, %args) = @_;

  my $db  = $self->db  or return 0;
  my $dbh = $self->dbh or return 0;

  my $meta = $self->meta;

  my @key_columns = $meta->primary_key_column_names;
  my @key_methods = map { $meta->column_accessor_method_name($_) } @key_columns;
  my @key_values  = grep { defined } map { $self->$_() } @key_methods;

  # See comment below
  #my $null_key  = 0;
  #my $found_key = 0;

  unless(@key_values == @key_columns)
  {
    # This is nonsensical right now because the primary key 
    # always has to be non-null, and any update will use the 
    # primary key instead of a unique key.  But I'll leave the
    # code here (commented out) just in case.
    #foreach my $cols ($meta->unique_keys_column_names)
    #{
    #  my $defined = 0;
    #  @key_columns = @$cols;
    #  @key_methods = map { $meta->column_accessor_method_name($_) } @key_columns;
    #  @key_values  = map { $defined++ if(defined $_); $_ } 
    #                 map { $self->$_() } @key_methods;
    #
    #  if($defined)
    #  {
    #    $found_key = 1;
    #    $null_key  = 1  unless($defined == @key_columns);
    #    last;
    #  }
    #}
    #
    #unless($found_key)
    #{
    #  @key_columns = $meta->primary_key_column_names;
    #
    #  $self->error("Cannot update " . ref($self) . " without a primary key (" .
    #               join(', ', @key_columns) . ') with ' .
    #               (@key_columns > 1 ? 'non-null values in all columns' : 
    #                                   'a non-null value') .
    #               ' or another unique key with at least one non-null value.');
    #  return 0;
    #}

    $self->error("Cannot update " . ref($self) . " without a primary key (" .
                 join(', ', @key_columns) . ') with ' .
                 (@key_columns > 1 ? 'non-null values in all columns' : 
                                     'a non-null value'));
  }

  #my $ret = $db->begin_work;
  #
  #unless($ret)
  #{
  #  $self->error('Could not begin transaction before inserting - ' . $db->error);
  #  return undef;
  #}
  #
  #my $started_new_tx = ($ret == Rose::DB::Constants::IN_TRANSACTION) ? 0 : 1;

  eval
  {
    local $self->{STATE_SAVING()} = 1;
    local $dbh->{'RaiseError'} = 1;

    my $sth;

    if($meta->allow_inline_column_values)
    {
      # This versions of update_sql_with_inlining is not needed (see comments
      # in Rose/DB/Object/Metadata.pm for more information)
      #my($sql, $bind) = 
      #  $meta->update_sql_with_inlining($self, \@key_columns, \@key_values);

      my($sql, $bind) = 
        $meta->update_sql_with_inlining($self, \@key_columns);

      if($Debug)
      {
        no warnings;
        warn "$sql - bind params: ", join(', ', @$bind, @key_values), "\n";
      }

      $sth = $dbh->prepare($sql, $meta->prepare_update_options);
      $sth->execute(@$bind, @key_values);
    }
    else
    {
      # See comment above regarding primary keys vs. unique keys for updates
      #my($sql, $sth);
      #
      #if($null_key)
      #{
      #  $sql = $meta->update_sql_with_null_key(\@key_columns, \@key_values);
      #  $sth = $dbh->prepare($sql, $meta->prepare_update_options);
      #}
      #else
      #{
      #  $sql = $meta->update_sql(\@key_columns);
      #  # Was prepare_cached() but that can't be used across transactions
      #  $sth = $dbh->prepare($sql, $meta->prepare_update_options);
      #}

      my $sql = $meta->update_sql(\@key_columns);
      # Was prepare_cached() but that can't be used across transactions
      my $sth = $dbh->prepare($sql, $meta->prepare_update_options);

      my %key = map { ($_ => 1) } @key_methods;

      my $method_names = $meta->column_accessor_method_names;

      if($Debug)
      {
        no warnings;
        warn "$sql - bind params: ", 
          join(', ', (map { $self->$_() } grep { !$key{$_} } @$method_names), 
                      grep { defined } @key_values), "\n";
      }

      $sth->execute(
        (map { $self->$_() } grep { !$key{$_} } @$method_names), 
        grep { defined } @key_values);
    }
    #if($started_new_tx)
    #{
    #  $db->commit or die $db->error;
    #}
  };

  if($@)
  {
    $self->error("update() - $@");
    #$db->rollback or warn $db->error  if($started_new_tx);
    $self->meta->handle_error($self);
    return 0;
  }

  return $self || 1;
}

sub insert
{
  my($self, %args) = @_;

  my $db  = $self->db  or return 0;
  my $dbh = $self->dbh or return 0;

  my $meta = $self->meta;

  my @pk_methods = map { $meta->column_accessor_method_name($_) } 
                   $meta->primary_key_column_names;
  my @pk_values  = grep { defined } map { $self->$_() } @pk_methods;

  #my $ret = $db->begin_work;
  #
  #unless($ret)
  #{
  #  $self->error('Could not begin transaction before inserting - ' . $db->error);
  #  return undef;
  #}
  #
  #my $started_new_tx = ($ret > 0) ? 1 : 0;

  my $using_pk_placeholders = 0;

  unless(@pk_values == @pk_methods)
  {
    @pk_values = $meta->generate_primary_key_values($db);

    unless(@pk_values)
    {
      @pk_values = $meta->generate_primary_key_placeholders($db);
      $using_pk_placeholders = 1;
    }

    unless(@pk_values == @pk_methods)
    {
      my $s = (@pk_values == 1 ? '' : 's');
      $self->error("Could not generate primary key$s for column$s " .
                   join(', ', @pk_methods));
      $self->meta->handle_error($self);
      return undef;
    }

    foreach my $name (@pk_methods)
    {
      $self->$name(shift @pk_values);
    }
  }

  eval
  {
    local $self->{STATE_SAVING()} = 1;
    local $dbh->{'RaiseError'} = 1;

    my $options = $meta->prepare_insert_options;

    my $sth;

    if($meta->allow_inline_column_values)
    {
      my($sql, $bind) = $meta->insert_sql_with_inlining($self);

      if($Debug)
      {
        no warnings;
        warn "$sql - bind params: ", join(', ', @$bind), "\n";
      }

      $sth = $dbh->prepare($sql, $options);
      $sth->execute(@$bind);
    }
    else
    {
      my $column_names = $meta->column_names;

      # Was prepare_cached() but that can't be used across transactions
      $sth = $dbh->prepare($meta->insert_sql, $options);

      if($Debug)
      {
        no warnings;
        warn $meta->insert_sql, " - bind params: ", 
          join(', ', (map { $self->$_() } $meta->column_accessor_method_names)), 
          "\n";
      }

      $sth->execute(map { $self->$_() } $meta->column_accessor_method_names);
    }

    if(@pk_methods == 1)
    {
      my $pk = $pk_methods[0];

      if($using_pk_placeholders || !defined $self->$pk())
      {
        #$self->$pk($db->last_insertid_from_sth($sth, $self));
        $self->$pk($db->last_insertid_from_sth($sth));
        $self->{STATE_IN_DB()} = 1;
      }
      elsif(!$using_pk_placeholders && defined $self->$pk())
      {
        $self->{STATE_IN_DB()} = 1;
      }
    }
    elsif(@pk_values == @pk_methods)
    {
      $self->{STATE_IN_DB()} = 1;
    }
    elsif(!$using_pk_placeholders)
    {
      my $have_pk = 1;

      foreach my $pk (@pk_methods)
      {
        $have_pk = 0  unless(defined $self->$pk());
      }

      $self->{STATE_IN_DB()} = $have_pk;
    }

    #if($started_new_tx)
    #{
    #  $db->commit or die $db->error;
    #}
  };

  if($@)
  {
    $self->error("update() - $@");
    #$db->rollback or warn $db->error  if($started_new_tx);
    $self->meta->handle_error($self);
    return 0;
  }

  return $self || 1;
}

my %CASCADE_VALUES = (delete => 'delete', null => 'null', 1 => 'delete');

sub delete
{
  my($self, %args) = @_;

  my $meta = $self->meta;

  my @pk_methods = map { $meta->column_accessor_method_name($_) } $meta->primary_key_column_names;
  my @pk_values  = grep { defined } map { $self->$_() } @pk_methods;

  unless(@pk_values == @pk_methods)
  {
    $self->error("Cannot delete " . ref($self) . " without a primary key (" .
                 join(', ', @pk_methods) . ')');
    $self->meta->handle_error($self);
    return 0;
  }

  # Totally separate code path for cascaded delete
  if(my $cascade = $args{'cascade'})
  {
    unless(exists $CASCADE_VALUES{$cascade})
    {
      Carp::croak "Illegal value for 'cascade' parameter: '$cascade'.  ",
                  "Valid values are 'delete', 'null', and '1'";
    }

    $cascade = $CASCADE_VALUES{$cascade};

    my $mgr_error_mode = Rose::DB::Object::Manager->error_mode;
    my($db, $started_new_tx);

    eval
    {
      $db = $self->db;
      my $meta  = $self->meta;

      my $ret = $db->begin_work;
      
      unless(defined $ret)
      {
        die 'Could not begin transaction before deleting with cascade - ',
            $db->error;
      }

      $started_new_tx = ($ret == IN_TRANSACTION) ? 0 : 1;

      unless($self->{STATE_IN_DB()})
      {
        $self->load 
          or die "Could not load in preparation for cascading delete: ", 
                 $self->error;
      }

      Rose::DB::Object::Manager->error_mode('fatal');

      # Process all the rows for each "... to many" relationship
      REL: foreach my $relationship ($meta->relationships)
      {
        my $rel_type = $relationship->type;
        
        if($rel_type eq 'one to many')
        {
          my $column_map = $relationship->column_map;
          my @query;
  
          while(my($local_column, $foreign_column) = each(%$column_map))
          {
            my $method = $meta->column_accessor_method_name($local_column);
            my $value =  $self->$method();
            
            # XXX: Comment this out to allow null keys
            next FK  unless(defined $value);
  
            push(@query, $foreign_column => $value);
          }
    
          if($cascade eq 'delete')
          {
            Rose::DB::Object::Manager->delete_objects(
              db           => $db,
              object_class => $relationship->class,
              where        => \@query);
          }
          elsif($cascade eq 'null')
          {
            my %set = map { $_ => undef } values(%$column_map);
  
            Rose::DB::Object::Manager->update_objects(
              db           => $db,
              object_class => $relationship->class,
              set          => \%set,
              where        => \@query);        
          }
          else { Carp::confess "Illegal cascade value '$cascade' snuck through" }
        }
        elsif($rel_type eq 'many to many')
        {
          my $map_class  = $relationship->map_class;
          my $map_from   = $relationship->map_from;
  
          my $map_from_relationship = 
            $map_class->meta->foreign_key($map_from)  ||
            $map_class->meta->relationship($map_from) ||
            Carp::confess "No foreign key or 'many to one' relationship ",
                          "named '$map_from' in class $map_class";
  
          my $key_columns = $map_from_relationship->key_columns;
          my @query;
  
          # "Local" here means "local to the mapping table"
          while(my($local_column, $foreign_column) = each(%$key_columns))
          {
            my $method = $meta->column_accessor_method_name($foreign_column);
            my $value  = $self->$method();
  
            # XXX: Comment this out to allow null keys
            next REL  unless(defined $value);
  
            push(@query, $local_column => $value);
          }

          if($cascade eq 'delete')
          {
            Rose::DB::Object::Manager->delete_objects(
              db           => $db,
              object_class => $map_class,
              where        => \@query);
          }
          elsif($cascade eq 'null')
          {
            my %set = map { $_ => undef } keys(%$key_columns);
  
            Rose::DB::Object::Manager->update_objects(
              db           => $db,
              object_class => $map_class,
              set          => \%set,
              where        => \@query);        
          }
          else { Carp::confess "Illegal cascade value '$cascade' snuck through" }
        }
      }

      # Delete the object itself
      my $dbh = $db->dbh or die "Could not get dbh: ", $self->error;
      local $self->{STATE_SAVING()} = 1;
      local $dbh->{'RaiseError'} = 1;
  
      # Was prepare_cached() but that can't be used across transactions
      my $sth = $dbh->prepare($meta->delete_sql, $meta->prepare_delete_options);
  
      $Debug && warn $meta->delete_sql, " - bind params: ", join(', ', @pk_values), "\n";
      $sth->execute(@pk_values);
  
      unless($sth->rows > 0)
      {
        $self->error("Did not delete " . ref($self) . ' where ' . 
                     join(', ', @pk_methods) . ' = ' . join(', ', @pk_values));
      }

      # Process all rows referred to by "one to one" foreign keys
      FK: foreach my $fk ($meta->foreign_keys)
      {
        next  unless($fk->relationship_type eq 'one to one');

        my $key_columns = $fk->key_columns;
        my @query;

        while(my($local_column, $foreign_column) = each(%$key_columns))
        {
          my $method = $meta->column_accessor_method_name($local_column);
          my $value =  $self->$method();
          
          # XXX: Comment this out to allow null keys
          next FK  unless(defined $value);

          push(@query, $foreign_column => $value);
        }
  
        if($cascade eq 'delete')
        {
          Rose::DB::Object::Manager->delete_objects(
            db           => $db,
            object_class => $fk->class,
            where        => \@query);
        }
        elsif($cascade eq 'null')
        {
          my %set = map { $_ => undef } values(%$key_columns);

          Rose::DB::Object::Manager->update_objects(
            db           => $db,
            object_class => $fk->class,
            set          => \%set,
            where        => \@query);        
        }
        else { Carp::confess "Illegal cascade value '$cascade' snuck through" }
      }

      if($started_new_tx)
      {
        $db->commit or die $db->error;
      }
    };

    if($@)
    {
      Rose::DB::Object::Manager->error_mode($mgr_error_mode);
      $self->error("delete() with cascade - $@");
      $db->rollback  if($db && $started_new_tx);
      $self->meta->handle_error($self);
      return 0;
    }

    Rose::DB::Object::Manager->error_mode($mgr_error_mode);
    $self->{STATE_IN_DB()} = 0;
    return 1;
  }
  else
  {
    my $dbh = $self->dbh or return 0;

    eval
    {
      local $self->{STATE_SAVING()} = 1;
      local $dbh->{'RaiseError'} = 1;
  
      # Was prepare_cached() but that can't be used across transactions
      my $sth = $dbh->prepare($meta->delete_sql, $meta->prepare_delete_options);
  
      $Debug && warn $meta->delete_sql, " - bind params: ", join(', ', @pk_values), "\n";
      $sth->execute(@pk_values);
  
      unless($sth->rows > 0)
      {
        $self->error("Did not delete " . ref($self) . ' where ' . 
                     join(', ', @pk_methods) . ' = ' . join(', ', @pk_values));
      }
    };
  
    if($@)
    {
      $self->error("delete() - $@");
      $self->meta->handle_error($self);
      return 0;
    }
  
    $self->{STATE_IN_DB()} = 0;
    return 1;
  }
}

sub clone
{
  my($self) = shift;
  my $class = ref $self;
  local $self->{STATE_CLONING()} = 1;
  return $class->new(map { $_ => $self->$_() } $self->meta->column_accessor_method_names);
}

our $AUTOLOAD;

sub AUTOLOAD
{
  my $self = shift;

  my $msg = '';

  # Not sure if this will ever be used, but just in case...
  eval
  {
    my @fks  = $self->meta->deferred_foreign_keys;
    my @rels = $self->meta->deferred_relationships;

    if(@fks || @rels)
    {
      my $tmp_msg =<<"EOF";
Methods for the following relationships and foreign keys were deferred and
then never actually created.

TYPE           NAME
----           ----
EOF

      my $class = ref $self;

      foreach my $thing (@fks || @rels)
      {
        next  unless($thing->parent->class eq $class);
        my $type = 
          $thing->isa('Rose::DB::Object::Metadata::Relationship') ? 'Relationship' :
          $thing->isa('Rose::DB::Object::Metadata::ForeignKey') ? 'Foreign Key' :
          '???';

        $tmp_msg .= sprintf("%-15s %s\n", $type, $thing->name);
      }

      $msg = "\n\n$tmp_msg"  if($tmp_msg);
    }
  };

  $AUTOLOAD =~ /^(.+)::(\w+)$/;
  Carp::confess qq(Can't locate object method "$2" via package "$1"$msg);
}

sub DESTROY
{
  my($self) = shift;

  if($self->{FLAG_DB_IS_PRIVATE()})
  {
    if(my $db = $self->{'db'})
    {
      #$Debug && warn "$self DISCONNECT\n";
      $db->disconnect;
    }
  }
}

1;

__END__

=head1 NAME

Rose::DB::Object - Extensible, high performance RDBMS-OO mapper.

=head1 SYNOPSIS

  ## First, set up your Rose::DB data sources, otherwise you
  ## won't be able to connect to the database at all!  See 
  ## the Rose::DB documentation for more information.

  ##
  ## Create classes - two possible approaches:
  ##

  #
  # 1. Automatic configuration
  #

  package Category;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  __PACKAGE__->meta->table('categories');

  __PACKAGE__->meta->auto_initialize;

  ...

  package Price;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  __PACKAGE__->meta->table('prices');

  __PACKAGE__->meta->auto_initialize;

  ...

  package Product;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  __PACKAGE__->meta->table('products');

  __PACKAGE__->meta->auto_initialize;

  #
  # 2. Manual configuration
  #

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

  package Price;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  __PACKAGE__->meta->table('prices');

  __PACKAGE__->meta->columns
  (
    id         => { type => 'int', primary_key => 1 },
    price      => { type => 'decimal' },
    region     => { type => 'char', length => 3 },
    product_id => { type => 'int' }
  );

  __PACKAGE__->meta->add_unique_key('product_id', 'region');

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

    date_created     => { type => 'timestamp', default => 'now' },  
    last_modified    => { type => 'timestamp', default => 'now' },
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

  # This part cannot be done automatically.
  # perldoc Rose::DB::Object::Metadata to find out why.
  __PACKAGE__->meta->relationships
  (
    prices =>
    {
      type       => 'one to many',
      class      => 'Price',
      column_map => { id => 'id_product' },
    },
  );

  __PACKAGE__->meta->initialize;

  ...

  #
  # Example usage
  #

  $product = Product->new(id          => 123,
                          name        => 'GameCube',
                          status      => 'active',
                          start_date  => '11/5/2001',
                          end_date    => '12/1/2007',
                          category_id => 5);

  $product->save;

  ...

  $product = Product->new(id => 123);
  $product->load;

  # Load foreign object via "one to one" relationship
  print $product->category->name;

  $product->end_date->add(days => 45);

  $product->save;

  ...

  $product = Product->new(id => 456);
  $product->load;

  # Load foreign objects via "one to many" relationship
  print join ' ', $product->prices;

  ...

=head1 DESCRIPTION

L<Rose::DB::Object> is a base class for objects that encapsulate a single row in a database table.  L<Rose::DB::Object>-derived objects are sometimes simply called "L<Rose::DB::Object> objects" in this documentation for the sake of brevity, but be assured that derivation is the only reasonable way to use this class.

L<Rose::DB::Object> inherits from, and follows the conventions of, L<Rose::Object>.  See the L<Rose::Object> documentation for more information.

=head2 Restrictions

L<Rose::DB::Object> objects can represent rows in almost any database table, subject to the following constraints.

=over 4

=item * The database server must be supported by L<Rose::DB>.

=item * The database table must have a primary key.

=item * The primary key must not allow null values in any of its columns.

=back

Although the list above contains the only hard and fast rules, there may be other realities that you'll need to work around.

The most common example is the existence of a column name in the database table that conflicts with the name of a method in the L<Rose::DB::Object> API.  There are two possible workarounds: either explicitly alias the column, or define a L<mapping function|Rose::DB::Object::Metadata/column_name_to_method_name_mapper>.  See the L<alias_column|Rose::DB::Object::Metadata/alias_column> and L<column_name_to_method_name_mapper|Rose::DB::Object::Metadata/column_name_to_method_name_mapper> methods in the L<Rose::DB::Object::Metadata> documentation for more details.

There are also varying degrees of support for data types in each database server supported by L<Rose::DB>.  If you have a table that uses a data type not supported by an existing L<Rose::DB::Object::Metadata::Column>-derived class, you will have to write your own column class and then map it to a type name using L<Rose::DB::Object::Metadata>'s L<column_type_class|Rose::DB::Object::Metadata/column_type_class> method, yada yada.  (Or, of course, you can map the new type to an existing column class.)

The entire framework is extensible.  This module distribution contains straight-forward implementations of the most common column types, but there's certainly more that can be done.  Submissions are welcome.

=head2 Features

L<Rose::DB::Object> provides the following functions:

=over 4

=item * Create a row in the database by saving a newly constructed object.

=item * Initialize an object by loading a row from the database.

=item * Update a row by saving a modified object back to the database.

=item * Delete a row from the database.

=item * Fetch an object referred to by a foreign key in the current object. (i.e., "one to one" relationships.)

=item * Fetch multiple objects that refer to the current object, either directly through foreign keys or indirectly through a mapping table.  (i.e., "one to many" and "many to many" relationships.)

=back

Objects can be loaded based on either a primary key or a unique key.  Since all tables fronted by L<Rose::DB::Object>s must have non-null primary keys, insert, update, and delete operations are done based on the primary key.

In addition, its sibling class, L<Rose::DB::Object::Manager>, can do the following:

=over 4

=item * Fetch multiple objects from the database using arbitrary query conditions, limits, and offsets.

=item * Iterate over a list of objects, fetching from the database in response to each step of the iterator.

=item * Fetch objects along with "foreign objects" (connected via "one to one" or "one to many" relationships) in a single query by automatically generating the appropriate SQL join(s).

=item * Count the number of objects that match a complex query.

=item * Update objects that match a complex query.

=item * Delete objects that match a complex query.

=back

L<Rose::DB::Object::Manager> can be subclassed and used separately (the recommended approach), or it can create object manager methods within a L<Rose::DB::Object> subclass.  See the L<Rose::DB::Object::Manager> documentation for more information.

L<Rose::DB::Object> can parse, coerce, inflate, and deflate column values on your behalf, providing the most convenient possible data representations on the Perl side of the fence, while allowing the programmer to completely forget about the ugly details of the data formats required by the database.  Default implementations are included for most common column types, and the framework is completely extensible.

=head2 Configuration

Before L<Rose::DB::Object> can do any useful work, you must register at least one L<Rose::DB> data source.  By default, L<Rose::DB::Object> instantiates a L<Rose::DB> object by passing no arguments to its constructor.  (See the L<db|/db> method.)  If you register a L<Rose::DB> data source using the default type and domain, this will work fine.  Otherwise, you must override the L<meta|/meta> method in your L<Rose::DB::Object> subclass and have it return the appropriate L<Rose::DB>-derived object.

To define your own L<Rose::DB::Object>-derived class, you must describe the table that your class will act as a front-end for.    This is done through the L<Rose::DB::Object::Metadata> object associated with each L<Rose::DB::Object>-dervied class.  The metadata object is accessible via L<Rose::DB::Object>'s L<meta|/meta> method.

Metadata objects can be populated manually or automatically.  Both techniques are shown in the L<synopsis|/SYNOPSIS> above.  The automatic mode works by asking the database itself for the information.  There are some caveats to this approach.  See the L<auto-initialization|Rose::DB::Object::Metadata/"AUTO-INITIALIZATION"> section of the L<Rose::DB::Object::Metadata> documentation for more information.

=head2 Error Handling

Error handling for L<Rose::DB::Object>-derived objects is controlled by the L<error_mode|Rose::DB::Object::Metadata/error_mode> method of the L<Rose::DB::Object::Metadata> object associated with the class (accessible via the L<meta|/meta> method).  The default setting is "fatal", which means that L<Rose::DB::Object> methods will L<croak|Carp/croak> if they encounter an error.

B<PLEASE NOTE:> The error return values described in the L<object method|/"OBJECT METHODS"> documentation are only relevant when the error mode is set to something "non-fatal."  In other words, if an error occurs, you'll never see any of those return values if the selected error mode L<die|perlfunc/die>s or L<croak|Carp/croak>s or otherwise throws an exception when an error occurs.

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Returns a new L<Rose::DB::Object> constructed according to PARAMS, where PARAMS are name/value pairs.  Any object method is a valid parameter name.

=back

=head1 CLASS METHODS

=over 4

=item B<meta>

Returns the L<Rose::DB::Object::Metadata>-derived object associated with this class.  This object describes the database table whose rows are fronted by this class: the name of the table, its columns, unique keys, foreign keys, etc.

See the L<Rose::DB::Object::Metadata> documentation for more information.

=item B<meta_class>

Return the name of the L<Rose::DB::Object::Metadata>-derived class used to store this object's metadata.  Subclasses should override this method if they want to use a custom L<Rose::DB::Object::Metadata> subclass.  (See the source code for L<Rose::DB::Object::Std> for an example of this.)

=back

=head1 OBJECT METHODS

=over 4

=item B<db [DB]>

Get or set the L<Rose::DB> object used to access the database that contains the table whose rows are fronted by the L<Rose::DB::Object>-derived class.

If it does not already exist, this object is created with a simple, argument-less call to C<Rose::DB-E<gt>new()>.  To override this default in a subclass, override the L<init_db|/init_db> method and return the L<Rose::DB> to be used as the new default.

=item B<init_db>

Returns the L<Rose::DB>-derived object used to access the database in the absence of an explicit L<db|/db> value.  The default implementation simply calls C<Rose::DB-E<gt>new()> with no arguments.

Override this method in your subclass in order to use a different default data source.

=item B<dbh>

Returns the L<DBI> database handle contained in L<db|/db>.

=item B<delete [PARAMS]>

Delete the row represented by the current object.  The object must have been previously loaded from the database (or must otherwise have a defined primary key value) in order to be deleted.  Returns true if the row was deleted or did not exist, false otherwise.

PARAMS are optional name/value pairs.  Valid PARAMS are:

=over 4

=item C<cascade TYPE>

Also process related rows.  TYPE must be "delete", "null", or "1".  The value "1" is an alias for "delete".  Passing an illegal TYPE value will cause a fatal error.

For each "one to many" relationship, all of the rows in the foreign ("many") table that reference the current object ("one") will be deleted in "delete" mode, or will have the column(s) that reference the current object set to NULL in "null" mode.

For each "many to many" relationship, all of the rows in the "mapping table" that reference the current object will deleted in "delete" mode, or will have the columns that reference the two tables that the mapping table maps between set to NULL in "null" mode.

For each "one to one" relationship or foreign key with a "one to one" L<relationship type|Rose::DB::Object::Metadata::ForeignKey/relationship_type>, all of the rows in the foreign table that reference the current object will deleted in "delete" mode, or will have the column(s) that reference the current object set to NULL in "null" mode.

In all modes, if the L<db|/db> is not currently in a transaction (i.e., if L<AutoCommit|Rose::DB/autocommit> is turned off), a new transaction is started.  If any part of the cascaded delete fails, the transaction is rolled back.

=back

The cascaded delete feature described above plays it safe by only deleting rows that are not referenced by any other rows (according to the metadata provided by each L<Rose::DB::Object>-derived class).  I B<strongly recommend> that you implement "cascaded delete" in the database itself, rather than using this feature.  It will undoubtedly be faster and more robust than doing it "client-side."  You may also want to cascade only to certain tables, or otherwise deviate from the "safe" plan.  If your database supports automatic cascaded delete and/or triggers, please consider using thse features.

=item B<error>

Returns the text message associated with the last error that occurred.

=item B<load [PARAMS]>

Load a row from the database table, initializing the object with the values from that row.  An object can be loaded based on either a primary key or a unique key.

Returns true if the row was loaded successfully, undef if the row could not be loaded due to an error, or zero (0) if the row does not exist.  The true value returned on success will be the object itself.  If the object L<overload>s its boolean value such that it is not true, then a true value will be returned instead of the object itself.

PARAMS are optional name/value pairs.  If the parameter C<speculative> is passed with a true value, and if the load failed because the row was L<not found|/not_found>, then the L<error_mode|Rose::DB::Object::Metadata/error_mode> setting is ignored and zero (0) is returned.

=item B<not_found>

Returns true if the previous call to L<load|/load> failed because a row in the database table with the specified primary or unique key did not exist, false otherwise.

=item B<meta>

Returns the L<Rose::DB::Object::Metadata> object associated with this class.  This object describes the database table whose rows are fronted by this class: the name of the table, its columns, unique keys, foreign keys, etc.

See the L<Rose::DB::Object::Metadata> documentation for more information.

=item B<save [PARAMS]>

Save the current object to the database table.  In the absence of PARAMS, if the object was previously L<load|/load>ed from the database, the row will be updated.  Otherwise, a new row will be created.

PARAMS are name/value pairs.  Valid parameters are:

=over 4

=item * C<insert>

If set to a true value, then an insert is attempted, regardless of whether or not the object was previously L<load|/load>ed from the database.

=item * C<update>

If set to a true value, then an update is attempted, regardless of whether or not the object was previously L<load|/load>ed from the database.

=back

It is an error to pass both the C<insert> and C<update> parameters in a single call.

Returns true if the row was inserted or updated successfully, false otherwise.  The true value returned on success will be the object itself.  If the object L<overload>s its boolean value such that it is not true, then a true value will be returned instead of the object itself.

If an insert was performed and the primary key is a single column that supports auto-generated values, then the object accessor for the primary key column will contain the auto-generated value.

Here are examples of primary key column definitions that provide auto-generated  values, one for each of the databases supported by L<Rose::DB>.

=over

=item * PostgreSQL

    CREATE TABLE mytable
    (
      id   SERIAL PRIMARY KEY,
      ...
    );

=item * MySQL

    CREATE TABLE mytable
    (
      id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      ...
    );

=item * Informix

    CREATE TABLE mytable
    (
      id   SERIAL NOT NULL PRIMARY KEY,
      ...
    );

=back

Other data definitions are possible, of course, but the three definitions above are used in the L<Rose::DB::Object> test suite and are therefore guaranteed to work.  If you have success with alternative approaches, patches and/or new tests are welcome.

If your table has a multi-column primary key or does not use a column type that supports auto-generated values, you can define a custom primary key generator function using the L<primary_key_generator|Rose::DB::Object::Metadata/primary_key_generator> method of the L<Rose::DB::Object::Metadata>-derived object that contains the metadata for this class.  Example:

    package MyDBObject;

    use Rose::DB::Object;
    our @ISA = qw(Rose::DB::Object);

    __PACKAGE__->meta->table('mytable');

    __PACKAGE__->meta->columns
    (
      k1   => { type => 'int', not_null => 1 },
      k2   => { type => 'int', not_null => 1 },
      name => { type => 'varchar', length => 255 },
      ...
    );

    __PACKAGE__->meta->primary_key_columns('k1', 'k2');

    __PACKAGE__->meta->initialize;

    __PACKAGE__->meta->primary_key_generator(sub
    {
      my($meta, $db) = @_;

      # Generate primary key values somehow
      my $k1 = ...;
      my $k2 = ...;

      return $k1, $k2;
    });

See the L<Rose::DB::Object::Metadata> documentation for more information on custom primary key generators.

=back

=head1 RESERVED METHODS

As described in the L<Rose::DB::Object::Metadata> documentation, each column in the database table has an associated get/set accessor method in the L<Rose::DB::Object>.  Since the L<Rose::DB::Object> API already defines many methods (L<load|/load>, L<save|/save>, L<meta|/meta>, etc.), accessor methods for columns that share the name of an existing method pose a problem.  The solution is to alias such columns using L<Rose::DB::Object::Metadata>'s  L<alias_column|Rose::DB::Object::Metadata/alias_column> method. 

Here is a list of method names reserved by the L<Rose::DB::Object> API.  If you have a column with one of these names, you must alias it.

    db
    dbh
    delete
    DESTROY
    error
    init_db
    _init_db
    insert
    load
    meta
    meta_class
    not_found
    save
    update

Note that not all of these methods are public.  These methods do not suddenly become public just because you now know their names!  Remember the stated policy of the L<Rose> web application framework: if a method is not documented, it does not exist.  (And no, the list of method names above does not constitute "documentation")

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
