package Rose::HTML::Form::Field::DateTime::Split;

use strict;

use Rose::HTML::Form::Field::DateTime;
use Rose::HTML::Form::Field::Compound;
our @ISA = qw(Rose::HTML::Form::Field::Compound Rose::HTML::Form::Field::DateTime);

our $VERSION = '0.02';

# Multiple inheritence never quite works out the way I want it to...
Rose::HTML::Form::Field::DateTime->import_methods
(
  'inflate_value',
  'validate',
);

Rose::HTML::Form::Field::Compound->import_methods
(
  'name',
);

1;
