package Rose::WebSite::Server::Static::Conf;

use strict;

use vars qw(@ISA %CONF);

require Rose::Conf::File;
@ISA = qw(Rose::Conf::File);

%CONF =
(
  SERVER_ROOT  => undef,
  SERVER_ADMIN => 'nonesuch@nonesuch.com',

  USE_SSL      => 0,

  SERVER_NAME  => undef,
  SERVER_EXE   => undef,
  HTTP_IP      => undef,
  HTTP_PORT    => 80,
  HTTPS_IP     => undef,
  HTTPS_PORT   => 443,

  SSL_CERT_FILE     => 'conf/ssl/certs/acme.cert',
  SSL_CERT_KEY_FILE => 'conf/ssl/private/acme.key',

  APACHE_HTTPD_CONF   => 'conf/httpd.conf',
  APACHE_MIME_TYPES   => 'conf/mime.types',

  APACHE_MIN_SPARE_SERVERS      => 2,
  APACHE_MAX_SPARE_SERVERS      => 5,
  APACHE_START_SERVERS          => 2,
  APACHE_MAX_CLIENTS            => 100,
  APACHE_MAX_REQUESTS_PER_CHILD => 10000,

  APACHE_LOCK_FILE => 'logs/accept.lock',
);

1;
