package Rose::DB::Object::MakeMethods::Date;

use strict;

use Carp();

use Rose::Object::MakeMethods;
our @ISA = qw(Rose::Object::MakeMethods);

use Rose::DB::Object::Constants
  qw(PRIVATE_PREFIX FLAG_DB_IS_PRIVATE STATE_IN_DB STATE_LOADING
     STATE_SAVING);

use Rose::DB::Object::Util qw(column_value_formatted_key);

our $VERSION = '0.05';

sub date
{
  my($class, $name, $args) = @_;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';
  my $tz = $args->{'time_zone'} || 0;

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
        if(@_ == 2)
        {
          my $dt = $self->{$key} || $self->{$formatted_key,$driver};

          if(defined $dt && !ref $dt)
          {
            my $dt2 = $db->parse_date($dt);

            unless($dt2)
            {
              $dt2 = Rose::DateTime::Util::parse_date($dt, $tz || $db->server_time_zone) or
                Carp::croak "Could not parse date '$dt'";
            }

            $dt = $dt2;
          }

          if($_[0] eq 'format')
          {
            return $dt  unless(ref $dt);
            return Rose::DateTime::Util::format_date($dt, (ref $_[1] ? @{$_[1]} : $_[1]));
          }
          elsif($_[0] eq 'truncate')
          {
            return undef  unless($self->{$key});
            return $dt  unless(ref $dt);
            return $db->format_date($dt->clone->truncate(to => $_[1]));
          }
          else
          {
            Carp::croak "Invalid argument(s) to $name: @_";
          }
        }

        if(defined $_[0])
        {
          if($self->{STATE_LOADING()})
          {
            $self->{$key} = undef;
            $self->{$formatted_key,$driver} = $_[0];
          }
          else
          {
            my $dt = $db->parse_date($_[0]);

            unless($dt)
            {
              $dt = Rose::DateTime::Util::parse_date($_[0], $tz || $db->server_time_zone) or
                Carp::croak "Invalid date: '$_[0]'";
            }

            if(ref $dt)
            {
              $dt->set_time_zone($tz || $db->server_time_zone);
              $self->{$key} = $dt;
              $self->{$formatted_key,$driver} = undef;
            }
            else
            {
              $self->{$key} = undef;
              $self->{$formatted_key,$driver} = $dt;
            }
          }
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = undef;
        }
      }

      return  unless(defined wantarray);

      if(defined $default && !$self->{$key} && !defined $self->{$formatted_key,$driver})
      {
        my $dt = $db->parse_date($default);

        unless($dt)
        {
          $dt = Rose::DateTime::Util::parse_date($default, $tz || $db->server_time_zone) or
            Carp::croak "Invalid default date: '$default'";
        }

        if(ref $dt)
        {
          $dt->set_time_zone($tz || $db->server_time_zone);
          $self->{$key} = $dt;
          $self->{$formatted_key,$driver} = undef;
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = $dt;
        }
      }

      if($self->{STATE_SAVING()})
      {
        return ($self->{$key} || $self->{$formatted_key,$driver}) ? 
          ($self->{$formatted_key,$driver} ||= $db->format_date($self->{$key})) : undef;
      }

      return $self->{$key} ? $self->{$key} : 
             $self->{$formatted_key,$driver} ? 
             ($self->{$key} = $db->parse_date($self->{$formatted_key,$driver})) : undef;
    };
  }
  elsif($interface eq 'get')
  {
    $methods{$name} = sub
    {
      my $self = shift;

      my $db = $self->db or die "Missing Rose::DB object attribute";
      my $driver = $db->driver || 'unknown';

      if(@_ == 2)
      {
        my $dt = $self->{$key} || $self->{$formatted_key,$driver};

        if(defined $dt && !ref $dt)
        {
          my $dt2 = $db->parse_date($dt);

          unless($dt2)
          {
            $dt2 = Rose::DateTime::Util::parse_date($dt, $tz || $db->server_time_zone) or
              Carp::croak "Could not parse date '$dt'";
          }

          $dt = $dt2;
        }

        if($_[0] eq 'format')
        {
          return $dt  unless(ref $dt);
          return Rose::DateTime::Util::format_date($dt, (ref $_[1] ? @{$_[1]} : $_[1]));
        }
        elsif($_[0] eq 'truncate')
        {
          return undef  unless($self->{$key});
          return $dt  unless(ref $dt);
          return $db->format_date($dt->clone->truncate(to => $_[1]));
        }
        else
        {
          Carp::croak "Invalid argument(s) to $name: @_";
        }
      }

      if(defined $default && !$self->{$key} && !defined $self->{$formatted_key,$driver})
      {
        my $dt = $db->parse_date($default);

        unless($dt)
        {
          $dt = Rose::DateTime::Util::parse_date($default, $tz || $db->server_time_zone) or
            Carp::croak "Invalid default date: '$default'";
        }

        if(ref $dt)
        {
          $dt->set_time_zone($tz || $db->server_time_zone);
          $self->{$key} = $dt;
          $self->{$formatted_key,$driver} = undef;
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = $dt;
        }
      }

      if($self->{STATE_SAVING()})
      {
        return ($self->{$key} || $self->{$formatted_key,$driver}) ? 
          ($self->{$formatted_key,$driver} ||= $db->format_date($self->{$key})) : undef;
      }

      return $self->{$key} ? $self->{$key} : 
             $self->{$formatted_key,$driver} ? 
             ($self->{$key} = $db->parse_date($self->{$formatted_key,$driver})) : undef;
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
          my $dt = $db->parse_date($_[0]);

          unless($dt)
          {
            $dt = Rose::DateTime::Util::parse_date($_[0], $tz || $db->server_time_zone) or
              Carp::croak "Invalid date: '$_[0]'";
          }

          if(ref $dt)
          {
            $dt->set_time_zone($tz || $db->server_time_zone);
            $self->{$key} = $dt;
            $self->{$formatted_key,$driver} = undef;
          }
          else
          {
            $self->{$key} = undef;
            $self->{$formatted_key,$driver} = $dt;
          }
        }
      }
      else
      {
        $self->{$key} = undef;
        $self->{$formatted_key,$driver} = undef;
      }

      return  unless(defined wantarray);

      if(defined $default && !$self->{$key} && !defined $self->{$formatted_key,$driver})
      {
        my $dt = $db->parse_date($default);

        unless($dt)
        {
          $dt = Rose::DateTime::Util::parse_date($default, $tz || $db->server_time_zone) or
            Carp::croak "Invalid default date: '$default'";
        }

        if(ref $dt)
        {
          $dt->set_time_zone($tz || $db->server_time_zone);
          $self->{$key} = $dt;
          $self->{$formatted_key,$driver} = undef;
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = $dt;
        }
      }

      if($self->{STATE_SAVING()})
      {
        return ($self->{$key} || $self->{$formatted_key,$driver}) ? 
          ($self->{$formatted_key,$driver} ||= $db->format_date($self->{$key})) : undef;
      }

      return $self->{$key} ? $self->{$key} : 
             $self->{$formatted_key,$driver} ? 
             ($self->{$key} = $db->parse_date($self->{$formatted_key,$driver})) : undef;
    };
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

