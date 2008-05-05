#!/usr/bin/perl -w

use strict;

use Test::More 'no_plan'; #tests => 176;

BEGIN 
{
  use_ok('Rose::HTML::Form');
  use_ok('Rose::HTML::Form::Field::Text');
  use_ok('Rose::HTML::Form::Field::SelectBox');
  use_ok('Rose::HTML::Form::Field::RadioButtonGroup');
  use_ok('Rose::HTML::Form::Field::CheckboxGroup');
  use_ok('Rose::HTML::Form::Field::DateTime::Split::MonthDayYear');
  use_ok('Rose::HTML::Form::Field::DateTime::Split::MDYHMS');
}

my $form = MyPersonAddressesForm->new;

$form->params({});
$form->init_fields;

my @fields = 
  qw(person.age person.bday person.gender person.name person.start 
    address.1.city address.1.state address.1.street address.1.zip
    address.2.city address.2.state address.2.street address.2.zip);
is_deeply([ $form->field_names ], \@fields, 'person address field names');

is_deeply(scalar $form->form_names, [ 'person', 'address' ], 'person addresses form names 1');

exit;

=pod

$person_form  = $form->form('person');
is(ref $person_form, 'MyPersonForm', 'person form 1');
is($person_form->rank, 1, 'person form rank 1');
is($person_form->form_name, 'person', 'person form name 1');

$address_form = $form->form('address');
is(ref $address_form, 'MyAddressForm', 'address form 1');
is($address_form->rank, 2, 'address form rank 1');
is($address_form->form_name, 'address', 'address form name 1');

my $field = $form->field('person.bday');
is(ref $field, 'Rose::HTML::Form::Field::DateTime::Split::MonthDayYear', 'person.bday field 1');

$form->params(
{
  'person.name'    => 'John', 
  'person.age'     => ' 10 ', 
  'person.gender'  => 'm', 
  'person.bday'    => '1/2/1983',
  'address.street' => '1 Main St.', 
  'address.city'   => 'Smithtown', 
  'address.state'  => ' NY ', 
  'address.zip'    => 11787  
});

is($form->form('person')->param('person.name'), 'John', 'shared params 1');
is($form->form('address')->param('person.name'), 'John', 'shared params 2');

$form->delete_params;

is($form->form('person')->param('person.name'), undef, 'shared params 3');
is($form->form('address')->param('person.name'), undef, 'shared params 4');

$form->params(
{
  'person.name'    => 'John', 
  'person.age'     => ' 10 ', 
  'person.gender'  => 'm', 
  'person.bday'    => '1/2/1983',
  'address.street' => '1 Main St.', 
  'address.city'   => 'Smithtown', 
  'address.state'  => ' NY ', 
  'address.zip'    => 11787  
});

$form->init_fields;

is($form->field('person.name')->internal_value, 'John', 'person_address name 1');
is($form->field('person.age')->internal_value, '10', 'person_address age 1');
is($form->field('person.gender')->internal_value, 'm', 'person_address gender 1');
is($form->field('person.bday')->internal_value->strftime('%Y-%m-%d'), '1983-01-02', 'person_address bday 1');

is($form->field('address.street')->internal_value, '1 Main St.', 'person_address street 1');
is($form->field('address.city')->internal_value, 'Smithtown', 'person_address city 1');
is($form->field('address.state')->internal_value, 'NY', 'person_address state 1');
is($form->field('address.zip')->internal_value, '11787', 'person_address zip 1');

$person = $form->person_from_form;

is(ref $person, 'MyPerson', 'person_from_form 2');
is($person->name, 'John', 'person name 2');
is($person->age, '10', 'person age 2');
is($person->gender, 'm', 'person gender 2');
is($person->bday->strftime('%Y-%m-%d'), '1983-01-02', 'person bday 2');

$address = $form->address_from_form;

is(ref $address, 'MyAddress', 'address_from_form 2');
is($address->street, '1 Main St.', 'address street 2');
is($address->city, 'Smithtown', 'address city 2');
is($address->state, 'NY', 'address state 2');
is($address->zip, 11787, 'address zip 2');

$form = MyPersonAddressDogForm->new;

ok(!defined $form->form('person_address_na'), 'no such form 1');
ok(!defined $form->form('person_address.person_na'), 'no such form 2');

