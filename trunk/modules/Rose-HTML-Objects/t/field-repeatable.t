#!/usr/bin/perl -w

use strict;

use Test::More 'no_plan'; #tests => 174;

BEGIN 
{
  use_ok('Rose::HTML::Form');
  use_ok('Rose::HTML::Form::Field::Text');
  use_ok('Rose::HTML::Form::Field::Integer');
  use_ok('Rose::HTML::Form::Field::SelectBox');
  use_ok('Rose::HTML::Form::Field::RadioButtonGroup');
  use_ok('Rose::HTML::Form::Field::CheckboxGroup');
  use_ok('Rose::HTML::Form::Field::DateTime::Split::MonthDayYear');
  use_ok('Rose::HTML::Form::Field::DateTime::Split::MDYHMS');
}

my $f = MyPersonForm->new;

$f->add_form(n => MyPersonForm->new);

print join(', ', map { $_->name } $f->fields), "\n";

$f->form('n')->add_field('new' => { type => 'text' });

print join(', ', map { $_->name } $f->fields), "\n";

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
      
      #repeatable =>
      #{
      #  field =>
      #  {
      #    name => 'nickname',
      #    type => 'text',
      #    size => 25,
      #  },
      #  default_count => 3,
      #},
    );
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

  sub validate
  {
    my($self) = shift;

    $self->SUPER::validate or return 0;
    $self->field('street')->error('Blah');
    no warnings 'uninitialized';
    return ($self->field('zip')->internal_value == 666) ? 0 : 1;
  }

  sub address_from_form { shift->object_from_form('MyAddress') }

  package MyPersonAddressForm;

  our @ISA = qw(Rose::HTML::Form); #qw(MyAddressForm MyPersonForm);

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
