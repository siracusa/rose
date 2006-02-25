package Rose::Test::Apache1::Module;

use strict;

use Data::Dumper;

use Apache::Util qw(escape_html);

use Rose::Apache::Module;
our @ISA = qw(Rose::Apache::Module);

use Apache::Constants qw(:response);

sub handler($$)
{
  my($self, $r) = @_;

  $self = $self->new($r)  unless(ref($self));

  $self->sanity_check() or return $self->status;
  $self->parse_query or return $self->status;

  $r->content_type('text/html');
  $r->send_http_header;

  $r->no_cache(1);

  $r->print(<<"EOF");
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::Apache1::Module</title>
</head>
<body>
EOF

  $r->print('Params: <pre>', escape_html(Dumper(scalar $self->params) || ''), "</pre><br>\n");
  $r->print('Param Names: ', join(', ', map { escape_html($_) } $self->param_names), "<br>\n");
  $r->print('Param Values: <pre>', join("\n", map { escape_html(Dumper($_)) } $self->param_values), "</pre><br>\n");
  $r->print('Param Exists(a): ', $self->param_exists('a'), "<br>\n");
  $r->print('Param Exists(z): ', $self->param_exists('z'), "<br>\n");

  $self->delete_param('c');

  $r->print("delete_param('c')<br>");

  $r->print('Params: <pre>', escape_html(Dumper(scalar $self->params) || ''), "</pre><br>\n");
  $r->print('Param Names: ', join(', ', map { escape_html($_) } $self->param_names), "<br>\n");
  $r->print('Param Values: <pre>', join("\n", map { escape_html(Dumper($_)) } $self->param_values), "</pre><br>\n");
  $r->print('Param Exists(a): ', $self->param_exists('a'), "<br>\n");
  $r->print('Param Exists(c): ', $self->param_exists('c'), "<br>\n");

  $r->print('</body></html>');

  return OK;
}

1;