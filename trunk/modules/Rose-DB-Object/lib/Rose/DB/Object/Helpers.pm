package Rose::DB::Object::Helpers;

use strict;

use Rose::DB::Object::MixIn;
our @ISA = qw(Rose::DB::Object::MixIn);

use Carp;

our $VERSION = '0.62';

__PACKAGE__->export_tag(all => [ qw(load_or_insert load_speculative) ]);

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

1;

__END__

=head1 NAME

Rose::DB::Object::Helpers - A mix-in class containing convenience methods for Rose::DB::Object.

=head1 SYNOPSIS

  package MyDBObject;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  use Rose::DB::Object::Helpers { load_or_insert => 'find_or_create' });
  ...

  $obj = MyDBObject->new(id => 123);
  $obj->find_or_create();

=head1 DESCRIPTION

L<Rose::DB::Object::Helpers> provides convenience methods from use with L<Rose::DB::Object>-derived classes.  These methods do not exist in L<Rose::DB::Object> in order to keep the method namespace clean.  (Each method added to L<Rose::DB::Object> is another potential naming conflict with a column accessor.)

This class inherits from L<Rose::DB::Object::MixIn>.  See the L<Rose::DB::Object::MixIn> documentation for a full explanation of how to import methods from this class.  The helper methods themselves are described below.

=head1 OBJECT METHODS

=over 4

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