my $person_address_form  = $form->form('person_address');
is(ref $person_address_form, 'MyPersonAddressesForm', 'person addresses form 1');
is($person_address_form->rank, 1, 'person addresses form rank 1');
is($person_address_form->form_name, 'person_address', 'person addresses form name 1');

$person_form  = $form->form('person_address.person');
is(ref $person_form, 'MyPersonForm', 'person form 2');
is($person_form->rank, 1, 'person form rank 2');
is($person_form->form_name, 'person', 'person form name 2');

$address_form = $form->form('person_address.address');
is(ref $address_form, 'MyAddressForm', 'address form 2');
is($address_form->rank, 2, 'address form rank 2');
is($address_form->form_name, 'address', 'address form name 2');

$field = $form->field('person_address.person.age');
is($field, $person_form->field('age'), 'person_address.person.age 1');

$field = $form->field('person_address.person.bday.month');

is(ref $field, 'Rose::HTML::Form::Field::Text', 'person_address.person.bday.month verify 1');
is($field->name, 'person_address.person.bday.month', 'person_address.person.bday.month verify 2');

is($field, $person_form->field('bday.month'), 'person_address.person.bday.month 1');
is($field, $person_form->field('bday')->field('month'), 'person_address.person.bday.month 2');

is($field, $form->form('person_address')->field('person.bday.month'), 'person_address.person.bday.month 3');
is($field, $form->form('person_address')->field('person.bday')->field('month'), 'person_address.person.bday.month 4');
is($field, $form->form('person_address')->form('person')->field('bday.month'), 'person_address.person.bday.month 5');
is($field, $form->form('person_address')->form('person')->field('bday')->field('month'), 'person_address.person.bday.month 6');
is($field, $form->form('person_address.person')->field('bday.month'), 'person_address.person.bday.month 7');
is($field, $form->form('person_address.person')->field('bday')->field('month'), 'person_address.person.bday.month 8');
is($field, $form->form('person_address.person')->field('bday.month'), 'person_address.person.bday.month 9');
is($field, $form->form('person_address.person')->field('bday')->field('month'), 'person_address.person.bday.month 10');

@fields =
  qw(dog person_address.person.age person_address.person.bday
     person_address.person.gender person_address.person.name
     person_address.person.start person_address.address.city 
     person_address.address.state person_address.address.street
     person_address.address.zip);

is_deeply(scalar $form->field_monikers, \@fields, 'field_names() nested');

@fields = 
  qw(dog person_address.person.age person_address.person.bday
     person_address.person.gender person_address.person.name
     person_address.person.start person_address.address.city 
     person_address.address.state person_address.address.street
     person_address.address.zip);

is_deeply([ map { $_->name } $form->fields ], \@fields, 'fields() name nested');

$form->params(
{
  'dog'                           => 'Woof',
  'person_address.person.name'    => 'John', 
  'person_address.person.age'     => ' 10 ', 
  'person_address.person.gender'  => 'm', 
  'person_address.person.bday'    => '1/2/1983',
  'person_address.address.street' => '1 Main St.', 
  'person_address.address.city'   => 'Smithtown', 
  'person_address.address.state'  => ' NY ', 
  'person_address.address.zip'    => 11787  
});

$form->init_fields;

is($form->field('dog')->internal_value, 'Woof', 'person_address_dog dog 1');
is($form->field('person_address.person.name')->internal_value, 'John', 'person_address_dog name 1');

is($form->field('person_address.person.age')->internal_value, '10', 'person_address_dog age 1');
is($form->field('person_address.person.gender')->internal_value, 'm', 'person_address_dog gender 1');
is($form->field('person_address.person.bday')->internal_value->strftime('%Y-%m-%d'), '1983-01-02', 'person_address_dog bday 1');

is($form->field('person_address.address.street')->internal_value, '1 Main St.', 'person_address_dog street 1');
is($form->field('person_address.address.city')->internal_value, 'Smithtown', 'person_address_dog city 1');
is($form->field('person_address.address.state')->internal_value, 'NY', 'person_address_dog state 1');
is($form->field('person_address.address.zip')->internal_value, '11787', 'person_address_dog zip 1');

ok($person_address_form->validate, 'validate() 1');
ok($person_address_form->validate(cascade => 0), 'validate() 2');

$person_address_form->field('person_address.address.zip')->input_value(666);

ok(!$person_address_form->validate, 'validate() 3');
ok($person_address_form->validate(cascade => 0), 'validate() 4');

$person_address_form->field('person_address.address.zip')->input_value(11787);

