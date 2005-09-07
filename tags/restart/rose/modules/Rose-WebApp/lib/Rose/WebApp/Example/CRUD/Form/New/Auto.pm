package Rose::WebApp::Example::CRUD::Form::New::Auto;

use strict;

use Rose::WebApp::Example::CRUD::Form::Edit::Auto;
our @ISA = qw(Rose::WebApp::Example::CRUD::Form::Edit::Auto);

sub is_edit_form { 0 }

sub auto_populated_field_names { wantarray ? () : [] }

1;
