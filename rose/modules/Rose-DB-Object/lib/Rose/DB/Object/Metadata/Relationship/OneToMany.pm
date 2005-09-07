package Rose::DB::Object::Metadata::Relationship::OneToMany;

use strict;

use Carp();

use Rose::DB::Object::Metadata::Relationship;
our @ISA = qw(Rose::DB::Object::Metadata::Relationship);

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Generic;

our $VERSION = '0.02';

__PACKAGE__->default_auto_method_types('get');

__PACKAGE__->add_common_method_maker_argument_names
(
  qw(class share_db key_columns manager_class manager_method manager_args query_args)
);

use Rose::Object::MakeMethods::Generic
(
  boolean =>
  [
    'share_db' => { default => 1 },
  ],

  hash =>
  [
    key_column  => { hash_key  => 'key_columns' },
    key_columns => { interface => 'get_set_all' },
  ],
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => 
  [
    __PACKAGE__->common_method_maker_argument_names
  ],
);

__PACKAGE__->method_maker_info
(
  get =>
  {
    class => 'Rose::DB::Object::MakeMethods::Generic',
    type  => 'objects_by_key',
  },
);

sub type { 'one to many' }

*map_column = \&key_column;
*column_map = \&key_columns;

sub build_method_name_for_type
{
  my($self, $type) = @_;
  
  if($type eq 'get')
  {
    return $self->name;
  }

  return undef;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Relationship::OneToMany - One to many table relationship metadata object.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Relationship::OneToMany;

  $rel = Rose::DB::Object::Metadata::Relationship::OneToMany->new(...);
  $rel->make_methods(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for relationships in which a single row from one table refers to multiple rows in another table.

This class inherits from L<Rose::DB::Object::Metadata::Relationship>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Relationship> documentation for more information.

=head1 METHOD MAP

=over 4

=item C<get>

L<Rose::DB::Object::MakeMethods::Generic>, L<objects_by_key|Rose::DB::Object::MakeMethods::Generic/objects_by_key>, ...

=back

See the L<Rose::DB::Object::Metadata::Relationship|Rose::DB::Object::Metadata::Relationship/"MAKING METHODS"> documentation for an explanation of this method map.


=head1 OBJECT METHODS

=over 4

=item B<build_method_name_for_type TYPE>

Return a method name for the relationship method type TYPE.  Returns the relationship's L<name|Rose::DB::Object::Metadata::Relationship/name> for the method type "get", undef otherwise.

=item B<map_column LOCAL [, FOREIGN]>

If passed a local column name LOCAL, return the corresponding column name in the foreign table.  If passed both a local column name LOCAL and a foreign column name FOREIGN, set the local/foreign mapping and return the foreign column name.

=item B<column_map [HASH | HASHREF]>

Get or set a reference to a hash that maps local column names to foreign column names.

=item B<type>

Returns "one to many".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
