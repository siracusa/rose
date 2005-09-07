package Rose::WebSite::Server::Conf;

use strict;

require Rose::Conf::File;
our @ISA = qw(Rose::Conf::File);

our %CONF =
(
  ROOT          => '/www/rose/website',
  SERVER_ADMIN  => 'nonesuch@nonesuch.com',
  SERVER_NAME   => undef,
  SERVER_URL    => undef,

  SERVER_URL_SECURE   => undef,
  SERVER_URL_INSECURE => undef,

  DEVELOPMENT_SERVER  => 0,

  USE_SSL => 1,

  ACTION_PATH   => 'exec',
  ACTION_SUFFIX => '.pl',

  APP_PATH      => '/app.mc',
);

1;
