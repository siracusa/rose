package Rose::DB::Pg;

use strict;

use DateTime::Format::Pg;

use Rose::DB;
our @ISA = qw(Rose::DB);

our $VERSION = '0.023';

our $Debug = 0;

#
# Object methods
#

sub build_dsn
{
  my($self_or_class, %args) = @_;

  my %info;

  $info{'dbname'} = $args{'db'} || $args{'database'};
  $info{'host'}   = $args{'host'};
  $info{'port'}   = $args{'port'};

  return
    "dbi:$args{'dbi_driver'}:" . 
    join(';', map { "$_=$info{$_}" } grep { defined $info{$_} }
              qw(dbname host port));
}

sub init_date_handler
{
  my($self) = shift;
  my $parser = 
    DateTime::Format::Pg->new(
      ($self->SUPER::european_dates ? (european => 1) : ()),
      ($self->SUPER::server_time_zone ? 
        (server_tz => $self->SUPER::server_time_zone) : ()));

  return $parser;
}

sub default_implicit_schema { 'public' }
sub likes_lowercase_table_names { 1 }

sub insertid_param { 'unsupported' }
sub null_date      { '0000-00-00'  }
sub null_datetime  { '0000-00-00 00:00:00' }
sub null_timestamp { '00000000000000' }
sub min_timestamp  { '-infinity' }
sub max_timestamp  { 'infinity' }

sub last_insertid_from_sth
{
  #my($self, $sth, $obj) = @_;

  # Postgres demands that the primary key column not be in the insert
  # statement at all in order for it to auto-generate a value.  The
  # insert SQL will need to be modified to make this work for
  # Rose::DB::Object...
  #if($DBD::Pg::VERSION >= 1.40)
  #{
  #  my $meta = $obj->meta;
  #  return $self->dbh->last_insert_id(undef, $meta->schema, $meta->table, undef);
  #}

  return undef;
}

sub parse_datetime
{
  return DateTime::Infinite::Past->new   if($_[1] eq '-infinity');
  return DateTime::Infinite::Future->new if($_[1] eq 'infinity');
  shift->SUPER::parse_datetime(@_);
}

sub parse_timestamp
{
  return DateTime::Infinite::Past->new   if($_[1] eq '-infinity');
  return DateTime::Infinite::Future->new if($_[1] eq 'infinity');
  shift->SUPER::parse_timestamp(@_);
}

sub validate_date_keyword
{
  no warnings;
  $_[1] =~ /^(?:now|epoch|today|tomorrow|yesterday|\w+\(.*\))$/;
}

sub validate_time_keyword
{
  no warnings;
  $_[1] =~ /^(?:now|allballs|\w+\(.*\))$/;
}

sub validate_timestamp_keyword
{
  no warnings;
  $_[1] =~ /^(?:now|-?infinity|epoch|today|tomorrow|yesterday|allballs|\w+\(.*\))$/;
}

*validate_datetime_keyword = \&validate_timestamp_keyword;

sub server_time_zone
{
  $_[0]->{'date_handler'} = undef  if(@_ > 1);
  shift->SUPER::server_time_zone(@_)
}

sub european_dates
{
  $_[0]->{'date_handler'} = undef  if(@_ > 1);
  shift->SUPER::european_dates(@_)
}

sub parse_array
{
  my($self) = shift;

  return $_[0]  if(ref $_[0]);
  return [ @_ ] if(@_ > 1);

  my $val = $_[0];

  return undef  unless(defined $val);

  $val =~ s/^\{(.*)\}$/$1/;

  my @array;

  while($val =~ s/(?:"((?:[^"\\]+|\\.)*)"|([^",]+))(?:,|$)//)
  {
    push(@array, (defined $1) ? $1 : $2);
  }

  return \@array;
}

sub format_array
{
  my($self) = shift;

  my @array = (ref $_[0]) ? @{$_[0]} : @_;

  return undef  unless(@array && defined $array[0]);

  return '{' . join(',', map 
  {
    if(!defined $_)
    {
      Carp::croak 'Undefined value found in array or list passed to ',
                  __PACKAGE__, '::format_array()';
    }
    elsif(/^[-+]?\d+(?:\.\d*)?$/)
    {
      $_
    }
    else
    {
      s/\\/\\\\/g; 
      s/"/\\"/g;
      qq("$_") 
    }
  } @array) . '}';
}

sub next_value_in_sequence
{
  my($self, $seq) = @_;

  my $dbh = $self->dbh or return undef;

  my $id;

  eval
  {
    my $sth = $dbh->prepare(qq(SELECT nextval(?)));
    $sth->execute($seq);
    $id = ${$sth->fetchrow_arrayref}[0];
  };

  if($@)
  {
    $self->error("Could not get the next value in the sequence '$seq' - $@");
    return undef;
  }

  return $id;
}

