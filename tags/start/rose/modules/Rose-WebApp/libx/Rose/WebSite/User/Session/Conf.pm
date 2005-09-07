package Rose::WebSite::User::Session::Conf;

use strict;

require Rose::Conf::File;
our @ISA = qw(Rose::Conf::File);

our %CONF =
(
  ID_COOKIE       => 'rose_session_id',
  DB_DSN          => 'dbi:mysql:database=web;host=localhost;port=3306',
  DB_USERNAME     => 'web',
  DB_PASSWORD     => 'apache',

  LOGIN_REFRESH   => 4, # Fraction of login duration: 1/LOGIN_REFRESH
  LOGIN_DURATION  => 60 * 60, # seconds
);

1;
