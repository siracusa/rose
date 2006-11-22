package Rose::DB::Registry::Entry;

use strict;

use Clone::PP();

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.729';

our $Debug = 0;

#
# Object data
#

use Rose::Object::MakeMethods::Generic
(
  'scalar' =>
  [
    qw(database domain dsn dbi_driver host password port
       server_time_zone schema catalog type username
       description)
  ],

  'boolean' =>
  [
    'auto_create'    => { default => 1 },
    'european_dates' => { default => 0 },
  ],

  'hash' =>
  [
    'connect_options' => { interface => 'get_set_init' },
    'connect_option'  => { hash_key => 'connect_options' },
  ],

  'array' =>
  [
    'pre_disconnect_sql',
    'post_connect_sql',
  ]
);

sub init_connect_options { {} }

sub autocommit  { shift->connect_option('AutoCommit', @_) }
sub print_error { shift->connect_option('PrintError', @_) }
sub raise_error { shift->connect_option('RaiseError', @_) }

sub driver
{
  my($self) = shift;
  return $self->{'driver'}  unless(@_);
  $self->{'dbi_driver'} = shift;
  return $self->{'driver'} = lc $self->{'dbi_driver'};
}

sub dump
{
  my($self) = shift;

  my %dump;

  foreach my $attr (qw(database dsn driver host password port
                       description server_time_zone schema catalog 
                       type username connect_options pre_disconnect_sql 
                       post_connect_sql))
  {
    my $value = $self->$attr();
    next  unless(defined $value);
    $dump{$attr} = Clone::PP::clone($value);
  }

  # These booleans have default, but we only want the ones 
  # where the values were explicitly set.  Ugly...
  foreach my $attr (qw(auto_create european_dates))
  {
    my $value = $self->{$attr};
    next  unless(defined $value);
    $dump{$attr} = Clone::PP::clone($value);
  }

  return \%dump;
}

sub clone { Clone::PP::clone($_[0]) }

1;

__END__

=head1 NAME

Rose::DB::Registry::Entry - Data source registry entry.

=head1 SYNOPSIS

  use Rose::DB::Registry::Entry;

  $entry = Rose::DB::Registry::Entry->new(
    domain   => 'production',
    type     => 'main',
    driver   => 'Pg',
    database => 'big_db',
    host     => 'dbserver.acme.com',
    username => 'dbadmin',
    password => 'prodsecret',
    server_time_zone => 'UTC');

  Rose::DB->register_db($entry);

  # ...or...

  Rose::DB->registry->add_entry($entry);

  ...

=head1 DESCRIPTION

C<Rose::DB::Registry::Entry> objects store information about a single L<Rose::DB> data source.  See the L<Rose::DB> documentation for more information on data sources, and the L<Rose::DB::Registry> documentation to learn how C<Rose::DB::Registry::Entry> objects are managed.

C<Rose::DB::Registry::Entry> inherits from, and follows the conventions of, L<Rose::Object>.  See the L<Rose::Object> documentation for more information.

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a C<Rose::DB::Registry::Entry> object based on PARAMS, where PARAMS are name/value pairs.  Any object method is a valid parameter name.

=back

=head1 OBJECT METHODS

=over 4

=item B<autocommit [VALUE]>

Get or set the value of the "AutoCommit" connect option.

=item B<catalog [CATALOG]>

Get or set the database catalog name.  This setting is only relevant to databases that support the concept of catalogs.

=item B<clone>

Returns a clone (i.e., deep copy) of the current object.

=item B<connect_option NAME [, VALUE]>

Get or set the connect option named NAME.  Returns the current value of the connect option.

=item B<connect_options [HASHREF | PAIRS]>

Get or set the options passed in a hash reference as the fourth argument to the call to C<DBI-E<gt>connect()>.  See the C<DBI> documentation for descriptions of the various options.

If a reference to a hash is passed, it replaces the connect options hash.  If a series of name/value pairs are passed, they are added to the connect options hash.

Returns a reference to the hash of options in scalar context, or a list of name/value pairs in list context.

=item B<database [NAME]>

Get or set the database name.

=item B<description [TEXT]>

A description of the data source.

=item B<domain [DOMAIN]>

Get or set the data source domain.  Note that changing the C<domain> after a registry entry has been added to the registry has no affect on where the entry appears in the registry.

=item B<driver [DRIVER]>

Get or set the driver name.  The DRIVER argument is converted to lowercase before being set.

=item B<dsn [DSN]>

Get or set the C<DBI> DSN (Data Source Name).  Note that an explicitly set DSN may render some other attributes inaccurate.  For example, the DSN may contain a host name that is different than the object's current C<host()> value.  I recommend not setting the DSN value explicitly unless you are also willing to manually synchronize (or ignore) the corresponding object attributes.

=item B<dump>

Returns a reference to a hash of the entry's attributes.  Only those attributes with defined values are included in the hash keys.  All values are deep copies.

=item B<host [NAME]>

Get or set the database server host name.

=item B<password [PASS]>

Get or set the database password.

=item B<port [NUM]>

Get or set the database server port number.

=item B<pre_disconnect_sql [STATEMENTS]>

Get or set the SQL statements that will be run immediately before disconnecting from the database.  STATEMENTS should be a list or reference to an array of SQL statements.  Returns a reference to the array of SQL statements in scalar context, or a list of SQL statements in list context.

=item B<post_connect_sql [STATEMENTS]>

Get or set the SQL statements that will be run immediately after connecting to the database.  STATEMENTS should be a list or reference to an array of SQL statements.  Returns a reference to the array of SQL statements in scalar context, or a list of SQL statements in list context.

=item B<print_error [VALUE]>

Get or set the value of the "PrintError" connect option.

=item B<raise_error [VALUE]>

Get or set the value of the "RaiseError" connect option.

=item B<schema [SCHEMA]>

Get or set the database schema name.  This setting is only useful to databases that support the concept of schemas (e.g., PostgreSQL).

=item B<server_time_zone [TZ]>

Get or set the time zone used by the database server software.  TZ should be a time zone name that is understood by C<DateTime::TimeZone>.  See the C<DateTime::TimeZone> documentation for acceptable values of TZ.

=item B<type [TYPE]>

Get or set the  data source type.  Note that changing the C<type> after a registry entry has been added to the registry has no affect on where the entry appears in the registry.

=item B<username [NAME]>

Get or set the database username.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