sub datetime
{
  my($class, $name, $args) = @_;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';
  my $type = $args->{'type'} || 'datetime';
  my $tz = $args->{'time_zone'} || 0;

  for($type)
  {
    # "datetime year to fraction(5)" -> datetime_year_to_fraction_5
    tr/ /_/;
    s/\(([1-5])\)$/_$1/; 
  }

  my $format_method = "format_$type";
  my $parse_method  = "parse_$type";

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
        if(@_ == 2)
        {
          my $dt = $self->{$key} || $self->{$formatted_key,$driver};

          if(defined $dt && !ref $dt)
          {
            my $dt2 = $db->$parse_method($dt);

            unless($dt2)
            {
              $dt2 = Rose::DateTime::Util::parse_date($dt, $tz || $db->server_time_zone);
                Carp::croak "Could not parse datetime '$dt'";
            }

            $dt = $dt2;
          }

          if($_[0] eq 'format')
          {
            return $dt  unless(ref $dt);
            return Rose::DateTime::Util::format_date($dt, (ref $_[1] ? @{$_[1]} : $_[1]));
          }
          elsif($_[0] eq 'truncate')
          {
            return undef  unless($self->{$key});
            return $db->$format_method($dt)  unless(ref $dt);
            return $dt->clone->truncate(to => $_[1]);
          }
        }

        if(defined $_[0])
        {
          if($self->{STATE_LOADING()})
          {
            $self->{$key} = undef;
            $self->{$formatted_key,$driver} = $_[0];
          }
          else
          {
            my $dt = $db->$parse_method($_[0]);

            unless($dt)
            {
              $dt = Rose::DateTime::Util::parse_date($_[0], $tz || $db->server_time_zone) or
                Carp::croak "Invalid datetime: '$_[0]'";
            }

            $dt->set_time_zone($tz || $db->server_time_zone)  if(ref $dt);
            $self->{$key} = $dt;
            $self->{$formatted_key,$driver} = undef;
          }
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = undef;
        }
      }

      return  unless(defined wantarray);

      if(defined $default && !$self->{$key} && !defined $self->{$formatted_key,$driver})
      {
        my $dt = $db->$parse_method($default);

        unless($dt)
        {
          $dt = Rose::DateTime::Util::parse_date($default, $tz || $db->server_time_zone) or
            Carp::croak "Invalid default datetime: '$default'";
        }

        if(ref $dt)
        {
          $dt->set_time_zone($tz || $db->server_time_zone);
          $self->{$key} = $dt;
          $self->{$formatted_key,$driver} = undef;
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = $dt;
        }
      }

      if($self->{STATE_SAVING()})
      {
        return ($self->{$key} || $self->{$formatted_key,$driver}) ? 
          ($self->{$formatted_key,$driver} ||= $db->$format_method($self->{$key})) : undef;
      }

      return $self->{$key} ? $self->{$key} : 
             $self->{$formatted_key,$driver} ? 
             ($self->{$key} = $db->$parse_method($self->{$formatted_key,$driver})) : undef;
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
        my $dt = $db->$parse_method($default);

        unless($dt)
        {
          $dt = Rose::DateTime::Util::parse_date($default, $tz || $db->server_time_zone) or
            Carp::croak "Invalid default datetime: '$default'";
        }

        if(ref $dt)
        {
          $dt->set_time_zone($tz || $db->server_time_zone);
          $self->{$key} = $dt;
          $self->{$formatted_key,$driver} = undef;
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = $dt;
        }
      }

      if($self->{STATE_SAVING()})
      {
        return ($self->{$key} || $self->{$formatted_key,$driver}) ? 
          ($self->{$formatted_key,$driver} ||= $db->$format_method($self->{$key})) : undef;
      }

      return $self->{$key} ? $self->{$key} : 
             $self->{$formatted_key,$driver} ? 
             ($self->{$key} = $db->$parse_method($self->{$formatted_key,$driver})) : undef;
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
          my $dt = $db->$parse_method($_[0]);

          unless($dt)
          {
            $dt = Rose::DateTime::Util::parse_date($_[0], $tz || $db->server_time_zone) or
              Carp::croak "Invalid datetime: '$_[0]'";
          }

          $dt->set_time_zone($tz || $db->server_time_zone)  if(ref $dt);
          $self->{$key} = $dt;
          $self->{$formatted_key,$driver} = undef;
        }
      }
      else
      {
        $self->{$key} = undef;
        $self->{$formatted_key,$driver} = undef;
      }

      return  unless(defined wantarray);

      if(defined $default && !$self->{$key} && !defined $self->{$formatted_key,$driver})
      {
        my $dt = $db->$parse_method($default);

        unless($dt)
        {
          $dt = Rose::DateTime::Util::parse_date($default, $tz || $db->server_time_zone) or
            Carp::croak "Invalid default datetime: '$default'";
        }

        if(ref $dt)
        {
          $dt->set_time_zone($tz || $db->server_time_zone);
          $self->{$key} = $dt;
          $self->{$formatted_key,$driver} = undef;
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = $dt;
        }
      }

      if($self->{STATE_SAVING()})
      {
        return ($self->{$key} || $self->{$formatted_key,$driver}) ? 
          ($self->{$formatted_key,$driver} ||= $db->$format_method($self->{$key})) : undef;
      }

      return $self->{$key} ? $self->{$key} : 
             $self->{$formatted_key,$driver} ? 
             ($self->{$key} = $db->$parse_method($self->{$formatted_key,$driver})) : undef;
    };
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