$person = $form->person_from_form;

is(ref $person, 'MyPerson', 'person_from_form 3');
is($person->name, 'John', 'person name 3');
is($person->age, '10', 'person age 3');
is($person->gender, 'm', 'person gender 3');
is($person->bday->strftime('%Y-%m-%d'), '1983-01-02', 'person bday 3');

$address = $form->address_from_form;

is(ref $address, 'MyAddress', 'address_from_form 3');
is($address->street, '1 Main St.', 'address street 3');
is($address->city, 'Smithtown', 'address city 3');
is($address->state, 'NY', 'address state 3');
is($address->zip, 11787, 'address zip 3');

$form->field('person_address.person.bday.day')->input_value(7);

$person = $form->person_from_form;

is($person->bday->strftime('%Y-%m-%d'), '1983-01-07', 'person bday change 1');

$form->params(
{
  'dog'                           => 'Woof',
  'person_address.person.name'    => 'John', 
  'person_address.person.age'     => ' 10 ', 
  'person_address.person.gender'  => 'm', 
  'person_address.person.bday'    => '1/2/1983',
  'person_address.address.street' => '1 Main St.', 
  'person_address.address.city'   => 'Smithtown', 
  'person_address.address.state'  => ' NY ', 
  'person_address.address.zip'    => 11787,
  'person_address.person.start'   => '2/3/2004 1:23pm',
});

$form->init_fields;

is($form->field('person_address.person.start')->internal_value->strftime('%Y-%m-%d %H:%M:%S'), '2004-02-03 13:23:00', 'person_address_dog start 1');

$person = $form->person_from_form;
is($person->start->strftime('%Y-%m-%d %H:%M:%S'), '2004-02-03 13:23:00', 'person start 1');

$field = $form->field('person_address.person.start.time.ampm');
$person_form  = $form->form('person_address.person');
$address_form = $form->form('person_address.address');

is(ref $field, 'Rose::HTML::Form::Field::PopUpMenu', 'person_address.person.start.time.ampm verify 1');
is($field->name, 'person_address.person.start.time.ampm', 'person_address.person.start.time.ampm verify 2');

is($field, $person_form->field('start.time.ampm'), 'person_address.person.start.time.ampm 1');
is($field, $person_form->field('start')->field('time')->field('ampm'), 'person_address.person.start.time.ampm 2');

is($field, $form->form('person_address')->field('person.start.time')->field('ampm'), 'person_address.person.start.time.ampm 3');
is($field, $form->form('person_address')->field('person.start')->field('time.ampm'), 'person_address.person.start.time.ampm 4');
is($field, $form->form('person_address')->form('person')->field('start.time.ampm'), 'person_address.person.start.time.ampm 5');
is($field, $form->form('person_address')->form('person')->field('start')->field('time')->field('ampm'), 'person_address.person.start.time.ampm 6');
is($field, $form->form('person_address.person')->field('start.time.ampm'), 'person_address.person.start.time.ampm 7');
is($field, $form->form('person_address.person')->field('start')->field('time.ampm'), 'person_address.person.start.time.ampm 8');
is($field, $form->form('person_address.person')->field('start')->field('time')->field('ampm'), 'person_address.person.start.time.ampm 9');

#
# Rename forms
#

$form->clear;
$form->form('person_address')->form_name('pa');

$form->params(
{
  'dog'               => 'Woof',
  'pa.person.name'    => 'John', 
  'pa.person.age'     => ' 10 ', 
  'pa.person.gender'  => 'm', 
  'pa.person.bday'    => '1/2/1983',
  'pa.address.street' => '1 Main St.', 
  'pa.address.city'   => 'Smithtown', 
  'pa.address.state'  => ' NY ', 
  'pa.address.zip'    => 11787,
  'pa.person.start'   => '2/3/2004 1:23pm',
});

$form->init_fields;

is($form->field('pa.person.start')->internal_value->strftime('%Y-%m-%d %H:%M:%S'), '2004-02-03 13:23:00', 'person_address_dog start 2');

$person = $form->person_from_form;
is($person->start->strftime('%Y-%m-%d %H:%M:%S'), '2004-02-03 13:23:00', 'person start 2');

$field = $form->field('pa.person.start.time.ampm');
$person_form  = $form->form('pa.person');
$address_form = $form->form('pa.address');

