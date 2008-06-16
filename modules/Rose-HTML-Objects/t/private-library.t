#!/usr/bin/perl -w

use strict;

use Test::More 'no_plan'; #tests => 258;

use_ok('Rose::HTML::Objects');

my %code =
(
  'My::HTML::Object::Message::Localizer' =><<'EOF',
sub get_localized_message_text
{
  my($self) = shift;
  no warnings 'uninitialized';
  return uc $self->SUPER::get_localized_message_text(@_);
}
EOF
);

my($packages, $perl) = 
  Rose::HTML::Objects->private_library_perl(in_memory => 1, 
                                            prefix    => 'My::',
                                            code      => \%code);

foreach my $pkg (@$packages)
{
  my $code = $perl->{$pkg};
  print $code, "\n";
  eval $code;
  die "Could not eval $pkg - $@"  if($@);
}

my $field     = My::HTML::Form::Field::Text->new(name => 'x', required => 1);
my $std_field = Rose::HTML::Form::Field::Text->new(name => 'x', required => 1);

$field->validate;
$std_field->validate;

is($field->error, uc $std_field->error, 'upcase error 1');

$field = My::HTML::Form::Field::PopUpMenu->new(name => 'x');

$field->options(a => 'Apple', b => 'Pear');

is(ref $field->option('a'), 'My::HTML::Form::Field::Option', 'option 1');
