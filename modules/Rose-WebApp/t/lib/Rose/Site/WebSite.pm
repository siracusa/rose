package Rose::Site::WebSite;

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
      [ docs  => $class->apache->request->document_root ],
      [ comps => $class->apache->request->server_root_relative('comps') ],
    ],
    data_dir      => $class->apache->request->server_root_relative('data'),
    #error_mode    => $MASON_ERROR_MODE,
    #error_format  => $MASON_ERROR_FORMAT,
    allow_globals => [ qw($r $app) ]);
}

sub server_host_secure   { '206.82.55.25' }
sub server_host_insecure { '206.82.55.25' }

sub server_port_secure   { 5443 }
sub server_port_insecure { 5080 }

1;
