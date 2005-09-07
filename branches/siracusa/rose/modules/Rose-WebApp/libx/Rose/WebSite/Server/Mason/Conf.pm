package Rose::WebSite::Server::Mason::Conf;

use strict;

require Rose::Conf::File;
our @ISA = qw(Rose::Conf::File);

our %CONF =
(
  SERVER_ROOT  => undef,
  SERVER_ADMIN => 'nonesuch@nonesuch.com',

  SERVER_NAME  => undef,
  SERVER_EXE   => undef,
  HTTP_IP      => 127.0.0.1,
  HTTP_PORT    => 80,

  APACHE_HTTPD_CONF   => 'conf/httpd.conf',
  APACHE_MIME_TYPES   => 'conf/mime.types',
  APACHE_PERL_STARTUP => 'conf/startup.pl',

  APACHE_MIN_SPARE_SERVERS      => 2,
  APACHE_MAX_SPARE_SERVERS      => 2,
  APACHE_START_SERVERS          => 1,
  APACHE_MAX_CLIENTS            => 100,
  APACHE_MAX_REQUESTS_PER_CHILD => 1000,

  APACHE_LOCK_FILE         => 'logs/accept.lock',
);

1;
