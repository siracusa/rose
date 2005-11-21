package Rose::DB::MySQL;

use strict;

use Carp();

use DateTime::Format::MySQL;

use Rose::DB;
our @ISA = qw(Rose::DB);

our $VERSION = '0.03';

our $Debug = 0;

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar => 'max_array_characters',
);

__PACKAGE__->max_array_characters(255);

#
# Object methods
#

sub build_dsn
{
  my($self_or_class, %args) = @_;

  my %info;

  $info{'database'} = $args{'db'} || $args{'database'};
  $info{'host'}     = $args{'host'};
  $info{'port'}     = $args{'port'};

  return
    "dbi:$args{'dbi_driver'}:" . 
    join(';', map { "$_=$info{$_}" } grep { defined $info{$_} }
              qw(database host port));
}

sub quote_column_name { qq(`$_[1]`) }

sub init_date_handler { DateTime::Format::MySQL->new }

sub insertid_param { 'mysql_insertid' }
sub null_date      { '0000-00-00'  }
sub null_datetime  { '0000-00-00 00:00:00' }
sub null_timestamp { '00000000000000' }
sub min_timestamp  { '00000000000000' }
sub max_timestamp  { '00000000000000' }

sub last_insertid_from_sth { $_[1]->{'mysql_insertid'} }

sub validate_date_keyword
{
  no warnings;
  !ref $_[1] && $_[1] =~ /^(?:0000-00-00|\w+\(.*\))$/;
}

sub validate_datetime_keyword
{
  no warnings;
  !ref $_[1] && $_[1] =~ /^(?:0000-00-00 00:00:00|\w+\(.*\))$/;
}

sub validate_timestamp_keyword
{
  no warnings;
  !ref $_[1] && $_[1] =~ /^(?:0000-00-00 00:00:00|00000000000000|\w+\(.*\))$/;
}

*format_timestamp = \&Rose::DB::format_datetime;

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

  my $str = '{' . join(',', map 
  {
    if(/^[-+]?\d+(?:\.\d*)?$/)
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

  if(length($str) > $self->max_array_characters)
  {
    Carp::croak "Array string is longer than ", ref($self), 
                "->max_array_characters (", $self->max_array_characters,
                ") characters long: $str";
  }

  return $str;
}

# sub format_limit_with_offset
# {
#   #my($self, $limit, $offset) = @_;
#   return join(', ', @_[2,1]);
# }

sub refine_dbi_column_info
{
  my($self, $col_info) = @_;

  $self->SUPER::refine_dbi_column_info($col_info);

  if($col_info->{'TYPE_NAME'} eq 'timestamp' && defined $col_info->{'COLUMN_DEF'})
  {
    if($col_info->{'COLUMN_DEF'} eq '0000-00-00 00:00:00' || 
       $col_info->{'COLUMN_DEF'} eq '00000000000000')
    {
      # MySQL uses strange "all zeros" default values for timestamp fields.
      # We'll just ignore them, since MySQL will use them internally no
      # matter what we do.
      $col_info->{'COLUMN_DEF'} = undef;
    }
    elsif($col_info->{'COLUMN_DEF'} eq 'CURRENT_TIMESTAMP')
    {
      # Translate "current time" value into something that our date parser
      # will understand.
      #$col_info->{'COLUMN_DEF'} = 'now';
      
      # Actually, let the database handle this.
      $col_info->{'COLUMN_DEF'} = undef;
    }
  }

  return;
}

sub likes_redundant_join_conditions { 1 }

1;

__END__

=head1 NAME

Rose::DB::MySQL - MySQL driver class for Rose::DB.

=head1 SYNOPSIS

  use Rose::DB;

  Rose::DB->register_db(
    domain   => 'development',
    type     => 'main',
    driver   => 'mysql',
    database => 'dev_db',
    host     => 'localhost',
    username => 'devuser',
    password => 'mysecret',
  );


  Rose::DB->default_domain('development');
  Rose::DB->default_type('main');
  ...

  # Set max length of varchar columns used to emulate an array data type
  Rose::DB::MySQL->max_array_characters(128);

  $db = Rose::DB->new; # $db is really a Rose::DB::MySQL object
  ...

=head1 DESCRIPTION

This is the subclass that L<Rose::DB> blesses an object into when the C<driver> is "mysql".  This mapping of drivers to class names is configurable.  See the documentation for L<Rose::DB>'s C<new()> and C<driver_class()> methods for more information.

Using this class directly is not recommended.  Instead, use L<Rose::DB> and let it bless objects into the appropriate class for you, according to its C<driver_class()> mappings.

This class inherits from L<Rose::DB>.  B<Only the methods that are new or have  different behaviors are documented here.>  See the L<Rose::DB> documentation for information on the inherited methods.

=head1 CLASS METHODS

=over 4

=item B<max_array_characters [INT]>

Get or set the maximum length of varchar columns used to emulate an array data type.  The default value is 255.

MySQL does not have a native "ARRAY" data type, but it can be emulated using a "VARCHAR" column and a specially formatted string.  The formatting and parsing of this string is handled by the C<format_array()> and C<parse_array()> object methods.  The maximum length limit is honored by the C<format_array()> object method.

=back

=head1 OBJECT METHODS

=head2 Value Parsing and Formatting

=over 4

=item B<format_array ARRAYREF | LIST>

Given a reference to an array or a list of values, return a specially formatted string.  Undef is returned if ARRAYREF points to an empty array or if LIST is not passed.  The array or list must not contain undefined values.

If the resulting string is longer than C<max_array_characters()>, a fatal error will occur.

=item B<parse_array STRING | LIST | ARRAYREF>

Parse STRING and return a reference to an array.  STRING should be formatted according to the MySQL array data type emulation format returned by C<format_array()>.  Undef is returned if STRING is undefined.

If a LIST of more than one item is passed, a reference to an array containing the values in LIST is returned.

If a an ARRAYREF is passed, it is returned as-is.

=item B<validate_date_keyword STRING>

Returns true if STRING is a valid keyword for the MySQL "date" data type.  Valid date keywords are:

    00000-00-00

Any string that looks like a function call (matches /^\w+\(.*\)$/) is also considered a valid date keyword.

=item B<validate_datetime_keyword STRING>

Returns true if STRING is a valid keyword for the MySQL "datetime" data type, false otherwise.  Valid datetime keywords are:

    0000-00-00 00:00:00

Any string that looks like a function call (matches /^\w+\(.*\)$/) is also considered a valid datetime keyword.

=item B<validate_timestamp_keyword STRING>

Returns true if STRING is a valid keyword for the MySQL "timestamp" data type, false otherwise.  Valid timestamp keywords are:

    0000-00-00 00:00:00
    00000000000000

Any string that looks like a function call (matches /^\w+\(.*\)$/) is also considered a valid timestamp keyword.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
