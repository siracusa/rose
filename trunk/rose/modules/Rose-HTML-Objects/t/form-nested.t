#!/usr/bin/perl -w

use strict;

use Test::More 'no_plan'; #tests => 89;

BEGIN 
{
  use_ok('Rose::HTML::Form');
  use_ok('Rose::HTML::Form::Field::Text');
  use_ok('Rose::HTML::Form::Field::SelectBox');
  use_ok('Rose::HTML::Form::Field::RadioButtonGroup');
  use_ok('Rose::HTML::Form::Field::CheckBoxGroup');
  use_ok('Rose::HTML::Form::Field::DateTime::Split::MonthDayYear');
  use_ok('Rose::HTML::Form::Field::DateTime::Split::MDYHMS');
}

my $person_form = MyPersonForm->new;

my @fields = qw(age bday gender your_name);
is_deeply([ $person_form->field_monikers ], \@fields, 'person field monikers');
@fields = qw(age bday gender name);
is_deeply([ sort keys %{ $person_form->{'fields_by_name'} } ], \@fields, 'person field names 1');
is_deeply([ map { $_->name } $person_form->fields ], \@fields, 'person field names 2');

$person_form->params({ name => 'John', age => ' 10 ', gender => 'm', bday => '1/2/1983' });
$person_form->init_fields;

my $person = $person_form->person_from_form;

is(ref $person, 'MyPerson', 'person_from_form 1');
is($person->name, 'John', 'person name 1');
is($person->age, '10', 'person age 1');
is($person->gender, 'm', 'person gender 1');
is($person->bday->strftime('%Y-%m-%d'), '1983-01-02', 'person bday 1');

my $address_form = MyAddressForm->new;

@fields = qw(city your_state street zip);
is_deeply([ $address_form->field_monikers ], \@fields, 'address field monikers');
@fields = qw(city state street zip);
is_deeply([ sort keys %{ $address_form->{'fields_by_name'} } ], \@fields, 'address field names 1');
is_deeply([ map { $_->name } $address_form->fields ], \@fields, 'address field names 2');

$address_form->params({ street => '1 Main St.', city => 'Smithtown', state => ' NY ', zip => 11787  });
$address_form->init_fields;

my $address = $address_form->address_from_form;

is(ref $address, 'MyAddress', 'address_from_form 1');
is($address->street, '1 Main St.', 'address street 1');
is($address->city, 'Smithtown', 'address city 1');
is($address->state, 'NY', 'address state 1');
is($address->zip, 11787, 'address zip 1');

my $form = MyPersonAddressForm->new;

@fields = qw(person.age person.bday person.gender person.your_name address.city address.your_state address.street address.zip);
is_deeply([ $form->field_monikers ], \@fields, 'person address field monikers');
@fields = qw(address.city address.state address.street address.zip person.age person.bday person.gender person.name);
is_deeply([ sort keys %{ $form->{'fields_by_name'} } ], \@fields, 'person address field names 1');
@fields = qw(person.age person.bday person.gender person.name address.city address.state address.street address.zip);
is_deeply([ map { $_->name } $form->fields ], \@fields, 'person address field names 2');

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

# print $field->name, "\n";
# $DB::single = 1;
# print $form->field('person.bday.month'), "\n";
# 
# my $f = $form->fields;
# my $fields = join(',', map { $_->name } $form->fields);
# 
# print $fields, "\n";

# $DB::single = 1;
# my @ff =  $form->fields;
# print join(' ',  $form->field_monikers), "\n";
# print join(' ', sort keys %{ $form->{'fields_by_name'} }), "\n";
# print join(' ', map { $_->name } $form->fields), "\n";
# exit;

