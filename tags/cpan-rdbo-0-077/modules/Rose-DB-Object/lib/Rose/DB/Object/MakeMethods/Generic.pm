package Rose::DB::Object::MakeMethods::Generic;

use strict;

use Bit::Vector::Overload;

use Carp();

use Rose::Object::MakeMethods;
our @ISA = qw(Rose::Object::MakeMethods);

use Rose::DB::Object::Manager;
use Rose::DB::Constants qw(IN_TRANSACTION);
use Rose::DB::Object::Constants 
  qw(PRIVATE_PREFIX FLAG_DB_IS_PRIVATE STATE_IN_DB STATE_LOADING
     STATE_SAVING ON_SAVE_ATTR_NAME);

our $VERSION = '0.07';

sub scalar
{
  my($class, $name, $args) = @_;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';

  my %methods;

  if($interface eq 'get_set')
  {
    if(my $check = $args->{'check_in'})
    {
      $check = [ $check ] unless(ref $check);
      my %check = map { $_ => 1 } @$check;

      my $default = $args->{'default'};

      if(defined $default)
      {
        $methods{$name} = sub
        {
          if(@_ > 1 && defined $_[1])
          {
            Carp::croak "Invalid $name: '$_[1]'"  unless(exists $check{$_[1]});
            return $_[0]->{$key} = $_[1];
          }
          return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                   ($_[0]->{$key} = $default);
        };
      }
      elsif(exists $args->{'with_init'} || exists $args->{'init_method'})
      {
        my $init_method = $args->{'init_method'} || "init_$name";

        $methods{$name} = sub
        {
          if(@_ > 1 && defined $_[1])
          {
            Carp::croak "Invalid $name: '$_[1]'"  unless(exists $check{$_[1]});
            return $_[0]->{$key} = $_[1];
          }
          return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                   ($_[0]->{$key} = $_[0]->$init_method());
        };
      }
      else
      {
        $methods{$name} = sub
        {
          if(@_ > 1 && defined $_[1])
          {
            Carp::croak "Invalid $name: '$_[1]'"  unless(exists $check{$_[1]});
            return $_[0]->{$key} = $_[1];
          }
          return $_[0]->{$key};
        };
      }
    }
    else
    {
      my $default = $args->{'default'};

      if(defined $default)
      {
        $methods{$name} = sub
        {
          return $_[0]->{$key} = $_[1]  if(@_ > 1);
          return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                   ($_[0]->{$key} = $default);
        };
      }
      elsif(exists $args->{'with_init'} || exists $args->{'init_method'})
      {
        my $init_method = $args->{'init_method'} || "init_$name";

        $methods{$name} = sub
        {
          return $_[0]->{$key} = $_[1]  if(@_ > 1);
          return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                   ($_[0]->{$key} = $_[0]->$init_method());
        };
      }
      else
      {
        $methods{$name} = sub
        {
          return $_[0]->{$key} = $_[1]  if(@_ > 1);
          return $_[0]->{$key};
        };
      }
    }
  }
  elsif($interface eq 'set')
  {
    if(my $check = $args->{'check_in'})
    {
      $check = [ $check ] unless(ref $check);
      my %check = map { $_ => 1 } @$check;

      $methods{$name} = sub
      {
        Carp::croak "Missing argument in call to $name"  unless(@_ > 1);
        Carp::croak "Invalid $name: '$_[1]'"  unless(exists $check{$_[1]});
        return $_[0]->{$key} = $_[1];
      };
    }
    else
    {
      $methods{$name} = sub
      {
        Carp::croak "Missing argument in call to $name"  unless(@_ > 1);
        return $_[0]->{$key} = $_[1];
      };
    }
  }
  elsif($interface eq 'get')
  {
    my $default = $args->{'default'};

    if(defined $default)
    {
      $methods{$name} = sub
      {
        return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                 ($_[0]->{$key} = $default);
      };
    }
    elsif(exists $args->{'with_init'} || exists $args->{'init_method'})
    {
      my $init_method = $args->{'init_method'} || "init_$name";

      $methods{$name} = sub
      {
        return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                 ($_[0]->{$key} = $_[0]->$init_method());
      };
    }
    else
    {
      $methods{$name} = sub
      {
        return $_[0]->{$key};
      };
    }
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

sub character
{
  my($class, $name, $args) = @_;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';
  my $length    = $args->{'length'} || 0;

  my %methods;

  if($interface eq 'get_set')
  {
    if(my $check = $args->{'check_in'})
    {
      $check = [ $check ] unless(ref $check);
      my %check = map { $_ => 1 } @$check;

      my $default = $args->{'default'};

      if(defined $default)
      {
        $methods{$name} = sub
        {
          if(@_ > 1 && defined $_[1])
          {
            Carp::croak "Invalid $name: '$_[1]'"  unless(exists $check{$_[1]});
            return $_[0]->{$key} = ($length && defined $_[1]) ?
              sprintf('%-*s', $length, substr($_[1], 0, $length)) : $_[1];
          }
          return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                   ($_[0]->{$key} = $default);
        };
      }
      elsif(exists $args->{'with_init'} || exists $args->{'init_method'})
      {
        my $init_method = $args->{'init_method'} || "init_$name";

        $methods{$name} = sub
        {
          if(@_ > 1 && defined $_[1])
          {
            Carp::croak "Invalid $name: '$_[1]'"  unless(exists $check{$_[1]});
            return $_[0]->{$key} = ($length && defined $_[1]) ?
              sprintf('%-*s', $length, substr($_[1], 0, $length)) : $_[1];
          }
          return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                   ($_[0]->{$key} = $_[0]->$init_method());
        };
      }
      else
      {
        $methods{$name} = sub
        {
          if(@_ > 1 && defined $_[1])
          {
            Carp::croak "Invalid $name: '$_[1]'"  unless(exists $check{$_[1]});
            return $_[0]->{$key} = ($length && defined $_[1]) ?
              sprintf('%-*s', $length, substr($_[1], 0, $length)) : $_[1];
          }
          return $_[0]->{$key};
        };
      }
    }
    else
    {
      my $default = $args->{'default'};

      if(defined $default)
      {
        $methods{$name} = sub
        {
          if(@_ > 1)
          {
            return $_[0]->{$key} = ($length && defined $_[1]) ?
              sprintf('%-*s', $length, substr($_[1], 0, $length)) : $_[1];
          }
          return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                   ($_[0]->{$key} = $default);
        };
      }
      elsif(exists $args->{'with_init'} || exists $args->{'init_method'})
      {
        my $init_method = $args->{'init_method'} || "init_$name";

        $methods{$name} = sub
        {
          if(@_ > 1)
          {
            return $_[0]->{$key} = ($length && defined $_[1]) ?
              sprintf('%-*s', $length, substr($_[1], 0, $length)) : $_[1];
          }
          return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                   ($_[0]->{$key} = $_[0]->$init_method());
        };
      }
      else
      {
        $methods{$name} = sub
        {
          if(@_ > 1)
          {
            return $_[0]->{$key} = ($length && defined $_[1]) ?
              sprintf('%-*s', $length, substr($_[1], 0, $length)) : $_[1];
          }
          return $_[0]->{$key};
        };
      }
    }
  }
  elsif($interface eq 'get')
  {
    my $default = $args->{'default'};

    if(defined $default)
    {
      $methods{$name} = sub
      {
        return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                 ($_[0]->{$key} = $default);
      };
    }
    elsif(exists $args->{'with_init'} || exists $args->{'init_method'})
    {
      my $init_method = $args->{'init_method'} || "init_$name";

      $methods{$name} = sub
      {
        return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                 ($_[0]->{$key} = $_[0]->$init_method());
      };
    }
    else
    {
      $methods{$name} = sub { shift->{$key} };
    }
  }
  elsif($interface eq 'set')
  {
    if(my $check = $args->{'check_in'})
    {
      $check = [ $check ] unless(ref $check);
      my %check = map { $_ => 1 } @$check;

      if(exists $args->{'with_init'} || exists $args->{'init_method'})
      {
        my $init_method = $args->{'init_method'} || "init_$name";

        $methods{$name} = sub
        {
          Carp::croak "Missing argument in call to $name"  unless(@_ > 1);
          Carp::croak "Invalid $name: '$_[1]'"  unless(exists $check{$_[1]});
          return $_[0]->{$key} = ($length && defined $_[1]) ?
            sprintf('%-*s', $length, substr($_[1], 0, $length)) : $_[1];
        };
      }
      else
      {
        $methods{$name} = sub
        {
          Carp::croak "Missing argument in call to $name"  unless(@_ > 1);
          Carp::croak "Invalid $name: '$_[1]'"  unless(exists $check{$_[1]});
          return $_[0]->{$key} = ($length && defined $_[1]) ?
            sprintf('%-*s', $length, substr($_[1], 0, $length)) : $_[1];
        };
      }
    }
    else
    {
      $methods{$name} = sub
      {
        Carp::croak "Missing argument in call to $name"  unless(@_ > 1);
        return $_[0]->{$key} = ($length && defined $_[1]) ?
          sprintf('%-*s', $length, substr($_[1], 0, $length)) : $_[1];
      };
    }
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

sub varchar
{
  my($class, $name, $args) = @_;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';
  my $length    = $args->{'length'} || 0;

  my %methods;

  if($interface eq 'get_set')
  {
    if(my $check = $args->{'check_in'})
    {
      $check = [ $check ] unless(ref $check);
      my %check = map { $_ => 1 } @$check;

      my $default = $args->{'default'};

      if(defined $default)
      {
        $methods{$name} = sub
        {
          if(@_ > 1 && defined $_[1])
          {
            Carp::croak "Invalid $name: '$_[1]'"  unless(exists $check{$_[1]});
            return $_[0]->{$key} = $length ? substr($_[1], 0, $length) : $_[1];
          }
          return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                   ($_[0]->{$key} = $default);
        };
      }
      elsif(exists $args->{'with_init'} || exists $args->{'init_method'})
      {
        my $init_method = $args->{'init_method'} || "init_$name";

        $methods{$name} = sub
        {
          if(@_ > 1 && defined $_[1])
          {
            Carp::croak "Invalid $name: '$_[1]'"  unless(exists $check{$_[1]});
            return $_[0]->{$key} = $length ? substr($_[1], 0, $length) : $_[1];
          }
          return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                   ($_[0]->{$key} = $_[0]->$init_method());
        };
      }
      else
      {
        $methods{$name} = sub
        {
          if(@_ > 1 && defined $_[1])
          {
            Carp::croak "Invalid $name: '$_[1]'"  unless(exists $check{$_[1]});
            return $_[0]->{$key} = $length ? substr($_[1], 0, $length) : $_[1];
          }
          return $_[0]->{$key};
        };
      }
    }
    else
    {
      my $default = $args->{'default'};

      if(defined $default)
      {
        $methods{$name} = sub
        {
          if(@_ > 1)
          {
            no warnings; # substr on undef is ok here
            return $_[0]->{$key} = $length ? substr($_[1], 0, $length) : $_[1];
          }
          return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                   ($_[0]->{$key} = $default);
        };
      }
      elsif(exists $args->{'with_init'} || exists $args->{'init_method'})
      {
        my $init_method = $args->{'init_method'} || "init_$name";

        $methods{$name} = sub
        {
          if(@_ > 1)
          {
            no warnings; # substr on undef is ok here
            return $_[0]->{$key} = $length ? substr($_[1], 0, $length) : $_[1];
          }
          return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                   ($_[0]->{$key} = $_[0]->$init_method());
        };
      }
      else
      {
        $methods{$name} = sub
        {
          if(@_ > 1)
          {
            no warnings; # substr on undef is ok here
            return $_[0]->{$key} = $length ? substr($_[1], 0, $length) : $_[1];
          }
          return $_[0]->{$key};
        };
      }
    }
  }
  elsif($interface eq 'get')
  {
    my $default = $args->{'default'};

    if(defined $default)
    {
      $methods{$name} = sub
      {
        return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                 ($_[0]->{$key} = $default);
      };
    }
    elsif(exists $args->{'with_init'} || exists $args->{'init_method'})
    {
      my $init_method = $args->{'init_method'} || "init_$name";

      $methods{$name} = sub
      {
        return (defined $_[0]->{$key}) ? $_[0]->{$key} : 
                 ($_[0]->{$key} = $_[0]->$init_method());
      };
    }
    else
    {
      $methods{$name} = sub { shift->{$key} };
    }
  }
  elsif($interface eq 'set')
  {
    if(my $check = $args->{'check_in'})
    {
      $check = [ $check ] unless(ref $check);
      my %check = map { $_ => 1 } @$check;

      $methods{$name} = sub
      {
        Carp::croak "Missing argument in call to $name"  unless(@_ > 1);
        Carp::croak "Invalid $name: '$_[1]'"  unless(exists $check{$_[1]});
        return $_[0]->{$key} = $length ? substr($_[1], 0, $length) : $_[1];
      };
    }
    else
    {
      $methods{$name} = sub
      {
        Carp::croak "Missing argument in call to $name"  unless(@_ > 1);
        no warnings; # substr on undef is ok here
        return $_[0]->{$key} = $length ? substr($_[1], 0, $length) : $_[1];
      };
    }
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

sub boolean
{
  my($class, $name, $args) = @_;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';

  my %methods;

  if($interface eq 'get_set')
  {
    my $default = $args->{'default'};

    if(defined $default)
    {
      $default = ($default) ? 1 : 0;

      $methods{$name} = sub
      {
        my $self = shift;

        if(@_)
        {
          my $db = $self->db or die "Missing Rose::DB object attribute";

          if($_[0])
          {
            if($_[0] =~ /^(?:1(?:\.0*)?|t(?:rue)?|y(?:es)?)$/i)
            {
              return $self->{$key} = 1;
            }
            elsif($_[0] =~ /^(?:0(?:\.0*)?|f(?:alse)?|no?)$/i)
            {
              return $self->{$key} = 0;
            }
            else
            {
              my $value = $db->parse_boolean($_[0]);
              Carp::croak($db->error)  unless(defined $value);
              return $self->{$key} = $value;
            }
          }

          return $self->{$key} = 0;
        }

        if($self->{STATE_SAVING()})
        {
          my $db = $self->db or die "Missing Rose::DB object attribute";
          return (defined $self->{$key}) ? $db->format_boolean($self->{$key}) : 
                                           $db->format_boolean($self->{$key} = $default);
        }

        return (defined $self->{$key}) ? $self->{$key} : ($self->{$key} = $default);
      }
    }
    else
    {
      $methods{$name} = sub
      {
        my $self = shift;

        if(@_)
        {
          my $db = $self->db or die "Missing Rose::DB object attribute";

          if($_[0])
          {
            if($_[0] =~ /^(?:1(?:\.0*)?|t(?:rue)?|y(?:es)?)$/i)
            {
              return $self->{$key} = 1;
            }
            elsif($_[0] =~ /^(?:0(?:\.0*)?|f(?:alse)?|no?)$/i)
            {
              return $self->{$key} = 0;
            }
            else
            {
              my $value = $db->parse_boolean($_[0]);
              Carp::croak($db->error)  unless(defined $value);
              return $self->{$key} = $value;
            }
          }

          return $self->{$key} = 0;
        }

        if($self->{STATE_SAVING()})
        {
          my $db = $self->db or die "Missing Rose::DB object attribute";
          return (defined $self->{$key}) ? $db->format_boolean($self->{$key}) : undef;
        }

        return $self->{$key};
      }
    }
  }
  elsif($interface eq 'get')
  {
    my $default = $args->{'default'};

    if(defined $default)
    {
      $default = ($default) ? 1 : 0;

      $methods{$name} = sub
      {
        my $self = shift;

        if($self->{STATE_SAVING()})
        {
          my $db = $self->db or die "Missing Rose::DB object attribute";
          return (defined $self->{$key}) ? $db->format_boolean($self->{$key}) : 
                                           $db->format_boolean($self->{$key} = $default);
        }

        return (defined $self->{$key}) ? $self->{$key} : ($self->{$key} = $default);
      }
    }
    else
    {
      $methods{$name} = sub
      {
        my $self = shift;

        if($self->{STATE_SAVING()})
        {
          my $db = $self->db or die "Missing Rose::DB object attribute";
          return (defined $self->{$key}) ? $db->format_boolean($self->{$key}) : undef;
        }

        return $self->{$key};
      }
    }
  }
  elsif($interface eq 'set')
  {
    my $default = $args->{'default'};

    $methods{$name} = sub
    {
      my $self = shift;

      Carp::croak "Missing argument in call to $name"  unless(@_);
      my $db = $self->db or die "Missing Rose::DB object attribute";

      if($_[0])
      {
        if($_[0] =~ /^(?:0*1(?:\.0*)?|t(?:rue)?|y(?:es)?)$/i)
        {
          return $self->{$key} = 1;
        }
        elsif($_[0] =~ /^(?:0+(?:\.0*)?|f(?:alse)?|no?)$/i)
        {
          return $self->{$key} = 0;
        }
        else
        {
          my $value = $db->parse_boolean($_[0]);
          Carp::croak($db->error)  unless(defined $value);
          return $self->{$key} = $value;
        }
      }

      return $self->{$key} = 0;
    }
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

sub bitfield
{
  my($class, $name, $args) = @_;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';

  my %methods;

  if($interface eq 'get_set')
  {
    my $size = $args->{'bits'} ||= 32;

    my $default = $args->{'default'};
    my $formatted_key = PRIVATE_PREFIX . "_${key}_formatted";

    if(defined $default)
    {
      $methods{$name} = sub
      {
        my $self = shift;

        my $db = $self->db or die "Missing Rose::DB object attribute";

        if(@_)
        {
          if($self->{STATE_LOADING()})
          {
            $self->{$key} = undef;
            $self->{$formatted_key} = $_[0];
          }
          else
          {
            $self->{$key} = $db->parse_bitfield($_[0], $size);

            unless(defined $self->{$key})
            {
              $self->error($db->error);
            }
          }
        }
        elsif(!defined $self->{$key} && (!$self->{STATE_SAVING()} || !defined $self->{$formatted_key}))
        {
          $self->{$key} = $db->parse_bitfield($default, $size);

          unless(defined $self->{$key})
          {
            $self->error($db->error);
          }
        }

        if($self->{STATE_SAVING()})
        {
          $self->{$formatted_key} = $db->format_bitfield($self->{$key})
            unless(defined $self->{$formatted_key} || !defined $self->{$key});

          return $self->{$formatted_key};
        }

        return unless(defined wantarray);

        return $self->{$key} ? $self->{$key} : 
               $self->{$formatted_key} ? $db->parse_bitfield($self->{$formatted_key}) : undef;
      };
    }
    else
    {
      $methods{$name} = sub
      {
        my $self = shift;

        my $db = $self->db or die "Missing Rose::DB object attribute";

        if(@_)
        {
          if($self->{STATE_LOADING()})
          {
            $self->{$key} = undef;
            $self->{$formatted_key} = $_[0];
          }
          else
          {
            $self->{$key} = $db->parse_bitfield($_[0], $size);
          }
        }

        if($self->{STATE_SAVING()})
        {
          return undef  unless(defined($self->{$formatted_key}) || $self->{$key});

          $self->{$formatted_key} = $db->format_bitfield($self->{$key})
            unless(defined $self->{$formatted_key} || !defined $self->{$key});

          return $self->{$formatted_key};
        }

        return unless(defined wantarray);

        return $self->{$key} ? $self->{$key} : 
               $self->{$formatted_key} ? $db->parse_bitfield($self->{$formatted_key}) : undef;
      };


      if($args->{'with_intersects'})
      {
        my $method = $args->{'intersects'} || $name . '_intersects';

        $methods{$method} = sub 
        {
          my($self, $vec) = @_;

          my $val = $self->{$key} or return undef;

          unless(ref $vec)
          {
            my $db = $self->db or die "Missing Rose::DB object attribute";
            $vec = $db->parse_bitfield($vec, $size);
          }

          $vec = Bit::Vector->new_Bin($size, $vec->to_Bin)  if($vec->Size != $size);

          my $test = Bit::Vector->new($size);
          $test->Intersection($val, $vec);
          return ($test->to_Bin > 0) ? 1 : 0;
        };
      }
    }
  }
  elsif($interface eq 'get')
  {
    my $size = $args->{'bits'} ||= 32;

    my $default = $args->{'default'};
    my $formatted_key = PRIVATE_PREFIX . "_${key}_formatted";

    if(defined $default)
    {
      $methods{$name} = sub
      {
        my $self = shift;

        my $db = $self->db or die "Missing Rose::DB object attribute";

        if(!defined $self->{$key} && (!$self->{STATE_SAVING()} || !defined $self->{$formatted_key}))
        {
          $self->{$key} = $db->parse_bitfield($default, $size);

          unless(defined $self->{$key})
          {
            $self->error($db->error);
          }
        }

        if($self->{STATE_SAVING()})
        {
          $self->{$formatted_key} = $db->format_bitfield($self->{$key})
            unless(defined $self->{$formatted_key} || !defined $self->{$key});

          return $self->{$formatted_key};
        }

        return unless(defined wantarray);

        return $self->{$key} ? $self->{$key} : 
               $self->{$formatted_key} ? $db->parse_bitfield($self->{$formatted_key}) : undef;
      };
    }
    else
    {
      $methods{$name} = sub
      {
        my $self = shift;

        my $db = $self->db or die "Missing Rose::DB object attribute";

        if($self->{STATE_SAVING()})
        {
          return undef  unless(defined($self->{$formatted_key}) || $self->{$key});

          $self->{$formatted_key} = $db->format_bitfield($self->{$key})
            unless(defined $self->{$formatted_key} || !defined $self->{$key});

          return $self->{$formatted_key};
        }

        return unless(defined wantarray);

        return $self->{$key} ? $self->{$key} : 
               $self->{$formatted_key} ? $db->parse_bitfield($self->{$formatted_key}) : undef;
      };
    }
  }
  elsif($interface eq 'set')
  {
    my $size = $args->{'bits'} ||= 32;

    my $default = $args->{'default'};
    my $formatted_key = PRIVATE_PREFIX . "_${key}_formatted";

    $methods{$name} = sub
    {
      my $self = shift;

      my $db = $self->db or die "Missing Rose::DB object attribute";

      Carp::croak "Missing argument in call to $name"  unless(@_);

      if($self->{STATE_LOADING()})
      {
        $self->{$key} = undef;
        $self->{$formatted_key} = $_[0];
      }
      else
      {
        $self->{$key} = $db->parse_bitfield($_[0], $size);
      }

      if($self->{STATE_SAVING()})
      {
        return undef  unless(defined($self->{$formatted_key}) || $self->{$key});

        $self->{$formatted_key} = $db->format_bitfield($self->{$key})
          unless(defined $self->{$formatted_key} || !defined $self->{$key});

        return $self->{$formatted_key};
      }

      return unless(defined wantarray);

      return $self->{$key} ? $self->{$key} : 
             $self->{$formatted_key} ? $db->parse_bitfield($self->{$formatted_key}) : undef;
    };
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

sub array
{
  my($class, $name, $args) = @_;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';

  my %methods;

  if($interface eq 'get_set')
  {
    my $default = $args->{'default'};

    if(defined $default)
    {
      $methods{$name} = sub
      {
        my $self = shift;

        my $db = $self->db or die "Missing Rose::DB object attribute";

        if(@_)
        {
          $self->{$key} = $db->parse_array(@_);
        }
        elsif(!defined $self->{$key})
        {
          $self->{$key} = $db->parse_array($default);
        }

        if($self->{STATE_SAVING()})
        {
          return defined $self->{$key} ? $db->format_array($self->{$key}) : undef;
        }

        return defined $self->{$key} ? wantarray ? @{$self->{$key}} : $self->{$key} : undef;        
      }
    }
    else
    {
      $methods{$name} = sub
      {
        my $self = shift;

        my $db = $self->db or die "Missing Rose::DB object attribute";

        if(@_)
        {
          $self->{$key} = $db->parse_array(@_);
        }

        if($self->{STATE_SAVING()})
        {
          return defined $self->{$key} ? $db->format_array($self->{$key}) : undef;
        }

        return defined $self->{$key} ? wantarray ? @{$self->{$key}} : $self->{$key} : undef;
      }
    }
  }
  elsif($interface eq 'get')
  {
    my $default = $args->{'default'};

    if(defined $default)
    {
      $methods{$name} = sub
      {
        my $self = shift;

        my $db = $self->db or die "Missing Rose::DB object attribute";

        if(!defined $self->{$key})
        {
          $self->{$key} = $db->parse_array($default);
        }

        if($self->{STATE_SAVING()})
        {
          return defined $self->{$key} ? $db->format_array($self->{$key}) : undef;
        }

        return defined $self->{$key} ? wantarray ? @{$self->{$key}} : $self->{$key} : undef;        
      }
    }
    else
    {
      $methods{$name} = sub
      {
        my $self = shift;

        my $db = $self->db or die "Missing Rose::DB object attribute";

        if($self->{STATE_SAVING()})
        {
          return defined $self->{$key} ? $db->format_array($self->{$key}) : undef;
        }

        return defined $self->{$key} ? wantarray ? @{$self->{$key}} : $self->{$key} : undef;
      }
    }
  }
  elsif($interface eq 'set')
  {
    $methods{$name} = sub
    {
      my $self = shift;

      my $db = $self->db or die "Missing Rose::DB object attribute";

      Carp::croak "Missing argument in call to $name"  unless(@_);
      $self->{$key} = $db->parse_array(@_);

      if($self->{STATE_SAVING()})
      {
        return defined $self->{$key} ? $db->format_array($self->{$key}) : undef;
      }

      return defined $self->{$key} ? wantarray ? @{$self->{$key}} : $self->{$key} : undef;
    }
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

sub set
{
  my($class, $name, $args) = @_;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';

  my %methods;

  if($interface eq 'get_set')
  {
    my $default = $args->{'default'};

    if(defined $default)
    {
      $methods{$name} = sub
      {
        my $self = shift;

        my $db = $self->db or die "Missing Rose::DB object attribute";

        if(@_)
        {
          $self->{$key} = $db->parse_set(@_);
        }
        elsif(!defined $self->{$key})
        {
          $self->{$key} = $db->parse_set($default);
        }

        if($self->{STATE_SAVING()})
        {
          return defined $self->{$key} ? $db->format_set($self->{$key}) : undef;
        }

        return defined $self->{$key} ? wantarray ? @{$self->{$key}} : $self->{$key} : undef;        
      }
    }
    else
    {
      $methods{$name} = sub
      {
        my $self = shift;

        my $db = $self->db or die "Missing Rose::DB object attribute";

        if(@_)
        {
          $self->{$key} = $db->parse_set(@_);
        }

        if($self->{STATE_SAVING()})
        {
          return defined $self->{$key} ? $db->format_set($self->{$key}) : undef;
        }

        return defined $self->{$key} ? wantarray ? @{$self->{$key}} : $self->{$key} : undef;
      }
    }
  }
  elsif($interface eq 'get')
  {
    my $default = $args->{'default'};

    if(defined $default)
    {
      $methods{$name} = sub
      {
        my $self = shift;

        my $db = $self->db or die "Missing Rose::DB object attribute";

        if(!defined $self->{$key})
        {
          $self->{$key} = $db->parse_set($default);
        }

        if($self->{STATE_SAVING()})
        {
          return defined $self->{$key} ? $db->format_set($self->{$key}) : undef;
        }

        return defined $self->{$key} ? wantarray ? @{$self->{$key}} : $self->{$key} : undef;        
      }
    }
    else
    {
      $methods{$name} = sub
      {
        my $self = shift;

        my $db = $self->db or die "Missing Rose::DB object attribute";

        if($self->{STATE_SAVING()})
        {
          return defined $self->{$key} ? $db->format_set($self->{$key}) : undef;
        }

        return defined $self->{$key} ? wantarray ? @{$self->{$key}} : $self->{$key} : undef;
      }
    }
  }
  elsif($interface eq 'set')
  {
    $methods{$name} = sub
    {
      my $self = shift;

      my $db = $self->db or die "Missing Rose::DB object attribute";

      Carp::croak "Missing argument in call to $name"  unless(@_);
      $self->{$key} = $db->parse_set(@_);

      if($self->{STATE_SAVING()})
      {
        return defined $self->{$key} ? $db->format_set($self->{$key}) : undef;
      }

      return defined $self->{$key} ? wantarray ? @{$self->{$key}} : $self->{$key} : undef;
    };
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

sub object_by_key
{
  my($class, $name, $args, $options) = @_;

  my %methods;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';
  my $target_class = $options->{'target_class'} or die "Missing target class";

  my $fk         = $args->{'foreign_key'} || $args->{'relationship'};
  my $fk_class   = $args->{'class'} or die "Missing foreign object class";
  my $fk_meta    = $fk_class->meta;
  my $meta       = $target_class->meta;

  my $fk_columns = $args->{'key_columns'} or die "Missing key columns hash";
  my $share_db   = $args->{'share_db'};

  if($interface eq 'get_set')
  {
    $methods{$name} = sub
    {
      my($self) = shift;

      if(@_)
      {
        return $self->{$key} = undef  unless(defined $_[0]);

        while(my($local_column, $foreign_column) = each(%$fk_columns))
        {
          my $local_method   = $meta->column_mutator_method_name($local_column);
          my $foreign_method = $fk_meta->column_accessor_method_name($foreign_column);

          $self->$local_method($_[0]->$foreign_method);
        }

        return $self->{$key} = $_[0];
      }

      return $self->{$key}  if(defined $self->{$key});

      my %key;

      while(my($local_column, $foreign_column) = each(%$fk_columns))
      {
        my $local_method   = $meta->column_accessor_method_name($local_column);
        my $foreign_method = $fk_meta->column_mutator_method_name($foreign_column);

        $key{$foreign_method} = $self->$local_method();

        # XXX: Comment this out to allow null keys
        unless(defined $key{$foreign_method})
        {
          keys(%$fk_columns); # reset iterator
          $self->error("Could not load $name object - the " .
                       "$local_method attribute is undefined");
          return undef;
        }
      }

      my $obj;

      if($share_db)
      {
        $obj = $fk_class->new(%key, db => $self->db);
      }
      else
      {
        $obj = $fk_class->new(%key);
      }

      my $ret;

      eval { $ret = $obj->load };

      if($@ || !$ret)
      {
        $self->error("Could not load $fk_class with key ", 
                     join(', ', map { "$_ = '$key{$_}'" } sort keys %key) .
                     " - " . $obj->error);
        $self->meta->handle_error($self);
        return $ret;
      }

      return $self->{$key} = $obj;
    };
  }
  elsif($interface eq 'get_set_now')
  {
    $methods{$name} = sub
    {
      my($self) = shift;

      if(@_)
      {
        # If loading, just assign
        if($self->{STATE_LOADING()})
        {
          return $self->{$key} = $_[0];
        }

        # Can't add until the object is saved
        unless($self->{STATE_IN_DB()})
        {
          Carp::croak "Can't $name() until this object is loaded or saved";
        }

        my $object;

        if(@_ == 1)
        {
          # Object argument
          if(my $arg_class = ref $_[0])
          {
            unless($arg_class eq $fk_class)
            {
              Carp::croak "$arg_class is not a $fk_class object";
            }

            $object = $_[0];
          }
          elsif(!defined $_[0]) # undef argument
          {
            return $self->{$key} = undef;
          }
        }
        else
        {
          # Primary key value
          if(@_ == 1)
          {
            my @pk_columns  = $fk_meta->primary_key_columns;

            if(@pk_columns > 1)
            {
              Carp::croak "Single argument is insufficient to add an object ",
                          "of class $fk_class which has ", scalar(@pk_columns),
                          " primary key columns";
            }

            $object = $fk_class->new($pk_columns[0]->name => $_[0]);
          }
          else # Object constructor arguments
          {
            $object = $fk_class->new(@_);
          }
        }  

        my($db, $started_new_tx);

        eval
        {
          $db = $self->db;
          $object->db($db)  if($share_db);

          my $ret = $db->begin_work;

          unless(defined $ret)
          {
            die 'Could not begin transaction during call to $name() - ',
                $db->error;
          }

          $started_new_tx = ($ret == IN_TRANSACTION) ? 0 : 1;

          if($object->{STATE_IN_DB()})
          {
            $object->save or die $object->error;
          }
          else
          {
            $object->load(speculative => 1);
            $object->save or die $object->error;
          }

          while(my($local_column, $foreign_column) = each(%$fk_columns))
          {
            my $local_method   = $meta->column_mutator_method_name($local_column);
            my $foreign_method = $fk_meta->column_accessor_method_name($foreign_column);

            $self->$local_method($object->$foreign_method);
          }

          $self->save or die $self->error;

          $self->{$key} = $object;

          if($started_new_tx)
          {
            $db->commit or die $db->error;
          }
        };

        if($@)
        {
          $self->error("Could not add $name object - $@");
          $db->rollback  if($db && $started_new_tx);
          $meta->handle_error($self);
          return undef;
        }

        return $self->{$key};
      }

      return $self->{$key}  if(defined $self->{$key});

      my %key;

      while(my($local_column, $foreign_column) = each(%$fk_columns))
      {
        my $local_method   = $meta->column_accessor_method_name($local_column);
        my $foreign_method = $fk_meta->column_mutator_method_name($foreign_column);

        $key{$foreign_method} = $self->$local_method();

        # XXX: Comment this out to allow null keys
        unless(defined $key{$foreign_method})
        {
          keys(%$fk_columns); # reset iterator
          $self->error("Could not load $name object - the " .
                       "$local_method attribute is undefined");
          return undef;
        }
      }

      my $obj;

      if($share_db)
      {
        $obj = $fk_class->new(%key, db => $self->db);
      }
      else
      {
        $obj = $fk_class->new(%key);
      }

      my $ret;

      eval { $ret = $obj->load };

      if($@ || !$ret)
      {
        $self->error("Could not load $fk_class with key ", 
                     join(', ', map { "$_ = '$key{$_}'" } sort keys %key) .
                     " - " . $obj->error);
        $self->meta->handle_error($self);
        return $ret;
      }

      return $self->{$key} = $obj;
    };
  }
  elsif($interface eq 'get_set_on_save')
  {
    unless($fk)
    {
      Carp::confess "Cannot make 'get_set_on_save' method $name without foreign key argument";
    }

    my $fk_name = $fk->name;

    $methods{$name} = sub
    {
      my($self) = shift;

      if(@_)
      {
        # If loading, just assign
        if($self->{STATE_LOADING()})
        {
          return $self->{$key} = $_[0];
        }

        my $object;

        if(@_ == 1)
        {
          # Object argument
          if(my $arg_class = ref $_[0])
          {
            unless($arg_class eq $fk_class)
            {
              Carp::croak "$arg_class is not a $fk_class object";
            }

            $object = $_[0];
          }
          elsif(!defined $_[0]) # undef argument
          {
            # Clear foreign key columns
            foreach my $local_column (keys %$fk_columns)
            {
              my $local_method = $meta->column_accessor_method_name($local_column);
              $self->$local_method(undef);
            }

            delete $self->{ON_SAVE_ATTR_NAME()}{'pre'}{'fk'}{$fk_name}{'set'};
            return $self->{$key} = undef;
          }
        }
        else
        {
          # Primary key value
          if(@_ == 1)
          {
            my @pk_columns  = $fk_meta->primary_key_columns;

            if(@pk_columns > 1)
            {
              Carp::croak "Single argument is insufficient to add an object ",
                          "of class $fk_class which has ", scalar(@pk_columns),
                          " primary key columns";
            }

            $object = $fk_class->new($pk_columns[0]->name => $_[0]);
          }
          else # Object constructor arguments
          {
            $object = $fk_class->new(@_);
          }
        }

        # Try loading the object
        unless($object->{STATE_IN_DB()})
        {
          $object->load(speculative => 1);
        }

        # Set the foreign key columns
        while(my($local_column, $foreign_column) = each(%$fk_columns))
        {
          my $local_method   = $meta->column_mutator_method_name($local_column);
          my $foreign_method = $fk_meta->column_accessor_method_name($foreign_column);

          $self->$local_method($object->$foreign_method);
        }

        # Set the attribute
        $self->{$key} = $object;

        # Make the code that will run on save()
        my $save_code = sub
        {
          # Bail if there's nothing to do
          my $object = $self->{$key} or return;

          my $db;

          eval
          {
            $db = $self->db;
            $object->db($db)  if($share_db);

            # Save the object, load or create if necessary
            if($object->{STATE_IN_DB()})
            {
              $object->save or die $object->error;
            }
            else
            {
              $object->load(speculative => 1);
              $object->save or die $object->error;
            }

            # Set the foreign key columns
            while(my($local_column, $foreign_column) = each(%$fk_columns))
            {
              my $local_method   = $meta->column_mutator_method_name($local_column);
              my $foreign_method = $fk_meta->column_accessor_method_name($foreign_column);

              $self->$local_method($object->$foreign_method);
            }

            return $self->{$key} = $object;
          };

          if($@)
          {
            $self->error("Could not add $name object - $@");
            $meta->handle_error($self);
            return undef;
          }

          return $self->{$key};
        };

        $self->{ON_SAVE_ATTR_NAME()}{'pre'}{'fk'}{$fk_name}{'set'} = $save_code;
        return $self->{$key};
      }

      return $self->{$key}  if(defined $self->{$key});

      my %key;

      while(my($local_column, $foreign_column) = each(%$fk_columns))
      {
        my $local_method   = $meta->column_accessor_method_name($local_column);
        my $foreign_method = $fk_meta->column_mutator_method_name($foreign_column);

        $key{$foreign_method} = $self->$local_method();

        # XXX: Comment this out to allow null keys
        unless(defined $key{$foreign_method})
        {
          keys(%$fk_columns); # reset iterator
          $self->error("Could not load $name object - the " .
                       "$local_method attribute is undefined");
          return undef;
        }
      }

      my $obj;

      if($share_db)
      {
        $obj = $fk_class->new(%key, db => $self->db);
      }
      else
      {
        $obj = $fk_class->new(%key);
      }

      my $ret;

      eval { $ret = $obj->load };

      if($@ || !$ret)
      {
        $self->error("Could not load $fk_class with key ", 
                     join(', ', map { "$_ = '$key{$_}'" } sort keys %key) .
                     " - " . $obj->error);
        $self->meta->handle_error($self);
        return $ret;
      }

      return $self->{$key} = $obj;
    };
  }
  elsif($interface eq 'delete_now')
  {
    unless($fk)
    {
      Carp::croak "Cannot make 'delete' method $name without foreign key argument";
    }

    my $fk_name = $fk->name;

    $methods{$name} = sub
    {
      my($self) = shift;

      my $object = $self->{$key} || $fk_class->new;

      my %key;

      while(my($local_column, $foreign_column) = each(%$fk_columns))
      {
        my $local_method   = $meta->column_accessor_method_name($local_column);
        my $foreign_method = $fk_meta->column_mutator_method_name($foreign_column);

        $key{$foreign_method} = $self->$local_method();

        # XXX: Comment this out to allow null keys
        unless(defined $key{$foreign_method})
        {
          keys(%$fk_columns); # reset iterator

          # If this failed because we haven't saved it yet
          if(delete $self->{ON_SAVE_ATTR_NAME()}{'pre'}{'fk'}{$fk_name}{'set'})
          {
            # Clear foreign key columns
            foreach my $local_column (keys %$fk_columns)
            {
              my $local_method = $meta->column_accessor_method_name($local_column);
              $self->$local_method(undef);
            }

            $self->{$key} = undef;
            return 1;
          }

          $self->error("Could not delete $name object - the " .
                       "$local_method attribute is undefined");
          return undef;
        }
      }

      $object->init(%key);

      my($db, $started_new_tx, $deleted, %save_fk, $to_save);

      eval
      {
        $db = $self->db;
        $object->db($db)  if($share_db);

        my $ret = $db->begin_work;

        unless(defined $ret)
        {
          die 'Could not begin transaction during call to $name() - ',
              $db->error;
        }

        $started_new_tx = ($ret == IN_TRANSACTION) ? 0 : 1;

        # Clear columns that reference the foreign key
        foreach my $local_column (keys %$fk_columns)
        {
          my $local_method = $meta->column_accessor_method_name($local_column);
          $save_fk{$local_method} = $self->$local_method();
          $self->$local_method(undef);
        }

        # Forget about any value we were going to set on save
        $to_save = delete $self->{ON_SAVE_ATTR_NAME()}{'pre'}{'fk'}{$fk_name}{'set'};

        $self->save or die $self->error;

        # Propogate cascade arg, if any
        $deleted = $object->delete(@_) or die $object->error;

        if($started_new_tx)
        {
          $db->commit or die $db->error;
        }

        $self->{$key} = undef;
      };

      if($@)
      {
        $self->error("Could not delete $name object - $@");
        $db->rollback  if($db && $started_new_tx);

        # Restore foreign key column values
        while(my($method, $value) = each(%save_fk))
        {
          $self->$method($value);
        }

        # Restore any value we were going to set on save
        $self->{ON_SAVE_ATTR_NAME()}{'pre'}{'fk'}{$fk_name}{'set'} = $to_save
          if($to_save);

        $meta->handle_error($self);
        return undef;
      }

      return $deleted;
    };
  }
  elsif($interface eq 'delete_on_save')
  {
    unless($fk)
    {
      Carp::croak "Cannot make 'delete_on_save' method $name without foreign key argument";
    }

    my $fk_name = $fk->name;

    $methods{$name} = sub
    {
      my($self) = shift;

      my $object = $self->{$key} || $fk_class->new;

      my %key;

      while(my($local_column, $foreign_column) = each(%$fk_columns))
      {
        my $local_method   = $meta->column_accessor_method_name($local_column);
        my $foreign_method = $fk_meta->column_mutator_method_name($foreign_column);

        $key{$foreign_method} = $self->$local_method();

        # XXX: Comment this out to allow null keys
        unless(defined $key{$foreign_method})
        {
          keys(%$fk_columns); # reset iterator

          # If this failed because we haven't saved it yet
          if(delete $self->{ON_SAVE_ATTR_NAME()}{'pre'}{'fk'}{$fk_name}{'set'})
          {
            # Clear foreign key columns
            foreach my $local_column (keys %$fk_columns)
            {
              my $local_method = $meta->column_accessor_method_name($local_column);
              $self->$local_method(undef);
            }

            $self->{$key} = undef;
            return 0;
          }

          $self->error("Could not delete $name object - the " .
                       "$local_method attribute is undefined");
          return undef;
        }
      }

      $object->init(%key);

      my %save_fk;

      # Clear columns that reference the foreign key, saving old values
      foreach my $local_column (keys %$fk_columns)
      {
        my $local_method = $meta->column_accessor_method_name($local_column);
        $save_fk{$local_method} = $self->$local_method();
        $self->$local_method(undef);
      }

      # Forget about any value we were going to set on save
      delete $self->{ON_SAVE_ATTR_NAME()}{'pre'}{'fk'}{$fk_name}{'set'};

      # Clear the foreignobject attribute
      $self->{$key} = undef;

      # Make the code to run on save
      my $delete_code = sub
      {  
        my $db;

        eval
        {
          $db = $self->db;
          $object->db($db)  if($share_db);
          $object->delete(@_) or die $object->error;
        };

        if($@)
        {
          $self->error("Could not delete $name object - $@");

          # Restore old foreign key column values if prudent
          while(my($method, $value) = each(%save_fk))
          {
            $self->$method($value)  unless(defined $self->$method);
          }

          $meta->handle_error($self);
          return undef;
        }

        return 1;
      };

      # Add the on save code to the list
      push(@{$self->{ON_SAVE_ATTR_NAME()}{'post'}{'fk'}{$fk_name}{'delete'}}, 
           { code => $delete_code, object => $object });

      return 1;
    };
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

sub objects_by_key
{
  my($class, $name, $args, $options) = @_;

  my %methods;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';
  my $target_class = $options->{'target_class'} or die "Missing target class";

  my $relationship = $args->{'relationship'};

  my $ft_class   = $args->{'class'} or die "Missing foreign object class";
  my $meta       = $target_class->meta;

  my $ft_columns = $args->{'key_columns'} or die "Missing key columns hash";
  my $ft_manager = $args->{'manager_class'};
  my $ft_method  = $args->{'manager_method'} || 'get_objects';
  my $share_db   = $args->{'share_db'} || 1;
  my $mgr_args   = $args->{'manager_args'} || {};
  my $query_args = $args->{'query_args'} || [];

  if(@$query_args % 2 != 0)
  {
    Carp::croak "Odd number of arguments passed in query_args parameter";
  }

  unless($ft_manager)
  {
    $ft_manager = 'Rose::DB::Object::Manager';
    $mgr_args->{'object_class'} = $ft_class;
  }

  if($interface eq 'get_set' || $interface eq 'get_set_load')
  {
    $methods{$name} = sub
    {
      my($self) = shift;

      if(@_)
      {      
        return $self->{$key} = undef  if(@_ == 1 && !defined $_[0]);
        return $self->{$key} = (@_ == 1 && ref $_[0] eq 'ARRAY') ? $_[0] : [ @_ ];
      }

      if(defined $self->{$key})
      {
        return wantarray ? @{$self->{$key}} : $self->{$key};  
      }

      my %key;

      while(my($local_column, $foreign_column) = each(%$ft_columns))
      {
        my $local_method = $meta->column_accessor_method_name($local_column);

        $key{$foreign_column} = $self->$local_method();

        # Comment this out to allow null keys
        unless(defined $key{$foreign_column})
        {
          keys(%$ft_columns); # reset iterator
          $self->error("Could not fetch objects via $name() - the " .
                       "$local_method attribute is undefined");
          return wantarray ? () : undef;
        }
      }

      my $objs;

      eval
      {
        if($share_db)
        {
          $objs = 
            $ft_manager->$ft_method(query => [ %key, @$query_args ], 
                                   %$mgr_args, db => $self->db)
              or die $ft_manager->error;
        }
        else
        {
          $objs = 
            $ft_manager->$ft_method(query => [ %key, @$query_args ], %$mgr_args)
              or die $ft_manager->error;
        }
      };

      if($@ || !$objs)
      {
        $self->error("Could not load $ft_class objects with key ", 
                     join(', ', map { "$_ = '$key{$_}'" } sort keys %key) .
                     " - " . $ft_manager->error);
        $self->meta->handle_error($self);
        return $objs;
      }

      $self->{$key} = $objs;

      return wantarray ? @{$self->{$key}} : $self->{$key};
    };

    if($interface eq 'get_set_load')
    {
      my $method_name = $args->{'load_method'} || 'load_' . $name;

      $methods{$method_name} = sub
      {
        return (defined shift->$name(@_)) ? 1 : 0;
      };
    }
  }
  elsif($interface eq 'get_set_now')
  {
    my $ft_delete_method  = $args->{'manager_delete_method'} || 'delete_objects';

    unless($relationship)
    {
      Carp::confess "Cannot make 'get_set_now' method $name without relationship argument";
    }

    my $rel_name = $relationship->name;

    $methods{$name} = sub
    {
      my($self) = shift;

      if(@_)
      {
        # If loading, just assign
        if($self->{STATE_LOADING()})
        {
          return $self->{$key} = undef  if(@_ == 1 && !defined $_[0]);
          return $self->{$key} = (@_ == 1 && ref $_[0] eq 'ARRAY') ? $_[0] : [ @_ ];
        }

        # Can't set until the object is saved
        unless($self->{STATE_IN_DB()})
        {
          Carp::croak "Can't set $name() until this object is loaded or saved";
        }

        # Set to undef resets the attr  
        if(@_ == 1 && !defined $_[0])
        {
          # Delete any pending set or add actions
          delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'set'};
          delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'add'};

          $self->{$key} = undef;
          return;
        }

        # Set up join conditions and column map
        my(%key, %map);

        my $ft_meta = $ft_class->meta 
          or Carp::croak "Missing metadata for foreign object class $ft_class";

        while(my($local_column, $foreign_column) = each(%$ft_columns))
        {
          my $local_method   = $meta->column_accessor_method_name($local_column);
          my $foreign_method = $ft_meta->column_accessor_method_name($foreign_column);

          $key{$foreign_column} = $map{$foreign_method} = $self->$local_method();

          # Comment this out to allow null keys
          unless(defined $key{$foreign_column})
          {
            keys(%$ft_columns); # reset iterator
            $self->error("Could not set objects via $name() - the " .
                         "$local_method attribute is undefined");
            return wantarray ? () : undef;
          }
        }

        my($db, $started_new_tx);

        eval
        {
          $db = $self->db;

          my $ret = $db->begin_work;

          unless(defined $ret)
          {
            die 'Could not begin transaction during call to $name() - ',
                $db->error;
          }

          $started_new_tx = ($ret == IN_TRANSACTION) ? 0 : 1;

          # Delete any existing objects
          my $deleted = 
            $ft_manager->$ft_delete_method(object_class => $ft_class,
                                           where => [ %key ], 
                                           db => $db);
          die $ft_manager->error  unless(defined $deleted);

          # Save all the new objects
          my $objects;

          if(@_ == 1)
          {    
            if(ref $_[0] eq 'ARRAY') { $objects = $_[0]  }
            else                     { $objects = [ @_ ] }

          }
          else { $objects = [ @_ ] }

          foreach my $object (@$objects)
          {
            # It's essential to share the db so that the load()
            # below can see the delete (above) which happened in
            # the current transaction
            $object->db($db); 

            # Try to load the object if doesn't appear to exist already
            unless($object->{STATE_IN_DB()})
            {
              # It's okay if this fails (e.g., if the primary key is undefined)
              eval { $object->load(speculative => 1) };
            }

            # Map object to parent
            $object->init(%map);

            # Save the object
            $object->save or die $object->error;

            # Not sharing?  Aw.
            $object->db(undef)  unless($share_db);
          }

          # Assign to attribute or blank the attribute, causing the objects
          # to be fetched from the db next time, depending on whether or not
          # there's a custom sort order
          $self->{$key} = defined $mgr_args->{'sort_by'} ? undef : $objects;

          if($started_new_tx)
          {
            $db->commit or die $db->error;
          }

          # Delete any pending set or add actions
          delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'set'};
          delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'add'};
        };

        if($@)
        {
          $self->error("Could not set $name objects - $@");
          $db->rollback  if($db && $started_new_tx);
          $meta->handle_error($self);
          return undef;
        }

        return 1  unless(defined $self->{$key});
        return wantarray ? @{$self->{$key}} : $self->{$key};
      }

      # Return existing list of objects, if it exists
      if(defined $self->{$key})
      {
        return wantarray ? @{$self->{$key}} : $self->{$key};  
      }

      my $objs;

      # Get query key
      my %key;

      while(my($local_column, $foreign_column) = each(%$ft_columns))
      {
        my $local_method = $meta->column_accessor_method_name($local_column);

        $key{$foreign_column} = $self->$local_method();

        # Comment this out to allow null keys
        unless(defined $key{$foreign_column})
        {
          keys(%$ft_columns); # reset iterator
          $self->error("Could not fetch objects via $name() - the " .
                       "$local_method attribute is undefined");
          return wantarray ? () : undef;
        }
      }

      # Make query for object list
      eval
      {
        if($share_db)
        {
          $objs = 
            $ft_manager->$ft_method(query => [ %key, @$query_args ], 
                                   %$mgr_args, db => $self->db)
              or die $ft_manager->error;
        }
        else
        {
          $objs = 
            $ft_manager->$ft_method(query => [ %key, @$query_args ], %$mgr_args)
              or die $ft_manager->error;
        }
      };

      if($@ || !$objs)
      {
        $self->error("Could not load $ft_class objects with key ", 
                     join(', ', map { "$_ = '$key{$_}'" } sort keys %key) .
                     " - " . $ft_manager->error);
        $self->meta->handle_error($self);
        return $objs;
      }

      $self->{$key} = $objs;

      return wantarray ? @{$self->{$key}} : $self->{$key};
    };
  }
  elsif($interface eq 'get_set_on_save')
  {
    my $ft_delete_method  = $args->{'manager_delete_method'} || 'delete_objects';

    unless($relationship)
    {
      Carp::confess "Cannot make 'get_set_on_save' method $name without relationship argument";
    }

    my $rel_name = $relationship->name;

    $methods{$name} = sub
    {
      my($self) = shift;

      if(@_)
      {
        # If loading, just assign
        if($self->{STATE_LOADING()})
        {
          return $self->{$key} = undef  if(@_ == 1 && !defined $_[0]);
          return $self->{$key} = (@_ == 1 && ref $_[0] eq 'ARRAY') ? $_[0] : [ @_ ];
        }

        my $objects;

        if(@_ == 1)
        {
          # Set to undef resets the attr  
          unless(defined $_[0])
          {
            # Delete any pending set or add actions
            delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'set'};
            delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'add'};

            $self->{$key} = undef;
            return;
          }

          if(ref $_[0] eq 'ARRAY') { $objects = $_[0]  }
          else                     { $objects = [ @_ ] }
        }
        else { $objects = [ @_ ] }

        my $db = $self->db;

        # Set up column map
        my %map;

        my $ft_meta = $ft_class->meta 
          or Carp::croak "Missing metadata for foreign object class $ft_class";

        while(my($local_column, $foreign_column) = each(%$ft_columns))
        {
          my $local_method   = $meta->column_accessor_method_name($local_column);
          my $foreign_method = $ft_meta->column_accessor_method_name($foreign_column);

          $map{$foreign_method} = $self->$local_method();
        }

        # Map all the objects to the parent
        foreach my $object (@$objects)
        {
          $object->init(%map, ($share_db ? (db => $db) : ()));
        }

        # Set the attribute
        $self->{$key} = $objects;

        my $save_code = sub
        {
          # Set up join conditions and column map
          my(%key, %map);

          my $ft_meta = $ft_class->meta 
            or Carp::croak "Missing metadata for foreign object class $ft_class";

          while(my($local_column, $foreign_column) = each(%$ft_columns))
          {
            my $local_method   = $meta->column_accessor_method_name($local_column);
            my $foreign_method = $ft_meta->column_accessor_method_name($foreign_column);

            $key{$foreign_column} = $map{$foreign_method} = $self->$local_method();

            # Comment this out to allow null keys
            unless(defined $key{$foreign_column})
            {
              keys(%$ft_columns); # reset iterator
              $self->error("Could not set objects via $name() - the " .
                           "$local_method attribute is undefined");
              return wantarray ? () : undef;
            }
          }

          my $db = $self->db;

          # Delete any existing objects
          my $deleted = 
            $ft_manager->$ft_delete_method(object_class => $ft_class,
                                           where => [ %key ], 
                                           db => $db);
          die $ft_manager->error  unless(defined $deleted);

          # Save all the objects.  Use the current list, even if it's
          # different than it was when the "set on save" was called.
          foreach my $object (@{$self->{$key} || []})
          {
            # It's essential to share the db so that the load()
            # below can see the delete (above) which happened in
            # the current transaction
            $object->db($db); 

            # Try to load the object if doesn't appear to exist already
            unless($object->{STATE_IN_DB()})
            {
              # It's okay if this fails (e.g., if the primary key is undefined)
              eval { $object->load(speculative => 1) };
            }

            # Map object to parent
            $object->init(%map);

            # Save the object
            $object->save or die $object->error;

            # Not sharing?  Aw.
            $object->db(undef)  unless($share_db);
          }

          # Forget about any adds if we just set the list
          if(defined $self->{$key})
          {
            # Set to undef instead of deleting because this code ref
            # will be called while iterating over this very hash.
            $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'add'} = undef;
          }

          # Blank the attribute, causing the objects to be fetched from
          # the db next time, if there's a custom sort order
          $self->{$key} = undef  if(defined $mgr_args->{'sort_by'});

          return 1;
        };

        $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'set'} = $save_code;

        # Forget about any adds
        delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'add'};

        return 1  unless(defined $self->{$key});
        return wantarray ? @{$self->{$key}} : $self->{$key};
      }

      # Return existing list of objects, if it exists
      if(defined $self->{$key})
      {
        return wantarray ? @{$self->{$key}} : $self->{$key};  
      }

      my $objs;

      # Get query key
      my %key;

      while(my($local_column, $foreign_column) = each(%$ft_columns))
      {
        my $local_method = $meta->column_accessor_method_name($local_column);

        $key{$foreign_column} = $self->$local_method();

        # Comment this out to allow null keys
        unless(defined $key{$foreign_column})
        {
          keys(%$ft_columns); # reset iterator
          $self->error("Could not fetch objects via $name() - the " .
                       "$local_method attribute is undefined");
          return wantarray ? () : undef;
        }
      }

      # Make query for object list
      eval
      {
        if($share_db)
        {
          $objs = 
            $ft_manager->$ft_method(query => [ %key, @$query_args ], 
                                   %$mgr_args, db => $self->db)
              or die $ft_manager->error;
        }
        else
        {
          $objs = 
            $ft_manager->$ft_method(query => [ %key, @$query_args ], %$mgr_args)
              or die $ft_manager->error;
        }
      };

      if($@ || !$objs)
      {
        $self->error("Could not load $ft_class objects with key ", 
                     join(', ', map { "$_ = '$key{$_}'" } sort keys %key) .
                     " - " . $ft_manager->error);
        $self->meta->handle_error($self);
        return $objs;
      }

      $self->{$key} = $objs;

      return wantarray ? @{$self->{$key}} : $self->{$key};
    };
  }
  elsif($interface eq 'add_now')
  {
    unless($relationship)
    {
      Carp::confess "Cannot make 'add_now' method $name without relationship argument";
    }

    my $rel_name = $relationship->name;

    $methods{$name} = sub
    {
      my($self) = shift;

      unless(@_)
      {
        $self->error("No $name to add");
        return;
      }

      # Can't add until the object is saved
      unless($self->{STATE_IN_DB()})
      {
        Carp::croak "Can't add $name until this object is loaded or saved";
      }

      if($self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'set'})
      {
        Carp::croak "Cannot add objects via the 'add_now' method $name() ",
                    "because the list of objects is already going to be ".
                    "set to something else on save.  Use the 'add_on_save' ",
                    "method type instead.";
      }

      # Set up column map
      my %map;

      my $ft_meta = $ft_class->meta 
        or Carp::croak "Missing metadata for foreign object class $ft_class";

      while(my($local_column, $foreign_column) = each(%$ft_columns))
      {
        my $local_method   = $meta->column_accessor_method_name($local_column);
        my $foreign_method = $ft_meta->column_accessor_method_name($foreign_column);

        $map{$foreign_method} = $self->$local_method();

        # Comment this out to allow null keys
        unless(defined $map{$foreign_method})
        {
          keys(%$ft_columns); # reset iterator
          $self->error("Could add set objects via $name() - the " .
                       "$local_method attribute is undefined");
          return wantarray ? () : undef;
        }
      }

      my $objects;

      if(@_ == 1 && ref $_[0] eq 'ARRAY') 
      {
        $objects = $_[0];
      }
      else { $objects = [ @_ ] }

      my($db, $started_new_tx);

      eval
      {
        $db = $self->db;

        my $ret = $db->begin_work;

        unless(defined $ret)
        {
          die 'Could not begin transaction during call to $name() - ',
              $db->error;
        }

        $started_new_tx = ($ret == IN_TRANSACTION) ? 0 : 1;

        # Add all the new objects
        foreach my $object (@$objects)
        {
          # Map object to parent
          $object->init(%map, db => $db);

          # Save the object
          $object->save or die $object->error;
        }

        # Clear the existing list, forcing it to be reloaded next time
        # it's asked for
        $self->{$key} = undef;

        if($started_new_tx)
        {
          $db->commit or die $db->error;
        }
      };

      if($@)
      {
        $self->error("Could not add $name - $@");
        $db->rollback  if($db && $started_new_tx);
        $meta->handle_error($self);
        return undef;
      }

      return 1;
    };
  }
  elsif($interface eq 'add_on_save')
  {
    unless($relationship)
    {
      Carp::confess "Cannot make 'add_on_save' method $name without relationship argument";
    }

    my $rel_name = $relationship->name;

    $methods{$name} = sub
    {
      my($self) = shift;

      unless(@_)
      {
        $self->error("No $name to add");
        return undef;
      }

      # Add all the new objects
      my $objects;

      if(@_ == 1 && ref $_[0] eq 'ARRAY') 
      {
        $objects = [ @{$_[0]} ];
      }
      else { $objects = [ @_ ] }

      # Add the objects to the list, if it's defined
      if(defined $self->{$key})
      {
        my $db = $self->db;

        # Set up column map
        my %map;

        my $ft_meta = $ft_class->meta 
          or Carp::croak "Missing metadata for foreign object class $ft_class";

        while(my($local_column, $foreign_column) = each(%$ft_columns))
        {
          my $local_method   = $meta->column_accessor_method_name($local_column);
          my $foreign_method = $ft_meta->column_accessor_method_name($foreign_column);

          $map{$foreign_method} = $self->$local_method();
        }

        # Map all the objects to the parent
        foreach my $object (@$objects)
        {
          $object->init(%map, ($share_db ? (db => $db) : ()));
        }

        # Add the objects
        push(@{$self->{$key}}, @$objects);
      }

      my $add_code = sub
      {
        # Set up column map
        my %map;

        my $ft_meta = $ft_class->meta 
          or Carp::croak "Missing metadata for foreign object class $ft_class";

        while(my($local_column, $foreign_column) = each(%$ft_columns))
        {
          my $local_method   = $meta->column_accessor_method_name($local_column);
          my $foreign_method = $ft_meta->column_accessor_method_name($foreign_column);

          $map{$foreign_method} = $self->$local_method();

          # Comment this out to allow null keys
          unless(defined $map{$foreign_method})
          {
            keys(%$ft_columns); # reset iterator
            die $self->error("Could not add objects via $name() - the " .
                             "$local_method attribute is undefined");
          }
        }

        my $db = $self->db;

        # Add all the objects.
        foreach my $object (@$objects)
        {
          # Map object to parent
          $object->init(%map, db => $db);

          # Save the object
          $object->save or die $object->error;
        }

        # Blank the attribute, causing the objects to be fetched from
        # the db next time, if there's a custom sort order
        $self->{$key} = undef  if(defined $mgr_args->{'sort_by'});

        return 1;
      };

      $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'add'} = $add_code;
      return 1;
    };
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

sub objects_by_map
{
  my($class, $name, $args, $options) = @_;

  my %methods;

  my $key = $args->{'hash_key'} || $name;
  my $interface = $args->{'interface'} || 'get_set';
  my $target_class = $options->{'target_class'} or die "Missing target class";

  my $relationship = $args->{'relationship'} or die "Missing relationship";
  my $rel_name     = $relationship->name;
  my $map_class    = $args->{'map_class'} or die "Missing map class";
  my $map_meta     = $map_class->meta or die "Missing meta for $map_class";
  my $map_from     = $args->{'map_from'};
  my $map_to       = $args->{'map_to'};
  my $map_manager  = $args->{'manager_class'};
  my $map_method   = $args->{'manager_method'} || 'get_objects';
  my $mgr_args     = $args->{'manager_args'} || {};
  my $query_args   = $args->{'query_args'} || [];

  my($map_to_class, $map_to_meta, $map_to_method);

  my $map_delete_method = $args->{'map_delete_method'} || 'delete_objects';

  if(@$query_args % 2 != 0)
  {
    Carp::croak "Odd number of arguments passed in query_args parameter";
  }

  unless($map_manager)
  {
    $map_manager = 'Rose::DB::Object::Manager';
    $mgr_args->{'object_class'} = $map_class;
  }

  my $meta     = $target_class->meta;
  my $share_db = $args->{'share_db'} || 1;

  # "map" is the map table, "self" is the $target_class, and "remote"
  # is the foreign object class
  my(%map_column_to_self_method,
     %map_column_to_self_column,
     %map_method_to_remote_method);

  # Also grab the foreign object class that the mapper points to,
  # the relationship name that points back to us, and the class 
  # name of the objects we really want to fetch.
  my($require_objects, $local_rel, $foreign_class, %seen_fk);

  foreach my $item ($map_meta->foreign_keys, $map_meta->relationships)
  {
    # Track which foreign keys we've seen
    if($item->isa('Rose::DB::Object::Metadata::ForeignKey'))
    {
      $seen_fk{$item->id}++;
    }
    elsif($item->isa('Rose::DB::Object::Metadata::Relationship'))
    {
      # Skip a relationship if we've already seen the equivalent foreign key
      next  if($seen_fk{$item->id});
    }

    if($item->class eq $target_class)
    {
      # Skip if there was an explicit local relationship name and
      # this is not that name.
      next  if($map_from && $item->name ne $map_from);

      if(%map_column_to_self_method)
      {
        Carp::croak "Map class $map_class has more than one foreign key ",
                    "and/or 'many to one' relationship that points to the ",
                    "class $target_class.  Please specify one by name ",
                    "with a 'local' parameter in the 'map' hash";
      }

      $map_from = $local_rel = $item->name;

      my $map_columns = 
        $item->can('column_map') ? $item->column_map : $item->key_columns;

      # "local" and "foreign" here are relative to the *mapper* class
      while(my($local_column, $foreign_column) = each(%$map_columns))
      {
        my $foreign_method = $meta->column_accessor_method_name($foreign_column)
          or Carp::croak "Missing accessor method for column '$foreign_column'", 
                         " in class ", $meta->class;
        $map_column_to_self_method{$local_column} = $foreign_method;
        $map_column_to_self_column{$local_column} = $foreign_column;
      }
    }
    elsif($item->isa('Rose::DB::Object::Metadata::ForeignKey') ||
          $item->type eq 'many to one')
    {
      # Skip if there was an explicit foreign relationship name and
      # this is not that name.
      next  if($map_to && $item->name ne $map_to);

      $map_to = $item->name;

      if($require_objects)
      {
        Carp::croak "Map class $map_class has more than one foreign key ",
                    "and/or 'many to one' relationship that points to a ",
                    "class other than $target_class.  Please specify one ",
                    "by name with a 'foreign' parameter in the 'map' hash";
      }

      $map_to_class = $item->class;
      $map_to_meta  = $map_to_class->meta;

      my $map_columns = 
        $item->can('column_map') ? $item->column_map : $item->key_columns;

      # "local" and "foreign" here are relative to the *mapper* class
      while(my($local_column, $foreign_column) = each(%$map_columns))
      {
        my $local_method = $map_meta->column_accessor_method_name($local_column)
          or Carp::croak "Missing accessor method for column '$local_column'", 
                         " in class ", $map_meta->class;

        my $foreign_method = $map_to_meta->column_accessor_method_name($foreign_column)
          or Carp::croak "Missing accessor method for column '$foreign_column'", 
                         " in class ", $map_to_class->class;

        # local           foreign
        # Map:color_id => Color:id
        $map_method_to_remote_method{$local_method} = $foreign_method;
      }

      $require_objects = [ $item->name ];
      $foreign_class = $item->class;
      $map_to_method = $item->method_name('get_set') || 
                       $item->method_name('get_set_now') ||
                       $item->method_name('get_set_on_save') ||
                       Carp::confess "No 'get_*' method found for ",
                                     $item->name;
    }
  }

  unless(%map_column_to_self_method)
  {
    Carp::croak "Could not find a foreign key or 'many to one' relationship ",
                "in $map_class that points to $target_class";
  }

  unless(%map_column_to_self_column)
  {
    Carp::croak "Could not find a foreign key or 'many to one' relationship ",
                "in $map_class that points to ", ($map_to_class || $map_to);
  }

  unless($require_objects)
  {
    # Make a second attempt to find a a suitable foreign relationship in the
    # map class, this time looking for links back to $target_class so long as
    # it's a different relationship than the one used in the local link.
    foreach my $item ($map_meta->foreign_keys, $map_meta->relationships)
    {
      # Skip a relationship if we've already seen the equivalent foreign key
      if($item->isa('Rose::DB::Object::Metadata::Relationship'))
      {
        next  if($seen_fk{$item->id});
      }

      if(($item->isa('Rose::DB::Object::Metadata::ForeignKey') ||
         $item->type eq 'many to one') &&
         $item->class eq $target_class && $item->name ne $local_rel)
      {  
        if($require_objects)
        {
          Carp::croak "Map class $map_class has more than two foreign keys ",
                      "and/or 'many to one' relationships that points to a ",
                      "$target_class.  Please specify which ones to use ",
                      "by including 'local' and 'foreign' parameters in the ",
                      "'map' hash";
        }

        $require_objects = [ $item->name ];
        $foreign_class = $item->class;
        $map_to_method = $item->method_name('get_set') ||
                         $item->method_name('get_set_now') ||
                         $item->method_name('get_set_on_save') ||
                         Carp::confess "No 'get_*' method found for ",
                                       $item->name;
      }
    }
  }

  unless($require_objects)
  {
    Carp::croak "Could not find a foreign key or 'many to one' relationship ",
                "in $map_class that points to a class other than $target_class"
  }

  # Populate relationship with the info we've extracted
  $relationship->column_map(\%map_column_to_self_column);
  $relationship->map_from($map_from);
  $relationship->map_to($map_to);
  $relationship->foreign_class($foreign_class);

  # Relationship names
  $map_to   ||= $require_objects->[0];
  $map_from ||= $local_rel;

  if($interface eq 'get_set' || $interface eq 'get_set_load')
  {
    $methods{$name} = sub
    {
      my($self) = shift;

      if(@_)
      {      
        return $self->{$key} = undef  if(@_ == 1 && !defined $_[0]);
        return $self->{$key} = (@_ == 1 && ref $_[0] eq 'ARRAY') ? $_[0] : [@_];
      }

      if(defined $self->{$key})
      {
        return wantarray ? @{$self->{$key}} : $self->{$key};  
      }

      my %join_map_to_self;

      while(my($map_column, $self_method) = each(%map_column_to_self_method))
      {
        $join_map_to_self{$map_column} = $self->$self_method();

        # Comment this out to allow null keys
        unless(defined $join_map_to_self{$map_column})
        {
          keys(%map_column_to_self_method); # reset iterator
          $self->error("Could not fetch indirect objects via $name() - the " .
                       "$self_method attribute is undefined");
          return wantarray ? () : undef;
        }
      }

      my $objs;

      if($share_db)
      {
        $objs =
          $map_manager->$map_method(query        => [ %join_map_to_self, @$query_args ],
                                    require_objects => $require_objects,
                                    %$mgr_args, db => $self->db);
      }
      else
      {
        $objs = 
          $map_manager->$map_method(query        => [ %join_map_to_self, @$query_args ],
                                    require_objects => $require_objects,
                                    %$mgr_args);
      }

      unless($objs)
      {
        $self->error("Could not load $foreign_class objects via map class ", 
                     "$map_class - " . $map_manager->error);
        return wantarray ? () : $objs;
      }

      $self->{$key} = [ map { $_->$map_to_method() } @$objs ];

      return wantarray ? @{$self->{$key}} : $self->{$key};
    };

    if($interface eq 'get_set_load')
    {
      my $method_name = $args->{'load_method'} || 'load_' . $name;

      $methods{$method_name} = sub
      {
        return (defined shift->$name(@_)) ? 1 : 0;
      };
    }
  }
  elsif($interface eq 'get_set_now')
  {
    $methods{$name} = sub
    {
      my($self) = shift;

      if(@_)
      {
        # If loading, just assign
        if($self->{STATE_LOADING()})
        {
          return $self->{$key} = undef  if(@_ == 1 && !defined $_[0]);
          return $self->{$key} = (@_ == 1 && ref $_[0] eq 'ARRAY') ? $_[0] : [@_];
        }

        # Can't set until the object is saved
        unless($self->{STATE_IN_DB()})
        {
          Carp::croak "Can't set $name() until this object is loaded or saved";
        }

        # Set to undef resets the attr  
        if(@_ == 1 && !defined $_[0])
        {
          # Delete any pending set or add actions
          delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'set'};
          delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'add'};

          $self->{$key} = undef;
          return;
        }

        # Set up join conditions and map record connections
        my(%join_map_to_self,    # map column => self value
           %method_map_to_self); # map method => self value

        while(my($map_column, $self_method) = each(%map_column_to_self_method))
        {
          my $map_method = $map_meta->column_accessor_method_name($map_column);

          $method_map_to_self{$map_method} = $join_map_to_self{$map_column} = 
            $self->$self_method();

          # Comment this out to allow null keys
          unless(defined $join_map_to_self{$map_column})
          {
            keys(%map_column_to_self_method); # reset iterator
            $self->error("Could not fetch indirect objects via $name() - the " .
                         "$self_method attribute is undefined");
            return wantarray ? () : undef;
          }
        }

        my($db, $started_new_tx);

        eval
        {
          $db = $self->db;

          my $ret = $db->begin_work;

          unless(defined $ret)
          {
            die 'Could not begin transaction during call to $name() - ',
                $db->error;
          }

          $started_new_tx = ($ret == IN_TRANSACTION) ? 0 : 1;

          # Delete any existing objects
          my $deleted = 
            $map_manager->$map_delete_method(object_class => $map_class,
                                             where => [ %join_map_to_self ],
                                             db    => $db);
          die $map_manager->error  unless(defined $deleted);

          # Save all the new objects
          my $objects;

          if(@_ == 1)
          {    
            if(ref $_[0] eq 'ARRAY') { $objects = $_[0]  }
            else                     { $objects = [ @_ ] }
          }
          else { $objects = [ @_ ] }

          foreach my $object (@$objects)
          {
            # It's essential to share the db so that the load()
            # below can see the delete (above) which happened in
            # the current transaction
            $object->db($db); 

            # Try to load the object if doesn't appear to exist already
            unless($object->{STATE_IN_DB()})
            {
              # It's okay if this fails (e.g., if the primary key is undefined)
              eval { $object->load(speculative => 1) };
            }

            # Save the object
            $object->save or die $object->error;

            # Not sharing?  Aw.
            $object->db(undef)  unless($share_db);

            # Create map record, connected to self
            my $map_record = $map_class->new(%method_map_to_self, db => $db);

            # Connect map record to remote object
            while(my($map_method, $remote_method) = each(%map_method_to_remote_method))
            {
              $map_record->$map_method($object->$remote_method);
            }

            # Save the map record
            $map_record->save or die $map_record->error;
          }

          # Assign to attribute or blank the attribute, causing the objects
          # to be fetched from the db next time, depending on whether or not
          # there's a custom sort order
          $self->{$key} = defined $mgr_args->{'sort_by'} ? undef : $objects;

          if($started_new_tx)
          {
            $db->commit or die $db->error;
          }

          # Delete any pending set or add actions
          delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'set'};
          delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'add'};
        };

        if($@)
        {
          $self->error("Could not set $name objects - $@");
          $db->rollback  if($db && $started_new_tx);
          $meta->handle_error($self);
          return undef;
        }

        return 1  unless(defined $self->{$key});
        return wantarray ? @{$self->{$key}} : $self->{$key};
      }

      # Return existing list of objects, if it exists
      if(defined $self->{$key})
      {
        return wantarray ? @{$self->{$key}} : $self->{$key};  
      }

      my %join_map_to_self;

      while(my($local_column, $foreign_method) = each(%map_column_to_self_method))
      {
        $join_map_to_self{$local_column} = $self->$foreign_method();

        # Comment this out to allow null keys
        unless(defined $join_map_to_self{$local_column})
        {
          keys(%map_column_to_self_method); # reset iterator
          $self->error("Could not fetch indirect objects via $name() - the " .
                       "$foreign_method attribute is undefined");
          return wantarray ? () : undef;
        }
      }

      my $objs;

      if($share_db)
      {
        $objs =
          $map_manager->$map_method(query        => [ %join_map_to_self, @$query_args ],
                                    require_objects => $require_objects,
                                    %$mgr_args, db => $self->db);
      }
      else
      {
        $objs = 
          $map_manager->$map_method(query        => [ %join_map_to_self, @$query_args ],
                                    require_objects => $require_objects,
                                    %$mgr_args);
      }

      unless($objs)
      {
        $self->error("Could not load $foreign_class objects via map class ", 
                     "$map_class - " . $map_manager->error);
        return wantarray ? () : $objs;
      }

      $self->{$key} = [ map { $_->$map_to_method() } @$objs ];

      return wantarray ? @{$self->{$key}} : $self->{$key};
    };
  }
  elsif($interface eq 'get_set_on_save')
  {
    $methods{$name} = sub
    {
      my($self) = shift;

      if(@_)
      {
        # If loading, just assign
        if($self->{STATE_LOADING()})
        {
          return $self->{$key} = undef  if(@_ == 1 && !defined $_[0]);
          return $self->{$key} = (@_ == 1 && ref $_[0] eq 'ARRAY') ? $_[0] : [@_];
        }

        my $objects;

        if(@_ == 1)
        {
          # Set to undef resets the attr  
          unless(defined $_[0])
          {
            # Delete any pending set or add actions
            delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'set'};
            delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'add'};

            $self->{$key} = undef;
            return;
          }

          if(ref $_[0] eq 'ARRAY') { $objects = $_[0]  }
          else                     { $objects = [ @_ ] }
        }
        else { $objects = [ @_ ] }

        # Set the attribute
        $self->{$key} = $objects;

        my $save_code = sub
        {
          # Set up join conditions and map record connections
          my(%join_map_to_self,    # map column => self value
             %method_map_to_self); # map method => self value

          while(my($map_column, $self_method) = each(%map_column_to_self_method))
          {
            my $map_method = $map_meta->column_accessor_method_name($map_column);

            $method_map_to_self{$map_method} = $join_map_to_self{$map_column} = 
              $self->$self_method();

            # Comment this out to allow null keys
            unless(defined $join_map_to_self{$map_column})
            {
              keys(%map_column_to_self_method); # reset iterator
              $self->error("Could not fetch indirect objects via $name() - the " .
                           "$self_method attribute is undefined");
              return wantarray ? () : undef;
            }
          }

          my $db = $self->db;

          # Delete any existing objects
          my $deleted = 
            $map_manager->$map_delete_method(object_class => $map_class,
                                             where => [ %join_map_to_self ],
                                             db    => $db);
          die $map_manager->error  unless(defined $deleted);

          # Save all the objects.  Use the current list, even if it's
          # different than it was when the "set on save" was called.
          foreach my $object (@{$self->{$key} || []})
          {
            # It's essential to share the db so that the load()
            # below can see the delete (above) which happened in
            # the current transaction
            $object->db($db); 

            # Try to load the object if doesn't appear to exist already
            unless($object->{STATE_IN_DB()})
            {
              # It's okay if this fails (e.g., if the primary key is undefined)
              eval { $object->load(speculative => 1) };
            }

            # Save the object
            $object->save or die $object->error;

            # Not sharing?  Aw.
            $object->db(undef)  unless($share_db);

            # Create map record, connected to self
            my $map_record = $map_class->new(%method_map_to_self, db => $db);

            # Connect map record to remote object
            while(my($map_method, $remote_method) = each(%map_method_to_remote_method))
            {
              $map_record->$map_method($object->$remote_method);
            }

            # Save the map record
            $map_record->save or die $map_record->error;
          }

          # Forget about any adds if we just set the list
          if(defined $self->{$key})
          {
            # Set to undef instead of deleting because this code ref
            # will be called while iterating over this very hash.
            $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'add'} = undef;
          }

          # Blank the attribute, causing the objects to be fetched from
          # the db next time, if there's a custom sort order
          $self->{$key} = undef  if(defined $mgr_args->{'sort_by'});

          return 1;
        };

        $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'set'} = $save_code;

        return 1  unless(defined $self->{$key});
        return wantarray ? @{$self->{$key}} : $self->{$key};
      }

      # Return existing list of objects, if it exists
      if(defined $self->{$key})
      {
        return wantarray ? @{$self->{$key}} : $self->{$key};  
      }

      my %join_map_to_self;

      while(my($local_column, $foreign_method) = each(%map_column_to_self_method))
      {
        $join_map_to_self{$local_column} = $self->$foreign_method();

        # Comment this out to allow null keys
        unless(defined $join_map_to_self{$local_column})
        {
          keys(%map_column_to_self_method); # reset iterator
          $self->error("Could not fetch indirect objects via $name() - the " .
                       "$foreign_method attribute is undefined");
          return wantarray ? () : undef;
        }
      }

      my $objs;

      if($share_db)
      {
        $objs =
          $map_manager->$map_method(query        => [ %join_map_to_self, @$query_args ],
                                    require_objects => $require_objects,
                                    %$mgr_args, db => $self->db);
      }
      else
      {
        $objs = 
          $map_manager->$map_method(query        => [ %join_map_to_self, @$query_args ],
                                    require_objects => $require_objects,
                                    %$mgr_args);
      }

      unless($objs)
      {
        $self->error("Could not load $foreign_class objects via map class ", 
                     "$map_class - " . $map_manager->error);
        return wantarray ? () : $objs;
      }

      $self->{$key} = [ map { $_->$map_to_method() } @$objs ];

      return wantarray ? @{$self->{$key}} : $self->{$key};
    };
  }
  elsif($interface eq 'add_now')
  {
    $methods{$name} = sub
    {
      my($self) = shift;

      unless(@_)
      {
        $self->error("No $name to add");
        return;
      }

      # Can't set until the object is saved
      unless($self->{STATE_IN_DB()})
      {
        Carp::croak "Can't add $name until this object is loaded or saved";
      }

      if($self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'set'})
      {
        Carp::croak "Cannot add objects via the 'add_now' method $name() ",
                    "because the list of objects is already going to be ".
                    "set to something else on save.  Use the 'add_on_save' ",
                    "method type instead.";
      }

      # Set up join conditions and map record connections
      my(%join_map_to_self,    # map column => self value
         %method_map_to_self); # map method => self value

      while(my($map_column, $self_method) = each(%map_column_to_self_method))
      {
        my $map_method = $map_meta->column_accessor_method_name($map_column);

        $method_map_to_self{$map_method} = $join_map_to_self{$map_column} = 
          $self->$self_method();

        # Comment this out to allow null keys
        unless(defined $join_map_to_self{$map_column})
        {
          keys(%map_column_to_self_method); # reset iterator
          $self->error("Could not fetch indirect objects via $name() - the " .
                       "$self_method attribute is undefined");
          return wantarray ? () : undef;
        }
      }

      my $objects;

      if(@_ == 1 && ref $_[0] eq 'ARRAY') 
      {
        $objects = $_[0];
      }
      else { $objects = [ @_ ] }

      my($db, $started_new_tx);

      eval
      {
        $db = $self->db;

        my $ret = $db->begin_work;

        unless(defined $ret)
        {
          die 'Could not begin transaction during call to $name() - ',
              $db->error;
        }

        $started_new_tx = ($ret == IN_TRANSACTION) ? 0 : 1;

        # Add all the new objects
        foreach my $object (@$objects)
        {
          # It's essential to share the db so that the load()
          # below can see the delete (above) which happened in
          # the current transaction
          $object->db($db); 

          # Try to load the object if doesn't appear to exist already
          unless($object->{STATE_IN_DB()})
          {
            # It's okay if this fails (e.g., if the primary key is undefined)
            eval { $object->load(speculative => 1) };
          }

          # Save the object
          $object->save or die $object->error;

          # Not sharing?  Aw.
          $object->db(undef)  unless($share_db);

          # Create map record, connected to self
          my $map_record = $map_class->new(%method_map_to_self, db => $db);

          # Connect map record to remote object
          while(my($map_method, $remote_method) = each(%map_method_to_remote_method))
          {
            $map_record->$map_method($object->$remote_method);
          }

          # Save the map record
          $map_record->save or die $map_record->error;
        }

        # Clear the existing list, forcing it to be reloaded next time
        # it's asked for
        $self->{$key} = undef;

        if($started_new_tx)
        {
          $db->commit or die $db->error;
        }

        # Delete any pending set or add actions
        delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'set'};
        delete $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'add'};
      };

      if($@)
      {
        $self->error("Could not add $name objects - $@");
        $db->rollback  if($db && $started_new_tx);
        $meta->handle_error($self);
        return undef;
      }

      return 1;
    };
  }
  elsif($interface eq 'add_on_save')
  {
    $methods{$name} = sub
    {
      my($self) = shift;

      unless(@_)
      {
        $self->error("No $name to add");
        return undef;
      }

      my $objects;

      # Add all the new objects
      if(@_ == 1 && ref $_[0] eq 'ARRAY') 
      {
        $objects = [ @{$_[0]} ];
      }
      else { $objects = [ @_ ] }

      # Add the objects to the list, if it's defined
      if(defined $self->{$key})
      {
        push(@{$self->{$key}}, @$objects);
      }

      my $add_code = sub
      {
        # Set up join conditions and map record connections
        my(%join_map_to_self,    # map column => self value
           %method_map_to_self); # map method => self value

        while(my($map_column, $self_method) = each(%map_column_to_self_method))
        {
          my $map_method = $map_meta->column_accessor_method_name($map_column);

          $method_map_to_self{$map_method} = $join_map_to_self{$map_column} = 
            $self->$self_method();

          # Comment this out to allow null keys
          unless(defined $join_map_to_self{$map_column})
          {
            keys(%map_column_to_self_method); # reset iterator
            $self->error("Could not fetch indirect objects via $name() - the " .
                         "$self_method attribute is undefined");
            return wantarray ? () : undef;
          }
        }

        my $db = $self->db;

        # Add all the objects.
        foreach my $object (@$objects)
        {
          # It's essential to share the db so that the load()
          # below can see the delete (above) which happened in
          # the current transaction
          $object->db($db); 

          # Try to load the object if doesn't appear to exist already
          unless($object->{STATE_IN_DB()})
          {
            # It's okay if this fails (e.g., if the primary key is undefined)
            eval { $object->load(speculative => 1) };
          }

          # Save the object
          $object->save or die $object->error;

          # Not sharing?  Aw.
          $object->db(undef)  unless($share_db);

          # Create map record, connected to self
          my $map_record = $map_class->new(%method_map_to_self, db => $db);

          # Connect map record to remote object
          while(my($map_method, $remote_method) = each(%map_method_to_remote_method))
          {
            $map_record->$map_method($object->$remote_method);
          }

          # Save the map record
          $map_record->save or die $map_record->error;
        }

        # Blank the attribute, causing the objects to be fetched from
        # the db next time, if there's a custom sort order
        $self->{$key} = undef  if(defined $mgr_args->{'sort_by'});

        return 1;
      };

      $self->{ON_SAVE_ATTR_NAME()}{'post'}{'rel'}{$rel_name}{'add'} = $add_code;
      return 1;
    };
  }
  else { Carp::croak "Unknown interface: $interface" }

  return \%methods;
}

