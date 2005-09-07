package Rose::HTML::Form::Field::Time::Split;

use strict;

use Rose::HTML::Form::Field::Time;
use Rose::HTML::Form::Field::Compound;
our @ISA = qw(Rose::HTML::Form::Field::Compound Rose::HTML::Form::Field::Time);

our $VERSION = '0.011';

# Multiple inheritence never quite works out the way I want it to...
Rose::HTML::Form::Field::Time->import_methods
(
  'inflate_value',
  'validate',
);

1;