sub timestamp_without_time_zone
{
  my($class, $name, $args) = @_;

  if(exists $args->{'time_zone'})
  {
    Carp::croak "time_zone parameter is invalid for timestamp_without_time_zone methods";
  }

  $args->{'time_zone'} = 'floating';

  return $class->timestamp($name, $args);
}

sub timestamp
{
  my($class, $name, $args) = @_;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';
  my $tz = $args->{'time_zone'} || 0;

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
        if(@_ == 2)
        {
          my $dt = $self->{$key} || $self->{$formatted_key,$driver};

          if(defined $dt && !ref $dt)
          {
            my $dt2 = $db->parse_timestamp($dt);

            unless($dt2)
            {
              $dt2 = Rose::DateTime::Util::parse_date($dt, $tz || $db->server_time_zone, 1) or
                Carp::croak "Could not parse timestamp '$dt'";
            }

            $dt = $dt2;
          }

          if($_[0] eq 'format')
          {
            return $dt  unless(ref $dt);
            return Rose::DateTime::Util::format_date($dt, (ref $_[1] ? @{$_[1]} : $_[1]), 1);
          }
          elsif($_[0] eq 'truncate')
          {
            return undef  unless($self->{$key});
            return $db->format_timestamp($dt)  unless(ref $dt);
            return $dt->clone->truncate(to => $_[1]);
          }
          else
          {
            Carp::croak "Invalid argument(s) to $name: @_";
          }
        }

        if(defined $_[0])
        {
          if($self->{STATE_LOADING()})
          {
            $self->{$key} = undef;
            $self->{$formatted_key,$driver} = $_[0];
          }
          else
          {
            my $dt = $db->parse_timestamp($_[0]);

            unless($dt)
            {
              $dt = Rose::DateTime::Util::parse_date($_[0], $tz || $db->server_time_zone, 1) or
                Carp::croak "Invalid timestamp: '$_[0]'";
            }

            $dt->set_time_zone($tz || $db->server_time_zone)  if(ref $dt);
            $self->{$key} = $dt;
            $self->{$formatted_key,$driver} = undef;
          }
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = undef;
        }
      }

      return  unless(defined wantarray);

      if(defined $default && !$self->{$key} && !defined $self->{$formatted_key,$driver})
      {
        my $dt = $db->parse_timestamp($default);

        unless($dt)
        {
          $dt = Rose::DateTime::Util::parse_date($default, $tz || $db->server_time_zone, 1) or
            Carp::croak "Invalid default timestamp: '$default'";
        }

        if(ref $dt)
        {
          $dt->set_time_zone($tz || $db->server_time_zone);
          $self->{$key} = $dt;
          $self->{$formatted_key,$driver} = undef;
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = $dt;
        }
      }

      if($self->{STATE_SAVING()})
      {
        return ($self->{$key} || $self->{$formatted_key,$driver}) ? 
          ($self->{$formatted_key,$driver} ||= $db->format_timestamp($self->{$key})) : undef;
      }

      return $self->{$key} ? $self->{$key} : 
             $self->{$formatted_key,$driver} ? 
             ($self->{$key} = $db->parse_timestamp($self->{$formatted_key,$driver})) : undef;
    };
  }
  elsif($interface eq 'get')
  {
    $methods{$name} = sub
    {
      my $self = shift;

      my $db = $self->db or die "Missing Rose::DB object attribute";
      my $driver = $db->driver || 'unknown';

      if(@_ == 2)
      {
        my $dt = $self->{$key} || $self->{$formatted_key,$driver};

        if(defined $dt && !ref $dt)
        {
          my $dt2 = $db->parse_timestamp($dt);

          unless($dt2)
          {
            $dt2 = Rose::DateTime::Util::parse_date($dt, $tz || $db->server_time_zone, 1) or
              Carp::croak "Could not parse timestamp '$dt'";
          }

          $dt = $dt2;
        }

        if($_[0] eq 'format')
        {
          return $dt  unless(ref $dt);
          return Rose::DateTime::Util::format_date($dt, (ref $_[1] ? @{$_[1]} : $_[1]), 1);
        }
        elsif($_[0] eq 'truncate')
        {
          return undef  unless($self->{$key});
          return $db->format_timestamp($dt)  unless(ref $dt);
          return $dt->clone->truncate(to => $_[1]);
        }
        else
        {
          Carp::croak "Invalid argument(s) to $name: @_";
        }
      }

      if(defined $default && !$self->{$key} && !defined $self->{$formatted_key,$driver})
      {
        my $dt = $db->parse_timestamp($default);

        unless($dt)
        {
          $dt = Rose::DateTime::Util::parse_date($default, $tz || $db->server_time_zone, 1) or
            Carp::croak "Invalid default timestamp: '$default'";
        }

        if(ref $dt)
        {
          $dt->set_time_zone($tz || $db->server_time_zone);
          $self->{$key} = $dt;
          $self->{$formatted_key,$driver} = undef;
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = $dt;
        }
      }

      if($self->{STATE_SAVING()})
      {
        return ($self->{$key} || $self->{$formatted_key,$driver}) ? 
          ($self->{$formatted_key,$driver} ||= $db->format_timestamp($self->{$key})) : undef;
      }

      return $self->{$key} ? $self->{$key} : 
             $self->{$formatted_key,$driver} ? 
             ($self->{$key} = $db->parse_timestamp($self->{$formatted_key,$driver})) : undef;
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
          my $dt = $db->parse_timestamp($_[0]);

          unless($dt)
          {
            $dt = Rose::DateTime::Util::parse_date($_[0], $tz || $db->server_time_zone, 1) or
              Carp::croak "Invalid timestamp: '$_[0]'";
          }

          $dt->set_time_zone($tz || $db->server_time_zone)  if(ref $dt);
          $self->{$key} = $dt;
          $self->{$formatted_key,$driver} = undef;
        }
      }
      else
      {
        $self->{$key} = undef;
        $self->{$formatted_key,$driver} = undef;
      }

      return  unless(defined wantarray);

      if(defined $default && !$self->{$key} && !defined $self->{$formatted_key,$driver})
      {
        my $dt = $db->parse_timestamp($default);

        unless($dt)
        {
          $dt = Rose::DateTime::Util::parse_date($default, $tz || $db->server_time_zone, 1) or
            Carp::croak "Invalid default timestamp: '$default'";
        }

        if(ref $dt)
        {
          $dt->set_time_zone($tz || $db->server_time_zone);
          $self->{$key} = $dt;
          $self->{$formatted_key,$driver} = undef;
        }
        else
        {
          $self->{$key} = undef;
          $self->{$formatted_key,$driver} = $dt;
        }
      }

      if($self->{STATE_SAVING()})
      {
        return ($self->{$key} || $self->{$formatted_key,$driver}) ? 
          ($self->{$formatted_key,$driver} ||= $db->format_timestamp($self->{$key})) : undef;
      }

      return $self->{$key} ? $self->{$key} : 
             $self->{$formatted_key,$driver} ? 
             ($self->{$key} = $db->parse_timestamp($self->{$formatted_key,$driver})) : undef;
    };
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

