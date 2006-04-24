package Rose::Test::MP1::WebApp::Features::Logger;

use strict;

use Rose::Test::MP1::MyApp;
our @ISA = qw(Rose::Test::MP1::MyApp);

__PACKAGE__->use_features('logger');

sub init_default_action { 'default' }

sub do_default
{
  my($self) = shift;

  my $logger = $self->logger;

  $self->server_log_level('debug');

    #print STDERR "0 LOGGER LEVEL: ", $self->log_level, ' ', $self->logger->log_level, "\n";
    #print STDERR "0 SERVER LEVEL: ", $self->server_log_level, "\n";

  my @levels = qw(emergency alert critical error warn notice info debug);

  foreach my $level (qw(emergency alert critical error warn notice info debug))
  {
    $self->log_level($level);
    shift @levels;

    #print STDERR "LOGGER LEVEL: ", $self->log_level, ' ', $self->logger->log_level, "\n";
    #print STDERR "SERVER LEVEL: ", $self->server_log_level, "\n";

    foreach my $sublevel (@levels)
    {
      my $method = "log_$sublevel";
      $self->$method("NOT OK - $level $method");
    }
  }

  my $error_log = $self->server->server_root_relative('logs/error_log');

  my $log_fh;

  open($log_fh, $error_log) or die "Could not open $error_log - $!";
  {
    local $/;
    my $log = <$log_fh>;
    close($log_fh);

    die "Found 'NOT OK' line in error log! $1"  if($log =~ m{^(.*NOT OK - .*)$}m);
  }

  $self->log_level('debug');
  $self->server_log_level('emergency');

  foreach my $level (qw(emergency alert critical error warn notice info debug))
  {
    my $method = "log_$level";
    $self->$method("OK $level");
  }

  open($log_fh, $error_log) or die "Could not open $error_log - $!";
  {
    local $/;
    my $log = <$log_fh>;
    close($log_fh);

    foreach my $level (qw(emergency alert critical error warn notice info debug))
    {
      die "Missing 'OK' line in error log for level $level"  
        unless($log =~ m{^.*OK $level.*$}m);
    }
  }

  $self->send_http_header;
  $self->print('Hello world');
}

1;
