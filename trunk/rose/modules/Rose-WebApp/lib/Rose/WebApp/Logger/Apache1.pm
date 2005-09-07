package Rose::WebApp::Logger::Apache1;

use strict;

use Apache::Log;

use Rose::WebApp::Logger;
our @ISA = qw(Rose::WebApp::Logger);

our $VERSION = '0.01';

our %LOG_LEVEL_RANK =
(
  Apache::Log::EMERG()   => 1,
  Apache::Log::ALERT()   => 2,
  Apache::Log::CRIT()    => 3,
  Apache::Log::ERR()     => 4,
  Apache::Log::WARNING() => 5,
  Apache::Log::NOTICE()  => 6,
  Apache::Log::INFO()    => 7,
  Apache::Log::DEBUG()   => 8,
);

sub _log
{
  my($self, $level, $level_rank, $level_name) = (shift, shift, shift, shift);

  my $logger_level_rank = $LOG_LEVEL_RANK{$self->log_level_constant} 
    or die "Ack! Invalid logger log level constant: '", $self->log_level_constant, "'";

  if($logger_level_rank < $level_rank)
  {
    #print STDERR "REFUSING TO LOG $level_name BECAUSE LOGGER LEVEL ", 
    #  $self->log_level, " IS MORE RESTRICTIVE THAN $level_name\n";
    return;
  }

  my $server_log_level_rank = $LOG_LEVEL_RANK{$self->app->server_log_level_constant};

  # Use log_error to force writing when logger log level is lower than the 
  # server log level.
  if($server_log_level_rank < $logger_level_rank)
  {
    #print STDERR "FALLING BACK TO LOG NOTICE: ", $self->app->server_log_level, 
    #             " IS MORE RESTRICTIVE THAN $level_name\n";
    $self->app->apache->log_notice(@_);
  }

  my $method = "log_$level_name";

  no strict 'refs';
  $self->app->apache->$method(@_);
}

# XXX: Hard-code rank and name to avoid lookups.
sub log_emergency { shift->_log(Apache::Log::EMERG,   1, 'emergency', @_) }
sub log_alert     { shift->_log(Apache::Log::ALERT,   2, 'alert',     @_) }
sub log_critical  { shift->_log(Apache::Log::CRIT,    3, 'critical',  @_) }
sub log_error     { shift->_log(Apache::Log::ERR,     4, 'error',     @_) }
sub log_warning   { shift->_log(Apache::Log::WARNING, 5, 'warning',   @_) }
sub log_notice    { shift->_log(Apache::Log::NOTICE,  6, 'notice',    @_) }
sub log_info      { shift->_log(Apache::Log::INFO,    7, 'info',      @_) }
sub log_debug     { shift->_log(Apache::Log::DEBUG,   8, 'debug',     @_) }

*log_warn = \&log_warning;

1;