is(ref $field, 'Rose::HTML::Form::Field::PopUpMenu', 'pa.person.start.time.ampm verify 1');
is($field->name, 'pa.person.start.time.ampm', 'pa.person.start.time.ampm verify 2');

is($field, $person_form->field('start.time.ampm'), 'pa.person.start.time.ampm 1');
is($field, $person_form->field('start')->field('time')->field('ampm'), 'pa.person.start.time.ampm 2');

is($field, $form->form('pa')->field('person.start.time')->field('ampm'), 'pa.person.start.time.ampm 3');
is($field, $form->form('pa')->field('person.start')->field('time.ampm'), 'pa.person.start.time.ampm 4');
is($field, $form->form('pa')->form('person')->field('start.time.ampm'), 'pa.person.start.time.ampm 5');
is($field, $form->form('pa')->form('person')->field('start')->field('time')->field('ampm'), 'pa.person.start.time.ampm 6');
is($field, $form->form('pa.person')->field('start.time.ampm'), 'pa.person.start.time.ampm 7');
is($field, $form->form('pa.person')->field('start')->field('time.ampm'), 'pa.person.start.time.ampm 8');
is($field, $form->form('pa.person')->field('start')->field('time')->field('ampm'), 'pa.person.start.time.ampm 9');

$form->clear;
$form->form('pa.person')->form_name('p');

$form->params(
{
  'dog'               => 'Woof',
  'pa.p.name'         => 'John', 
  'pa.p.age'          => ' 10 ', 
  'pa.p.gender'       => 'm', 
  'pa.p.bday'         => '1/2/1983',
  'pa.address.street' => '1 Main St.', 
  'pa.address.city'   => 'Smithtown', 
  'pa.address.state'  => ' NY ', 
  'pa.address.zip'    => 11787,
  'pa.p.start'        => '2/3/2004 1:23pm',
});

$form->init_fields;

is($form->field('pa.p.start')->internal_value->strftime('%Y-%m-%d %H:%M:%S'), '2004-02-03 13:23:00', 'person_address_dog start 3');

$person = $form->person_from_form;
is($person->start->strftime('%Y-%m-%d %H:%M:%S'), '2004-02-03 13:23:00', 'person start 3');

$field = $form->field('pa.p.start.time.ampm');
$person_form  = $form->form('pa.p');
$address_form = $form->form('pa.address');

is(ref $field, 'Rose::HTML::Form::Field::PopUpMenu', 'pa.p.start.time.ampm verify 1');
is($field->name, 'pa.p.start.time.ampm', 'pa.p.start.time.ampm verify 2');

is($field, $person_form->field('start.time.ampm'), 'pa.p.start.time.ampm 1');
is($field, $person_form->field('start')->field('time')->field('ampm'), 'pa.p.start.time.ampm 2');

is($field, $form->form('pa')->field('p.start.time')->field('ampm'), 'pa.p.start.time.ampm 3');
is($field, $form->form('pa')->field('p.start')->field('time.ampm'), 'pa.p.start.time.ampm 4');
is($field, $form->form('pa')->form('p')->field('start.time.ampm'), 'pa.p.start.time.ampm 5');
is($field, $form->form('pa')->form('p')->field('start')->field('time')->field('ampm'), 'pa.p.start.time.ampm 6');
is($field, $form->form('pa.p')->field('start.time.ampm'), 'pa.p.start.time.ampm 7');
is($field, $form->form('pa.p')->field('start')->field('time.ampm'), 'pa.p.start.time.ampm 8');
is($field, $form->form('pa.p')->field('start')->field('time')->field('ampm'), 'pa.p.start.time.ampm 9');

#
# Rename fields
#

$form->field('pa.p.start')->name('st');

$form->params(
{
  'dog'               => 'Woof',
  'pa.p.name'         => 'John', 
  'pa.p.age'          => ' 10 ', 
  'pa.p.gender'       => 'm', 
  'pa.p.bday'         => '1/2/1983',
  'pa.address.street' => '1 Main St.', 
  'pa.address.city'   => 'Smithtown', 
  'pa.address.state'  => ' NY ', 
  'pa.address.zip'    => 11787,
  'pa.p.st'           => '2/3/2004 1:23pm',
});

$form->init_fields;

is($form->field('pa.p.st')->internal_value->strftime('%Y-%m-%d %H:%M:%S'), '2004-02-03 13:23:00', 'person_address_dog start 4');

$field = $form->field('pa.p.st.time.ampm');
$person_form  = $form->form('pa.p');
$address_form = $form->form('pa.address');

