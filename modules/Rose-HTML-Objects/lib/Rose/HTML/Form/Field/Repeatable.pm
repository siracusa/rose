package Rose::HTML::Form::Field::Repeatable;

use strict;

use Rose::HTML::Object::Repeatable;
our @ISA = qw(Rose::HTML::Object::Repeatable);

our $VERSION = '0.554';

sub field      { shift->entity(@_) }
sub field_spec { shift->entity_spec(@_) }

1;