1;

__END__

=head1 NAME

Rose::DB::Object::MakeMethods::Generic - Create generic object methods for Rose::DB::Object-derived objects.

=head1 SYNOPSIS

  package MyDBObject;

  our @ISA = qw(Rose::DB::Object);

  use Rose::DB::Object::MakeMethods::Generic
  (
    scalar => 
    [
      'type' => 
      {
        with_init => 1,
        check_in  => [ qw(AA AAA C D) ],
      },

      'set_type' => { hash_key => 'type' },
    ],

    character =>
    [
      code => { length => 6 }
    ],

    varchar =>
    [
      name => { length => 10 }
    ],

    boolean => 
    [
      'is_red',
      'is_happy' => { default => 1 },
    ],
  );

  sub init_type { 'C' }
  ...

  $o = MyDBObject->new(...);

  print $o->type; # C

  $o->name('Bob');   # set
  $o->set_type('C'); # set
  $o->type('AA');    # set

  $o->set_type; # Fatal error: no argument passed to "set" method

  $o->name('C' x 40); # truncate on set
  print $o->name;     # 'CCCCCCCCCC'

  $o->code('ABC'); # pad on set
  print $o->code;  # 'ABC   '

  eval { $o->type('foo') }; # fatal error: invalid value

  print $o->name, ' is ', $o->type; # get

  $obj->is_red;         # returns undef
  $obj->is_red('true'); # returns 1 (assuming "true" a
                        # valid boolean literal according to
                        # $obj->db->parse_boolean('true'))
  $obj->is_red('');     # returns 0
  $obj->is_red;         # returns 0

  $obj->is_happy;       # returns 1

  ...

  package Person;

  our @ISA = qw(Rose::DB::Object);
  ...
  use Rose::DB::Object::MakeMethods::Generic
  (
    scalar => 'name',

    set => 
    [
      'nicknames',
      'parts' => { default => [ qw(arms legs) ] },
    ],

    # See the Rose::DB::Object::Metadata::Relationship::ManyToMany
    # documentation for a more complete example
    objects_by_map =>
    [
      friends =>
      {
        map_class    => 'FriendMap',
        manager_args => { sort_by => Friend->meta->table . '.name' },
      },
    ],
  );
  ...

  @parts = $person->parts; # ('arms', 'legs')
  $parts = $person->parts; # [ 'arms', 'legs' ]

  $person->nicknames('Jack', 'Gimpy');   # set with list
  $person->nicknames([ 'Slim', 'Gip' ]); # set with array ref

  print join(', ', map { $_->name } $person->friends);
  ...

  package Program;

  our @ISA = qw(Rose::DB::Object);
  ...
  use Rose::DB::Object::MakeMethods::Generic
  (
    objects_by_key =>
    [
      bugs => 
      {
        class => 'Bug',
        key_columns =>
        {
          # Map Program column names to Bug column names
          id      => 'program_id',
          version => 'version',
        },
        manager_args => 
        {
          sort_by => Bug->meta->table . '.date_submitted DESC',
        },
        query_args   => [ state => { ne => 'closed' } ],
      },
    ]
  );
  ...

  $prog = Program->new(id => 5, version => '3.0', ...);

  $bugs = $prog->bugs;

  # Calls (essentially):
  #
  # Rose::DB::Object::Manager->get_objects(
  #   db           => $prog->db, # share_db defaults to true
  #   object_class => 'Bug',
  #   query =>
  #   {
  #     program_id => 5,     # value of $prog->id
  #     version    => '3.0', # value of $prog->version
  #     state      => { ne => 'closed' },
  #   },
  #   sort_by => 'date_submitted DESC');

  ...

  package Product;

  our @ISA = qw(Rose::DB::Object);
  ...
  use Rose::DB::Object::MakeMethods::Generic
  (
    object_by_key =>
    [
      category => 
      {
        class => 'Category',
        key_columns =>
        {
          # Map Product column names to Category column names
          category_id => 'id',
        },
      },
    ]
  );
  ...

  $product = Product->new(id => 5, category_id => 99);

  $category = $product->category;

  # $product->category call is roughly equivalent to:
  #
  # $cat = Category->new(id => $product->category_id,
  #                      db => $prog->db);
  #
  # $ret = $cat->load;
  # return $ret  unless($ret);
  # return $cat;