is(ref $field, 'Rose::HTML::Form::Field::PopUpMenu', 'pa.p.st.time.ampm verify 1');
is($field->name, 'pa.p.st.time.ampm', 'pa.p.st.time.ampm verify 2');

is($field, $person_form->field('st.time.ampm'), 'pa.p.st.time.ampm 1');
is($field, $person_form->field('st')->field('time')->field('ampm'), 'pa.p.st.time.ampm 2');

is($field, $form->form('pa')->field('p.st.time')->field('ampm'), 'pa.p.st.time.ampm 3');
is($field, $form->form('pa')->field('p.st')->field('time.ampm'), 'pa.p.st.time.ampm 4');
is($field, $form->form('pa')->form('p')->field('st.time.ampm'), 'pa.p.st.time.ampm 5');
is($field, $form->form('pa')->form('p')->field('st')->field('time')->field('ampm'), 'pa.p.st.time.ampm 6');
is($field, $form->form('pa.p')->field('st.time.ampm'), 'pa.p.st.time.ampm 7');
is($field, $form->form('pa.p')->field('st')->field('time.ampm'), 'pa.p.st.time.ampm 8');
is($field, $form->form('pa.p')->field('st')->field('time')->field('ampm'), 'pa.p.st.time.ampm 9');

is($field->html, 
   qq(<select class="ampm" name="pa.p.st.time.ampm" size="1">\n) .
   qq(<option value=""></option>\n) .
   qq(<option value="AM">AM</option>\n) .
   qq(<option selected value="PM">PM</option>\n) .
   qq(</select>),
   'pa.p.st.time.ampm html 2');

#
# Check nested set
#

# Set nested form from the top-level
my $w_form = Rose::HTML::Form->new;
my $x_form = Rose::HTML::Form->new;
my $y_form = Rose::HTML::Form->new;
my $z_form = Rose::HTML::Form->new;

is(scalar @{ $w_form->children }, 0, 'children scalar 1');
is(scalar(() = $w_form->children), 0, 'children list 1');

$w_form->add_form('x' => $x_form);
$x_form->add_form('y' => $y_form);

is(scalar @{ $w_form->children }, 0, 'children scalar 2');
is(scalar(() = $w_form->children), 0, 'children list 2');

# Add $z_form to $w_form->form('x')->form('y') under the name 'z'
$w_form->add_form('x.y.z' => $z_form);

is($z_form, $w_form->form('x')->form('y')->form('z'), 'nested set 1');

# Test a nested field with the same name as a field in the parent

my $f1 = Rose::HTML::Form->new();

$f1->add_fields
(
  id => { type => 'int' },
);

my $f2 = Rose::HTML::Form->new();

$f2->add_fields
(
  id => { type => 'text' },
);

$f1->add_form(f2 => $f2);

is(join(',', sort map { $_->name } $f1->fields), 'f2.id,id', 'nested same-name fields');

$form = Rose::HTML::Form->new;
$form->add_field(foo => { type => 'text' });

my $subform = Rose::HTML::Form->new;
$subform->add_field(bar => { type => 'text' });

$form->add_form(sub => $subform);
#local $Rose::HTML::Form::Debug = 1;
# Call validate() on fields "foo" and "sub.bar" and
# call validate(form_only => 1) on the sub-form "sub"
$form->validate;
#print STDERR "---\n";
# Same as above
$form->validate(cascade => 1);
#print STDERR "---\n";
# Call validate() on fields "foo" and "sub.bar"
$form->validate(cascade => 0);
#print STDERR "---\n";
# Call validate(form_only => 1) on the sub-form "sub"
$form->validate(form_only => 1);
#print STDERR "---\n";
# Don't call validate() on any fields or sub-forms
$form->validate(form_only => 1, cascade => 0);

# no warnings 'redefine';
# *MyAddressForm::validate = sub
# {
#   my($self) = shift;
#   $self->field('street')->error('Blah');
#   $self->Rose::HTML::Form::validate(@_);
# };

$form = MyPersonAddressesForm->new;

$form->add_field(x => { type => 'text' });
$form->validate();

is($form->field('address.street')->error, 'Blah', 'nested validate');

$f1 = Rose::HTML::Form->new;
$f2 = Rose::HTML::Form->new;

$f2->add_fields
(
  bar =>
  {
    type    => 'radio group',
    choices => [ 'Yes', 'No' ],
  },
);

