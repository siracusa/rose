package Rose::DB::Object::Metadata::Column;

use strict;

use Carp();

use Rose::DB::Object::Metadata::Util qw(:all);

use Rose::DB::Object::Metadata::MethodMaker;
our @ISA = qw(Rose::DB::Object::Metadata::MethodMaker);

use Rose::DB::Object::Util 
  qw(column_value_formatted_key column_value_is_inflated_key);

use Rose::DB::Object::Constants 
  qw(STATE_IN_DB STATE_LOADING STATE_SAVING);

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Generic;

our $VERSION = '0.05';

use overload
(
  '""' => sub { shift->name },
   fallback => 1,
);

__PACKAGE__->add_default_auto_method_types('get_set');

__PACKAGE__->add_common_method_maker_argument_names(qw(column default type hash_key));

use Rose::Class::MakeMethods::Generic
(
  inheritable_hash =>
  [
    event_method_type  => { hash_key => 'event_method_types' },
    event_method_types => { interface => 'get_set_all' },
    delete_event_method_type => { interface => 'delete', hash_key => 'event_method_types' },
  ],
);

__PACKAGE__->event_method_types
(
  inflate => [ qw(get_set get) ],
  deflate => [ qw(get_set get) ],
  on_load => [ qw(get_set set) ],
  on_save => [ qw(get_set get) ],
  on_set  => [ qw(get_set set) ],
  on_get  => [ qw(get_set get) ],
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => 
  [
    'alias',
    'ordinal_position',
    __PACKAGE__->common_method_maker_argument_names,
  ],

  boolean => 
  [
    'manager_uses_method',
    'is_primary_key_member',
    'not_null',
    'triggers_disabled',
  ],
);

*primary_key = \&is_primary_key_member;

__PACKAGE__->method_maker_info
(
  get_set => 
  {
    class => 'Rose::DB::Object::MakeMethods::Generic',
    type  => 'scalar',
  },

  get =>
  {
    class => 'Rose::DB::Object::MakeMethods::Generic',
    type  => 'scalar',
  },

  set =>
  {
    class => 'Rose::DB::Object::MakeMethods::Generic',
    type  => 'scalar',
  },
);

sub available_method_types
{
  my($class) = shift;

  my @types = $class->SUPER::available_method_types;

  @types = qw(get_set get set)  unless(@types);

  return @types;
}

sub accessor_method_name
{
  return $_[0]->{'accessor_method_name'} ||= 
    $_[0]->method_name('get') || $_[0]->method_name('get_set')
}

sub mutator_method_name
{
  return $_[0]->{'mutator_method_name'} ||= 
    $_[0]->method_name('set') || $_[0]->method_name('get_set')
}

sub rw_method_name
{
  return $_[0]->{'rw_method_name'} ||= $_[0]->method_name('get_set')
}

sub build_method_name_for_type
{
  my($self, $type) = @_;

  if($type eq 'get_set')
  {
    return $self->alias || $self->name;
  }
  elsif($type eq 'set')
  {
    return 'set_' . ($self->alias || $self->name);
  }
  elsif($type eq 'get')
  {
    return 'get_' . ($self->alias || $self->name);
  }

  return undef;
}

sub made_method_type
{
  my($self, $type, $name) = @_;

  if($type eq 'get_set')
  {
    $self->{'accessor_method_name'} = $name;  
    $self->{'mutator_method_name'}  = $name;
    $self->{'rw_method_name'}       = $name;
    $self->{'alias'} = $name;
  }  
  elsif($type eq 'get')
  {
    $self->{'accessor_method_name'} = $name;
  }
  elsif($type eq 'set')
  {
    $self->{'mutator_method_name'} = $name;
  }
  
  $self->{'made_method_types'}{$type} = 1;
}

sub defined_method_types
{
  my($self) = shift;
  my @types = sort keys %{$self->{'made_method_types'} ||= {}};
  return wantarray ? @types : \@types;
}

sub method_maker_arguments
{
  my($self, $type) = @_;

  my $args = $self->SUPER::method_maker_arguments($type);

  $args->{'interface'} ||= $type;

  return wantarray ? %$args : $args;
}

