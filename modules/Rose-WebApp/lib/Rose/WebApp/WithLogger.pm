package Rose::WebApp::WithLogger;

use strict;

use Rose::WebApp::Feature;
our @ISA = qw(Rose::WebApp::Feature);

use Rose::WebApp::Logger::Apache;

our $VERSION = '0.01';

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' =>
  [
    'logger',
    'logger_class',
  ],
);

__PACKAGE__->register_subclass;

sub feature_name { 'logger' }

sub init_logger_class { 'Rose::WebApp::Logger::Apache' }

sub init_logger 
{
  my($self) = shift;
  return $self->logger_class->new(app => $self);
}

sub log_level { shift->logger->log_level(@_) }

sub log_level_constant { shift->logger->log_level_constant(@_) }

sub log_emergency { shift->logger->log_emergency(@_) }
sub log_alert     { shift->logger->log_alert(@_)     }
sub log_critical  { shift->logger->log_critical(@_)  }
sub log_error     { shift->logger->log_error(@_)     }
sub log_warning   { shift->logger->log_warning(@_)   }
sub log_notice    { shift->logger->log_notice(@_)    }
sub log_info      { shift->logger->log_info(@_)      }
sub log_debug     { shift->logger->log_debug(@_)     }

*log_warn = \&log_warning;

1;
