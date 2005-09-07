package Rose::WebApp::Page;

use strict;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.01';

use Rose::Object::MakeMethods::Generic
(
  'scalar' => 'page_path',

  array =>
  [
    'form_names'     => { interface => 'get_set' },
    'add_form_names' => { interface => 'add', hash_key => 'form_names' },
  ],
);

1;
