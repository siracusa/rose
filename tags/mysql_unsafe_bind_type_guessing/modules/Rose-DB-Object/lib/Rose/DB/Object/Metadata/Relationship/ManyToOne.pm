package Rose::DB::Object::Metadata::Relationship::ManyToOne;

use strict;

use Carp();

use Rose::DB::Object::Metadata::Relationship;
our @ISA = qw(Rose::DB::Object::Metadata::Relationship);

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Generic;

our $VERSION = '0.65';

__PACKAGE__->default_auto_method_types(qw(get_set_on_save delete_on_save));

__PACKAGE__->add_common_method_maker_argument_names
(
  qw(class share_db key_columns)
);

use Rose::Object::MakeMethods::Generic
(
  boolean =>
  [
    '_share_db' => { default => 1 },
  ],

  hash =>
  [
    _key_column  => { hash_key  => 'key_columns' },
    _key_columns => { interface => 'get_set_all' },
  ],
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => 
  [
    'foreign_key',
    __PACKAGE__->common_method_maker_argument_names
  ],
);

__PACKAGE__->method_maker_info
(
  get_set =>
  {
    class => 'Rose::DB::Object::MakeMethods::Generic',
    type  => 'object_by_key',
  },

  get_set_now =>
  {
    class => 'Rose::DB::Object::MakeMethods::Generic',
    type  => 'object_by_key',  
    interface => 'get_set_now',
  },

  get_set_on_save =>
  {
    class => 'Rose::DB::Object::MakeMethods::Generic',
    type  => 'object_by_key',  
    interface => 'get_set_on_save',
  },

  delete_now =>
  {
    class => 'Rose::DB::Object::MakeMethods::Generic',
    type  => 'object_by_key',  
    interface => 'delete_now',
  },

  delete_on_save =>
  {
    class => 'Rose::DB::Object::MakeMethods::Generic',
    type  => 'object_by_key',  
    interface => 'delete_on_save',
  },
);

sub type { 'many to one' }

sub share_db    { shift->_fk_or_self(share_db => @_)     }
sub key_column  { shift->_fk_or_self(key_column => @_)   }
sub key_columns { shift->_fk_or_self(key_columns => @_)  }

*map_column = \&key_column;
*column_map = \&key_columns;

sub _fk_or_self
{
  my($self, $method) = (shift, shift);

  if(my $fk = $self->foreign_key)
  {
    return $fk->$method(@_);
  }

  $method = "_$method"  if($self->can("_$method"));
  return $self->$method(@_);
}

sub method_name
{
  my($self) = shift;

  if(my $fk = $self->foreign_key)
  {
    return $fk->method_name(@_);
  }

  return $self->SUPER::method_name(@_);
}

sub is_ready_to_make_methods
{
  my($self) = shift;

  if(my $fk = $self->foreign_key)
  {
    return $fk->is_ready_to_make_methods(@_);
  }

  return $self->SUPER::is_ready_to_make_methods(@_);
}

sub make_methods
{
  my($self) = shift;

  if(my $fk = $self->foreign_key)
  {
    return $fk->make_methods(@_);
  }

  return $self->SUPER::make_methods(@_);
}

sub id
{
  my($self) = shift;

  my $column_map = $self->column_map;

  return $self->parent->class . ' ' .   $self->class . ' ' . 
    join("\0", map { join("\1", lc $_, lc $column_map->{$_}) } sort keys %$column_map);
}

sub build_method_name_for_type
{
  my($self, $type) = @_;

  if($type eq 'get_set' || $type eq 'get_set_now' || $type eq 'get_set_on_save')
  {
    return $self->name;
  }
  elsif($type eq 'delete_now' || $type eq 'delete_on_save')
  {
    return 'delete_' . $self->name;
  }

  return undef;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Relationship::ManyToOne - Many to one table relationship metadata object.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Relationship::ManyToOne;

  $rel = Rose::DB::Object::Metadata::Relationship::ManyToOne->new(...);
  $rel->make_methods(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for relationships in which a many rows in one table may refer to a single row in another table.

This class inherits from L<Rose::DB::Object::Metadata::Relationship>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Relationship> documentation for more information.

=head1 METHOD MAP

=over 4

=item C<get_set>

L<Rose::DB::Object::MakeMethods::Generic>, L<object_by_key|Rose::DB::Object::MakeMethods::Generic/object_by_key>, ...

=item C<get_set_now>

L<Rose::DB::Object::MakeMethods::Generic>, L<object_by_key|Rose::DB::Object::MakeMethods::Generic/object_by_key>, C<interface =E<gt> 'get_set_now'>

=item C<get_set_on_save>

L<Rose::DB::Object::MakeMethods::Generic>, L<object_by_key|Rose::DB::Object::MakeMethods::Generic/object_by_key>, C<interface =E<gt> 'get_set_on_save'>

=item C<delete_now>

L<Rose::DB::Object::MakeMethods::Generic>, L<object_by_key|Rose::DB::Object::MakeMethods::Generic/object_by_key>, C<interface =E<gt> 'delete_now'>

=item C<delete_on_save>

L<Rose::DB::Object::MakeMethods::Generic>, L<object_by_key|Rose::DB::Object::MakeMethods::Generic/object_by_key>, C<interface =E<gt> 'delete_on_save'>

=back

See the L<Rose::DB::Object::Metadata::Relationship|Rose::DB::Object::Metadata::Relationship/"MAKING METHODS"> documentation for an explanation of this method map.

=head1 CLASS METHODS

=over 4

=item B<default_auto_method_types [TYPES]>

Get or set the default list of L<auto_method_types|Rose::DB::Object::Metadata::Relationship/auto_method_types>.  TYPES should be a list of relationship method types.  Returns the list of default relationship method types (in list context) or a reference to an array of the default relationship method types (in scalar context).  The default list contains "get_set_on_save" and "delete_on_save".

=back

=head1 OBJECT METHODS

=over 4

=item B<build_method_name_for_type TYPE>

Return a method name for the relationship method type TYPE.  

For the method types "get_set", "get_set_now", and "get_set_on_save", the relationship's L<name|Rose::DB::Object::Metadata::Relationship/name> is returned.

For the method types "delete_now" and "delete_on_save", the relationship's  L<name|Rose::DB::Object::Metadata::Relationship/name> prefixed with "delete_" is returned.

Otherwise, undef is returned.

=item B<foreign_key [FK]>

Get or set the L<Rose::DB::Object::Metadata::ForeignKey> object to which this object delegates all responsibility.

Many to one relationships encapsulate essentially the same information as foreign keys.  If a foreign key object is stored in this relationship object, then I<all compatible operations are passed through to the foreign key object.>  This includes making object method(s) and adding or modifying the local-to-foreign column map.  In other words, if a L<foreign_key|/foreign_key> is set, the relationship object simply acts as a proxy for the foreign key object.

=item B<map_column LOCAL [, FOREIGN]>

If passed a local column name LOCAL, return the corresponding column name in the foreign table.  If passed both a local column name LOCAL and a foreign column name FOREIGN, set the local/foreign mapping and return the foreign column name.

=item B<column_map [HASH | HASHREF]>

Get or set a reference to a hash that maps local column names to foreign column names.

=item B<type>

Returns "many to one".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