$form->params(
{
  'person.name'    => 'John', 
  'person.age' 	   => ' 10 ', 
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
is($form->field('person.gender')->internal_value->[0], 'm', 'person_address gender 1');
is($form->field('person.bday')->internal_value->strftime('%Y-%m-%d'), '1983-01-02', 'person_address bday 1');

is($form->field('address.street')->internal_value, '1 Main St.', 'person_address street 1');
is($form->field('address.city')->internal_value, 'Smithtown', 'person_address city 1');
is($form->field('address.state')->internal_value, 'NY', 'person_address state 1');
is($form->field('address.zip')->internal_value, '11787', 'person_address zip 1');

# $person = $form->person_from_form;
# 
# is(ref $person, 'MyPerson', 'person_from_form 1');
# is($person->name, 'John', 'person name 1');
# is($person->age, '10', 'person age 1');
# is($person->gender, 'm', 'person gender 1');
# is($person->bday->strftime('%Y-%m-%d'), '1983-01-02', 'person bday 1');
# 
# $address = $form->address_from_form;
# 
# is(ref $address, 'MyAddress', 'address_from_form 1');
# is($address->street, '1 Main St.', 'address street 1');
# is($address->city, 'Smithtown', 'address city 1');
# is($address->state, 'NY', 'address state 1');
# is($address->zip, 11787, 'address zip 1');

$form = MyPersonAddressDogForm->new;

ok(!defined $form->form('person_address_na'), 'no such form 1');
ok(!defined $form->form('person_address.person_na'), 'no such form 2');

my $person_address_form  = $form->form('person_address');
is(ref $person_address_form, 'MyPersonAddressForm', 'person address form 1');
is($person_address_form->rank, 1, 'person address form rank 1');
is($person_address_form->form_name, 'person_address', 'person address form name 1');

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
     person_address.person.gender person_address.person.your_name
     person_address.address.city person_address.address.your_state
     person_address.address.street person_address.address.zip);

is_deeply(scalar $form->field_monikers, \@fields, 'field_names() nested');

@fields = 
  qw(dog person_address.person.age person_address.person.bday
     person_address.person.gender person_address.person.name
     person_address.address.city person_address.address.state
     person_address.address.street person_address.address.zip);

is_deeply([ map { $_->name } $form->fields ], \@fields, 'fields() name nested');

$form->params(
{
  'dog'                           => 'Woof',
  'person_address.person.name'    => 'John', 
  'person_address.person.age' 	  => ' 10 ', 
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
is($form->field('person_address.person.gender')->internal_value->[0], 'm', 'person_address_dog gender 1');
is($form->field('person_address.person.bday')->internal_value->strftime('%Y-%m-%d'), '1983-01-02', 'person_address_dog bday 1');

is($form->field('person_address.address.street')->internal_value, '1 Main St.', 'person_address_dog street 1');
is($form->field('person_address.address.city')->internal_value, 'Smithtown', 'person_address_dog city 1');
is($form->field('person_address.address.state')->internal_value, 'NY', 'person_address_dog state 1');
is($form->field('person_address.address.zip')->internal_value, '11787', 'person_address_dog zip 1');

# my @f = $form->fields;
# print join(', ',  $form->field_monikers), "\n";
# print join(', ', sort keys %{ $form->{'fields_by_name'} }), "\n";
# print join(' ', map { $_->name } $form->fields), "\n";

BEGIN
{
  package MyPerson;

  our @ISA = qw(Rose::Object);
  use Rose::Object::MakeMethods::Generic
  (
    scalar => [ qw(name age bday gender) ],
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

    my %fields;

    $fields{'your_name'} = 
      Rose::HTML::Form::Field::Text->new(
        name => 'name',
        size => 25);

    $fields{'age'} = 
      Rose::HTML::Form::Field::Text->new(
        name => 'age',
        size => 3);

    $fields{'gender'} = 
      Rose::HTML::Form::Field::RadioButtonGroup->new(
        name          => 'gender',
        radio_buttons => { 'm' => 'Male', 'f' => 'Female' },
        default       => 'm');

    $fields{'bday'} = 
      Rose::HTML::Form::Field::DateTime::Split::MonthDayYear->new(
        name => 'bday');

    $self->add_fields(%fields);
  }

  sub person_from_form { shift->object_from_form('MyPerson') }

  package MyAddressForm;

  our @ISA = qw(Rose::HTML::Form);

  sub build_form 
  {
    my($self) = shift;

    my %fields;

    $fields{'street'} = 
      Rose::HTML::Form::Field::Text->new(
        name => 'street',
        size => 25);

    $fields{'city'} = 
      Rose::HTML::Form::Field::Text->new(
        name => 'city',
        size => 25);

    $fields{'your_state'} = 
      Rose::HTML::Form::Field::Text->new(
        name => 'state',
        size => 2);

    $fields{'zip'} = 
      Rose::HTML::Form::Field::Text->new(
        name => 'zip',
        size => 2);

    $self->add_fields(%fields);
  }

  sub address_from_form { shift->object_from_form('MyAddress') }

  package MyPersonAddressForm;

  our @ISA = qw(MyAddressForm MyPersonForm);

  sub build_form 
  {
    my($self) = shift;

	$self->add_forms
	(
	  person  => MyPersonForm->new,
	  address => MyAddressForm->new,
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
	  person_address  => MyPersonAddressForm->new,
	);
  }
}

# package MyPersonForm;
# use base 'Rose::HTML::Form';
# sub build_form 
# {
#   shift->add_fields
#   (
#     name   => 'text',
#     age    => { type => 'text', size => 3 },
#     bday   => 'date mdy split',
#     gender => { 'radio group' choices => { 'm' => 'Male', 'f' => 'Female' },
#                 default => 'm' },
#   );
# }
# 
# package MyAddressForm;
# use base 'Rose::HTML::Form';
# sub build_form 
# {
#   shift->add_fields
#   (
#     street => 'text',
#     city   => 'text',
#     state  => { type => 'text', size => 2 },
#     zip    => 'us zipcode',
#   );
# }
# 
# package MyPersonAddressForm;
# use base 'Rose::HTML::Form';
# sub build_form 
# {
#   shift->add_forms
#   (
# 	person  => MyPersonForm->new,
# 	address => MyAddressForm->new,
#   );
# }
# 
# package MyPersonAddressDogForm;
# use base 'Rose::HTML::Form';
# sub build_form 
# {
#   my($self) = shift;
#   $self->add_field('dog');
#   $self->add_forms(person_address => MyPersonAddressForm->new);
# }
# 
# ...
# 
# # Field addressing: 5 ways to get at the same field
# $form->field('person_address.person.bday.month')
# $form->form('person_address')->field('person.bday.month')
# $form->form('person_address')->field('person.bday')->field('month')
# $form->form('person_address')->form('person')->field('bday.month')
# $form->form('person_address')->form('person')->field('bday')->field('month')
