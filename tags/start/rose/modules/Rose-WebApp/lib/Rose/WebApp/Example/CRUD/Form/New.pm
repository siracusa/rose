package Rose::WebApp::Example::CRUD::Form::New;

use strict;

use Rose::WebApp::Example::CRUD::Form::Edit;
our @ISA = qw(Rose::WebApp::Example::CRUD::Form::Edit);

sub is_edit_form { 0 }

1;