$f1->add_form(subform => $f2);

is(join("\n", map { $_->html } $f1->fields),
   qq(<input name="subform.bar" type="radio" value="Yes"> <label>Yes</label><br>\n) .
   qq(<input name="subform.bar" type="radio" value="No"> <label>No</label>),
   'nested grouped fields 1');

#
# Modifying nested fields
#

my $f = MyPersonForm->new;

$f->add_form(n => MyPersonForm->new);

is(join(', ', map { $_->name } $f->fields), 'age, bday, gender, name, start, n.age, n.bday, n.gender, n.name, n.start', 'nested modification 1');

$f->form('n')->add_field('new' => { type => 'text' });

is(join(', ', map { $_->name } $f->fields), 'age, bday, gender, name, start, n.age, n.bday, n.gender, n.name, n.new, n.start', 'nested modification 2');

#
# local_fields()
#

$form = MyPersonAddressDogForm->new;

is(join(' ', map { $_->name } sort { $a->name cmp $b->name } $form->local_fields), 'dog', 'local fields 1');

$form->add_field(bar => { type => 'text' });

is(join(' ', map { $_->name } sort { $a->name cmp $b->name } $form->local_fields), 'bar dog', 'local fields 2');
is(join(' ', map { $_->name } sort { $a->name cmp $b->name } $form->form('person_address')->local_fields), '', 'local fields 3');
is(join(' ', map { $_->name } sort { $a->name cmp $b->name } $form->form('person_address.person')->local_fields), 'person_address.person.age person_address.person.bday person_address.person.gender person_address.person.name person_address.person.start', 'local fields 4');
is(join(' ', map { $_->local_name } sort { $a->local_name cmp $b->local_name } $form->form('person_address.person')->local_fields), 'age bday gender name start', 'local fields 5');

=cut

BEGIN
{
  package MyPerson;

  our @ISA = qw(Rose::Object);
  use Rose::Object::MakeMethods::Generic
  (
    scalar => [ qw(name age bday gender start) ],
  );

  package MyAddress;

  our @ISA = qw(Rose::Object);
  use Rose::Object::MakeMethods::Generic
  (
    scalar => [ qw(street city state zip) ],
  );

  package MyPersonForm;

  our @ISA = qw(Rose::HTML::Form);

  sub build_form 
  {
    my($self) = shift;

    $self->add_fields
    (
      name =>
      {
        type => 'text',
        size => 25,
      },
      
      age =>
      {
        type     => 'integer',
        positive => 1,
      },
      
      gender =>
      {
        type     => 'radio group',
        choices  => { 'm' => 'Male', 'f' => 'Female' },
        default  => 'm',
      },
      
      bday =>
      {
        type => 'datetime split mdy', 
      },
      
      start =>
      {
        type => 'datetime split mdyhms',
      },
    );
  }

  sub person_from_form { shift->object_from_form('MyPerson') }

  package MyAddressForm;

  our @ISA = qw(Rose::HTML::Form);

  sub build_form 
  {
    my($self) = shift;

    $self->add_fields
    (
      street =>
      {
        type => 'text',
        size => 25,
      },
  
      city => 
      {
        type => 'text',
        size => 25,
      },
  
      state => 
      {
        type => 'text',
        size => 2,
      },
  
      zip => 
      {
        type => 'text',
        size => 10,
      },
    );
  }

  sub validate
  {
    my($self) = shift;

    $self->SUPER::validate or return 0;
    $self->field('street')->error('Blah');
    no warnings 'uninitialized';
    return ($self->field('zip')->internal_value == 666) ? 0 : 1;
  }

  sub address_from_form { shift->object_from_form('MyAddress') }

  package MyPersonAddressesForm;

  our @ISA = qw(Rose::HTML::Form);

  sub build_form
  {
    my($self) = shift;

    $self->add_forms
    (
      person  => MyPersonForm->new,
      address => 
      {
        form       => MyAddressForm->new,
        repeatable => 2,
      }
    );
  }

  package MyPersonAddressDogForm;

  our @ISA = qw(MyAddressForm MyPersonForm);

  sub build_form 
  {
    my($self) = shift;

    my %fields;

    $fields{'dog'} = 
      Rose::HTML::Form::Field::Text->new(
        name => 'dog',
        size => 50);

    $self->add_fields(%fields);

    $self->add_forms
    (
      person_addresses => MyPersonAddressesForm->new,
    );
  }
}
