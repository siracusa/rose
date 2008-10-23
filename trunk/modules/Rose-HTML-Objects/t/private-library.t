#!/usr/bin/perl -w

use strict;

use FindBin qw($Bin);

use Test::More 'no_plan'; #tests => 258;

use_ok('Rose::HTML::Objects');

use File::Spec;
use File::Path;

#
# In-memory
#

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
  Rose::HTML::Objects->make_private_library(in_memory => 1, 
                                            prefix    => 'My::',
                                            code      => \%code);

my $field     = My::HTML::Form::Field::Text->new(name => 'x', required => 1);
my $std_field = Rose::HTML::Form::Field::Text->new(name => 'x', required => 1);

$field->validate;
$std_field->validate;

is($field->error, uc $std_field->error, 'upcase error 1');

$field = My::HTML::Form::Field::PopUpMenu->new(name => 'x');

$field->options(a => 'Apple', b => 'Pear');

is(ref $field->option('a'), 'My::HTML::Form::Field::Option', 'option 1');

my $object = My::HTML::Object->new('xyz');

is($object->validate_html_attrs, 0, 'generic object 1');

eval { $object->html_attr(foo => 'bar') };
ok(!$@, 'generic object 2');

foreach my $type (My::HTML::Object->object_type_names)
{
  my $std_class = Rose::HTML::Object->object_type_class($type);
  (my $new_class = $std_class) =~ s/^Rose::/My::/;
  
  is(My::HTML::Object->object_type_class($type), $new_class, "object type class: $type");
}

#
# Module files
#

my $lib_dir = File::Spec->catfile($Bin, 'tmplib');

mkdir($lib_dir)  unless(-d $lib_dir);
die "Could not mkdir($lib_dir) - $!"  unless(-d $lib_dir);

%code =
(
  'My2::HTML::Object::Message::Localizer' =><<'EOF',
sub get_localized_message_text
{
  my($self) = shift;
  no warnings 'uninitialized';
  return rand > 0.5 ? uc $self->SUPER::get_localized_message_text(@_) :
                      lc $self->SUPER::get_localized_message_text(@_);
}
EOF
);

$packages =
  Rose::HTML::Objects->make_private_library(modules_dir => $lib_dir, 
                                            prefix      => 'My2::',
                                            code        => \%code);

unshift(@INC, $lib_dir);

require My2::HTML::Form::Field::Text;

$field     = My2::HTML::Form::Field::Text->new(name => 'x', required => 1);
$std_field = Rose::HTML::Form::Field::Text->new(name => 'x', required => 1);

$field->validate;
$std_field->validate;

my @errors;

for(1 .. 10)
{
  push(@errors, $field->error . '');
}

ok((scalar grep { lc $std_field->error } @errors), 'lowercase error 1');
ok((scalar grep { lc $std_field->error } @errors), 'uppercase error 1');

require My2::HTML::Form::Field::PopUpMenu;

$field = My2::HTML::Form::Field::PopUpMenu->new(name => 'x');

$field->options(a => 'Apple', b => 'Pear');

is(ref $field->option('a'), 'My2::HTML::Form::Field::Option', 'option 1');
exit;
require My2::HTML::Object;

$object = My2::HTML::Object->new('xyz');

is($object->validate_html_attrs, 0, 'generic object 1');

eval { $object->html_attr(foo => 'bar') };
ok(!$@, 'generic object 2');

foreach my $type (My2::HTML::Object->object_type_names)
{
  my $std_class = Rose::HTML::Object->object_type_class($type);
  (my $new_class = $std_class) =~ s/^Rose::/My2::/;
  
  is(My2::HTML::Object->object_type_class($type), $new_class, "object type class: $type");
}

END
{
  if($lib_dir && -d $lib_dir)
  {
    #rmtree($lib_dir);
  }
}