sub auto_sequence_name
{
  my($self, %args) = @_;

  my $table = $args{'table'};
  Carp::croak "Missing table argument"  unless(defined $table);

  my $column = $args{'column'};
  Carp::croak "Missing column argument"  unless(defined $column);

  return "\L${table}_${column}_seq";
}

#
# DBI introspection
#

sub refine_dbi_column_info
{
  my($self, $col_info) = @_;

  $self->SUPER::refine_dbi_column_info($col_info);

  # Pg has some odd names for types.  Convert them to standard forms.
  if($col_info->{'TYPE_NAME'} eq 'character varying')
  {
    $col_info->{'TYPE_NAME'} = 'varchar';
  }
  elsif($col_info->{'TYPE_NAME'} eq 'bit')
  {
    $col_info->{'TYPE_NAME'} = 'bits';
  }

  # Postgres 8.1 sometimes adds double quotes around the column name
  if($col_info->{'COLUMN_NAME'} =~ /^"(.+)"$/)
  {
    $col_info->{'COLUMN_NAME'} = $1;
  }

  # Pg does not populate COLUMN_SIZE correctly for bit fields, so
  # we have to extract the number of bits from pg_type.
  if($col_info->{'pg_type'} =~ /^bit\((\d+)\)$/)
  {
    $col_info->{'COLUMN_SIZE'} = $1;
  }

  # Extract precision and scale from numeric types
  if($col_info->{'pg_type'} =~ /^numeric/i)
  {
    if($col_info->{'COLUMN_SIZE'} =~ /^(\d+),(\d+)$/)
    {
      $col_info->{'COLUMN_SIZE'}    = $1;
      $col_info->{'DECIMAL_DIGITS'} = $2;
    }
    elsif($col_info->{'pg_type'} =~ /^numeric\((\d+),(\d+)\)$/i)
    {
      $col_info->{'COLUMN_SIZE'}    = $2;
      $col_info->{'DECIMAL_DIGITS'} = $1;
    }
  }

  # We currently treat all arrays the same, regardless of what they are 
  # arrays of: integer, character, float, etc.  So we covert TYPE_NAMEs
  # like 'integer[]' into 'array'
  if($col_info->{'TYPE_NAME'} =~ /^\w.*\[\]$/)
  {
    $col_info->{'TYPE_NAME'} = 'array';
  }

  return;
}

sub parse_dbi_column_info_default 
{
  my($self, $string) = @_;

  UNDEF_OK: # Avoid undef string warnings
  {
    no warnings;
    local $_ = $string;

    my $pg_vers = $self->dbh->{'pg_server_version'};

    # Example: q('value'::character varying)
    if(/^'.+'::[\w ]+$/)
    {
      my $default;

      # Single quotes are backslash-escaped, but Postgres 8.1 and
      # later uses doubled quotes '' instead.
      if($pg_vers >= 80100 && /^'((?:[^']+|'')*)'::[\w ]+$/)
      {
        $default = $1;
        $default =~ s/''/'/g;
      }
      elsif($pg_vers < 80100 && /^'((?:[^\\']+|\\.)*)'::[\w ]+$/)
      {
        $default = $1;
        $default =~ s/\\'/'/g;
      }

      return $default;
    }
    # Example: q(B'00101'::"bit")
    elsif(/^B'([01]+)'::(?:bit|"bit")$/)
    {
      return $1;
    }
    # Handle sequence-based defaults elsewhere (if at all)
    elsif(/^nextval\(/)
    {
      return undef;
    }
  }

  return $string;
}

sub list_tables
{
  my($self, %args) = @_;
  
  my $types = $args{'include_views'} ? "'TABLE','VIEW'" : 'TABLE';
  my @tables;

  my $schema = $self->schema;
  $schema = $self->default_implicit_schema  unless(defined $schema);

  eval
  {
    my $dbh = $self->dbh or die $self->error;

    local $dbh->{'RaiseError'} = 1;

    my $sth = $dbh->table_info($self->catalog, $schema, '', $types,
                               { noprefix => 1, pg_noprefix => 1 });

    $sth->execute;
    
    while(my $table_info = $sth->fetchrow_hashref)
    {
      push(@tables, $table_info->{'TABLE_NAME'})
    }
  };

  if($@)
  {
    Carp::croak "Could not last tables from ", $self->dsn, " - $@";
  }

  return wantarray ? @tables : \@tables;
}

