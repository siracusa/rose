package Rose::DB::Object::MakeMethods::Time;

use strict;

use Carp();

use Rose::Object::MakeMethods;
our @ISA = qw(Rose::Object::MakeMethods);

use Rose::DB::Object::Constants
  qw(PRIVATE_PREFIX FLAG_DB_IS_PRIVATE STATE_IN_DB STATE_LOADING
     STATE_SAVING MODIFIED_COLUMNS);

use Rose::DB::Object::Util qw(column_value_formatted_key);

our $VERSION = '0.73';

sub interval
{
  my($class, $name, $args) = @_;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';

  my $column_name = $args->{'column'} ? $args->{'column'}->name : $name;

  my $formatted_key = column_value_formatted_key($key);
  my $default = $args->{'default'};

  my %methods;

  if($interface eq 'get_set')
  {
    $methods{$name} = sub
    {
      my $self = shift;

      my $db = $self->db or die "Missing Rose::DB object attribute";
      my $driver = $db->driver || 'unknown';

      if(@_)
      {
        if(defined $_[0])
        {
          if($self->{STATE_LOADING()})
          {
            $self->{$key} = undef;
            $self->{$formatted_key,$driver} = $_[0];
          }
          else
          {
            my $dt_duration = $db->parse_interval($_[0]);
            Carp::croak $db->error  unless(defined $dt_duration);

            if(ref $dt_duration)
            {
              $self->{$key} = $dt_duration;
              $self->{$formatted_key,$driver} = undef;
            }
            else
            {
              $self->{$key} = undef;
              $self->{$formatted_key,$driver} = $dt_duration;
            }

            $self->{MODIFIED_COLUMNS()}{$column_name} = 1;
          }
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = undef;
          $self->{MODIFIED_COLUMNS()}{$column_name} = 1
            unless($self->{STATE_LOADING()});
        }
      }

      return  unless(defined wantarray);

      if(defined $default && !$self->{$key} && !defined $self->{$formatted_key,$driver})
      {
        my $dt_duration = $db->parse_interval($default);
        Carp::croak $db->error  unless(defined $dt_duration);

        if(ref $dt_duration)
        {
          $self->{$key} = $dt_duration;
          $self->{$formatted_key,$driver} = undef;
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = $dt_duration;
        }

        $self->{MODIFIED_COLUMNS()}{$column_name} = 1
          unless($self->{STATE_IN_DB()});
      }

      if($self->{STATE_SAVING()})
      {
        return ($self->{$key} || $self->{$formatted_key,$driver}) ? 
          ($self->{$formatted_key,$driver} ||= $db->format_interval($self->{$key})) : undef;
      }

      return $self->{$key} ? $self->{$key} : 
             $self->{$formatted_key,$driver} ? 
             ($self->{$key} = $db->parse_interval($self->{$formatted_key,$driver})) : undef;
    };
  }
  elsif($interface eq 'get')
  {
    $methods{$name} = sub
    {
      my $self = shift;

      my $db = $self->db or die "Missing Rose::DB object attribute";
      my $driver = $db->driver || 'unknown';

      if(defined $default && !$self->{$key} && !defined $self->{$formatted_key,$driver})
      {
        my $dt_duration = $db->parse_interval($default);
        Carp::croak $db->error  unless(defined $dt_duration);

        if(ref $dt_duration)
        {
          $self->{$key} = $dt_duration;
          $self->{$formatted_key,$driver} = undef;
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = $dt_duration;
        }

        $self->{MODIFIED_COLUMNS()}{$column_name} = 1;
      }

      if($self->{STATE_SAVING()})
      {
        return ($self->{$key} || $self->{$formatted_key,$driver}) ? 
          ($self->{$formatted_key,$driver} ||= $db->format_interval($self->{$key})) : undef;
      }

      return $self->{$key} ? $self->{$key} : 
             $self->{$formatted_key,$driver} ? 
             ($self->{$key} = $db->parse_interval($self->{$formatted_key,$driver})) : undef;
    };
  }
  elsif($interface eq 'set')
  {
    $methods{$name} = sub
    {
      my $self = shift;

      my $db = $self->db or die "Missing Rose::DB object attribute";
      my $driver = $db->driver || 'unknown';

      Carp::croak "Missing argument in call to $name"  unless(@_);

      if(defined $_[0])
      {
        if($self->{STATE_LOADING()})
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = $_[0];
        }
        else
        {
          my $dt_duration = $db->parse_interval($_[0]);
          Carp::croak $db->error  unless(defined $dt_duration);

          if(ref $dt_duration)
          {
            $self->{$key} = $dt_duration;
            $self->{$formatted_key,$driver} = undef;
          }
          else
          {
            $self->{$key} = undef;
            $self->{$formatted_key,$driver} = $dt_duration;
          }
        }
      }
      else
      {
        $self->{$key} = undef;
        $self->{$formatted_key,$driver} = undef;
      }

      $self->{MODIFIED_COLUMNS()}{$column_name} = 1;

      return  unless(defined wantarray);

      if(defined $default && !$self->{$key} && !defined $self->{$formatted_key,$driver})
      {
        my $dt_duration = $db->parse_interval($default);
        Carp::croak $db->error  unless(defined $dt_duration);

        if(ref $dt_duration)
        {
          $self->{$key} = $dt_duration;
          $self->{$formatted_key,$driver} = undef;
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = $dt_duration;
        }
      }

      if($self->{STATE_SAVING()})
      {
        return ($self->{$key} || $self->{$formatted_key,$driver}) ? 
          ($self->{$formatted_key,$driver} ||= $db->format_interval($self->{$key})) : undef;
      }

      return $self->{$key} ? $self->{$key} : 
             $self->{$formatted_key,$driver} ? 
             ($self->{$key} = $db->parse_interval($self->{$formatted_key,$driver})) : undef;
    };
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

1;

__END__

=head1 NAME

Rose::DB::Object::MakeMethods::Time - Create time-related methods for Rose::DB::Object-derived objects.

=head1 SYNOPSIS

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Time
    (
      interval => 
      [
        't1' => { precision => 6 },
        't2' => { default => '3 days 6 minutes 5 seconds' },
      ],
    );

    ...

    $o->t1('5 minutes 0.003 seconds');

    $dt_dur = $o->t1; # DateTime::Duration object

    print $o->t1->minutes;     # 5
    print $o->t1->nanoseconds; # 3000000


=head1 DESCRIPTION

C<Rose::DB::Object::MakeMethods::Time> creates methods that deal with times, and inherits from L<Rose::Object::MakeMethods>.  See the L<Rose::Object::MakeMethods> documentation to learn about the interface.  The method types provided by this module are described below.

All method types defined by this module are designed to work with objects that are subclasses of (or otherwise conform to the interface of) L<Rose::DB::Object>.  In particular, the object is expected to have a L<db|Rose::DB::Object/db> method that returns a L<Rose::DB>-derived object.  See the L<Rose::DB::Object> documentation for more details.

=head1 METHODS TYPES

=over 4

=item B<interval>

Create get/set methods for interval (years, months, days, hours, minutes, seconds) attributes.

=over 4

=item Options

=over 4

=item C<default>

Determines the default value of the attribute.

=item C<hash_key>

The key inside the hash-based object to use for the storage of this
attribute.  Defaults to the name of the method.

=item C<interface>

Choose the interface.  The default is C<get_set>.

=item C<precision>

An integer number of places past the decimal point preserved for fractional seconds.  Defaults to 0.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a get/set method for a interval (years, months, days, hours, minutes, seconds) attribute.  When setting the attribute, the value is passed through the L<parse_interval|Rose::DB/parse_interval> method of the object's L<db|Rose::DB::Object/db> attribute.  If that fails, a fatal error will occur.

When saving to the database, the method will pass the attribute value through the L<format_interval|Rose::DB/format_interval> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.

This method is designed to allow date values to make a round trip from and back into the database without ever being "inflated" into L<DateTime::Duration> objects.  Any use of the attribute (get or set) outside the context of loading from or saving to the database will cause the value to be "inflated" using the  L<parse_interval|Rose::DB/parse_interval> method of the object's L<db|Rose::DB::Object/db> attribute.

=item C<get>

Creates an accessor method for a interval (years, months, days, hours, minutes, seconds) attribute.  This method behaves like the C<get_set> method, except that the value cannot be set. 

=item C<set>

Creates a mutator method for a interval (years, months, days, hours, minutes, seconds) attribute.  This method behaves like the C<get_set> method, except that a fatal error will occur if no arguments are passed.  It also does not support the C<truncate> and C<format> options.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Time
    (
      interval => 
      [
        't1' => { precision => 6 },
        't2' => { default => '3 days 6 minutes 5 seconds' },
      ],
    );

    ...

    $o->t1('5 minutes 0.003 seconds');

    $dt_dur = $o->t1; # DateTime::Duration object

    print $o->t1->minutes;     # 5
    print $o->t1->nanoseconds; # 3000000

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