sub type   { 'scalar' }
sub column { $_[0] }

sub should_inline_value { 0 }

sub name
{
  my($self) = shift;

  if(@_)
  {
    $self->name_sql(undef);
    return $self->{'name'} = shift;
  }

  return $self->{'name'};
}

sub hash_key { $_[0]->alias || $_[0]->name }

sub name_sql
{
  my($self) = shift;

  if(my $db = shift)
  {
    return $self->{'name_sql'}{$db->{'driver'}} ||= $db->quote_column_name($self->{'name'});
  }
  else
  {
    return $self->{'name'};
  }
}

sub parse_value  { $_[2] }
sub format_value { $_[2] }

sub primary_key_position
{
  my($self) = shift;

  $self->{'primary_key_position'} = shift  if(@_);

  unless($self->is_primary_key_member)
  {
    return $self->{'primary_key_position'} = undef;
  }

  return $self->{'primary_key_position'};
}

# These constants are from the DBI documentation.  Is there somewhere 
# I can load these from?
use constant SQL_NO_NULLS => 0;
use constant SQL_NULLABLE => 1;

sub init_with_dbi_column_info
{
  my($self, $col_info) = @_;

  # We're doing this in Rose::DB::Object::Metadata::Auto now
  #$self->parent->db->refine_dbi_column_info($col_info);

  $self->default($col_info->{'COLUMN_DEF'});

  if($col_info->{'NULLABLE'} == SQL_NO_NULLS)
  {
    $self->not_null(1);
  }
  elsif($col_info->{'NULLABLE'} == SQL_NULLABLE)
  {
    $self->not_null(0);
  }

  $self->ordinal_position($col_info->{'ORDINAL_POSITION'} || 0);

  return;
}

sub perl_column_defintion_attributes
{
  my($self) = shift;

  my @attrs;

  ATTR: foreach my $attr ('type', sort keys %$self)
  {
    if($attr =~ /^(?:name(?:_sql)? | is_primary_key_member | 
                  primary_key_position | method_name | method_code |
                  made_method_types| ordinal_position | triggers | 
                  trigger_index )$/x)
    {
      next ATTR;
    }

    my $val = $self->can($attr) ? $self->$attr() : next ATTR;

    if(!defined $val || ref $val || ($attr eq 'not_null' && !$self->not_null))
    {
      next ATTR;
    }

    if($attr eq 'alias' && $val eq $self->name)
    {
      next ATTR;
    }

    if($attr =~ /_method_name$/)
    {
      my $method = $self->$attr();

      my $ok = 0;

      foreach my $type ($self->auto_method_types)
      {
        $ok = 1  if($method eq $self->build_method_name_for_type($type));
      }

      next ATTR  if($ok);
    }

    push(@attrs, $attr);
  }

  return @attrs;
}

sub perl_hash_definition
{
  my($self, %args) = @_;

  my $meta = $self->parent;

  my $name_padding = $args{'name_padding'};

  my $indent = defined $args{'indent'} ? $args{'indent'} : 
                 ($meta ? $meta->default_perl_indent : undef);

  my $inline = defined $args{'inline'} ? $args{'inline'} : 1;

  my %hash;

  foreach my $attr ($self->perl_column_defintion_attributes)
  {
    $hash{$attr} = $self->$attr();
  }

  if($name_padding > 0)
  {
    return sprintf('%-*s => ', $name_padding, perl_quote_key($self->name)) .
           perl_hashref(hash      => \%hash, 
                        inline    => $inline, 
                        indent    => $indent, 
                        sort_keys => \&_sort_keys);
  }
  else
  {
    return perl_quote_key($self->name) . ' => ' .
           perl_hashref(hash      => \%hash, 
                        inline    => $inline, 
                        indent    => $indent, 
                        sort_keys => \&_sort_keys);
  }
}

sub _sort_keys 
{
  if($_[0] eq 'type')
  {
    return -1;
  }
  elsif($_[1] eq 'type')
  {
    return 1;
  }

  return lc $_[0] cmp lc $_[1];
}

