package Rose::DB::Object::Helpers;

use strict;

use Rose::DB::Object::Constants qw(:all);

use Rose::DB::Object::MixIn;
our @ISA = qw(Rose::DB::Object::MixIn);

use Carp;

our $VERSION = '0.723';

__PACKAGE__->export_tag
(
  all => [ qw(clone clone_and_reset load_or_insert load_speculative) ]
);

sub load_speculative { shift->load(@_, speculative => 1) }

sub load_or_insert
{
  my($self) = shift;

  my($ret, @ret);

  if(wantarray)
  {
    @ret = $self->load(@_, speculative => 1);
    return @ret  if($ret[0]);
  }
  else
  {
    $ret = $self->load(@_, speculative => 1);
    return $ret  if($ret);
  }

  return $self->insert;
}

sub clone
{
  my($self) = shift;
  my $class = ref $self;
  local $self->{STATE_CLONING()} = 1;
  return $class->new(map { $_ => $self->$_() } $self->meta->column_accessor_method_names);
}

sub clone_and_reset
{
  my($self) = shift;
  my $class = ref $self;
  local $self->{STATE_CLONING()} = 1;
  my $clone = $class->new(map { $_ => $self->$_() } $self->meta->column_accessor_method_names);
  
  my $meta = $class->meta;

  no strict 'refs';

  # Blank all primary and unique key columns
  foreach my $method ($meta->primary_key_column_mutator_names)
  {
    $clone->$method(undef);
  }
  
  foreach my $uk ($meta->unique_keys)
  {
    foreach my $column ($uk->columns)
    {
      my $method = $meta->column_mutator_method_name($column);
      $clone->$method(undef);
    }
  }

  # Also copy db object, if any
  if(my $db = $self->{'db'})
  {
    #$self->{FLAG_DB_IS_PRIVATE()} = 0;
    $clone->db($db);
  }

  return $clone;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Helpers - A mix-in class containing convenience methods for Rose::DB::Object.

=head1 SYNOPSIS

  package MyDBObject;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  use Rose::DB::Object::Helpers 'clone', { load_or_insert => 'find_or_create' };
  ...

  $obj = MyDBObject->new(id => 123);
  $obj->find_or_create();
  
  $obj2 = $obj->clone;

=head1 DESCRIPTION

L<Rose::DB::Object::Helpers> provides convenience methods from use with L<Rose::DB::Object>-derived classes.  These methods do not exist in L<Rose::DB::Object> in order to keep the method namespace clean.  (Each method added to L<Rose::DB::Object> is another potential naming conflict with a column accessor.)

This class inherits from L<Rose::DB::Object::MixIn>.  See the L<Rose::DB::Object::MixIn> documentation for a full explanation of how to import methods from this class.  The helper methods themselves are described below.

=head1 OBJECT METHODS

=over 4

=item B<clone>

Returns a new object initialized with the column values of the existing object.  For example, imagine a C<Person> class with three columns, C<id>, C<name>, and C<age>.

    $a = Person->new(id => 123, name => 'John', age => 30);

This use of the C<clone()> method:
    
    $b = $a->clone;

is equivalent to this:

    $b = Person->new(id => $a->id, name => $a->name, age => $a->age);

=item B<clone_and_reset>

This is the same as the L<clone|/clone> method described above, except that it also sets all of the L<primary|Rose::DB::Object::Metadata/primary_key_columns> and L<unique key columns|Rose::DB::Object::Metadata/unique_keys> to undef.  If the cloned object has a L<db|Rose::DB::Object/db> attribute, then it is copied to the clone object as well.

For example, imagine a C<Person> class with three columns, C<id>, C<name>, and C<age>, where C<id> is the primary key and C<name> is a unique key.

    $a = Person->new(id => 123, name => 'John', age => 30, db => $db);

This use of the C<clone_and_reset()> method:
    
    $b = $a->clone_and_reset;

is equivalent to this:

    $b = Person->new(id => $a->id, name => $a->name, age => $a->age);
    $b->id(undef);   # reset primary key
    $b->name(undef); # reset unique key
    $b->db($a->db);  # copy db

=item B<load_or_insert [PARAMS]>

Try to L<load|Rose::DB::Object/load> the object, passing PARAMS to the call to the L<load()|Rose::DB::Object/load> method.  The parameter "speculative => 1" is automatically added to PARAMS.  If no such object is found, then the object is L<inserted|Rose::DB::Object/insert>.

Example:

    # Get object id 123 if it exists, otherwise create it now.
    $obj = MyDBObject->new(id => 123)->load_or_insert;

=item B<load_speculative [PARAMS]>

Try to L<load|Rose::DB::Object/load> the object, passing PARAMS to the call to the L<load()|Rose::DB::Object/load> method along with the "speculative => 1" parameter.  See the documentation for L<Rose::DB::Object>'s L<load|Rose::DB::Object/load> method for more information.

Example:

    $obj = MyDBObject->new(id => 123);

    if($obj->load_speculative)
    {
      print "Found object id 123\n";
    }
    else
    {
      print "Object id 123 not found\n";
    }

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
