package Rose::Class::MakeMethods::Generic;

use strict;

use Carp();

our $VERSION = '0.02';

use Rose::Object::MakeMethods;
our @ISA = qw(Rose::Object::MakeMethods);

our %Scalar;
# (
#   class_name =>
#   {
#     some_attr_name1 => ...,
#     some_attr_name2 => ...,
#     ...
#   },
#   ...
# );

sub scalar
{
  my($class, $name, $args, $options) = @_;

  my %methods;

  my $interface = $args->{'interface'} || 'get_set';

  if($interface eq 'get_set')
  {
    $methods{$name} = sub
    {
      return $Scalar{$_[0]}{$name} = $_[1]  if(@_ > 1);
      return $Scalar{$_[0]}{$name};
    };
  }
  elsif($interface eq 'get_set_init')
  {
    my $init_method = $args->{'init_method'} || "init_$name";

    $methods{$name} = sub
    {      
      return $Scalar{$_[0]}{$name} = $_[1]  if(@_ > 1);
      return defined $Scalar{$_[0]}{$name} ? 
        $Scalar{$_[0]}{$name} : ($Scalar{$_[0]}{$name} = $_[0]->$init_method())
    };
  }

  return \%methods;
}

our %Inheritable_Scalar;
# (
#   class_name =>
#   {
#     some_attr_name1 => ...,
#     some_attr_name2 => ...,
#     ...
#   },
#   ...
# );

