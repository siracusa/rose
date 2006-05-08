package Rose::Test::MP1::MySite;

use strict;

use HTML::Mason::Interp;

use Rose::WebSite;
our @ISA = qw(Rose::WebSite);

our $Interp;

sub mason_interp
{
  my($class) = shift;

  return $Interp ||=
  HTML::Mason::Interp->new(
    comp_root =>
    [
      [ docs  => $class->server->document_root ],
      [ comps => $class->server->server_root_relative('comps') ],
    ],
    data_dir      => $class->server->server_root_relative('data'),
    #error_mode    => $MASON_ERROR_MODE,
    #error_format  => $MASON_ERROR_FORMAT,
    allow_globals => [ qw($r $app) ]);
}

1;
