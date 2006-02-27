package Rose::WebApp::Logger;

use strict;

use Rose::Apache1;

use Rose::Object;
use Rose::WebApp::Child;
our @ISA = qw(Rose::Object Rose::WebApp::Child);

our $VERSION = '0.01';

# XXX: I'm directly accessing Rose::Apache1::LOG_LEVEL* only because
# XXX: I'm the author of both modules and I know I'm limiting the log
# XXX: levels to those supported by apache 1.  Don't do this if you're
# XXX: not me.

our(%LOG_LEVEL_CONST_TO_NAME, %LOG_LEVEL_NAME_TO_CONST);
*LOG_LEVEL_CONST_TO_NAME = \%Rose::Apache1::LOG_LEVEL_CONST_TO_NAME;
*LOG_LEVEL_NAME_TO_CONST = \%Rose::Apache1::LOG_LEVEL_NAME_TO_CONST;

sub log_level 
{
  my($self) = shift;

  if(@_)
  {
    my $level = shift;

    Carp::croak "Invalid log level: '$level'"  
      unless(exists $LOG_LEVEL_NAME_TO_CONST{$level});

    $self->log_level_constant($LOG_LEVEL_NAME_TO_CONST{$level});

    return $level;
  }

  my $level = $self->{'log_level_constant'};

  unless(defined $level)
  {
    my $level_name = $self->init_log_level;

    Carp::croak "Cannot init with invalid log level: '$level_name'"  
      unless(exists $LOG_LEVEL_NAME_TO_CONST{$level_name});

    $self->log_level_constant($LOG_LEVEL_NAME_TO_CONST{$level_name});
    return $level_name;
  }

  return $LOG_LEVEL_CONST_TO_NAME{$level};
}

sub log_level_constant
{
  my($self) = shift;

  if(@_)
  {
    my $level = shift;

    Carp::croak "Invalid log level constant: '$level'"  
      unless(exists $LOG_LEVEL_CONST_TO_NAME{$level});

    return $self->{'log_level_constant'} = $level
  }

  unless(defined $self->{'log_level_constant'})
  {
    $self->log_level; # inits log level constant as side-effect
  }

  return $self->{'log_level_constant'};
}

sub init_log_level { 'warn' }

# Default implementation should never be used, but exists
# to show the API and at least do something sensible.
sub log_emergency { shift->app->log_emergency(@_) }
sub log_alert     { shift->app->log_alert(@_)     }
sub log_critical  { shift->app->log_critical(@_)  }
sub log_error     { shift->app->log_error(@_)     }
sub log_warning   { shift->app->log_warning(@_)   }
sub log_notice    { shift->app->log_notice(@_)    }
sub log_info      { shift->app->log_info(@_)      }
sub log_debug     { shift->app->log_debug(@_)     }

*log_warn = \&log_warning;

1;