=head1 DESCRIPTION

L<Rose::DB::Object::MakeMethods::Generic> is a method maker that inherits
from L<Rose::Object::MakeMethods>.  See the L<Rose::Object::MakeMethods>
documentation to learn about the interface.  The method types provided
by this module are described below.

All method types defined by this module are designed to work with objects that are subclasses of (or otherwise conform to the interface of) L<Rose::DB::Object>.  In particular, the object is expected to have a L<db|Rose::DB::Object/db> method that returns a L<Rose::DB>-derived object.  See the L<Rose::DB::Object> documentation for more details.

=head1 METHODS TYPES

=over 4

=item B<array>

Create get/set methods for "array" attributes.   A "array" column in a database table contains an ordered list of values.  Not all databases support an "array" column type.  Check the L<Rose::DB|Rose::DB/"DATABASE SUPPORT"> documentation for your database type.

=over 4

=item Options

=over 4

=item C<default>

Determines the default value of the attribute.  The value should be a reference to an array.

=item C<hash_key>

The key inside the hash-based object to use for the storage of this
attribute.  Defaults to the name of the method.

=item C<interface>

Choose the interface.  The default is C<get_set>.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a get/set method for a "array" object attribute.  A "array" column in a database table contains an ordered list of values.

When setting the attribute, the value is passed through the L<parse_array|Rose::DB::Pg/parse_array> method of the object's L<db|Rose::DB::Object/db> attribute.