*timestamp_with_time_zone = \&timestamp;

1;

__END__

=head1 NAME

Rose::DB::Object::MakeMethods::Date - Create date-related methods for Rose::DB::Object-derived objects.

=head1 SYNOPSIS

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Date
    (
      date => 
      [
        'start_date',
        'end_date' => { default => '2005-01-30' }
      ],

      datetime => 
      [
        'date_created',
        'other_date' => { type => 'datetime year to minute' },
      ],

      timestamp => 
      [
        'last_modified' => { default => '2005-01-30 12:34:56.123' }
      ],
    );

    ...

    $o->start_date('2/3/2004 8am');
    $dt = $o->start_date(truncate => 'day');

    print $o->end_date(format => '%m/%d/%Y'); # 2005-01-30

    $o->date_created('now');

    $o->other_date('2001-02-20 12:34:56');

    # 02/20/2001 12:34:00
    print $o->other_date(format => '%m/%d/%Y %H:%M:%S'); 

    print $o->last_modified(format => '%S.%5N'); # 56.12300 

=head1 DESCRIPTION

C<Rose::DB::Object::MakeMethods::Date> creates methods that deal with dates, and inherits from L<Rose::Object::MakeMethods>.  See the L<Rose::Object::MakeMethods> documentation to learn about the interface.  The method types provided by this module are described below.

