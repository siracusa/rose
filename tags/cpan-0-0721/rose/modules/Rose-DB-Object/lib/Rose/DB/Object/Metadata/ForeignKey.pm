package Rose::DB::Object::Metadata::ForeignKey;

use strict;

use Rose::DB::Object::Metadata::Util qw(:all);

use Rose::DB::Object::Metadata::Column;
our @ISA = qw(Rose::DB::Object::Metadata::Column);

our $VERSION = '0.02';

use overload
(
  # "Undo" inherited overloaded stringification.  
  # (Using "no overload ..." didn't seem to work.)
  '""' => sub { overload::StrVal($_[0]) },
   fallback => 1,
);

__PACKAGE__->default_auto_method_types('get');

__PACKAGE__->add_common_method_maker_argument_names
(
  qw(share_db class key_columns)
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
  scalar => [ __PACKAGE__->common_method_maker_argument_names ],
);

__PACKAGE__->method_maker_info
(
  get =>
  {
    class => 'Rose::DB::Object::MakeMethods::Generic',
    type  => 'object_by_key',
  },
);

sub type { 'foreign key' }

sub build_method_name_for_type
{
  my($self, $type) = @_;
  
  if($type eq 'get')
  {
    return $self->name;
  }

  return undef;
}

sub id
{
  my($self) = shift;

  my $key_columns = $self->key_columns;

  return $self->class . ' ' . 
    join("\0", map { join("\1", lc $_, lc $key_columns->{$_}) } sort keys %$key_columns);
}

