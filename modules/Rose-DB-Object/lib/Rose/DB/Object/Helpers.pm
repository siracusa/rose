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
    @ret = $self->load(speculative => 1);
    return @ret  if($ret[0]);
  }
  else
  {
    $ret = $self->load(speculative => 1);
    return $ret  if($ret);
  }
  
  return $self->insert(@_);
}

1;

__END__

=head1 NAME

Rose::DB::Object::MixIn - Utility functions for use in Rose::DB::Object subclasses and method makers.

=head1 SYNOPSIS

  package MyDBObject;

  use Rose::DB::Object::MixIn qw(:all);

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);
  ...
  sub whatever
  {
    my($self) = shift;
    ...
    if(is_loading($self)) 
    {
      ...
      set_state_in_db($self);
    }
    ...
  }

=head1 DESCRIPTION

L<Rose::DB::Object::MixIn> provides functions that are useful for developers who are subclassing L<Rose::DB::Object> or otherwise extending or modifying its behavior.

L<Rose::DB::Object>s have some awareness of their current situation.  Certain optimizations rely on this awareness.  For example, when loading column values directly from the database, there's no reason to validate the format of the data or immediately "inflate" the values.  The L<is_loading|/is_loading> function will tell you when these steps can safely be skipped.

Similarly, it may be useful to set these state characteristics in your code.  The C<set_sate_*> functions provide that ability.

=head1 EXPORTS

C<Rose::DB::Object::MixIn> does not export any function names by default.

The 'get_state' tag:

    use Rose::DB::Object::MixIn qw(:get_state);

will cause the following function names to be imported:

    is_in_db()
    is_loading()
    is_saving()

The 'set_state' tag:

    use Rose::DB::Object::MixIn qw(:set_state);

will cause the following function names to be imported:

    set_state_in_db()
    set_state_loading()
    set_state_saving()

The 'unset_state' tag:

    use Rose::DB::Object::MixIn qw(:unset_state);

will cause the following function names to be imported:

    unset_state_in_db()
    unset_state_loading()
    unset_state_saving()

The 'all' tag:

    use Rose::DB::Object::MixIn qw(:all);

will cause the following function names to be imported:

    is_in_db()
    is_loading()
    is_saving()

    set_state_in_db()
    set_state_loading()
    set_state_saving()

    unset_state_in_db()
    unset_state_loading()
    unset_state_saving()

=head1 FUNCTIONS

=over 4

=item B<is_in_db OBJECT>

Given the L<Rose::DB::Object>-derived object OBJECT, returns true if the object was L<load|Rose::DB::Object/load>ed from, or has ever been L<save|Rose::DB::Object/save>d into, the database, or false if it has not.

=item B<is_loading OBJECT>

Given the L<Rose::DB::Object>-derived object OBJECT, returns true if the object is currently being L<load|Rose::DB::Object/load>ed, false otherwise.

=item B<is_saving OBJECT>

Given the L<Rose::DB::Object>-derived object OBJECT, returns true if the object is currently being L<save|Rose::DB::Object/save>d, false otherwise.

=item B<set_state_in_db OBJECT>

Mark the L<Rose::DB::Object>-derived object OBJECT as having been L<load|Rose::DB::Object/load>ed from or L<save|Rose::DB::Object/save>d into the database at some point in the past.

=item B<set_state_loading OBJECT>

Indicate that the L<Rose::DB::Object>-derived object OBJECT is currently being L<load|Rose::DB::Object/load>ed from the database.

=item B<set_state_saving OBJECT>

Indicate that the L<Rose::DB::Object>-derived object OBJECT is currently being L<save|Rose::DB::Object/save>d into the database.

=item B<unset_state_in_db OBJECT>

Mark the L<Rose::DB::Object>-derived object OBJECT as B<not> having been L<load|Rose::DB::Object/load>ed from or L<save|Rose::DB::Object/save>d into the database at some point in the past.

=item B<unset_state_loading OBJECT>

Indicate that the L<Rose::DB::Object>-derived object OBJECT is B<not> currently being L<load|Rose::DB::Object/load>ed from the database.

=item B<unset_state_saving OBJECT>

Indicate that the L<Rose::DB::Object>-derived object OBJECT is B<not> currently being L<save|Rose::DB::Object/save>d into the database.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