sub inheritable_scalar
{
  my($class, $name, $args, $options) = @_;

  my %methods;

  my $interface = $args->{'interface'} || 'get_set';

  if($interface eq 'get_set')
  {
    $methods{$name} = sub 
    {
      my($class) = ref($_[0]) ? ref(shift) : shift;

      if(@_)
      {
        return $Inheritable_Scalar{$class}{$name} = shift;
      }

      return $Inheritable_Scalar{$class}{$name}
        if(exists $Inheritable_Scalar{$class}{$name});

      my @parents = ($class);

      while(my $parent = shift(@parents))
      {
        no strict 'refs';
        foreach my $subclass (@{$parent . '::ISA'})
        {
          push(@parents, $subclass);

          if(exists $Inheritable_Scalar{$subclass}{$name})
          {
            return $Inheritable_Scalar{$subclass}{$name}
          }
        }
      }

      return undef;
    };
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

our %Hash;
# (
#   class_name =>
#   {
#     key =>
#     {
#       some_attr_name1 => ...,
#       some_attr_name2 => ...,
#       ...
#     },
#     ...
#   },
#   ...
# );

sub hash
{
  my($class, $name, $args) = @_;

  my %methods;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';

  if($interface eq 'get_set_all')
  {
    $methods{$name} = sub
    {
      my($class) = ref $_[0] ? ref shift : shift;

      # If called with no arguments, return hash contents
      return wantarray ? %{$Hash{$class}{$key} || {}} : $Hash{$class}{$key}  unless(@_);

      # Set hash to arguments
      if(@_ == 1 && ref $_[0] eq 'HASH')
      {
        $Hash{$class}{$key} = $_[0];
      }
      else
      {
        # Push on new values and return complete set
        Carp::croak "Odd number of items in assigment to $name"  if(@_ % 2);

        while(@_)
        {
          local $_ = shift;
          $Hash{$class}{$key}{$_} = shift;
        }
      }

      return wantarray ? %{$Hash{$class}{$key} || {}} : $Hash{$class}{$key};
    }
  }
  elsif($interface eq 'clear')
  {
    $methods{$name} = sub
    {
      $Hash{$_[0]}{$key} = {}
    }
  }
  elsif($interface eq 'reset')
  {
    $methods{$name} = sub
    {
      $Hash{$_[0]}{$key} = undef
    }
  }
  elsif($interface eq 'delete')
  {
    $methods{($interface eq 'manip' ? 'delete_' : '') . $name} = sub
    {
      Carp::croak "Missing key(s) to delete"  unless(@_ > 1);
      delete @{$Hash{$_[0]}{$key}}{@_[1 .. $#_]};
    }
  }
  elsif($interface eq 'exists')
  {
    $methods{$name . ($interface eq 'manip' ? '_exists' : '')} = sub
    {
      Carp::croak "Missing key argument"  unless(@_ == 2);
      defined $Hash{$_[0]}{$key} ? exists $Hash{$_[0]}{$key}{$_[1]} : undef;
    }
  }
  elsif($interface =~ /^(?:keys|names)$/)
  {
    $methods{$name} = sub
    {
      wantarray ? (defined $Hash{$_[0]}{$key} ? keys %{$Hash{$_[0]}{$key}} : ()) :
                  (defined $Hash{$_[0]}{$key} ? [ keys %{$Hash{$_[0]}{$key}} ] : []);
    }
  }
  elsif($interface eq 'values')
  {
    $methods{$name} = sub
    {
      wantarray ? (defined $Hash{$_[0]}{$key} ? values %{$Hash{$_[0]}{$key}} : ()) :
                  (defined $Hash{$_[0]}{$key} ? [ values %{$Hash{$_[0]}{$key}} ] : []);
    }
  }
  elsif($interface eq 'get_set')
  {
    $methods{$name} = sub
    {
      my($class) = ref $_[0] ? ref shift : shift;

      # If called with no arguments, return hash contents
      unless(@_)
      {
        return wantarray ? (defined $Hash{$class}{$key} ? %{$Hash{$class}{$key}} : ()) : $Hash{$class}{$key}  
      }

      # If called with a hash ref, set value
      if(@_ == 1 && ref $_[0] eq 'HASH')
      {
        $Hash{$class}{$key} = $_[0];
      }
      else
      {      
        # If called with an index, get that value, or a slice for array refs
        if(@_ == 1)
        {
          return ref $_[0] eq 'ARRAY' ? @{$Hash{$class}{$key}}{@{$_[0]}} : 
                                        $Hash{$class}{$key}{$_[0]};
        }

        # Push on new values and return complete set
        Carp::croak "Odd number of items in assigment to $name"  if(@_ % 2);

        while(@_)
        {
          local $_ = shift;
          $Hash{$class}{$key}{$_} = shift;
        }
      }

      return wantarray ? %{$Hash{$class}{$key} || {}} : $Hash{$class}{$key};
    };
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}
our %Inheritable_Hash;
# (
#   class_name =>
#   {
#     key =>
#     {
#       some_attr_name1 => ...,
#       some_attr_name2 => ...,
#       ...
#     },
#     ...
#   },
#   ...
# );

sub inheritable_hash
{
  my($class, $name, $args) = @_;

  my %methods;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';

  my $init_method = sub
  {
    my($class) = ref $_[0] ? ref shift : shift;

    # Inherit shallow copy from subclass
    my @parents = ($class);

    SEARCH: while(my $parent = shift(@parents))
    {
      no strict 'refs';
      foreach my $subclass (@{$parent . '::ISA'})
      {
        push(@parents, $subclass);

        if(exists $Inheritable_Hash{$subclass}{$key})
        {
          $Inheritable_Hash{$class}{$key} = { %{$Inheritable_Hash{$subclass}{$key}} };
          last SEARCH;
        }
      }
    }
  };

  if($interface eq 'get_set_all')
  {
    $methods{$name} = sub
    {
      my($class) = ref $_[0] ? ref shift : shift;

      defined $Inheritable_Hash{$class}{$key} || $init_method->($class);

      # If called with no arguments, return hash contents
      return wantarray ? %{$Inheritable_Hash{$class}{$key} || {}} : $Inheritable_Hash{$class}{$key}  unless(@_);

      # Set hash to arguments
      if(@_ == 1 && ref $_[0] eq 'HASH')
      {
        $Inheritable_Hash{$class}{$key} = $_[0];
      }
      else
      {
        # Push on new values and return complete set
        Carp::croak "Odd number of items in assigment to $name"  if(@_ % 2);

        while(@_)
        {
          local $_ = shift;
          $Inheritable_Hash{$class}{$key}{$_} = shift;
        }
      }

      return wantarray ? %{$Inheritable_Hash{$class}{$key} || {}} : $Inheritable_Hash{$class}{$key};
    }
  }
  elsif($interface eq 'clear')
  {
    $methods{$name} = sub
    {
      $Inheritable_Hash{$_[0]}{$key} = {}
    }
  }
  elsif($interface eq 'reset')
  {
    $methods{$name} = sub
    {
      $Inheritable_Hash{$_[0]}{$key} = undef;
    }
  }
  elsif($interface eq 'delete')
  {
    $methods{($interface eq 'manip' ? 'delete_' : '') . $name} = sub
    {
      Carp::croak "Missing key(s) to delete"  unless(@_ > 1);
      defined $Inheritable_Hash{$_[0]}{$key} || $init_method->($_[0]);
      delete @{$Inheritable_Hash{$_[0]}{$key}}{@_[1 .. $#_]};
    }
  }
  elsif($interface eq 'exists')
  {
    $methods{$name . ($interface eq 'manip' ? '_exists' : '')} = sub
    {
      Carp::croak "Missing key argument"  unless(@_ == 2);
      defined $Inheritable_Hash{$_[0]}{$key} || $init_method->($_[0]);
      defined $Inheritable_Hash{$_[0]}{$key} ? exists $Inheritable_Hash{$_[0]}{$key}{$_[1]} : undef;
    }
  }
  elsif($interface =~ /^(?:keys|names)$/)
  {
    $methods{$name} = sub
    {
      defined $Inheritable_Hash{$_[0]}{$key} || $init_method->($_[0]);
      wantarray ? (defined $Inheritable_Hash{$_[0]}{$key} ? keys %{$Inheritable_Hash{$_[0]}{$key} || {}} : ()) :
                  (defined $Inheritable_Hash{$_[0]}{$key} ? [ keys %{$Inheritable_Hash{$_[0]}{$key} || {}} ] : []);
    }
  }
  elsif($interface eq 'values')
  {
    $methods{$name} = sub
    {
      defined $Inheritable_Hash{$_[0]}{$key} || $init_method->($_[0]);
      wantarray ? (defined $Inheritable_Hash{$_[0]}{$key} ? values %{$Inheritable_Hash{$_[0]}{$key} || {}} : ()) :
                  (defined $Inheritable_Hash{$_[0]}{$key} ? [ values %{$Inheritable_Hash{$_[0]}{$key} || {}} ] : []);
    }
  }
  elsif($interface eq 'get_set')
  {
    $methods{$name} = sub
    {
      my($class) = ref $_[0] ? ref shift : shift;

      defined $Inheritable_Hash{$class}{$key} || $init_method->($class);

      # If called with no arguments, return hash contents
      unless(@_)
      {
        return wantarray ? (defined $Inheritable_Hash{$class}{$key} ? %{$Inheritable_Hash{$class}{$key} || {}} : ()) : $Inheritable_Hash{$class}{$key}  
      }

      # If called with a hash ref, set value
      if(@_ == 1 && ref $_[0] eq 'HASH')
      {
        $Inheritable_Hash{$class}{$key} = $_[0];
      }
      else
      {      
        # If called with an index, get that value, or a slice for array refs
        if(@_ == 1)
        {
          return ref $_[0] eq 'ARRAY' ? @{$Inheritable_Hash{$class}{$key}}{@{$_[0]}} : 
                                        $Inheritable_Hash{$class}{$key}{$_[0]};
        }

        # Push on new values and return complete set
        Carp::croak "Odd number of items in assigment to $name"  if(@_ % 2);

        while(@_)
        {
          local $_ = shift;
          $Inheritable_Hash{$class}{$key}{$_} = shift;
        }
      }

      return wantarray ? %{$Inheritable_Hash{$class}{$key} || {}} : $Inheritable_Hash{$class}{$key};
    };
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

1;

__END__

=head1 NAME

Rose::Class::MakeMethods::Generic - Create simple class methods.

=head1 SYNOPSIS

  package MyClass;

  use Rose::Class::MakeMethods::Generic
  (
    scalar => 
    [
      'error',
      'type' => { interface => 'get_set_init' },
    ],

    inheritable_scalar => 'name',
  );

  sub init_type { 'special' }
  ...

  package MySubClass;
  our @ISA = qw(MyClass);
  ...

  MyClass->error(123);

  print MyClass->type; # 'special'

  MyClass->name('Fred');
  print MySubClass->name; # 'Fred'

  MyClass->name('Wilma');
  print MySubClass->name; # 'Wilma'

  MySubClass->name('Bam');
  print MyClass->name;    # 'Wilma'
  print MySubClass->name; # 'Bam'

=head1 DESCRIPTION

C<Rose::Class::MakeMethods::Generic> is a method maker that inherits
from L<Rose::Object::MakeMethods>.  See the L<Rose::Object::MakeMethods>
documentation to learn about the interface.  The method types provided
by this module are described below.  All methods work only with
classes, not objects.

=head1 METHODS TYPES

=over 4

=item B<scalar>

Create get/set methods for scalar class attributes.

=over 4

=item Options

=over 4

=item C<init_method>

The name of the class method to call when initializing the value of an
undefined attribute.  This option is only applicable when using the
C<get_set_init> interface.  Defaults to the method name with the prefix
C<init_> added.

=item C<interface>

Choose one of the two possible interfaces.  Defaults to C<get_set>.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a simple get/set accessor method for a class attribute.  When
called with an argument, the value of the attribute is set.  The current
value of the attribute is returned.

=item C<get_set_init> 

Behaves like the C<get_set> interface unless the value of the attribute
is undefined.  In that case, the class method specified by the
C<init_method> option is called and the attribute is set to the return
value of that method.

=back

=back

Example:

    package MyClass;

    use Rose::Class::MakeMethods::Generic
    (
      scalar => 'power',
      'scalar --get_set_init' => 'name',
    );

    sub init_name { 'Fred' }
    ...

    MyClass->power(99);    # returns 99
    MyClass->name;         # returns "Fred"
    MyClass->name('Bill'); # returns "Bill"

=item B<inheritable_scalar>

Create get/set methods for scalar class attributes that are
inherited by subclasses until/unless their values are changed.

=over 4

=item Options

=over 4

=item C<interface>

Choose the interface.  This is kind of pointless since there is only
one interface right now.  Defaults to C<get_set>, obviously.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a get/set accessor method for a class attribute.  When called
with an argument, the value of the attribute is set and then returned.

If called with no arguments, and if the attribute was never set for this
class, then a left-most, breadth-first search of the parent classes is
initiated.  The value returned is taken from first parent class 
encountered that has ever had this attribute set.

=back

=back

Example:

    package MyClass;

    use Rose::Class::MakeMethods::Generic
    (
      inheritable_scalar => 'name',
    );
    ...

    package MySubClass;
    our @ISA = qw(MyClass);
    ...

    package MySubSubClass;
    our @ISA = qw(MySubClass);
    ...

    $x = MyClass->name;       # undef
    $y = MySubClass->name;    # undef
    $z = MySubSubClass->name; # undef

    MyClass->name('Fred');
    $x = MyClass->name;       # 'Fred'
    $y = MySubClass->name;    # 'Fred'
    $z = MySubSubClass->name; # 'Fred'

    MyClass->name('Wilma');
    $x = MyClass->name;       # 'Wilma'
    $y = MySubClass->name;    # 'Wilma'
    $z = MySubSubClass->name; # 'Wilma'

    MySubClass->name('Bam');
    $x = MyClass->name;       # 'Wilma'
    $y = MySubClass->name;    # 'Bam'
    $z = MySubSubClass->name; # 'Bam'

    MyClass->name('Koop');
    MySubClass->name(undef);
    $x = MyClass->name;       # 'Koop'
    $y = MySubClass->name;    # undef
    $z = MySubSubClass->name; # undef

    MySubSubClass->name('Sam');
    $x = MyClass->name;       # 'Koop'
    $y = MySubClass->name;    # undef
    $z = MySubSubClass->name; # 'Sam'

=item B<hash>

Create methods to manipulate a hash of class attributes.

=over 4

=item Options

=over 4

=item C<hash_key>

The key to use for the storage of this attribute.  Defaults to the name of the method.

=item C<interface>

Choose which interface to use.  Defaults to C<get_set>.

=back

=item Interfaces

=over 4

=item C<get_set>

If called with no arguments, returns a list of key/value pairs in
list context or a reference to the actual hash used to store values
in scalar context.

If called with one argument, and that argument is a reference to a hash,
that hash reference is used as the new value for the attribute.  Returns
a list of key/value pairs in list context or a reference to the actual
hash used to store values in scalar context.

If called with one argument, and that argument is a reference to an array,
then a list of the hash values for each key in the array is returned.

If called with one argument, and it is not a reference to a hash or an array,
then the hash value for that key is returned.

If called with an even number of arguments, they are taken as name/value pairs
and are added to the hash.  It then returns a list of key/value pairs in list
context or a reference to the actual hash used to store values in scalar
context.

Passing an odd number of arguments greater than 1 causes a fatal error.

=item C<get_set_all> 

If called with no arguments, returns a list of key/value pairs in
list context or a reference to the actual hash used to store values
in scalar context.

If called with one argument, and that argument is a reference to a hash,
that hash reference is used as the new value for the attribute.  Returns
a list of key/value pairs in list context or a reference to the actual
hash used to store values in scalar context.

Otherwise, the hash is emptied and the arguments are taken as name/value pairs
that are then added to the hash.  It then returns a list of key/value pairs in
list context or a reference to the actual hash used to store values in scalar
context.

=item C<clear> 

Sets the attribute to an empty hash.

=item C<reset> 

Sets the attribute to undef.

=item C<delete> 

Deletes the key(s) passed as arguments.  Failure to pass any arguments
causes a fatal error.

=item C<exists> 

Returns true of the argument exists in the hash, false otherwise.
Failure to pass an argument or passing more than one argument causes a
fatal error.

=item C<keys> 

Returns the keys of the hash in list context, or a reference to an array
of the keys of the hash in scalar context.  The keys are not sorted.

=item C<names> 

An alias for the C<keys> interface.

=item C<values> 

Returns the values of the hash in list context, or a reference to an array
of the values of the hash in scalar context.  The values are not sorted.

=back

=back

Example:

    package MyClass;

    use Rose::Class::MakeMethods::Generic
    (
      hash =>
      [
        param        => { hash_key =>'params' },
        params       => { interface=>'get_set_all' },
        param_names  => { interface=>'keys',   hash_key=>'params' },
        param_values => { interface=>'values', hash_key=>'params' },
        param_exists => { interface=>'exists', hash_key=>'params' },
        delete_param => { interface=>'delete', hash_key=>'params' },

        clear_params => { interface=>'clear', hash_key=>'params' },
        reset_params => { interface=>'reset', hash_key=>'params' },
      ],
    );
    ...

    MyClass->params; # undef

    MyClass->params(a => 1, b => 2); # add pairs
    $val = MyClass->param('b'); # 2

    %params = MyClass->params; # copy hash keys and values
    $params = MyClass->params; # get hash ref

    MyClass->params({ c => 3, d => 4 }); # replace contents

    MyClass->param_exists('a'); # false

    $keys = join(',', sort MyClass->param_names);  # 'c,d'
    $vals = join(',', sort MyClass->param_values); # '3,4'

    MyClass->delete_param('c');
    MyClass->param(f => 7, g => 8);

    $vals = join(',', sort MyClass->param_values); # '4,7,8'

    MyClass->clear_params;
    $params = MyClass->params; # empty hash

    MyClass->reset_params;
    $params = MyClass->params; # undef

=item B<inheritable_hash>

Create methods to manipulate a hash of class attributes that can be inherited by subclasses.

The hash of attributes is inherited by subclasses using a one-time copy.  Any subclass that accesses or manipulates the hash in any way will immediately get its own private copy of the hash I<as it exists in the superclass at the time of the access or manipulation>.  

The superclass from which the hash is copied is the closest ("least super") class that has ever accessed or manipulated this hash.  The copy is a "shallow" copy, duplicating only the keys and values.  Reference values are not recursively copied.

Setting to hash to undef (using the 'reset' interface) will cause it to be re-copied from a superclass the next time it is accessed.

=over 4

=item Options

=over 4

=item C<hash_key>

The key to use for the storage of this attribute.  Defaults to the name of the method.

=item C<interface>

Choose which interface to use.  Defaults to C<get_set>.

=back

=item Interfaces

=over 4

=item C<get_set>

If called with no arguments, returns a list of key/value pairs in
list context or a reference to the actual hash used to store values
in scalar context.

If called with one argument, and that argument is a reference to a hash,
that hash reference is used as the new value for the attribute.  Returns
a list of key/value pairs in list context or a reference to the actual
hash used to store values in scalar context.

If called with one argument, and that argument is a reference to an array,
then a list of the hash values for each key in the array is returned.

If called with one argument, and it is not a reference to a hash or an array,
then the hash value for that key is returned.

If called with an even number of arguments, they are taken as name/value pairs
and are added to the hash.  It then returns a list of key/value pairs in list
context or a reference to the actual hash used to store values in scalar
context.

Passing an odd number of arguments greater than 1 causes a fatal error.

=item C<get_set_all> 

If called with no arguments, returns a list of key/value pairs in
list context or a reference to the actual hash used to store values
in scalar context.

If called with one argument, and that argument is a reference to a hash,
that hash reference is used as the new value for the attribute.  Returns
a list of key/value pairs in list context or a reference to the actual
hash used to store values in scalar context.

Otherwise, the hash is emptied and the arguments are taken as name/value pairs
that are then added to the hash.  It then returns a list of key/value pairs in
list context or a reference to the actual hash used to store values in scalar
context.

=item C<clear> 

Sets the attribute to an empty hash.

=item C<reset> 

Sets the attribute to undef.

=item C<delete> 

Deletes the key(s) passed as arguments.  Failure to pass any arguments
causes a fatal error.

=item C<exists> 

Returns true of the argument exists in the hash, false otherwise.
Failure to pass an argument or passing more than one argument causes a
fatal error.

=item C<keys> 

Returns the keys of the hash in list context, or a reference to an array
of the keys of the hash in scalar context.  The keys are not sorted.

=item C<names> 

An alias for the C<keys> interface.

=item C<values> 

Returns the values of the hash in list context, or a reference to an array
of the values of the hash in scalar context.  The values are not sorted.

=back

=back

Example:

    package MyClass;

    use Rose::Class::MakeMethods::Generic
    (
      inheritable_hash =>
      [
        param        => { hash_key =>'params' },
        params       => { interface=>'get_set_all' },
        param_names  => { interface=>'keys',   hash_key=>'params' },
        param_values => { interface=>'values', hash_key=>'params' },
        param_exists => { interface=>'exists', hash_key=>'params' },
        delete_param => { interface=>'delete', hash_key=>'params' },

        clear_params => { interface=>'clear', hash_key=>'params' },
        reset_params => { interface=>'reset', hash_key=>'params' },
      ],
    );
    ...

    package MySubClass;
    our @ISA = qw(MyClass);
    ...

    MyClass->params; # undef

    MyClass->params(a => 1, b => 2); # add pairs
    $val = MyClass->param('b'); # 2

    %params = MyClass->params; # copy hash keys and values
    $params = MyClass->params; # get hash ref

    # Inherit a copy of params from MyClass
    $params = MySubClass->params; # { a => 1, b => 2 }

    MyClass->params({ c => 3, d => 4 }); # replace contents

    # MySubClass params are still as the existed at the time
    # they were originally copied from MyClass
    $params = MySubClass->params; # { a => 1, b => 2 }

    # MySubClass can manipulate its own params as it wishes
    MySubClass->param(z => 9);

    $params = MySubClass->params; # { a => 1, b => 2, z => 9 }

    MyClass->param_exists('a'); # false

    $keys = join(',', sort MyClass->param_names);  # 'c,d'
    $vals = join(',', sort MyClass->param_values); # '3,4'

    # Reset params (set to undef) so that they will be re-copied
    # from MyClass the next time they're accessed
    MySubClass->reset_params;

    MyClass->delete_param('c');
    MyClass->param(f => 7, g => 8);

    $vals = join(',', sort MyClass->param_values); # '4,7,8'

    # Inherit a copy of params from MyClass
    $params = MySubClass->params; # { d => 4, f => 7, g => 8 }

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
