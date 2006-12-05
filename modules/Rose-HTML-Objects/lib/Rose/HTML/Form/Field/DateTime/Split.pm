package Rose::HTML::Form::Field::DateTime::Split;

use strict;

use Rose::HTML::Form::Field::DateTime;
use Rose::HTML::Form::Field::Compound;
our @ISA = qw(Rose::HTML::Form::Field::Compound Rose::HTML::Form::Field::DateTime);

our $VERSION = '0.545';

# Multiple inheritence never quite works out the way I want it to...
Rose::HTML::Form::Field::DateTime->import_methods
(
  'inflate_value',
);

Rose::HTML::Form::Field::Compound->import_methods
(
  'name',
);

sub validate
{
  my($self) = shift;

  my $ok = $self->Rose::HTML::Form::Field::Compound::validate(@_);
  return $ok  unless($ok);

  return $self->Rose::HTML::Form::Field::DateTime::validate(@_);
}

1;