our %Trigger_Events =
(
  inflate => 1,
  deflate => 1,
  on_load => 1,
  on_save => 1,
  on_set  => 1,
  on_get  => 1,
);

sub triggers
{
  my($self, $event) = (shift, shift);

  Carp::croak "Invalid event: $event"  unless(exists $Trigger_Events{$event});

  if(@_)
  {
    my $code = shift;

    unless((ref($code) || '') eq 'CODE')
    {
      Carp::croak "Not a code reference: $code";
    }

    $self->{'triggers'}{$event} = [ $code ];
    $self->reapply_triggers($event);
    return;
  }

  return $self->{'triggers'}{$event};
}

sub disable_triggers { shift->triggers_disabled(1) }
sub enable_triggers  { shift->triggers_disabled(0) }

sub add_trigger
{
  my($self, %args) = @_;

  my($event, $position, $code, $name);
  
  if(@_ == 3 && $Trigger_Events{$_[1]})
  {
    $event = $_[1];
    $code  = $_[2];
  }
  else
  {
    $event    = $args{'event'};
    $code     = $args{'code'};
  }

  $name     = $args{'name'} || $self->generate_trigger_name;
  $position = $args{'position'} || 'end';

  Carp::croak "Invalid event: '$event'"  
    unless(exists $Trigger_Events{$event});

  unless((ref($code) || '') eq 'CODE')
  {
    Carp::croak "Not a code reference: $code";
  }
  
  if($position =~ /^(?:end|last|push)$/)
  {
    push(@{$self->{'triggers'}{$event}}, $code);
    $self->trigger_index($event, $name, $#{$self->{'triggers'}{$event}});
  }
  elsif($position =~ /^(?:start|first|unshift)$/)
  {
    unshift(@{$self->{'triggers'}{$event}}, $code);
    
    # Shift all the other trigger positions
    my $indexes = $self->trigger_indexes($event);
    
    foreach my $name (keys(%$indexes))
    {
      $indexes->{$name}++;
    }

    # Set new position
    $self->trigger_index($event, $name, 0);
  }
  else { Carp::croak "Invalid trigger position: '$position'" }

  $self->reapply_triggers($event);
  return;
}

my $Trigger_Num = 0;

sub generate_trigger_name { "dyntrig_${$}_" . ++$Trigger_Num }

sub trigger_indexes { $_[0]->{'trigger_index'}{$_[1]} || {} }

sub trigger_index
{
  my($self, $event, $name) = (shift, shift, shift);
  
  if(@_)
  {
    return $self->{'trigger_index'}{$event}{$name} = shift;
  }

  return $self->{'trigger_index'}{$event}{$name};
}

sub delete_trigger
{
  my($self, %args) = @_;

  my $name  = $args{'name'} or Carp::croak "Missing name parameter";
  my $event = $args{'event'};

  Carp::croak "Invalid event: '$event'"  
    unless(exists $Trigger_Events{$event});

  my $index = $self->trigger_index($event, $name);
  
  unless(defined $index)
  {
    Carp::croak "No trigger named '$name' for event '$event'";
  }

  my $triggers = $self->{'triggers'}{$event};
  
  # Remove the trigger
  splice(@$triggers, $index, 1);

  my $indexes = $self->trigger_indexes($event);

  # Remove its index
  delete $indexes->{$name};

  # Shift all trigger indexes greater than $index
  foreach my $name (keys(%$indexes))
  {
    $indexes->{$name}--  if($indexes->{$name} > $index);
  }

  $self->reapply_triggers($event);
}

sub apply_triggers
{
  my($self, $event) = @_;

  my $method_types;

  if(defined $event)
  {
    $method_types = $self->event_method_type($event) 
      or Carp::croak "Invalid event: '$event'";

    my %defined = map { $_ => 1 } $self->defined_method_types;

    $method_types = [ grep { $defined{$_} } @$method_types ];
  }
  else
  {
    $method_types =  $self->defined_method_types;
  }

  foreach my $method_type (@$method_types)
  {
    $self->apply_method_triggers($method_type);
  }
  
  return;
}

*reapply_triggers = \&apply_triggers;

sub apply_method_triggers
{
  my($self, $type) = @_;

  my $column = $self; # $self masked in a deeper context below

  my $class = $self->parent->class;

  my $method_name = $self->method_name($type) or
    Carp::confess "No method name for method type '$type'";

  my $method_code = $self->method_code($type);
  
  # Save the original method code
  unless($method_code)
  {
    $method_code = \&{"${class}::$method_name"};
    $self->method_code($type, $method_code);
  }

  # Copying out into scalars to avoid method calls in the sub itself
  my $inflate_code = $self->triggers('inflate') || 0;
  my $deflate_code = $self->triggers('deflate') || 0;
  my $on_load_code = $self->triggers('on_load') || 0;
  my $on_save_code = $self->triggers('on_save') || 0;
  my $on_set_code  = $self->triggers('on_set')  || 0;
  my $on_get_code  = $self->triggers('on_get')  || 0;

  my $key             = $self->hash_key;
  my $formatted_key   = column_value_formatted_key($key);
  my $is_inflated_key = column_value_is_inflated_key($key);

  my $uses_formatted_key = $self->method_uses_formatted_key($type);

  if($type eq 'get_set')
  {
    if($inflate_code || $deflate_code || 
       $on_load_code || $on_save_code ||
       $on_set_code  || $on_get_code)
    {
      my $method = sub
      {
        my($self) = $_[0];
    
        if($column->method_should_set('get_set', \@_))
        {
          # This is a duplication of the 'set' code below.  Yes, it's
          # duplicated to save one measly function call.  So sue me.
          if($self->{STATE_LOADING()})
          {
            $self->{$is_inflated_key} = 0  unless($uses_formatted_key);

            &$method_code; # magic call using current @_
  
            unless($self->{'triggers_disabled'})
            {
              local $self->{'triggers_disabled'} = 1;
  
              if($on_load_code)
              {
                foreach my $code (@$on_load_code)
                {
                  $code->($self);
                }
              }
            }
          }
          else
          {
            $self->{$is_inflated_key} = 0  unless($uses_formatted_key);

            &$method_code; # magic call using current @_
  
            unless($self->{'triggers_disabled'})
            {
              local $self->{'triggers_disabled'} = 1;
  
              if($on_set_code)
              {
                foreach my $code (@$on_set_code)
                {
                  $code->($self);
                }
              }
            }
          }
        }
        else # getting
        {
          # This is a duplication of the 'get' code below.  Yes, it's
          # duplicated to save one measly function call.  So sue me.
          if($self->{STATE_SAVING()})
          {
            unless($self->{'triggers_disabled'})
            {
              local $self->{'triggers_disabled'} = 1;
  
              if($deflate_code)
              {
                if($uses_formatted_key)
                {
                  my $db = $self->db or die "Missing Rose::DB object attribute";
                  my $driver = $db->driver || 'unknown';

                  unless(defined $self->{$formatted_key,$driver})
                  {      
                    my $value = $self->{$key};
      
                    foreach my $code (@$deflate_code)
                    {
                      $value = $code->($self, $value);
                    }
    
                    $self->{$formatted_key,$driver} = $value;
                  }
                }
                else
                {
                  my $value = $self->{$key};
  
                  foreach my $code (@$deflate_code)
                  {
                    $value = $code->($self, $value);
                  }
  
                  $self->{$key} = $value;
                  $self->{$is_inflated_key} = 0;
                }
              }
                
              if($on_save_code)
              {
                foreach my $code (@$on_save_code)
                {
                  $code->($self);
                }
              }
            }
  
            &$method_code; # magic call using current @_
          }
          else
          {
            unless($self->{'triggers_disabled'})
            {
              local $self->{'triggers_disabled'} = 1;
  
              if($inflate_code)
              {
                my $value;
                
                if(defined $self->{$key})
                {
                  $value = $self->{$key};
                }
                else
                {
                  # Invoke built-in default and inflation code
                  # (The call must not be in void context)
                  $value = $method_code->($self, @_[1 .. $#$_]);
                }

                if($uses_formatted_key)
                {
                  foreach my $code (@$inflate_code)
                  {
                    $value = $code->($self, $value);
                  }

                  my $db = $self->db or die "Missing Rose::DB object attribute";
                  my $driver = $db->driver || 'unknown';
    
                  # Invalidate deflated value
                  $self->{$formatted_key,$driver} = undef;

                  # Set new inflated value
                  $self->{$key} = $value;
                }
                elsif(!$self->{$is_inflated_key})
                {    
                  foreach my $code (@$inflate_code)
                  {
                    $value = $code->($self, $value);
                  }
    
                  $self->{$is_inflated_key} = 1;
                  $self->{$key} = $value;
                }
              }
                
              if($on_get_code)
              {
                foreach my $code (@$on_get_code)
                {
                  $code->($self);
                }
              }
            }
  
            &$method_code; # magic call using current @_
          }
        }
      };

      no warnings;
      no strict 'refs';
      *{"${class}::$method_name"} = $method;
    }
    else # no applicable triggers for 'get'
    {
      no warnings;
      no strict 'refs';
      *{"${class}::$method_name"} = $method_code;
    }
  }
  elsif($type eq 'get')
  {
    if($inflate_code || $deflate_code || $on_save_code || $on_get_code)
    {
      my $method = sub
      {
        my($self) = $_[0];
    
        if($self->{STATE_SAVING()})
        {
          unless($self->{'triggers_disabled'})
          {
            local $self->{'triggers_disabled'} = 1;

            if($deflate_code)
            {
              if($uses_formatted_key)
              {
                my $db = $self->db or die "Missing Rose::DB object attribute";
                my $driver = $db->driver || 'unknown';

                unless(defined $self->{$formatted_key,$driver})
                {    
                  my $value = $self->{$key};
    
                  foreach my $code (@$deflate_code)
                  {
                    $value = $code->($self, $value);
                  }
  
                  $self->{$formatted_key,$driver} = $value;
                }
              }
              else
              {
                my $value = $self->{$key};

                foreach my $code (@$deflate_code)
                {
                  $value = $code->($self, $value);
                }

                $self->{$key} = $value;
                $self->{$is_inflated_key} = 0;
              }
            }
              
            if($on_save_code)
            {
              foreach my $code (@$on_save_code)
              {
                $code->($self);
              }
            }
          }

          &$method_code; # magic call using current @_
        }
        else
        {
          unless($self->{'triggers_disabled'})
          {
            local $self->{'triggers_disabled'} = 1;

              if($inflate_code)
              {
                my $value;
                
                if(defined $self->{$key})
                {
                  $value = $self->{$key};
                }
                else
                {
                  # Invoke built-in default and inflation code
                  # (The call must not be in void context)
                  $value = $method_code->($self, @_[1 .. $#$_]);
                }

                if($uses_formatted_key)
                {
                  foreach my $code (@$inflate_code)
                  {
                    $value = $code->($self, $value);
                  }

                  my $db = $self->db or die "Missing Rose::DB object attribute";
                  my $driver = $db->driver || 'unknown';
    
                  # Invalidate deflated value
                  $self->{$formatted_key,$driver} = undef;

                  # Set new inflated value
                  $self->{$key} = $value;
                }
                elsif(!$self->{$is_inflated_key})
                {    
                  foreach my $code (@$inflate_code)
                  {
                    $value = $code->($self, $value);
                  }
    
                  $self->{$is_inflated_key} = 1;
                  $self->{$key} = $value;
                }
              }

            if($on_get_code)
            {
              foreach my $code (@$on_get_code)
              {
                $code->($self);
              }
            }
          }

          &$method_code; # magic call using current @_
        }
      };

      no warnings;
      no strict 'refs';
      *{"${class}::$method_name"} = $method;
    }
    else # no applicable triggers for 'get'
    {
      no warnings;
      no strict 'refs';
      *{"${class}::$method_name"} = $method_code;
    }
  }
  elsif($type eq 'set')
  {
    if($on_load_code || $on_set_code)
    {
      my $method = sub
      {
        my($self) = $_[0];

        if($self->{STATE_LOADING()})
        {
          $self->{$is_inflated_key} = 0  unless($uses_formatted_key);

          &$method_code; # magic call using current @_

          unless($self->{'triggers_disabled'})
          {
            local $self->{'triggers_disabled'} = 1;

            if($on_load_code)
            {
              foreach my $code (@$on_load_code)
              {
                $code->($self);
              }
            }
          }
        }
        else
        {
          $self->{$is_inflated_key} = 0  unless($uses_formatted_key);

          &$method_code; # magic call using current @_

          unless($self->{'triggers_disabled'})
          {
            local $self->{'triggers_disabled'} = 1;

            if($on_set_code)
            {
              foreach my $code (@$on_set_code)
              {
                $code->($self);
              }
            }
          }
        }
      };

      no warnings;
      no strict 'refs';
      *{"${class}::$method_name"} = $method;
    }
    else # no applicable triggers for 'set'
    {
      no warnings;
      no strict 'refs';
      *{"${class}::$method_name"} = $method_code;
    }
  }
}

sub method_code
{
  my($self, $type) = (shift, shift);

  Carp::confess "Missing or undefined type argument"  unless(defined $type);

  if(@_)
  {
    return $self->{'method_code'}{$type} = shift;
  }

  return $self->{'method_code'}{$type};
}

sub make_methods
{
  my($self) = shift;
  
  $self->SUPER::make_methods(@_);
  $self->apply_triggers;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column - Base class for database column metadata objects.

=head1 SYNOPSIS

  package MyColumnType;

  use Rose::DB::Object::Metadata::Column;
  our @ISA = qw(Rose::DB::Object::Metadata::Column);
  ...

=head1 DESCRIPTION

This is the base class for objects that store and manipulate database column metadata.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for parsing, formatting, and creating object methods that manipulate column values.

L<Rose::DB::Object::Metadata::Column> objects stringify to the value returned by the L<name|/name> method.  This allows full-blown column objects to be used in place of column name strings in most situations.

=head2 MAKING METHODS

A L<Rose::DB::Object::Metadata::Column>-derived object is responsible for creating object methods that manipulate column values.  Each column object can make zero or more methods for each available column method type.  A column method type describes the purpose of a method.  The default column method types are:

=over 4

=item C<get_set>

A method that can both get and set the column value.  If an argument is passed, then the column value is set.  In either case, the current column value is returned.

=item C<get>

A method that returns the current column value.

=item C<set>

A method that sets the column value.

=back

Methods are created by calling L<make_methods|/make_methods>.  A list of method types can be passed to the call to L<make_methods|/make_methods>.  If absent, the list of method types is determined by the L<auto_method_types|/auto_method_types> method.  A list of all possible method types is available through the L<available_method_types|/available_method_types> method.

These methods make up the "public" interface to column method creation.  There are, however, several "protected" methods which are used internally to implement the methods described above.  (The word "protected" is used here in a vaguely C++ sense, meaning "accessible to subclasses, but not to the public.")  Subclasses will probably find it easier to override and/or call these protected methods in order to influence the behavior of the "public" method maker methods.

A L<Rose::DB::Object::Metadata::Column> object delegates method creation to a  L<Rose::Object::MakeMethods>-derived class.  Each L<Rose::Object::MakeMethods>-derived class has its own set of method types, each of which takes it own set of arguments.

Using this system, four pieces of information are needed to create a method on behalf of a L<Rose::DB::Object::Metadata::Column>-derived object:

=over 4

=item * The B<column method type> (e.g., C<get_set>, C<get>, C<set>)

=item * The B<method maker class> (e.g., L<Rose::DB::Object::MakeMethods::Generic>)

=item * The B<method maker method type> (e.g., L<scalar|Rose::DB::Object::MakeMethods::Generic/scalar>)

=item * The B<method maker arguments> (e.g., C<interface =E<gt> 'get_set_init'>)

=back

This information can be organized conceptually into a "method map" that connects a column method type to a method maker class and, finally, to one particular method type within that class, and its arguments.

The default method map is:

=over 4

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Generic>, L<scalar|Rose::DB::Object::MakeMethods::Generic/scalar>, C<interface =E<gt> 'get_set', ...>

=item C<get>

L<Rose::DB::Object::MakeMethods::Generic>, L<scalar|Rose::DB::Object::MakeMethods::Generic/scalar>, C<interface =E<gt> 'get', ...>

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Generic>, L<scalar|Rose::DB::Object::MakeMethods::Generic/scalar>, C<interface =E<gt> 'set', ...>

=back

Each item in the map is a column method type.  For each column method type, the method maker class, the method maker method type, and the "interesting" method maker arguments are listed, in that order.

The "..." in the method maker arguments is meant to indicate that other arguments have been omitted.  For example, the column object's L<default|/default> value is passed as part of the arguments for all method types.  These arguments that are common to all column method types are routinely omitted from the method map for the sake of brevity.  If there are no "interesting" method maker arguments, then "..." may appear by itself.

The purpose of documenting the method map is to answer the question, "What kind of method(s) will be created by this column object for a given method type?"  Given the method map, it's possible to read the documentation for each method maker class to determine how methods of the specified type behave when passed the listed arguments.

To this end, each L<Rose::DB::Object::Metadata::Column>-derived class in the L<Rose::DB::Object> module distribution will list its method map in its documentation.  This is a concise way to document the behavior that is specific to each column class, while omitting the common functionality (which is documented here, in the column base class).

Remember, the existence and behavior of the method map is really implementation detail.  A column object is free to implement the public method-making interface however it wants, without regard to any conceptual or actual method map.  It must then, of course, document what kinds of methods it makes for each of its method types, but it does not have to use a method map to do so.

=head1 CLASS METHODS

=over 4

=item B<default_auto_method_types [TYPES]>

Get or set the default list of L<auto_method_types|/auto_method_types>.  TYPES should be a list of column method types.  Returns the list of default column method types (in list context) or a reference to an array of the default column method types (in scalar context).  The default list contains only the "get_set" column method type.

=back

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new object based on PARAMS, where PARAMS are
name/value pairs.  Any object method is a valid parameter name.

=back

=head1 OBJECT METHODS

=over 4

=item B<accessor_method_name>

Returns the name of the method used to get the column value.  This is a convenient shortcut for:

    $column->method_name('get') || $column->method_name('get_set');

=item B<alias [NAME]>

Get or set an alternate L<name|/name> for this column.

=item B<available_method_types>

Returns the full list of column method types supported by this class.

=item B<auto_method_types [TYPES]>

Get or set the list of column method types that are automatically created when L<make_methods|/make_methods> is called without an explicit list of column method types.  The default list is determined by the L<default_auto_method_types|/default_auto_method_types> class method.

=item B<build_method_name_for_type TYPE>

Return a method name for the column method type TYPE.  The default implementation returns the column's L<alias|/alias> (if defined) or L<name|/name> for the method type "get_set", and the same thing with a "get_" or "set_" prefix for the "get" and "set" column method types, respectively.

=item B<default [VALUE]>

Get or set the default value of the column.

=item B<format_value DB, VALUE>

Convert VALUE into a string suitable for the database column of this type.  VALUE is expected to be like the return value of the L<parse_value|/parse_value> method.  DB is a L<Rose::DB> object that may be used as part of the parsing process.  Both arguments are required.

=item B<is_primary_key_member [BOOL]>

Get or set the boolean flag that indicates whether or not this column is part of the primary key for its table.

=item B<make_methods PARAMS>

Create object method used to manipulate column values.  PARAMS are name/value pairs.  Valid PARAMS are:

=over 4

=item C<preserve_existing BOOL>

Boolean flag that indicates whether or not to preserve existing methods in the case of a name conflict.

=item C<replace_existing BOOL>

Boolean flag that indicates whether or not to replace existing methods in the case of a name conflict.

=item C<target_class CLASS>

The class in which to make the method(s).  If omitted, it defaults to the calling class.

=item C<types ARRAYREF>

A reference to an array of column method types to be created.  If omitted, it defaults to the list of column method types returned by L<auto_method_types|/auto_method_types>.

=back

If any of the methods could not be created for any reason, a fatal error will occur.

=item B<manager_uses_method [BOOL]>

If true, then L<Rose::DB::Object::QueryBuilder> will pass column values through the object method(s) associated with this column when composing SQL queries where C<query_is_sql> is not set.  The default value is false.  See the L<Rose::DB::Object::QueryBuilder> documentation for more information.

Note: the method is named "manager_uses_method" instead of, say, "query_builder_uses_method" because L<Rose::DB::Object::QueryBuilder> is rarely used directly.  Instead, it's mostly used indirectly through the L<Rose::DB::Object::Manager> class.

=item B<method_name TYPE [, NAME]>

Get or set the name of the column method of type TYPE.

=item B<mutator_method_name>

Returns the name of the method used to set the column value.  This is a convenient shortcut for:

    $column->method_name('set') || $column->method_name('get_set');

=item B<name [NAME]>

Get or set the name of the column, not including the table name, username, schema, or any other qualifier.

=item B<not_null [BOOL]>

Get or set a boolean flag that indicates whether or not the column 
value can can be null.

=item B<parse_value DB, VALUE>

Parse and return a convenient Perl representation of VALUE.  What form this value will take is up to the column subclass.  If VALUE is a keyword or otherwise has special meaning to the underlying database, it may be returned unmodified.  DB is a L<Rose::DB> object that may be used as part of the parsing process.  Both arguments are required.

=item B<primary_key_position [INT]>

Get or set the column's ordinal position in the primary key.  Returns undef if the column is not part of the primary key.  Position numbering starts from 1.

=item B<rw_method_name>

Returns the name of the method used to get or set the column value.  This is a convenient shortcut for:

    $column->method_name('get_set');

=item B<should_inline_value DB, VALUE>

Given the L<Rose::DB>-derived object DB and the column value VALUE, return true of the value should be "inlined" (i.e., not bound to a "?" placeholder and passed as an argument to L<DBI>'s L<execute|DBI/execute> method), false otherwise.  The default implementation always returns false.

This method is necessary because some L<DBI> drivers do not (or cannot) always do the right thing when binding values to placeholders in SQL statements.  For example, consider the following SQL for the Informix database:

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

All of the information needed to make this decision is available to the call to L<should_inline_value|/should_inline_value>.  It gets passed a L<Rose::DB>-derived object, from which it can determine the database driver, and it gets passed the actual value, which it can check to see if it matches C</^current$/i>.

This is just one example.  Each subclass of L<Rose::DB::Object::Metadata::Column> must determine for itself when a value needs to be inlined.

=item B<type>

Returns the (possibly abstract) data type of the column.  The default implementation returns "scalar".

=back

=head1 PROTECTED API

These methods are not part of the public interface, but are supported for use by subclasses.  Put another way, given an unknown object that "isa" L<Rose::DB::Object::Metadata::Column>, there should be no expectation that the following methods exist.  But subclasses, which know the exact class from which they inherit, are free to use these methods in order to implement the public API described above.

=over 4 

=item B<method_maker_arguments TYPE>

Returns a hash (in list context) or reference to a hash (in scalar context) of name/value arguments that will be passed to the L<method_maker_class|/method_maker_class> when making the column method type TYPE.

=item B<method_maker_class TYPE [, CLASS]>

If CLASS is passed, the name of the L<Rose::Object::MakeMethods>-derived class used to create the object method of type TYPE is set to CLASS.

Returns the name of the L<Rose::Object::MakeMethods>-derived class used to create the object method of type TYPE.

=item B<method_maker_type TYPE [, NAME]>

If NAME is passed, the name of the method maker method type for the column method type TYPE is set to NAME.

Returns the method maker method type for the column method type TYPE.  

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