sub perl_hash_definition
{
  my($self, %args) = @_;

  my $meta = $self->parent;

  my $indent = defined $args{'indent'} ? $args{'indent'} : 
                 ($meta ? $meta->default_perl_indent : undef);

  my $braces = defined $args{'braces'} ? $args{'braces'} : 
                 ($meta ? $meta->default_perl_braces : undef);

  my $indent_txt = ' ' x $indent;

  my $def = perl_quote_key($self->name) . ' => ' .
            ($braces eq 'bsd' ? "\n{\n" : "{\n") .
            $indent_txt . 'class => ' . perl_quote_value($self->class) . ",\n";

  my $key_columns = $self->key_columns;

  my $max_len = 0;
  my $min_len = -1;

  foreach my $name (keys %$key_columns)
  {
    $max_len = length($name)  if(length $name > $max_len);
    $min_len = length($name)  if(length $name < $min_len || $min_len < 0);
  }

  $def .= $indent_txt . 'key_columns => ' . ($braces eq 'bsd' ? "\n" : '');

  my $hash = perl_hashref(hash => $key_columns, indent => $indent * 2, inline => 0);

  for($hash)
  {
    s/^/$indent_txt/g;
    s/\A$indent_txt//;
    s/\}\Z/$indent_txt}/;
    s/\A(\s*\{)/$indent_txt$1/  if($braces eq 'bsd');
  }

  $def .= $hash . ",\n}";

  return $def;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::ForeignKey - Foreign key metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::ForeignKey;

  $fk = Rose::DB::Object::Metadata::ForeignKey->new(...);
  $fk->make_methods(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for foreign keys in a database table.  It stores information about which columns in the local table map to which columns in the foreign table.

This class will create methods for C<the thing referenced by> the foreign key column(s).  You'll still need accessor method(s) for the foreign key column(s) themselves.

Both the local table and the foreign table must have L<Rose::DB::Object>-derived classes fronting them.

=head2 MAKING METHODS

A L<Rose::DB::Object::Metadata::ForeignKey>-derived object is responsible for creating object methods that manipulate objects referenced by a foreign key.  Each foreign key object can make zero or more methods for each available foreign key method type.  A foreign key method type describes the purpose of a method.  The default list of foreign key method types contains only one type:

=over 4

=item C<get>

A method that returns the object referenced by the foreign key.

=back

Methods are created by calling L<make_methods|/make_methods>.  A list of method types can be passed to the call to L<make_methods|/make_methods>.  If absent, the list of method types is determined by the L<auto_method_types|/auto_method_types> method.  A list of all possible method types is available through the L<available_method_types|/available_method_types> method.

These methods make up the "public" interface to foreign key method creation.  There are, however, several "protected" methods which are used internally to implement the methods described above.  (The word "protected" is used here in a vaguely C++ sense, meaning "accessible to subclasses, but not to the public.")  Subclasses will probably find it easier to override and/or call these protected methods in order to influence the behavior of the "public" method maker methods.

A L<Rose::DB::Object::Metadata::ForeignKey> object delegates method creation to a  L<Rose::Object::MakeMethods>-derived class.  Each L<Rose::Object::MakeMethods>-derived class has its own set of method types, each of which takes it own set of arguments.

Using this system, four pieces of information are needed to create a method on behalf of a L<Rose::DB::Object::Metadata::ForeignKey>-derived object:

=over 4

=item * The B<foreign key method type> (e.g., C<get>)

=item * The B<method maker class> (e.g., L<Rose::DB::Object::MakeMethods::Generic>)

=item * The B<method maker method type> (e.g., L<object_by_key|Rose::DB::Object::MakeMethods::Generic/object_by_key>)

=item * The B<method maker arguments> (e.g., C<interface =E<gt> 'get'>)

=back

This information can be organized conceptually into a "method map" that connects a foreign key method type to a method maker class and, finally, to one particular method type within that class, and its arguments.

The default method map for L<Rose::DB::Object::Metadata::ForeignKey> is:

=over 4

=item C<get>

L<Rose::DB::Object::MakeMethods::Generic>, L<object_by_key|Rose::DB::Object::MakeMethods::Generic/object_by_key>, ...

=back

Each item in the map is a foreign key method type.  For each foreign key method type, the method maker class, the method maker method type, and the "interesting" method maker arguments are listed, in that order.

The "..." in the method maker arguments is meant to indicate that arguments have been omitted.  Arguments that are common to all foreign key method types are routinely omitted from the method map for the sake of brevity.  If there are no "interesting" method maker arguments, then "..." may appear by itself, as shown above.

The purpose of documenting the method map is to answer the question, "What kind of method(s) will be created by this foreign key object for a given method type?"  Given the method map, it's possible to read the documentation for each method maker class to determine how methods of the specified type behave when passed the listed arguments.

Remember, the existence and behavior of the method map is really implementation detail.  A foreign key object is free to implement the public method-making interface however it wants, without regard to any conceptual or actual method map.

=head1 CLASS METHODS

=over 4

=item B<default_auto_method_types [TYPES]>

Get or set the default list of L<auto_method_types|/auto_method_types>.  TYPES should be a list of foreign key method types.  Returns the list of default foreign key method types (in list context) or a reference to an array of the default foreign key method types (in scalar context).  The default list contains only the "get" foreign key method type.

=back

=head1 OBJECT METHODS

=over 4

=item B<available_method_types>

Returns the full list of foreign key method types supported by this class.

=item B<auto_method_types [TYPES]>

Get or set the list of foreign key method types that are automatically created when L<make_methods|/make_methods> is called without an explicit list of foreign key method types.  The default list is determined by the L<default_auto_method_types|/default_auto_method_types> class method.

=item B<build_method_name_for_type TYPE>

Return a method name for the foreign key method type TYPE.  The default implementation returns the foreign key's L<name|/name> for the foreign key method type "get", and undef otherwise.

=item B<class [CLASS]>

Get or set the class name of the L<Rose::DB::Object>-derived object that encapsulates rows from the table referenced by the foreign key column(s).

=item B<key_column LOCAL [, FOREIGN]>

If passed a local column name LOCAL, return the corresponding column name in the foreign table.  If passed both a local column name LOCAL and a foreign column name FOREIGN, set the local/foreign mapping and return the foreign column name.

=item B<key_columns [HASH | HASHREF]>

Get or set a reference to a hash that maps local column names to foreign column names in the table referenced by the foreign key.

=item B<make_methods PARAMS>

Create object method used to manipulate object referenced by the foreign key.  PARAMS are name/value pairs.  Valid PARAMS are:

=over 4

=item C<preserve_existing BOOL>

Boolean flag that indicates whether or not to preserve existing methods in the case of a name conflict.

=item C<replace_existing BOOL>

Boolean flag that indicates whether or not to replace existing methods in the case of a name conflict.

=item C<target_class CLASS>

The class in which to make the method(s).  If omitted, it defaults to the calling class.

=item C<types ARRAYREF>

A reference to an array of foreign key method types to be created.  If omitted, it defaults to the list of foreign key method types returned by L<auto_method_types|/auto_method_types>.

=back

If any of the methods could not be created for any reason, a fatal error will occur.

=item B<name [NAME]>

Get or set the name of the foreign key.  This name must be unique among all other foreign keys for a given L<Rose::DB::Object>-derived class.

=item B<share_db [BOOL]>

Get or set the boolean flag that determines whether the L<db|Rose::DB::Object/db> attribute of the current object is shared with the foreign object to be fetched.  The default value is true.

=item B<type>

Returns "foreign key".

=back

=head1 PROTECTED API

These methods are not part of the public interface, but are supported for use by subclasses.  Put another way, given an unknown object that "isa" L<Rose::DB::Object::Metadata::ForeignKey>, there should be no expectation that the following methods exist.  But subclasses, which know the exact class from which they inherit, are free to use these methods in order to implement the public API described above.

=over 4 

=item B<method_maker_arguments TYPE>

Returns a hash (in list context) or reference to a hash (in scalar context) of name/value arguments that will be passed to the L<method_maker_class|/method_maker_class> when making the foreign key method type TYPE.

=item B<method_maker_class TYPE [, CLASS]>

If CLASS is passed, the name of the L<Rose::Object::MakeMethods>-derived class used to create the object method of type TYPE is set to CLASS.

Returns the name of the L<Rose::Object::MakeMethods>-derived class used to create the object method of type TYPE.

=item B<method_maker_type TYPE [, NAME]>

If NAME is passed, the name of the method maker method type for the foreign key method type TYPE is set to NAME.

Returns the method maker method type for the foreign key method type TYPE.  

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
