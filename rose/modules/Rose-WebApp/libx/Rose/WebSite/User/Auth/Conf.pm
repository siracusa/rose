package Rose::WebSite::User::Auth::Conf;

require Rose::Conf::File;
@ISA = qw(Rose::Conf::File);

our %CONF =
(
  LOGIN_URI  => '/login',
  LOGOUT_URI => '/logout',

  REQ_URI_COOKIE        => 'rose_req_uri',
  POST_LOGIN_URI_COOKIE => 'rose_post_login_uri',

  NO_AUTH_REGEX  => '^/log(?:in|out)(?:/|$)',  
  NO_AUTHZ_REGEX => '^/log(?:in|out)(?:/|$)',
);

1;
