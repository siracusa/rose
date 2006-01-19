package Rose::DB::SQLite;

use strict;

use Carp();

use Rose::DB;
our @ISA = qw(Rose::DB);

our $VERSION = '0.53';

#our $Debug = 0;

#
# Object methods
#

sub build_dsn
{
  my($self_or_class, %args) = @_;

  my %info;

  $info{'dbname'} = $args{'db'} || $args{'database'};

  return
    "dbi:SQLite:" . 
    join(';', map { "$_=$info{$_}" } grep { defined $info{$_} } qw(dbname));
}

sub dbi_driver { 'SQLite' }

sub init_dbh
{
  my($self) = shift;

  my $database = $self->database;

  unless($self->auto_create || -e $database)
  {
    Carp::croak "Refusing to create non-existent SQLite database ",
                "file: '$database'";
  }

  $self->SUPER::init_dbh(@_);
}

sub last_insertid_from_sth { shift->dbh->func('last_insert_rowid') }

sub validate_date_keyword
{
  no warnings;
  !ref $_[1] && $_[1] =~ /^\w+\(.*\)$/;
}

sub validate_datetime_keyword
{
  no warnings;
  !ref $_[1] && $_[1] =~ /^\w+\(.*\)$/;
}

sub validate_timestamp_keyword
{
  no warnings;
  !ref $_[1] && $_[1] =~ /^\w+\(.*\)$/;
}

sub quote_table_name
{
  my($self, $table) = @_;

  $table =~ s/'/''/g;
  return qq('$table');
}

sub format_bitfield 
{
  my($self, $vec, $size) = @_;
  $vec = Bit::Vector->new_Bin($size, $vec->to_Bin)  if($size);
  return q(b') . $vec->to_Bin . q(');
}

sub refine_dbi_column_info
{
  my($self, $col_info) = @_;

  $self->SUPER::refine_dbi_column_info($col_info);

  if($col_info->{'TYPE_NAME'} eq 'bit')
  {
    $col_info->{'TYPE_NAME'} = 'bits';
  }

  return;
}

sub list_tables
{
  my($self, %args) = @_;

  my $types = $args{'include_views'} ? q('table', 'view') : q('table');

  my @tables;

  eval
  {
    my $dbh = $self->dbh or die $self->error;

    local $dbh->{'RaiseError'} = 1;

    my $sth = $dbh->prepare("SELECT name FROM sqlite_master WHERE type IN($types)");
    $sth->execute;

    my $name;
    $sth->bind_columns(\$name);

    while($sth->fetch)
    {
      push(@tables, $name);
    }
  };

  if($@)
  {
    Carp::croak "Could not list tables from ", $self->dsn, " - $@";
  }

  return wantarray ? @tables : \@tables;
}

1;

__END__

=head1 NAME

Rose::DB::SQLite - SQLite driver class for Rose::DB.

=head1 SYNOPSIS

  use Rose::DB;

  Rose::DB->register_db(
    domain   => 'development',
    type     => 'main',
    driver   => 'sqlite',
    database => '/path/to/some/file.db',
  );


  Rose::DB->default_domain('development');
  Rose::DB->default_type('main');
  ...

  # Set max length of varchar columns used to emulate an array data type
  Rose::DB::SQLite->max_array_characters(128);

  $db = Rose::DB->new; # $db is really a Rose::DB::SQLite object
  ...

=head1 DESCRIPTION

This is the subclass that L<Rose::DB> blesses an object into when the C<driver> is "sqlite".  This mapping of drivers to class names is configurable.  See the documentation for L<Rose::DB>'s C<new()> and C<driver_class()> methods for more information.

Using this class directly is not recommended.  Instead, use L<Rose::DB> and let it bless objects into the appropriate class for you, according to its C<driver_class()> mappings.

This class supports SQLite version 3 only.  See the SQLite web site for more information on the major vrsions of SQLite:

L<http://www.sqlite.org/>

This class inherits from L<Rose::DB>.  B<Only the methods that are new or have  different behaviors are documented here.>  See the L<Rose::DB> documentation for information on the inherited methods.

=head1 DATA TYPES

SQLite doesn't care what value you pass for a given column, regardless of that column's nominal data type.  L<Rose::DB> does care, however.  The following data type formats are enforced by L<Rose::DB::SQLite>'s L<parse_*|Rose::DB/"Value Parsing and Formatting"> and L<format_*|Rose::DB/"Value Parsing and Formatting"> functions.

    Type        Format
    ---------   ------------------------------
    DATE        YYYY-MM-DD
    DATETIME    YYYY-MM-DD HH:MM::SS
    TIMESTAMP   YYYY-MM-DD HH:MM::SS.NNNNNNNNN

=head1 CLASS METHODS

=over 4

=item B<max_array_characters [INT]>

Get or set the maximum length of varchar columns used to emulate an array data type.  The default value is 255.

SQLite does not have a native "ARRAY" data type, but it can be emulated using a "VARCHAR" column and a specially formatted string.  The formatting and parsing of this string is handled by the C<format_array()> and C<parse_array()> object methods.  The maximum length limit is honored by the C<format_array()> object method.

=back

=head1 OBJECT METHODS

=over 4

=item B<auto_create [BOOL]>

Get or set a boolean value indicating whether or not a new SQLite L<database|Rose::DB/database> should be created if it does not already exist.  Defaults to true.

If false, and if the specified L<database|Rose::DB/database> does not exist, then a fatal error will occur when an attempt is made to L<connect|Rose::DB/connect> to the database.

=back

=head2 Value Parsing and Formatting

=over 4

=item B<format_array ARRAYREF | LIST>

Given a reference to an array or a list of values, return a specially formatted string.  Undef is returned if ARRAYREF points to an empty array or if LIST is not passed.  The array or list must not contain undefined values.

If the resulting string is longer than C<max_array_characters()>, a fatal error will occur.

=item B<parse_array STRING | LIST | ARRAYREF>

Parse STRING and return a reference to an array.  STRING should be formatted according to the SQLite array data type emulation format returned by C<format_array()>.  Undef is returned if STRING is undefined.

If a LIST of more than one item is passed, a reference to an array containing the values in LIST is returned.

If a an ARRAYREF is passed, it is returned as-is.

=item B<validate_date_keyword STRING>

Returns true if STRING is a valid keyword for the "date" data type.  Any strings that looks like a function call (matches /^\w+\(.*\)$/) is considered a valid date keyword.

=item B<validate_datetime_keyword STRING>

Returns true if STRING is a valid keyword for the "datetime" data type, false otherwise.   Any strings that looks like a function call (matches /^\w+\(.*\)$/) is considered a valid datetime keyword.

=item B<validate_timestamp_keyword STRING>

Returns true if STRING is a valid keyword for the "timestamp" data type, false otherwise.  Any strings that looks like a function call (matches /^\w+\(.*\)$/) is considered a valid timestamp keyword.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