All method types defined by this module are designed to work with objects that are subclasses of (or otherwise conform to the interface of) L<Rose::DB::Object>.  In particular, the object is expected to have a L<db|Rose::DB::Object/db> method that returns a L<Rose::DB>-derived object.  See the L<Rose::DB::Object> documentation for more details.

=head1 METHODS TYPES

=over 4

=item B<date>

Create get/set methods for date (year, month, day) attributes.

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

=item C<time_zone>

The time zone name, which must be in a format that is understood by L<DateTime::TimeZone>.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a get/set method for a date (year, month, day) attribute.  When setting the attribute, the value is passed through the C<parse_date()> method of the object's L<db|Rose::DB::Object/db> attribute.  If that fails, the value is passed to L<Rose::DateTime::Util>'s C<parse_date()> function.  If that fails, a fatal error will occur.

The time zone of the L<DateTime> object that results from a successful parse is set to the value of the C<time_zone> option, if defined.  Otherwise, it is set to the L<server_time_zone|Rose::DB/server_time_zone> value of the  object's L<db|Rose::DB::Object/db> attribute using L<DateTime>'s L<set_time_zone|DateTime/set_time_zone> method.

When saving to the database, the method will pass the attribute value through the L<format_date|Rose::DateTime::Util/format_date> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.  Otherwise, the value is returned as-is.

