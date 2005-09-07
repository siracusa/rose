package Rose::WebApp::Example::CRUD::Form::Edit;

use strict;

use Rose::HTML::Form;
use Rose::WebApp::Child;
our @ISA = qw(Rose::HTML::Form Rose::WebApp::Child);

sub is_edit_form { 1 }

1;
