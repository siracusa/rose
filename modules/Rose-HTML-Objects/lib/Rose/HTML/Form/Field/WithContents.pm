package Rose::HTML::Form::Field::WithContents;

use strict;

use Rose::HTML::Form::Field;
use Rose::HTML::Object::WithContents;
our @ISA = qw(Rose::HTML::Object::WithContents Rose::HTML::Form::Field);

our $VERSION = '0.011';

sub html_field  { shift->html_tag(@_) }
sub xhtml_field { shift->xhtml_tag(@_) }

1;