This method is designed to allow date values to make a round trip from and back into the database without ever being "inflated" into L<DateTime> objects.  Any use of the attribute (get or set) outside the context of loading from or saving to the database will cause the value to be "inflated" using the  C<parse_date()> method of the object's L<db|Rose::DB::Object/db> attribute.  If that fails, L<Rose::DateTime::Util>'s C<parse_date()> function is tried.  If that fails, a fatal error will occur.

If passed two arguments and the first argument is "format", then the second argument is taken as a format string and passed to L<Rose::DateTime::Util>'s L<format_date|Rose::DateTime::Util/format_date> function along with the current value of the date attribute.  Example:

    $o->start_date('2004-05-22');
    print $o->start_date(format => '%A'); # "Saturday"

If passed two arguments and the first argument is "truncate", then the second argument is taken as the value of the C<to> argument to L<DateTime>'s L<truncate|DateTime/truncate> method, which is applied to a clone of the current value of the date attribute, which is then returned.  Example:

    $o->start_date('2004-05-22');

    # Equivalent to: 
    # $d = $o->start_date->clone->truncate(to => 'month')
    $d = $o->start_date(truncate => 'month');

If the date attribute is undefined, then undef is returned (i.e., no clone or call to L<truncate|DateTime/truncate> is made).

If a valid date keyword is passed as an argument, the value will never be "inflated" but rather passed to the database I<and> returned to other code unmodified.  That means that the "truncate" and "format" calls described above will also return the date keyword unmodified.  See the L<Rose::DB> documentation for more information on date keywords.

=item C<get>

Creates an accessor method for a date (year, month, day) attribute.  This method behaves like the C<get_set> method, except that the value cannot be set. 

=item C<set>

Creates a mutator method for a date (year, month, day) attribute.  This method behaves like the C<get_set> method, except that a fatal error will occur if no arguments are passed.  It also does not support the C<truncate> and C<format> options.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Date
    (
      date => 
      [
        'start_date',
        'end_date' => { default => '2005-01-30' }
      ],
    );

    ...

    $o->start_date('2/3/2004');
    $dt = $o->start_date(truncate => 'week');

    print $o->end_date(format => '%m/%d/%Y'); # 01/30/2005

=item B<datetime>

Create get/set methods for "datetime" (year, month, day, hour, minute, second) attributes.

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

=item C<time_zone>

The time zone name, which must be in a format that is understood by L<DateTime::TimeZone>.

=item C<type>

