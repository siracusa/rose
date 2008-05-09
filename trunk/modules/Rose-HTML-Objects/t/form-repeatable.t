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
is_deeply([ $form->field_names ], \@fields, 'person address field names 1');

is_deeply(scalar $form->form_names, [ 'person', 'address' ], 'person addresses form names 1');

$form->params({ 'person.age' => 10, 'address.1.state' => undef, 'address.2.street' => '1 Main St.', 'address.3.zip' => 12345 });

$form->init_fields;

@fields = 
  qw(person.age person.bday person.gender person.name person.start 
     address.1.city address.1.state address.1.street address.1.zip
     address.2.city address.2.state address.2.street address.2.zip
     address.3.city address.3.state address.3.street address.3.zip);

is_deeply([ $form->field_names ], \@fields, 'person address field names 2');

$form->params({ 'person.age' => 10 });

$form->init_fields;

@fields = 
  qw(person.age person.bday person.gender person.name person.start 
     address.1.city address.1.state address.1.street address.1.zip
     address.2.city address.2.state address.2.street address.2.zip);

is_deeply([ $form->field_names ], \@fields, 'person address field names 3');

$form->form('address')->default_count(1);

$form->init_fields;

@fields = 
  qw(person.age person.bday person.gender person.name person.start 
     address.1.city address.1.state address.1.street address.1.zip);

is_deeply([ $form->field_names ], \@fields, 'person address field names 4');

$form->params({ 'person.age' => 10, 'address.1.state' => undef, 'address.2.street' => '1 Main St.', 'address.3.zip' => 12345 });

$form->init_fields;

$form->params({ 'person.age' => 10 });

$form->form('address')->default_count(0);

$form->init_fields;

@fields = qw(person.age person.bday person.gender person.name person.start);

is_deeply([ $form->field_names ], \@fields, 'person address field names 5');

$form->params({ 'person.age' => 10, 'address.1.state' => undef, 'address.2.street' => '1 Main St.', 'address.3.zip' => 12345 });

$form->init_fields;

@fields = 
  qw(person.age person.bday person.gender person.name person.start 
     address.1.city address.1.state address.1.street address.1.zip
     address.2.city address.2.state address.2.street address.2.zip
     address.3.city address.3.state address.3.street address.3.zip);

is_deeply([ $form->field_names ], \@fields, 'person address field names 6');


my $form_b = Rose::HTML::Form->new;
$form_b->add_field(b => { type => 'text' });

my $form_c = Rose::HTML::Form->new;
$form_c->add_field(c => { type => 'text' });

$form_b->add_repeatable_form(c => $form_c);
$form_b->repeatable_form('c')->default_count(2);

$form = Rose::HTML::Form->new;
$form->add_field(a => { type => 'text' });

$form->add_form(b => $form_b);

$form->init_fields;

@fields = qw(a b.b b.c.1.c b.c.2.c);
is_deeply([ $form->field_names ], \@fields, 'two-level repeate 1');

$form->params({ a => 'a', 'b.b' => 'bb', 'b.c.3.c' => 'bc3' });
$form->init_fields;
@fields = qw(a b.b b.c.3.c);
is_deeply([ $form->field_names ], \@fields, 'two-level repeate 2');

$form->params({ 'b.c.3.c' => 'bc3', 'b.c.1.c' => 'bc1' });
$form->init_fields;
@fields = qw(a b.b b.c.1.c b.c.3.c);
is_deeply([ $form->field_names ], \@fields, 'two-level repeate 3');

$form->params({ 'b.c.3.c' => 'bc3', 'b.c.2.c' => undef, 'b.c.1.c' => 'bc1' });
$form->init_fields;
@fields = qw(a b.b b.c.1.c b.c.2.c b.c.3.c);
is_deeply([ $form->field_names ], \@fields, 'two-level repeate 4');


my $form_x = Rose::HTML::Form->new;
$form_x->add_field(x => { type => 'text' });

$form_x->add_repeatable_form(f => $form);
$form_x->repeatable_form('f')->default_count(2);

$form_x->init_fields;
#print join(' ', $form_x->field_names), "\n";

#print $form_x->xhtml_table;
exit;

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
