package Rose::HTML::Form::Field::Repeatable;

use strict;

use Rose::HTML::Form::Field;

use base 'Rose::HTML::Object::Repeatable';

our $VERSION = '0.554';

__PACKAGE__->default_field_class('Rose::HTML::Form::Field');

#
# Class methods
#

sub default_field_class { shift->default_prototype_class(@_) }

#
# Object methods
#

sub prototype_field       { shift->prototype(@_) }
sub prototype_field_spec  { shift->prototype_spec(@_) }
sub prototype_field_clone { shift->prototype_clone(@_) }

sub is_repeatable_field { 1 }

1;