The datetime variant as a string.  Each space in the string is replaced with an underscore "_", then the string is appended to "format_" and "parse_" in order to form the names of the methods called on the object's L<db|Rose::DB::Object/db> attribute to format and parse datetime values.  The default is "datetime", which means that the C<format_datetime()> and C<parse_datetime()> methods will be used.

Any string that results in a set of method names that are supported by the object's L<db|Rose::DB::Object/db> attribute is acceptable.  Check the documentation for the class of the object's L<db|Rose::DB::Object/db> attribute for a list of valid method names.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a get/set method for a "datetime" attribute.  The exact granularity of the "datetime" value is determined by the value of the C<type> option (see above).

When setting the attribute, the value is passed through the C<parse_TYPE()> method of the object's L<db|Rose::DB::Object/db> attribute, where C<TYPE> is the value of the C<type> option.  If that fails, the value is passed to L<Rose::DateTime::Util>'s C<parse_date()> function.  If that fails, a fatal error will occur.

The time zone of the L<DateTime> object that results from a successful parse is set to the value of the C<time_zone> option, if defined.  Otherwise, it is set to the L<server_time_zone|Rose::DB/server_time_zone> value of the  object's L<db|Rose::DB::Object/db> attribute using L<DateTime>'s L<set_time_zone|DateTime/set_time_zone> method.

When saving to the database, the method will pass the attribute value through the C<format_TYPE()> method of the object's L<db|Rose::DB::Object/db> attribute before returning it, where C<TYPE> is the value of the C<type> option.  Otherwise, the value is returned as-is.

This method is designed to allow datetime values to make a round trip from and back into the database without ever being "inflated" into L<DateTime> objects.  Any use of the attribute (get or set) outside the context of loading from or saving to the database will cause the value to be "inflated" using the  C<parse_TYPE()> method of the object's L<db|Rose::DB::Object/db> attribute, where C<TYPE> is the value of the C<type> option.  If that fails, L<Rose::DateTime::Util>'s C<parse_date()> function is tried.  If that fails, a fatal error will occur.

If passed two arguments and the first argument is "format", then the second argument is taken as a format string and passed to L<Rose::DateTime::Util>'s L<format_date|Rose::DateTime::Util/format_date> function along with the current value of the datetime attribute.  Example:

    $o->start_date('2004-05-22 12:34:56');
    print $o->start_date(format => '%A'); # "Saturday"

If passed two arguments and the first argument is "truncate", then the second argument is taken as the value of the C<to> argument to L<DateTime>'s L<truncate|DateTime/truncate> method, which is applied to a clone of the current value of the datetime attribute, which is then returned.  Example:

    $o->start_date('2004-05-22 04:32:01');

    # Equivalent to: 
    # $d = $o->start_date->clone->truncate(to => 'month')
    $d = $o->start_date(truncate => 'month');

If the datetime attribute is undefined, then undef is returned (i.e., no clone or call to L<truncate|DateTime/truncate> is made).

If a valid datetime keyword is passed as an argument, the value will never be "inflated" but rather passed to the database I<and> returned to other code unmodified.  That means that the "truncate" and "format" calls described above will also return the datetime keyword unmodified.  See the L<Rose::DB> documentation for more information on datetime keywords.

=item C<get>

Creates an accessor method for a "datetime" attribute.  This method behaves like the C<get_set> method, except that the value cannot be set. 

=item C<set>

Creates a mutator method for a "datetime" attribute.  This method behaves like the C<get_set> method, except that a fatal error will occur if no arguments are passed.  It also does not support the C<truncate> and C<format> options.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Date
    (
      datetime => 
      [
        'start_date',
        'end_date'   => { default => '2005-01-30 12:34:56' }
        'other_date' => { type => 'datetime year to minute' },
      ],
    );

    ...

    $o->start_date('2/3/2004 8am');
    $dt = $o->start_date(truncate => 'day');

    # 01/30/2005 12:34:56
    print $o->end_date(format => '%m/%d/%Y %H:%M:%S'); 

    $o->other_date('2001-02-20 12:34:56');

    # 02/20/2001 12:34:00
    print $o->other_date(format => '%m/%d/%Y %H:%M:%S'); 

=item B<timestamp>

