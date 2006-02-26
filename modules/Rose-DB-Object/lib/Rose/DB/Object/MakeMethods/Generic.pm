package Rose::DB::Object::MakeMethods::Generic;

use strict;

use Bit::Vector::Overload;

use Carp();

use Rose::Object::MakeMethods;
our @ISA = qw(Rose::Object::MakeMethods);

use Rose::DB::Object::Manager;

use Rose::DB::Object::Constants 
  qw(PRIVATE_PREFIX FLAG_DB_IS_PRIVATE STATE_IN_DB STATE_LOADING
     STATE_SAVING);

our $VERSION = '0.061';

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

        # Comment this out to allow null keys
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

      my $ret = $obj->load;

      unless($ret)
      {
        $self->error("Could not load $fk_class with key ", 
                     join(', ', map { "$_ = '$key{$_}'" } sort keys %key) .
                     " - " . $obj->error);
        return $ret;
      }

      return $self->{$key} = $obj;
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

      if($share_db)
      {
        $objs = $ft_manager->$ft_method(query => [ %key, @$query_args ], %$mgr_args, db => $self->db);
      }
      else
      {
        $objs = $ft_manager->$ft_method(query => [ %key, @$query_args ], %$mgr_args);
      }

      unless($objs)
      {
        $self->error("Could not load $ft_class objects with key ", 
                     join(', ', map { "$_ = '$key{$_}'" } sort keys %key) .
                     " - " . $ft_manager->error);
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
  my $map_class    = $args->{'map_class'} or die "Missing map class";
  my $map_meta     = $map_class->meta or die "Missing meta for $map_class";
  my $map_from     = $args->{'map_from'};
  my $map_to       = $args->{'map_to'};
  my $map_manager  = $args->{'manager_class'};
  my $map_method   = $args->{'manager_method'} || 'get_objects';
  my $mgr_args     = $args->{'manager_args'} || {};
  my $query_args   = $args->{'query_args'} || [];
  my $map_to_method;

  if(@$query_args % 2 != 0)
  {
    Carp::croak "Odd number of arguments passed in query_args parameter";
  }

  unless($map_manager)
  {
    $map_manager = 'Rose::DB::Object::Manager';
    $mgr_args->{'object_class'} = $map_class;
  }

  my $meta       = $target_class->meta;
  my $share_db   = $args->{'share_db'} || 1;

  # Build the map of "local" column names to "foreign" object method names. 
  # The words "local" and "foreign" are relative to the *mapper* class.
  my(%key_template, %column_map);

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

      if(%key_template)
      {
        Carp::croak "Map class $map_class has more than one foreign key ",
                    "and/or 'one to one' relationship that points to the ",
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
        $key_template{$local_column} = $foreign_method;
        $column_map{$local_column} = $foreign_column;
      }
    }
    elsif($item->isa('Rose::DB::Object::Metadata::ForeignKey') ||
          $item->type eq 'one to one')
    {
      # Skip if there was an explicit foreign relationship name and
      # this is not that name.
      next  if($map_to && $item->name ne $map_to);

      $map_to = $item->name;

      if($require_objects)
      {
        Carp::croak "Map class $map_class has more than one foreign key ",
                    "and/or 'one to one' relationship that points to a ",
                    "class other than $target_class.  Please specify one ",
                    "by name with a 'foreign' parameter in the 'map' hash";
      }

      $require_objects  = [ $item->name ];
      $foreign_class = $item->class;
      $map_to_method = $item->method_name('get_set');
    }
  }

  unless(%key_template)
  {
    Carp::croak "Could not find a foreign key or 'one to one' relationship ",
                "in $map_class that points to $target_class";
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
         $item->type eq 'one to one') &&
         $item->class eq $target_class && $item->name ne $local_rel)
      {  
        if($require_objects)
        {
          Carp::croak "Map class $map_class has more than two foreign keys ",
                      "and/or 'one to one' relationships that points to a ",
                      "$target_class.  Please specify which ones to use ",
                      "by including 'local' and 'foreign' parameters in the ",
                      "'map' hash";
        }

        $require_objects = [ $item->name ];
        $foreign_class = $item->class;
        $map_to_method = $item->method_name('get_set');
      }
    }
  }

  unless($require_objects)
  {
    Carp::croak "Could not find a foreign key or 'one to one' relationship ",
                "in $map_class that points to a class other than $target_class"
  }

  # Populate relationship with the info we've extracted
  $relationship->column_map(\%column_map);
  $relationship->map_from($map_from);
  $relationship->map_to($map_to);
  $relationship->foreign_class($foreign_class);

  # Relationship names
  $map_to   ||= $require_objects->[0];
  $map_from ||= $local_rel;

  if($interface eq 'get_set')
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

      my %link;

      while(my($local_column, $foreign_method) = each(%key_template))
      {
        $link{$local_column} = $self->$foreign_method();

        # Comment this out to allow null keys
        unless(defined $link{$local_column})
        {
          keys(%key_template); # reset iterator
          $self->error("Could not fetch indirect objects via $name() - the " .
                       "$foreign_method attribute is undefined");
          return wantarray ? () : undef;
        }
      }

      my $objs;

      if($share_db)
      {
        $objs =
          $map_manager->$map_method(query        => [ %link, @$query_args ],
                                    require_objects => $require_objects,
                                    %$mgr_args, db => $self->db);
      }
      else
      {
        $objs = 
          $map_manager->$map_method(query        => [ %link, @$query_args ],
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
  elsif($interface eq 'load')
  {
    my $method_name = $args->{'load_method'} || 'load_' . $name;

    $methods{$method_name} = sub
    {
      return (defined shift->$name(@_)) ? 1 : 0;
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
        manager_args => { sort_by => 'name' },
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
        manager_args => { sort_by => 'date_submitted DESC' },
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

A reference to a hash of arguments passed to the C<manager_class> when fetching objects.  If C<manager_class> defaults to L<Rose::DB::Object::Manager>, the following argument is added to the C<manager_args> hash: C<object_class =E<gt> CLASS>, where CLASS is the value of the C<class> option (see above).

=item C<manager_class>

The name of the L<Rose::DB::Object::Manager>-derived class used to fetch the objects.  The C<manager_method> class method is called on this class.  Defaults to L<Rose::DB::Object::Manager>.

=item C<manager_method>

The name of the class method to call on C<manager_class> in order to fetch the objects.  Defaults to C<get_objects>.

=item C<interface>

Choose the interface.  The only current interface is C<get_set>, which is the default.

=item C<share_db>

If true, the L<db|Rose::DB::Object/db> attribute of the current object is shared with all of the objects fetched.  Defaults to true.

=item C<query_args>

A reference to an array of arguments added to the value of the C<query> parameter passed to the call to C<manager_class>'s C<manager_method> class method.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a method that will attempt to fetch L<Rose::DB::Object>-derived objects based on a key formed from attributes of the current object.

If passed a single argument of undef, the list of objects is set to undef.  If passed a reference to an array, the list of objects is set to point to that same array.  (Note that these objects are not automatically added to the database.)

If called with no arguments and the hash key used to store the list of objects is defined, the list (in list context) or a reference to that array (in scalar context) of objects is returned.  Otherwise, the objects are fetched.

The fetch may fail for several reasons.  The fetch will not even be attempted if any of the key attributes in the current object are undefined.  Instead, undef (in scalar context) or an empty list (in list context) will be returned.  If the call to C<manager_class>'s C<manager_method> method returns false, that false value (in scalar context) or an empty list (in list context) is returned.

If the fetch succeeds, a list (in list context) or a reference to the array of objects (in scalar context) is returned.  (If the fetch finds zero objects, the list or array reference will simply be empty.  This is still considered success.)

=back

=back

Example:

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
          manager_args => { sort_by => 'date_submitted DESC' },
          query_args   => { state => { ne => 'closed' } },
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

A reference to a hash of arguments passed to the C<manager_class> when fetching objects.

=item C<manager_class>

The name of the L<Rose::DB::Object::Manager>-derived class that the C<map_class> will use to fetch records.  Defaults to L<Rose::DB::Object::Manager>.

=item C<manager_method>

The name of the class method to call on C<manager_class> in order to fetch the objects.  Defaults to C<get_objects>.

=item C<map_class>

The name of the L<Rose::DB::Object>-derived class that maps between the other two L<Rose::DB::Object>-derived classes.  This class must have a foreign key and/or "one to one" relationship for each of the two tables that it maps between.

=item C<map_from>

The name of the "one to one" relationship or foreign key in C<map_class> that points to the object of the class that the method exists in.  Setting this value is only necessary if the C<map_class> has more than one foreign key or "one to one" relationship that points to one of the classes that it maps between.

=item C<map_to>

The name of the "one to one" relationship or foreign key in C<map_class> that points to the "foreign" object to be fetched.  Setting this value is only necessary if the C<map_class> has more than one foreign key or "one to one" relationship that points to one of the classes that it maps between.

=item C<share_db>

If true, the L<db|Rose::DB::Object/db> attribute of the current object is shared with all of the objects fetched.  Defaults to true.

=item C<query_args>

A reference to an array of arguments added to the value of the C<query> parameter passed to the call to C<manager_class>'s C<manager_method> class method.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a method that will attempt to fetch L<Rose::DB::Object>-derived objects that are related to the current object through the C<map_class>.

If passed a single argument of undef, the list of objects is set to undef.  If passed a reference to an array of objects, then the list or related objects is set to point to that same array.  (Note that these objects are not automatically added to the database.)

If the call to C<manager_class>'s C<manager_method> method returns false, that false value (in scalar context) or an empty list (in list context) is returned.

If the fetch succeeds, a list (in list context) or a reference to the array of objects (in scalar context) is returned.  (If the fetch finds zero objects, the list or array reference will simply be empty.  This is still considered success.)

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

=item C<hash_key>

The key inside the hash-based object to use for the storage of the object.  Defaults to the name of the method.

=item C<key_columns>

A reference to a hash that maps column names in the current object to those of the primary key in the object to be loaded.  This option is required.

=item C<interface>

Choose the interface.  The only current interface is C<get_set>, which is the default.

=item C<share_db>

If true, the L<db|Rose::DB::Object/db> attribute of the current object is shared with the object loaded.  Defaults to true.

=back

=item Interfaces

=over 4

=item C<get_set>

Creates a method that will attempt to create and load a L<Rose::DB::Object>-derived object based on a primary key formed from attributes of the current object.

If passed a single argument of undef, the C<hash_key> used to store the object is set to undef.  Otherwise, the argument is assumed to be an object of type C<class> and is assigned to C<hash_key> after having its C<key_columns> set to their corresponding values in the current object.

If called with no arguments and the C<hash_key> used to store the object is defined, the object is returned.  Otherwise, the object is created and loaded.

The load may fail for several reasons.  The load will not even be attempted if any of the key attributes in the current object are undefined.  Instead, undef will be returned.  If the call to the newly created object's C<load> method returns false, that false value is returned.

If the load succeeds, the object is returned.

=back

=back

Example:

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
    # $cat = Category->new(id => $product->category_id
    #                      db => $prog->db);
    #
    # $ret = $cat->load;
    # return $ret  unless($ret);
    # return $cat;

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
