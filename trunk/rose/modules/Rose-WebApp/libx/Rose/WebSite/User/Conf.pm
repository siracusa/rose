package Rose::WebSite::User::Conf;

use strict;

require Rose::Conf::File;
our @ISA = qw(Rose::Conf::File);

our %CONF =
(
  # Fraction of login duration: 1/LOGIN_REFRESH
  LOGIN_REFRESH => 4, 

  USER_GROUPS_REFRESH => 60 * 30, # seconds
);

1;