When saving to the database, if the attribute value is defined, the method will pass the attribute value through the L<format_array|Rose::DB::Pg/format_array> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.

When not saving to the database, the method returns the array as a list in list context, or as a reference to the array in scalar context.

=item C<get>

Creates an accessor method for a "array" object attribute.  A "array" column in a database table contains an ordered list of values.

When saving to the database, if the attribute value is defined, the method will pass the attribute value through the L<format_array|Rose::DB::Pg/format_array> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.

When not saving to the database, the method returns the array as a list in list context, or as a reference to the array in scalar context.

=item C<set>

Creates a mutator method for a "array" object attribute.  A "array" column in a database table contains an ordered list of values.

When setting the attribute, the value is passed through the L<parse_array|Rose::DB::Pg/parse_array> method of the object's L<db|Rose::DB::Object/db> attribute.

When saving to the database, if the attribute value is defined, the method will pass the attribute value through the L<format_array|Rose::DB::Pg/format_array> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.

When not saving to the database, the method returns the array as a list in list context, or as a reference to the array in scalar context.

If called with no arguments, a fatal error will occur.

=back

=back

Example:

    package Person;

    our @ISA = qw(Rose::DB::Object);
    ...
    use Rose::DB::Object::MakeMethods::Generic
    (
      array => 
      [
        'nicknames',
        'set_nicks' => { interface => 'set', hash_key => 'nicknames' },

        'parts' => { default => [ qw(arms legs) ] },

      ],
    );
    ...

    @parts = $person->parts; # ('arms', 'legs')
    $parts = $person->parts; # [ 'arms', 'legs' ]

    $person->nicknames('Jack', 'Gimpy');   # set with list
    $person->nicknames([ 'Slim', 'Gip' ]); # set with array ref

    $person->set_nicks('Jack', 'Gimpy');   # set with list
    $person->set_nicks([ 'Slim', 'Gip' ]); # set with array ref