# sub list_tables
# {
#   my($self) = shift;
# 
#   my @tables;
# 
#   my $schema = $self->schema;
#   $schema = $db->default_implicit_schema  unless(defined $schema);
#     
#   if($DBD::Pg::VERSION >= 1.31) 
#   {
#     @tables = $self->dbh->tables($self->catalog, $schema, '', 'TABLE',
#                               { noprefix => 1, pg_noprefix => 1 });
#     }
#     else 
#     {
#       @tables = $dbh->tables;
#     }
#   }
# 
#   return wantarray ? @tables : \@tables;
# }

1;

__END__

=head1 NAME

Rose::DB::Pg - PostgreSQL driver class for Rose::DB.

=head1 SYNOPSIS

  use Rose::DB;

  Rose::DB->register_db(
    domain   => 'development',
    type     => 'main',
    driver   => 'Pg',
    database => 'dev_db',
    host     => 'localhost',
    username => 'devuser',
    password => 'mysecret',
    server_time_zone => 'UTC',
    european_dates   => 1,
  );

  Rose::DB->default_domain('development');
  Rose::DB->default_type('main');
  ...

  $db = Rose::DB->new; # $db is really a Rose::DB::Pg object
  ...

=head1 DESCRIPTION

This is the subclass that L<Rose::DB> blesses an object into when the C<driver> is "Pg".  This mapping of drivers to class names is configurable.  See the documentation for L<Rose::DB>'s C<new()> and C<driver_class()> methods for more information.

Using this class directly is not recommended.  Instead, use L<Rose::DB> and let it bless objects into the appropriate class for you, according to its C<driver_class()> mappings.

This class inherits from L<Rose::DB>.  B<Only the methods that are new or have  different behaviors are documented here.>  See the L<Rose::DB> documentation for information on the inherited methods.

=head1 OBJECT METHODS

=over 4

=item B<european_dates [BOOL]>

Get or set the boolean value that determines whether or not dates are assumed to be in european dd/mm/yyyy format.  The default is to assume US mm/dd/yyyy format (because this is the default for PostgreSQL).

This value will be passed to C<DateTime::Format::Pg> as the value of the C<european> parameter in the call to the constructor C<new()>.  This C<DateTime::Format::Pg> object is used by C<Rose::DB::Pg> to parse and format date-related column values in methods like C<parse_date>, C<format_date>, etc.

=item B<next_value_in_sequence SEQUENCE>

Advance the sequence named SEQUENCE and return the new value.  Returns undef if there was an error.

=item B<server_time_zone [TZ]>

Get or set the time zone used by the database server software.  TZ should be a time zone name that is understood by C<DateTime::TimeZone>.  The default value is "floating".

This value will be passed to C<DateTime::Format::Pg> as the value of the C<server_tz> parameter in the call to the constructor C<new()>.  This C<DateTime::Format::Pg> object is used by C<Rose::DB::Pg> to parse and format date-related column values in methods like C<parse_date>, C<format_date>, etc.

See the C<DateTime::TimeZone> documentation for acceptable values of TZ.

=back

=head2 Value Parsing and Formatting

=over 4

=item B<format_array ARRAYREF | LIST>

Given a reference to an array or a list of values, return a string formatted according to the rules of PostgreSQL's "ARRAY" column type.  Undef is returned if ARRAYREF points to an empty array or if LIST is not passed.  If the array or list contains undefined values, a fatal error will occur.

=item B<parse_array STRING>

Parse STRING and return a reference to an array.  STRING should be formatted according to PostgreSQL's "ARRAY" data type.  Undef is returned if STRING is undefined.

=item B<validate_date_keyword STRING>

Returns true if STRING is a valid keyword for the PostgreSQL "date" data type.  Valid date keywords are:

    epoch
    now
    today
    tomorrow
    yesterday

The keywords are case sensitive.  Any string that looks like a function call (matches /^\w+\(.*\)$/) is also considered a valid date keyword.

=item B<validate_datetime_keyword STRING>

Returns true if STRING is a valid keyword for the PostgreSQL "datetime" data type, false otherwise.  Valid datetime keywords are:

    allballs
    epoch
    infinity
    -infinity
    now
    today
    tomorrow
    yesterday

The keywords are case sensitive.  Any string that looks like a function call (matches /^\w+\(.*\)$/) is also considered a valid datetime keyword.

=item B<validate_timestamp_keyword STRING>

Returns true if STRING is a valid keyword for the PostgreSQL "timestamp" data type, false otherwise.  Valid timestamp keywords are:

    allballs
    epoch
    infinity
    -infinity
    now
    today
    tomorrow
    yesterday

The keywords are case sensitive.  Any string that looks like a function call (matches /^\w+\(.*\)$/) is also considered a valid timestamp keyword.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