Create get/set methods for "timestamp" (year, month, day, hour, minute, second, fractional seconds) attributes.

=over 4

=item Options

=over 4

=item C<default>

Determines the default value of the attribute.

=item C<hash_key>

The key inside the hash-based object to use for the storage of this
attribute.  Defaults to the name of the method.

=item C<interface>

Choose the interface.  The default interface is C<get_set>.

=item C<time_zone>

The time zone name, which must be in a format that is understood by L<DateTime::TimeZone>.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a get/set method for a "timestamp" (year, month, day, hour, minute, second, fractional seconds) attribute.  When setting the attribute, the value is passed through the C<parse_timestamp()> method of the object's L<db|Rose::DB::Object/db> attribute.  If that fails, the value is passed to L<Rose::DateTime::Util>'s C<parse_date()> function.  If that fails, a fatal error will occur.

The time zone of the L<DateTime> object that results from a successful parse is set to the value of the C<time_zone> option, if defined.  Otherwise, it is set to the L<server_time_zone|Rose::DB/server_time_zone> value of the  object's L<db|Rose::DB::Object/db> attribute using L<DateTime>'s L<set_time_zone|DateTime/set_time_zone> method.

When saving to the database, the method will pass the attribute value through the L<format_date|Rose::DateTime::Util/format_date> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.  Otherwise, the value is returned as-is.

This method is designed to allow timestamp values to make a round trip from and back into the database without ever being "inflated" into L<DateTime> objects.  Any use of the attribute (get or set) outside the context of loading from or saving to the database will cause the value to be "inflated" using the  C<parse_timestamp()> method of the object's L<db|Rose::DB::Object/db> attribute.  If that fails, L<Rose::DateTime::Util>'s C<parse_date()> function is tried.  If that fails, a fatal error will occur.

If passed two arguments and the first argument is "format", then the second argument is taken as a format string and passed to L<Rose::DateTime::Util>'s L<format_date|Rose::DateTime::Util/format_date> function along with the current value of the timestamp attribute.  Example:

    $o->start_date('2004-05-22 12:34:56.123');
    print $o->start_date(format => '%A'); # "Saturday"

If passed two arguments and the first argument is "truncate", then the second argument is taken as the value of the C<to> argument to L<DateTime>'s L<truncate|DateTime/truncate> method, which is applied to a clone of the current value of the timestamp attribute, which is then returned.  Example:

    $o->start_date('2004-05-22 04:32:01.456');

    # Equivalent to: 
    # $d = $o->start_date->clone->truncate(to => 'month')
    $d = $o->start_date(truncate => 'month');

If the timestamp attribute is undefined, then undef is returned (i.e., no clone or call to L<truncate|DateTime/truncate> is made).

If a valid timestamp keyword is passed as an argument, the value will never be "inflated" but rather passed to the database I<and> returned to other code unmodified.  That means that the "truncate" and "format" calls described above will also return the timestamp keyword unmodified.  See the L<Rose::DB> documentation for more information on timestamp keywords.

=item C<get>

Creates an accessor method for a "timestamp" (year, month, day, hour, minute, second, fractional seconds) attribute.  This method behaves like the C<get_set> method, except that the value cannot be set. 

=item C<set>

Creates a mutator method for a "timestamp" (year, month, day, hour, minute, second, fractional seconds) attribute.  This method behaves like the C<get_set> method, except that a fatal error will occur if no arguments are passed.  It also does not support the C<truncate> and C<format> options.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Date
    (
      timestamp => 
      [
        'start_date',
        'end_date' => { default => '2005-01-30 12:34:56.123' }
      ],
    );

    ...

    $o->start_date('2/3/2004 8am');
    $dt = $o->start_date(truncate => 'day');

    # 01/30/2005 12:34:56.12300
    print $o->end_date(format => '%m/%d/%Y %H:%M:%S.%5N'); 

=item B<timestamp_with_time_zone>

This is identical to the L<timestamp|/timestamp> method described above.

=item B<timestamp_without_time_zone>

This is identical to the L<timestamp|/timestamp> method described above, but with the C<time_zone> parameter always set to the value "floating".  Any attempt to set the C<time_zone> parameter explicitly will cause a fatal error.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