=item B<bitfield>

Create get/set methods for bitfield attributes.

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

=item C<intersects>

Set the name of the "intersects" method.  (See C<with_intersects> below.)  Defaults to the bitfield attribute method name with "_intersects" appended.

=item C<bits>

The number of bits in the bitfield.  Defaults to 32.

=item C<with_intersects>

This option is only applicable with the C<get_set> interface.

If true, create an "intersects" helper method in addition to the C<get_set> method.  The intersection method name will be the attribute method name with "_intersects" appended, or the value of the C<intersects> option, if it is passed.

The "intersects" method will return true if there is any intersection between its arguments and the value of the bitfield attribute (i.e., if L<Bit::Vector>'s L<Intersection|Bit::Vector/Intersection> method returns a value greater than zero), false (but defined) otherwise.  Its argument is passed through the L<parse_bitfield|Rose::DB/parse_bitfield> method of the object's L<db|Rose::DB::Object/db> attribute before being tested for intersection.  Returns undef if the bitfield is not defined.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a get/set method for a bitfield attribute.  When setting the attribute, the value is passed through the L<parse_bitfield|Rose::DB/parse_bitfield> method of the object's L<db|Rose::DB::Object/db> attribute before being assigned.

When saving to the database, the method will pass the attribute value through the L<format_bitfield|Rose::DB/format_bitfield> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.  Otherwise, the value is returned as-is.

=item C<get>

Creates an accessor method for a bitfield attribute.  When saving to the database, the method will pass the attribute value through the L<format_bitfield|Rose::DB/format_bitfield> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.  Otherwise, the value is returned as-is.

=item C<set>

Creates a mutator method for a bitfield attribute.  When setting the attribute, the value is passed through the L<parse_bitfield|Rose::DB/parse_bitfield> method of the object's L<db|Rose::DB::Object/db> attribute before being assigned.

When saving to the database, the method will pass the attribute value through the L<format_bitfield|Rose::DB/format_bitfield> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.  Otherwise, the value is returned as-is.

If called with no arguments, a fatal error will occur.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Generic
    (
      bitfield => 
      [
        'flags' => { size => 32, default => 2 },
        'bits'  => { size => 16, with_intersects => 1 },
      ],
    );

    ...

    print $o->flags->to_Bin; # 00000000000000000000000000000010

    $o->bits('101');

    $o->bits_intersects('100'); # true
    $o->bits_intersects('010'); # false

=item B<boolean>

Create get/set methods for boolean attributes.

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

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a get/set method for a boolean attribute.  When setting the attribute, if the value is "true" according to Perl's rules, it is compared to a list of "common" true and false values: 1, 0, 1.0 (with any number of zeros), 0.0 (with any number of zeros), t, true, f, false, yes, no.  (All are case-insensitive.)  If the value matches, then it is set to true (1) or false (0) accordingly.

If the value does not match any of those, then it is passed through the L<parse_boolean|Rose::DB/parse_boolean> method of the object's L<db|Rose::DB::Object/db> attribute.  If L<parse_boolean|Rose::DB/parse_boolean> returns true (1) or false (0), then the attribute is set accordingly.  If L<parse_boolean|Rose::DB/parse_boolean> returns undef, a fatal error will occur.  If the value is "false" according to Perl's rules, the attribute is set to zero (0).

When saving to the database, the method will pass the attribute value through the L<format_boolean|Rose::DB/format_boolean> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.  Otherwise, the value is returned as-is.

=item C<get>

Creates an accessor method for a boolean attribute.  When saving to the database, the method will pass the attribute value through the L<format_boolean|Rose::DB/format_boolean> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.  Otherwise, the value is returned as-is.

=item C<set>

Creates a mutator method for a boolean attribute.  When setting the attribute, if the value is "true" according to Perl's rules, it is compared to a list of "common" true and false values: 1, 0, 1.0 (with any number of zeros), 0.0 (with any number of zeros), t, true, f, false, yes, no.  (All are case-insensitive.)  If the value matches, then it is set to true (1) or false (0) accordingly.

If the value does not match any of those, then it is passed through the L<parse_boolean|Rose::DB/parse_boolean> method of the object's L<db|Rose::DB::Object/db> attribute.  If L<parse_boolean|Rose::DB/parse_boolean> returns true (1) or false (0), then the attribute is set accordingly.  If L<parse_boolean|Rose::DB/parse_boolean> returns undef, a fatal error will occur.  If the value is "false" according to Perl's rules, the attribute is set to zero (0).

If called with no arguments, a fatal error will occur.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Generic
    (
      boolean => 
      [
        'is_red',
        'is_happy'  => { default => 1 },
        'set_happy' => { interface => 'set', hash_key => 'is_happy' },
      ],
    );

    $obj->is_red;         # returns undef
    $obj->is_red('true'); # returns 1 (assuming "true" a
                          # valid boolean literal according to
                          # $obj->db->parse_boolean('true'))
    $obj->is_red('');     # returns 0
    $obj->is_red;         # returns 0

    $obj->is_happy;       # returns 1
    $obj->set_happy(0);   # returns 0
    $obj->is_happy;       # returns 0

=item B<character>

Create get/set methods for fixed-length character string attributes.

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

=item C<length>

The number of characters in the string.  Any strings longer than this will be truncated, and any strings shorter will be padded with spaces to meet the length requirement.  If length is omitted, the string will be left unmodified.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a get/set method for a fixed-length character string attribute.  When setting, any strings longer than C<length> will be truncated, and any strings shorter will be padded with spaces to meet the length requirement.  If C<length> is omitted, the string will be left unmodified.

=item C<get>

Creates an accessor method for a fixed-length character string attribute.

=item C<set>

Creates a mutator method for a fixed-length character string attribute.  Any strings longer than C<length> will be truncated, and any strings shorter will be padded with spaces to meet the length requirement.  If C<length> is omitted, the string will be left unmodified.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Generic
    (
      character => 
      [
        'name' => { length => 3 },
      ],
    );

    ...

    $o->name('John'); # truncates on set
    print $o->name;   # 'Joh'

    $o->name('A'); # pads on set
    print $o->name;   # 'A  '

=item B<objects_by_key>

Create get/set methods for an array of L<Rose::DB::Object>-derived objects fetched based on a key formed from attributes of the current object.

=over 4

=item Options

=over 4

=item C<class>

The name of the L<Rose::DB::Object>-derived class of the objects to be fetched.  This option is required.

=item C<hash_key>

The key inside the hash-based object to use for the storage of the fetched objects.  Defaults to the name of the method.

=item C<key_columns>

A reference to a hash that maps column names in the current object to those in the objects to be fetched.  This option is required.

=item C<manager_args>

A reference to a hash of arguments passed to the C<manager_class> when fetching objects.  If C<manager_class> defaults to L<Rose::DB::Object::Manager>, the following argument is added to the C<manager_args> hash: C<object_class =E<gt> CLASS>, where CLASS is the value of the C<class> option (see above).  If C<manager_args> includes a "sort_by" argument, be sure to prefix each column name with the appropriate table name.  (See the L<synopsis|/SYNOPSIS> for examples.)

=item C<manager_class>

The name of the L<Rose::DB::Object::Manager>-derived class used to fetch the objects.  The C<manager_method> class method is called on this class.  Defaults to L<Rose::DB::Object::Manager>.

=item C<manager_method>

The name of the class method to call on C<manager_class> in order to fetch the objects.  Defaults to C<get_objects>.

=item C<interface>

Choose the interface.  The only current interface is C<get_set>, which is the default.

=item C<relationship>

The L<Rose::DB::Object::Metadata::Relationship> object that describes the "key" through which the "objects_by_key" are fetched.  This is required when using the "add_now", "add_on_save", and "get_set_on_save" interfaces.

=item C<share_db>

If true, the L<db|Rose::DB::Object/db> attribute of the current object is shared with all of the objects fetched.  Defaults to true.

=item C<query_args>

A reference to an array of arguments added to the value of the C<query> parameter passed to the call to C<manager_class>'s C<manager_method> class method.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a method that will attempt to fetch L<Rose::DB::Object>-derived objects based on a key formed from attributes of the current object.

If passed a single argument of undef, the list of objects is set to undef.  If passed a reference to an array, the list of objects is set to point to that same array.  (Note that these objects are B<not> added to the database.  Use the C<get_set_now> or C<get_set_on_save> interface to do that.)

If called with no arguments and the hash key used to store the list of objects is defined, the list (in list context) or a reference to that array (in scalar context) of objects is returned.  Otherwise, the objects are fetched.

The fetch may fail for several reasons.  The fetch will not even be attempted if any of the key attributes in the current object are undefined.  Instead, undef (in scalar context) or an empty list (in list context) will be returned.  If the call to C<manager_class>'s C<manager_method> method returns false, that false value (in scalar context) or an empty list (in list context) is returned.

If the fetch succeeds, a list (in list context) or a reference to the array of objects (in scalar context) is returned.  (If the fetch finds zero objects, the list or array reference will simply be empty.  This is still considered success.)

=item C<get_set_now>

Creates a method that will attempt to fetch L<Rose::DB::Object>-derived objects based on a key formed from attributes of the current object, and will also save the objects to the database when called with arguments.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed a single argument of undef, the list of objects is set to undef, causing it to be reloaded the next time the method is called with no arguments.  (Pass a reference to an empty array to cause all of the existing objects to be deleted from the database.)  Any pending C<set_on_save> or C<add_on_save> actions are discarded.

If passed a list or reference to an array of the appropriate L<Rose::DB::Object>-derived objects, the list of objects is copied from (in the case of a list) or set to point to (in the case of a reference to an array) the argument(s), the old objects are deleted from the database, and the new ones are added to the database.  Any pending C<set_on_save> or C<add_on_save> actions are discarded.

The parent object must have been L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>ed prior to setting the list of objects.  If this method is called with arguments before the object has been  L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>ed, a fatal error will occur.

If called with no arguments and the hash key used to store the list of objects is defined, the list (in list context) or a reference to that array (in scalar context) of objects is returned.  Otherwise, the objects are fetched.

The fetch may fail for several reasons.  The fetch will not even be attempted if any of the key attributes in the current object are undefined.  Instead, undef (in scalar context) or an empty list (in list context) will be returned.  If the call to C<manager_class>'s C<manager_method> method returns false, that false value (in scalar context) or an empty list (in list context) is returned.

If the fetch succeeds, a list (in list context) or a reference to the array of objects (in scalar context) is returned.  (If the fetch finds zero objects, the list or array reference will simply be empty.  This is still considered success.)

=item C<get_set_on_save>

Creates a method that will attempt to fetch L<Rose::DB::Object>-derived objects based on a key formed from attributes of the current object, and will also save the objects to the database when the "parent" object is L<save|Rose::DB::Object/save>ed.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed a single argument of undef, the list of objects is set to undef, causing it to be reloaded the next time the method is called with no arguments.  (Pass a reference to an empty array to cause all of the existing objects to be deleted from the database when the parent is L<save|Rose::DB::Object/save>ed.)

If passed a list or reference to an array of the appropriate L<Rose::DB::Object>-derived objects, the list of objects is copied from (in the case of a list) or set to point to (in the case of a reference to an array) the argument(s).  The old objects are scheduled to be deleted from the database and the new ones are scheduled to be added to the database when the parent is L<save|Rose::DB::Object/save>ed.  Any previously pending C<set_on_save> or C<add_on_save> actions are discarded.

If called with no arguments and the hash key used to store the list of objects is defined, the list (in list context) or a reference to that array (in scalar context) of objects is returned.  Otherwise, the objects are fetched.

The fetch may fail for several reasons.  The fetch will not even be attempted if any of the key attributes in the current object are undefined.  Instead, undef (in scalar context) or an empty list (in list context) will be returned.  If the call to C<manager_class>'s C<manager_method> method returns false, that false value (in scalar context) or an empty list (in list context) is returned.

If the fetch succeeds, a list (in list context) or a reference to the array of objects (in scalar context) is returned.  (If the fetch finds zero objects, the list or array reference will simply be empty.  This is still considered success.)

=item C<add_now>

Creates a method that will add to a list of L<Rose::DB::Object>-derived objects that are related to the current object by a key formed from attributes of the current object.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed an empty list, the method does nothing and the parent object's L<error|Rose::DB::Object/error> attribute is set.

The parent object must have been L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>ed prior to adding to the list of objects.  If this method is called with a non-empty list as an argument before the parent object has been  L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>ed, a fatal error will occur.

If passed a list or reference to an array of the appropriate kind of L<Rose::DB::Object>-derived objects, these objects are linked to the parent object (by setting the appropriate key attributes) and then added to the database.  The parent object's list of related objects is then set to undef, causing the related objects to be reloaded from the database the next time they're needed.

=item C<add_on_save>

Creates a method that will add to a list of L<Rose::DB::Object>-derived objects that are related to the current object by a key formed from attributes of the current object.  The objects will be added to the database when the parent object is L<save|Rose::DB::Object/save>ed.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed an empty list, the method does nothing and the parent object's L<error|Rose::DB::Object/error> attribute is set.

If passed a list or reference to an array of the appropriate kind of L<Rose::DB::Object>-derived objects, these objects are linked to the parent object (by setting the appropriate key attributes, whether or not they're defined in the parent object) and are scheduled to be added to the database when the parent object is L<save|Rose::DB::Object/save>ed.  They are also added to the parent object's current list of related objects, if the list is defined at the time of the call.

=back

=back

Example setup:

    # CLASS     DB TABLE
    # -------   --------
    # Program   programs
    # Bug       bugs

    package Program;

    our @ISA = qw(Rose::DB::Object);
    ...
    # You will almost never call the method-maker directly
    # like this.  See the Rose::DB::Object::Metadata docs
    # for examples of more common usage.
    use Rose::DB::Object::MakeMethods::Generic
    (
      objects_by_key =>
      [
        bugs => 
        {
          interface => '...', # get_set, get_set_now, or get_set_on_save
          class     => 'Bug',
          key_columns =>
          {
            # Map Program column names to Bug column names
            id      => 'program_id',
            version => 'version',
          },
          manager_args => { sort_by => 'date_submitted DESC' },
          query_args   => { state => { ne => 'closed' } },
        },

        add_bugs => 
        {
          interface => '...', # add_now or add_on_save
          class     => 'Bug',
          key_columns =>
          {
            # Map Program column names to Bug column names
            id      => 'program_id',
            version => 'version',
          },
          manager_args => { sort_by => 'date_submitted DESC' },
          query_args   => { state => { ne => 'closed' } },
        },
      ]
    );
    ...

Example - get_set interface:

    # Read from the programs table
    $prog = Program->new(id => 5)->load;

    # Read from the bugs table
    $bugs = $prog->bugs;

    # Calls (essentially):
    #
    # Rose::DB::Object::Manager->get_objects(
    #   db           => $prog->db, # share_db defaults to true
    #   object_class => 'Bug',
    #   query =>
    #   {
    #     program_id => 5,     # value of $prog->id
    #     version    => '3.0', # value of $prog->version
    #     state      => { ne => 'closed' },
    #   },
    #   sort_by => 'date_submitted DESC');
    ...
    $prog->version($new_version); # Does not hit the db
    $prog->bugs(@new_bugs);       # Does not hit the db

    # Write to the programs table only.  The bugs table is not
    # updates. See the get_set_now and get_set_on_save method
    # types for ways to write to the bugs table.
    $prog->save;

Example - get_set_now interface:

    # Read from the programs table
    $prog = Program->new(id => 5)->load;

    # Read from the bugs table
    $bugs = $prog->bugs;

    $prog->name($new_name); # Does not hit the db

    # Writes to the bugs table, deleting existing bugs and
    # replacing them with @new_bugs (which must be an array
    # of Bug objects, either existing or new)
    $prog->bugs(@new_bugs); 

    # Write to the programs table
    $prog->save;

Example - get_set_on_save interface:

    # Read from the programs table
    $prog = Program->new(id => 5)->load;

    # Read from the bugs table
    $bugs = $prog->bugs;

    $prog->name($new_name); # Does not hit the db
    $prog->bugs(@new_bugs); # Does not hit the db

    # Write to the programs table and the bugs table, deleting any
    # existing bugs and replacing them with @new_bugs (which must be
    # an array of Bug objects, either existing or new)
    $prog->save;

Example - add_now interface:

    # Read from the programs table
    $prog = Program->new(id => 5)->load;

    # Read from the bugs table
    $bugs = $prog->bugs;

    $prog->name($new_name); # Does not hit the db

    # Writes to the bugs table, adding @new_bugs to the current
    # list of bugs for this program
    $prog->add_bugs(@new_bugs);

    # Read from the bugs table, getting the full list of bugs, 
    # including the ones that were added above.
    $bugs = $prog->bugs;

    # Write to the programs table only
    $prog->save;

Example - add_on_save interface:

    # Read from the programs table
    $prog = Program->new(id => 5)->load;

    # Read from the bugs table
    $bugs = $prog->bugs;

    $prog->name($new_name);     # Does not hit the db
    $prog->add_bugs(@new_bugs); # Does not hit the db

    # Write to the programs table and the bugs table, adding
    # @new_bugs to the current list of bugs for this program
    $prog->save;

=item B<objects_by_map>

Create methods that fetch L<Rose::DB::Object>-derived objects via an intermediate L<Rose::DB::Object>-derived class that maps between two other L<Rose::DB::Object>-derived classes.  See the L<Rose::DB::Object::Metadata::Relationship::ManyToMany> documentation for a more complete example of this type of method in action.

=over 4

=item Options

=over 4

=item C<hash_key>

The key inside the hash-based object to use for the storage of the fetched objects.  Defaults to the name of the method.

=item C<interface>

Choose the interface.  The only current interface is C<get_set>, which is the default.

=item C<manager_args>

A reference to a hash of arguments passed to the C<manager_class> when fetching objects.  If C<manager_args> includes a "sort_by" argument, be sure to prefix each column name with the appropriate table name.  (See the L<synopsis|/SYNOPSIS> for examples.)

=item C<manager_class>

The name of the L<Rose::DB::Object::Manager>-derived class that the C<map_class> will use to fetch records.  Defaults to L<Rose::DB::Object::Manager>.

=item C<manager_method>

The name of the class method to call on C<manager_class> in order to fetch the objects.  Defaults to C<get_objects>.

=item C<map_class>

The name of the L<Rose::DB::Object>-derived class that maps between the other two L<Rose::DB::Object>-derived classes.  This class must have a foreign key and/or "many to one" relationship for each of the two tables that it maps between.

=item C<map_from>

The name of the "many to one" relationship or foreign key in C<map_class> that points to the object of the class that this relationship exists in.  Setting this value is only necessary if the C<map_class> has more than one foreign key or "many to one" relationship that points to one of the classes that it maps between.

=item C<map_to>

The name of the "many to one" relationship or foreign key in C<map_class> that points to the "foreign" object to be fetched.  Setting this value is only necessary if the C<map_class> has more than one foreign key or "many to one" relationship that points to one of the classes that it maps between.

=item C<relationship>

The L<Rose::DB::Object::Metadata::Relationship> object that describes the "key" through which the "objects_by_key" are fetched.  This option is required.

=item C<share_db>

If true, the L<db|Rose::DB::Object/db> attribute of the current object is shared with all of the objects fetched.  Defaults to true.

=item C<query_args>

A reference to an array of arguments added to the value of the C<query> parameter passed to the call to C<manager_class>'s C<manager_method> class method.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a method that will attempt to fetch L<Rose::DB::Object>-derived objects that are related to the current object through the C<map_class>.

If passed a single argument of undef, the list of objects is set to undef.  If passed a reference to an array of objects, then the list or related objects is set to point to that same array.  (Note that these objects are B<not> added to the database.  Use the C<get_set_now> or C<get_set_on_save> interface to do that.)

If the call to C<manager_class>'s C<manager_method> method returns false, that false value (in scalar context) or an empty list (in list context) is returned.

If the fetch succeeds, a list (in list context) or a reference to the array of objects (in scalar context) is returned.  (If the fetch finds zero objects, the list or array reference will simply be empty.  This is still considered success.)

=item C<get_set_now>

Creates a method that will attempt to fetch L<Rose::DB::Object>-derived objects that are related to the current object through the C<map_class>, and will also save objects to the database and map them to the parent object when called with arguments.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed a single argument of undef, the list of objects is set to undef, causing it to be reloaded the next time the method is called with no arguments.  (Pass a reference to an empty array to cause all of the existing objects to be "unmapped"--that is, to have their entries in the mapping table deleted from the database.)  Any pending C<set_on_save> or C<add_on_save> actions are discarded.

If passed a list or reference to an array of the appropriate L<Rose::DB::Object>-derived objects, the list of objects is copied from (in the case of a list) or set to point to (in the case of a reference to an array) the argument(s), the old entries are deleted from the mapping table in the database, and the new objects are added to the database, along with their corresponding mapping entries.  Any pending C<set_on_save> or C<add_on_save> actions are discarded.

The parent object must have been L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>ed prior to setting the list of objects.  If this method is called with arguments before the object has been  L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>ed, a fatal error will occur.

If called with no arguments and the hash key used to store the list of objects is defined, the list (in list context) or a reference to that array (in scalar context) of objects is returned.  Otherwise, the objects are fetched.

When fetching, if the call to C<manager_class>'s C<manager_method> method returns false, that false value (in scalar context) or an empty list (in list context) is returned.

If the fetch succeeds, a list (in list context) or a reference to the array of objects (in scalar context) is returned.  (If the fetch finds zero objects, the list or array reference will simply be empty.  This is still considered success.)

=item C<get_set_on_save>

Creates a method that will attempt to fetch L<Rose::DB::Object>-derived objects that are related to the current object through the C<map_class>, and will also save objects to the database and map them to the parent object when the "parent" object is L<save|Rose::DB::Object/save>ed.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed a single argument of undef, the list of objects is set to undef, causing it to be reloaded the next time the method is called with no arguments.  (Pass a reference to an empty array to cause all of the existing objects to be "unmapped"--that is, to have their entries in the mapping table deleted from the database.)  Any pending C<set_on_save> or C<add_on_save> actions are discarded.

If passed a list or reference to an array of the appropriate L<Rose::DB::Object>-derived objects, the list of objects is copied from (in the case of a list) or set to point to (in the case of a reference to an array) the argument(s).  The mapping table records that mapped the old objects to the parent object are scheduled to be deleted from the database and new ones are scheduled to be added to the database when the parent is L<save|Rose::DB::Object/save>ed.  Any previously pending C<set_on_save> or C<add_on_save> actions are discarded.

If called with no arguments and the hash key used to store the list of objects is defined, the list (in list context) or a reference to that array (in scalar context) of objects is returned.  Otherwise, the objects are fetched.

When fetching, if the call to C<manager_class>'s C<manager_method> method returns false, that false value (in scalar context) or an empty list (in list context) is returned.

If the fetch succeeds, a list (in list context) or a reference to the array of objects (in scalar context) is returned.  (If the fetch finds zero objects, the list or array reference will simply be empty.  This is still considered success.)

=item C<add_now>

Creates a method that will add to a list of L<Rose::DB::Object>-derived objects that are related to the current object through the C<map_class>, and will also save objects to the database and map them to the parent object.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed an empty list, the method does nothing and the parent object's L<error|Rose::DB::Object/error> attribute is set.

The parent object must have been L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>ed prior to adding to the list of objects.  If this method is called with a non-empty list as an argument before the parent object has been  L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>ed, a fatal error will occur.

If passed a list or reference to an array of the appropriate kind of L<Rose::DB::Object>-derived objects, these objects are linked to the parent object (by setting the appropriate key attributes) and then added to the database.  The parent object's list of related objects is then set to undef, causing the related objects to be reloaded from the database the next time they're needed.

=item C<add_on_save>

Creates a method that will add to a list of L<Rose::DB::Object>-derived objects that are related to the current object through the C<map_class>, and will also save objects to the database and map them to the parent object when the "parent" object is L<save|Rose::DB::Object/save>ed.  The objects and map records will be added to the database when the parent object is L<save|Rose::DB::Object/save>ed.  The objects do not have to already exist in the database; they will be inserted if needed.

If passed an empty list, the method does nothing and the parent object's L<error|Rose::DB::Object/error> attribute is set.

If passed a list or reference to an array of the appropriate kind of L<Rose::DB::Object>-derived objects, these objects are scheduled to be added to the database and mapped to the parent object when the parent object is L<save|Rose::DB::Object/save>ed.  They are also added to the parent object's current list of related objects, if the list is defined at the time of the call.

=back

=back

For a complete example of this method type in action, see the L<Rose::DB::Object::Metadata::Relationship::ManyToMany> documentation.

=item B<object_by_key>

Create a get/set methods for a single L<Rose::DB::Object>-derived object loaded based on a primary key formed from attributes of the current object.

=over 4

=item Options

=over 4

=item C<class>

The name of the L<Rose::DB::Object>-derived class of the object to be loaded.  This option is required.

=item C<foreign_key>

The L<Rose::DB::Object::Metadata::ForeignKey> object that describes the "key" through which the "object_by_key" is fetched.  This is required when using the "delete_now", "delete_on_save", and "get_set_on_save" interfaces.

=item C<hash_key>

The key inside the hash-based object to use for the storage of the object.  Defaults to the name of the method.

=item C<key_columns>

A reference to a hash that maps column names in the current object to those of the primary key in the object to be loaded.  This option is required.

=item C<interface>

Choose the interface.  The default is C<get_set>.

=item C<share_db>

If true, the L<db|Rose::DB::Object/db> attribute of the current object is shared with the object loaded.  Defaults to true.

=back

=item Interfaces

=over 4

=item C<delete_now>

Deletes a L<Rose::DB::Object>-derived object from the database based on a primary key formed from attributes of the current object.  First, the "parent" object will have all of its attributes that refer to the "foreign" set to null, and it will be saved into the database.  This needs to be done first because a database that enforces referential integrity will not allow a row to be deleted if it is still referenced by a foreign key in another table.

Any previously pending C<get_set_on_save> action is discarded.

The entire process takes place within a transaction if the database supports it.  If not currently in a transaction, a new one is started and then committed on success and rolled back on failure.

Returns true if the foreign object was deleted successfully or did not exist in the database, false if any of the keys that refer to the foreign object were undef, and triggers the normal L<Rose::DB::Object> L<error handling|Rose::DB::Object::Metadata/error_mode> in the case of any other kind of failure.

=item C<delete_on_save>

Deletes a L<Rose::DB::Object>-derived object from the database when the "parent" object is L<save|Rose::DB::Object/save>ed, based on a primary key formed from attributes of the current object.  The "parent" object will have all of its attributes that refer to the "foreign" set to null immediately, but the actual delete will not be done until the parent is saved.

Any previously pending C<get_set_on_save> action is discarded.

The entire process takes place within a transaction if the database supports it.  If not currently in a transaction, a new one is started and then committed on success and rolled back on failure.

Returns true if the foreign object was deleted successfully or did not exist in the database, false if any of the keys that refer to the foreign object were undef, and triggers the normal L<Rose::DB::Object> L<error handling|Rose::DB::Object::Metadata/error_mode> in the case of any other kind of failure.

=item C<get_set>

Creates a method that will attempt to create and load a L<Rose::DB::Object>-derived object based on a primary key formed from attributes of the current object.

If passed a single argument of undef, the C<hash_key> used to store the object is set to undef.  Otherwise, the argument is assumed to be an object of type C<class> and is assigned to C<hash_key> after having its C<key_columns> set to their corresponding values in the current object.

If called with no arguments and the C<hash_key> used to store the object is defined, the object is returned.  Otherwise, the object is created and loaded.

The load may fail for several reasons.  The load will not even be attempted if any of the key attributes in the current object are undefined.  Instead, undef will be returned.

If the call to the newly created object's L<load|Rose::DB::Object/load> method returns false, then the normal L<Rose::DB::Object> L<error handling|Rose::DB::Object::Metadata/error_mode> is triggered.  The false value returned by the call to the L<load|Rose::DB::Object/load> method is returned (assuming no exception was raised).

If the load succeeds, the object is returned.

=item C<get_set_now>

Creates a method that will attempt to create and load a L<Rose::DB::Object>-derived object based on a primary key formed from attributes of the current object, and will also save the object to the database when called with an appropriate object as an argument.

If passed a single argument of undef, the C<hash_key> used to store the object is set to undef.  Otherwise, the argument is assumed to be an object of type C<class> and is assigned to C<hash_key> after having its C<key_columns> set to their corresponding values in the current object.  The object is then immediately L<save|Rose::DB::Object/save>ed to the database.

The parent object must have been L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>ed prior to setting the list of objects.  If this method is called with arguments before the object has been  L<load|Rose::DB::Object/load>ed or L<save|Rose::DB::Object/save>ed, a fatal error will occur.

If called with no arguments and the C<hash_key> used to store the object is defined, the object is returned.  Otherwise, the object is created and loaded.

The load may fail for several reasons.  The load will not even be attempted if any of the key attributes in the current object are undefined.  Instead, undef will be returned.

If the call to the newly created object's L<load|Rose::DB::Object/load> method returns false, then the normal L<Rose::DB::Object> L<error handling|Rose::DB::Object::Metadata/error_mode> is triggered.  The false value returned by the call to the L<load|Rose::DB::Object/load> method is returned (assuming no exception was raised).

If the load succeeds, the object is returned.

=item C<get_set_on_save>

Creates a method that will attempt to create and load a L<Rose::DB::Object>-derived object based on a primary key formed from attributes of the current object, and save the object when the "parent" object is L<save|Rose::DB::Object/save>ed.

If passed a single argument of undef, the C<hash_key> used to store the object is set to undef.

If passed a set of name/value pairs, an object of type C<class> is constructed, with those parameters being passed to the constructor.

If passed a single value, and if C<class> has a single primary key column, then an object of type C<class> is constructed, with the primary key value passed to the constructor as the value of the primary key column's mutator method.

If passed an object of type C<class>, it is used as-is.

The object is then assigned to C<hash_key> after having its C<key_columns> set to their corresponding values in the current object.  The object will be saved into the database when the "parent" object is L<save|Rose::DB::Object/save>ed.  Any previously pending C<get_set_on_save> action is discarded.

If called with no arguments and the C<hash_key> used to store the object is defined, the object is returned.  Otherwise, the object is created and loaded from the database.

The load may fail for several reasons.  The load will not even be attempted if any of the key attributes in the current object are undefined.  Instead, undef will be returned.

If the call to the newly created object's L<load|Rose::DB::Object/load> method returns false, then the normal L<Rose::DB::Object> L<error handling|Rose::DB::Object::Metadata/error_mode> is triggered.  The false value returned by the call to the L<load|Rose::DB::Object/load> method is returned (assuming no exception was raised).

If the load succeeds, the object is returned.

=back

=back

Example setup:

    # CLASS     DB TABLE
    # -------   --------
    # Product   products
    # Category  categories

    package Product;

    our @ISA = qw(Rose::DB::Object);
    ...

    # You will almost never call the method-maker directly
    # like this.  See the Rose::DB::Object::Metadata docs
    # for examples of more common usage.
    use Rose::DB::Object::MakeMethods::Generic
    (
      object_by_key =>
      [
        category => 
        {
          interface   => 'get_set',
          class       => 'Category',
          key_columns =>
          {
            # Map Product column names to Category column names
            category_id => 'id',
          },
        },
      ]
    );
    ...

Example - get_set interface:


    $product = Product->new(id => 5, category_id => 99);

    # Read from the categories table
    $category = $product->category; 

    # $product->category call is roughly equivalent to:
    #
    # $cat = Category->new(id => $product->category_id
    #                      db => $prog->db);
    #
    # $ret = $cat->load;
    # return $ret  unless($ret);
    # return $cat;

    # Does not write to the db
    $product->category(Category->new(...));

    $product->save; # writes to products table only

Example - get_set_now interface:

    # Read from the products table
    $product = Product->new(id => 5)->load;

    # Read from the categories table
    $category = $product->category;

    # Write to the categories table
    $product->category(Category->new(...));

    # Write to the products table
    $product->save; 

Example - get_set_on_save interface:

    # Read from the products table
    $product = Product->new(id => 5)->load;

    # Read from the categories table
    $category = $product->category;

    # Does not write to the db
    $product->category(Category->new(...)); 

    # Write to both the products and categories tables
    $product->save; 

Example - delete_now interface:

    # Read from the products table
    $product = Product->new(id => 5)->load;

    # Write to both the categories and products tables
    $product->delete_category();

Example - delete_on_save interface:

    # Read from the products table
    $product = Product->new(id => 5)->load;

    # Does not write to the db
    $product->delete_category(); 

    # Write to both the products and categories tables
    $product->save;

=item B<scalar>

Create get/set methods for scalar attributes.

=over 4

=item Options

=over 4

=item C<default>

Determines the default value of the attribute.  This option is only
applicable when using the C<get_set> interface.

=item C<check_in>

A reference to an array of valid values.  When setting the attribute, if the new value is not equal (string comparison) to one of the valid values, a fatal error will occur.

=item C<hash_key>

The key inside the hash-based object to use for the storage of this
attribute.  Defaults to the name of the method.

=item C<init_method>

The name of the method to call when initializing the value of an
undefined attribute.  Defaults to the method name with the prefix
C<init_> added.  This option implies C<with_init>.

=item C<interface>

Choose the interface.  The only current interface is C<get_set>, which is the default.

=item C<with_init>

Modifies the behavior of the C<get_set> interface.  If the attribute is undefined, the method specified by the C<init_method>
option is called and the attribute is set to the return value of that
method.

=back

=item Interfaces

=over 4

=item C<get>

=item C<get_set>

Creates a get/set method for an object attribute.  When
called with an argument, the value of the attribute is set.  The current
value of the attribute is returned.

Creates an accessor method for an object attribute that returns the current
value of the attribute.

=item C<set>

Creates a mutator method for an object attribute.  When called with an argument, the value of the attribute is set.  If called with no arguments, a fatal error will occur.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Generic
    (
      scalar => 
      [
        name => { default => 'Joe' },
        type => 
        {
          with_init => 1,
          check_in  => [ qw(AA AAA C D) ],
        }
        set_type =>
        {
          check_in  => [ qw(AA AAA C D) ],        
        }
      ],
    );

    sub init_type { 'C' }
    ...

    $o = MyDBObject->new(...);

    print $o->name; # Joe
    print $o->type; # C

    $o->name('Bob'); # set
    $o->type('AA');  # set

    eval { $o->type('foo') }; # fatal error: invalid value

    print $o->name, ' is ', $o->type; # get

=item B<set>

Create get/set methods for "set" attributes.   A "set" column in a database table contains an unordered group of values.  Not all databases support a "set" column type.  Check the L<Rose::DB|Rose::DB/"DATABASE SUPPORT"> documentation for your database type.

=over 4

=item Options

=over 4

=item C<default>

Determines the default value of the attribute.  The value should be a reference to an array.

=item C<hash_key>

The key inside the hash-based object to use for the storage of this
attribute.  Defaults to the name of the method.

=item C<interface>

Choose the interface.  The default is C<get_set>.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a get/set method for a "set" object attribute.  A "set" column in a database table contains an unordered group of values.  On the Perl side of the fence, an ordered list (an array) is used to store the values, but keep in mind that the order is not significant, nor is it guaranteed to be preserved.

When setting the attribute, the value is passed through the L<parse_set|Rose::DB::Informix/parse_set> method of the object's L<db|Rose::DB::Object/db> attribute.

When saving to the database, if the attribute value is defined, the method will pass the attribute value through the L<format_set|Rose::DB::Informix/format_set> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.

When not saving to the database, the method returns the set as a list in list context, or as a reference to the array in scalar context.

=item C<get>

Creates an accessor method for a "set" object attribute.  A "set" column in a database table contains an unordered group of values.  On the Perl side of the fence, an ordered list (an array) is used to store the values, but keep in mind that the order is not significant, nor is it guaranteed to be preserved.

When saving to the database, if the attribute value is defined, the method will pass the attribute value through the L<format_set|Rose::DB::Informix/format_set> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.

When not saving to the database, the method returns the set as a list in list context, or as a reference to the array in scalar context.

=item C<set>

Creates a mutator method for a "set" object attribute.  A "set" column in a database table contains an unordered group of values.  On the Perl side of the fence, an ordered list (an array) is used to store the values, but keep in mind that the order is not significant, nor is it guaranteed to be preserved.

When setting the attribute, the value is passed through the L<parse_set|Rose::DB::Informix/parse_set> method of the object's L<db|Rose::DB::Object/db> attribute.

When saving to the database, if the attribute value is defined, the method will pass the attribute value through the L<format_set|Rose::DB::Informix/format_set> method of the object's L<db|Rose::DB::Object/db> attribute before returning it.

When not saving to the database, the method returns the set as a list in list context, or as a reference to the array in scalar context.

=back

=back

Example:

    package Person;

    our @ISA = qw(Rose::DB::Object);
    ...
    use Rose::DB::Object::MakeMethods::Generic
    (
      set => 
      [
        'nicknames',
        'set_nicks' => { interface => 'set', hash_key => 'nicknames' },

        'parts' => { default => [ qw(arms legs) ] },
      ],
    );
    ...

    @parts = $person->parts; # ('arms', 'legs')
    $parts = $person->parts; # [ 'arms', 'legs' ]

    $person->nicknames('Jack', 'Gimpy');   # set with list
    $person->nicknames([ 'Slim', 'Gip' ]); # set with array ref

    $person->set_nicks('Jack', 'Gimpy');   # set with list
    $person->set_nicks([ 'Slim', 'Gip' ]); # set with array ref

=item B<varchar>

Create get/set methods for variable-length character string attributes.

=over 4

=item Options

=over 4

=item C<default>

Determines the default value of the attribute.

=item C<hash_key>

The key inside the hash-based object to use for the storage of this
attribute.  Defaults to the name of the method.

=item C<interface>

Choose the interface.  The only current interface is C<get_set>, which is the default.

=item C<length>

The maximum number of characters in the string.  Any strings longer than this will be truncated.  If length is omitted, the string will be left unmodified.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a get/set accessor method for a fixed-length character string attribute.  When setting, any strings longer than C<length> will be truncated.  If C<length> is omitted, the string will be left unmodified.

=back

=back

Example:

    package MyDBObject;

    our @ISA = qw(Rose::DB::Object);

    use Rose::DB::Object::MakeMethods::Generic
    (
      varchar => 
      [
        'name' => { length => 3 },
      ],
    );

    ...

    $o->name('John'); # truncates on set
    print $o->name;   # 'Joh'

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.