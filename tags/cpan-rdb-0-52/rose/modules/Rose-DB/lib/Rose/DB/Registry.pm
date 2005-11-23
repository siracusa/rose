package Rose::DB::Registry;

use strict;

use Carp();

use Rose::DB::Registry::Entry;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.01';

our $Debug = 0;

#
# Object data
#

use Rose::Object::MakeMethods::Generic
(
  'scalar' =>
  [
    qw(error)
  ],

  'scalar --get_set_init' =>
  [
    'hash',
  ],
);

#
# Object methods
#

sub init_hash { {} }

sub add_entries
{
  my($self) = shift;

  my $entries = $self->hash;
  my $i = 0;

  foreach my $item (@_)
  {
    my($domain, $type, $entry);

    if(ref $item eq 'HASH')
    {
      if($entry = delete $item->{'entry'})
      {        
        $domain = delete $item->{'domain'};
        $type = delete $item->{'type'};

        if(keys(%$item))
        {
          Carp::croak "If an 'entry' parameter is passed, no other ",
                      "parameters (other than 'domain' and 'type') ",
                      "may be passed";
        }
      }
      else
      {
        $entry = Rose::DB::Registry::Entry->new(%$item);
      }
    }
    elsif(ref $item && $item->isa('Rose::DB::Registry::Entry'))
    {
      $entry = $item;
    }
    else { Carp::croak "Don't know how to add registry entry '$item'" }

    $domain = $entry->domain  unless(defined $domain);
    $type   = $entry->type    unless(defined $type   );

    Carp::croak "Missing domain for registry entry '$item'"
      unless(defined $domain);

    Carp::croak "Missing type for registry entry '$item'"
      unless(defined $type);

    Carp::croak "Missing driver for registry entry '$item'"
      unless(defined $entry->driver);

    $i++  unless(defined $entries->{$domain}{$type});
    $entries->{$domain}{$type} = $entry;
  }

  return $i;
}

sub add_entry
{
  my($self) = shift;

  if(@_ == 1 || (ref $_[0] && $_[0]->isa('Rose::DB::Registry::Entry')))
  {
    return $self->add_entries(@_);
  }

  return $self->add_entries({ @_ });
}

sub entry_exists
{
  my($self, %args) = @_;

  Carp::croak "Missing required 'type' argument"
    unless(defined $args{'type'});

  Carp::croak "Missing required 'domain' argument"
    unless(defined $args{'domain'});

  return exists $self->hash->{$args{'domain'}}{$args{'type'}};
}

sub delete_entry
{
  my($self, %args) = @_;
  return undef  unless($self->entry_exists(%args));
  return delete $self->hash->{$args{'domain'}}{$args{'type'}};
}

sub entry
{
  my($self, %args) = @_;
  return undef  unless($self->entry_exists(%args));
  return $self->hash->{$args{'domain'}}{$args{'type'}};
}

sub delete_domain
{
  my($self, $domain) = @_;
  my $entries = $self->hash;
  delete $entries->{$domain};
}

1;

__END__

=head1 NAME

Rose::DB::Registry - Data source registry.

=head1 SYNOPSIS

  use Rose::DB::Registry;

  $registry = Rose::DB::Registry->new;

  $registry->add_entry(
    domain   => 'development',
    type     => 'main',
    driver   => 'Pg',
    database => 'dev_db',
    host     => 'localhost',
    username => 'devuser',
    password => 'mysecret',
    server_time_zone => 'UTC');

  $entry = Rose::DB::Registry::Entry->new(
    domain   => 'production',
    type     => 'main',
    driver   => 'Pg',
    database => 'big_db',
    host     => 'dbserver.acme.com',
    username => 'dbadmin',
    password => 'prodsecret',
    server_time_zone => 'UTC');

  $registry->add_entry($entry);

  $entry = $registry->entry(domain => 'development', type => 'main');

  $registry->entry_exists(domain => 'foo', type => 'bar'); # false

  $registry->delete_entry(domain => 'development', type => 'main');

  ...

=head1 DESCRIPTION

C<Rose::DB::Registry> objects manage information about L<Rose::DB> data sources.  Each data source has a corresponding L<Rose::DB::Registry::Entry> object that contains its information.  The registry entries are organized in a two-level namespace based on a "domain" and a "type."  See the L<Rose::DB> documentation for more information on data source domains and types.

C<Rose::DB::Registry> inherits from, and follows the conventions of, L<Rose::Object>.  See the L<Rose::Object> documentation for more information.

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a C<Rose::DB::Registry> object based on PARAMS, where PARAMS are
name/value pairs.  Any object method is a valid parameter name.

=back

=head1 OBJECT METHODS

=over 4

=item B<add_entries ENTRY1 [, ENTRY2, ...]>

Add registry entries.  Each ENTRY must be either a L<Rose::DB::Registry::Entry>-derived object or  reference to a hash of name/value pairs.  The name/value pairs must be valid arguments for L<Rose::DB::Registry::Entry>'s constructor.

Each ENTRY must have a defined domain and type, either in the L<Rose::DB::Registry::Entry>-derived object or in the name/value pairs.  A fatal error will occur if these values are not defined.

If a registry entry for the specified domain and type already exists, then the new entry will overwrite it.  If you want to know beforehand whether or not an entry exists under a specific domain and type, use the C<entry_exists()> method.

=item B<add_entry ENTRY>

Add a registry entry.  ENTRY must be either a L<Rose::DB::Registry::Entry>-derived object or a list of name/value pairs.  The name/value pairs must be valid arguments for L<Rose::DB::Registry::Entry>'s constructor.

The ENTRY must have a defined domain and type, either in the L<Rose::DB::Registry::Entry>-derived object or in the name/value pairs.  A fatal error will occur if these values are not defined.

If a registry entry for the specified domain and type already exists, then the new entry will overwrite it.  If you want to know beforehand whether or not an entry exists under a specific domain and type, use the C<entry_exists()> method.

=item B<delete_domain DOMAIN>

Delete an entire domain, including all the registry entries under that domain.

=item B<delete_entry PARAMS>

Delete the registry entry specified by PARAMS, where PARAMS must be name/value pairs with defined values for C<domain> and C<type>.  A fatal error will occur if either one is missing or undefined.

If the specified entry does not exist, undef is returned.  Otherwise, the deleted entry is returned.

=item B<entry PARAMS>

Get the registry entry specified by PARAMS, where PARAMS must be name/value pairs with defined values for C<domain> and C<type>.  A fatal error will occur if either one is missing or undefined.  If the specified entry does not exist, undef is returned.

=item B<entry_exists PARAMS>

Returns true if the registry entry specified by PARAMS exists, false otherwise.  PARAMS must be name/value pairs with defined values for C<domain> and C<type>.  A fatal error will occur if either one is missing or undefined.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
