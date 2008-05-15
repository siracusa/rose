package Rose::HTML::Form::Repeatable;

use strict;

use Rose::HTML::Form;

use base 'Rose::HTML::Object::Repeatable';

our $VERSION = '0.554';

__PACKAGE__->default_form_class('Rose::HTML::Form');

#
# Class methods
#

sub default_form_class { shift->default_prototype_class(@_) }

#
# Object methods
#

sub prototype_form       { shift->prototype(@_) }
sub prototype_form_spec  { shift->prototype_spec(@_) }
sub prototype_form_class { shift->prototype_class(@_) }
sub prototype_form_clone { shift->prototype_clone(@_) }

sub form_class { shift->prototype_form_class(@_) }

sub is_repeatable_form { 1 }

sub prepare
{
  my($self) = shift;
  my(%args) = @_;

  my $fq_form_name = quotemeta $self->fq_form_name;
  
  my $re = qr(^$fq_form_name\.(\d+)\.);

  my %have_num;

  foreach my $param (keys %{$self->params})
  {
    if($param =~ $re)
    {
      my $num = $1;
      $have_num{$num}++;
      my $form = $self->form($num) || $self->make_form($num);
    }
  }

  unless(%have_num)
  {
    if($self->default_count)
    {
      foreach my $num (1 .. $self->default_count)
      {
        $self->form($num) || $self->make_form($num);
        $have_num{$num}++;
      }
    }
    else
    {
      $self->delete_forms;
    }
  }

  if(%have_num)
  {
    foreach my $form ($self->forms)
    {
      unless($have_num{$form->form_name})
      {
        $self->delete_form($form->form_name);
      }
    }
  }

  $self->SUPER::prepare(@_)  unless(delete $args{'init_only'});
}

sub init_fields
{
  my($self) = shift;
  $self->prepare(init_only => 1);
  $self->SUPER::init_fields(@_);
}

sub make_form
{
  my($self, $num) = @_;

  my $form = $self->prototype_form_clone;

  $form->rank($num);

  $self->add_form($num => $form);
  
  return $form;
}

sub objects_from_form
{
  my($self) = shift;

  my $method = 'object_from_form';

  if(@_ > 1)
  {
    my %args = @_;
    $method = $args{'method'}  if($args{'method'});
  }
  
  my @objects = map { $_->$method(@_) } $self->forms;
  
  return wantarray ? @objects : \@objects;
}

sub init_with_objects
{
  my($self) = shift;

  my $method = 'init_with_object';

  if(@_ > 1)
  {
    my %args = @_;
    $method = $args{'method'}  if($args{'method'});
  }
  
  foreach my $form ($self->forms)
  {
    $form->$method(shift(@_));
  }
}

1;

__END__

=head1 NAME

Rose::HTML::Form::Repeatable - HTML form base class.

=head1 SYNOPSIS

  package Person;
  
  use base 'Rose::Object';
  
  use Rose::Object::MakeMethods::Generic
  (
    scalar => [ 'name', 'age' ],
    array  => 'emails',
  );

  ...  

  package Email;
  
  use base 'Rose::Object';
  
  use Rose::Object::MakeMethods::Generic
  (
    scalar => 
    [
      'address',
      'type' => { check_in => [ 'home', 'work' ] },
    ],
  );
  
  ...
  
  package EmailForm;

  use base 'Rose::HTML::Form';

  sub build_form 
  {
    my($self) = shift;

    $self->add_fields
    (
      address     => { type => 'email', size => 50, required => 1 },
      type        => { type => 'pop-up menu', choices => [ 'home', 'work' ],
                       required => 1, default => 'home' },
      save_button => { type => 'submit', value => 'Save Email' },
    );
  }

  sub email_from_form { shift->object_from_form('Email') }
  sub init_with_email { shift->init_with_object(@_) }

  ...

  package PersonEmailsForm;

  use base 'Rose::HTML::Form';

  sub build_form 
  {
    my($self) = shift;

    $self->add_fields
    (
      name        => { type => 'text',  size => 25, required => 1 },
      age         => { type => 'integer', min => 0 },
      save_button => { type => 'submit', value => 'Save Person' },
    );

    # A person can have several emails
    $self->add_repeatable_form(emails => EmailForm->new);
  }

  sub init_with_person
  {
    my($self, $person) = @_;

    $self->init_with_object($person);

    # Delete any existing email forms and create 
    # the appropriate number for this $person

    my $email_form = $self->form('emails');
    $email_form->delete_forms;

    my $i = 1;

    foreach my $email ($person->emails)
    {
      $email_form->make_form($i++)->init_with_email($email);
    }
  }

  sub person_from_form
  {
    my($self) = shift;

    my $person = $self->object_from_form(class => 'Person');

    my @emails;

    foreach my $form ($self->form('emails')->forms)
    {
      push(@emails, $form->email_from_form);
    }
    
    $person->emails(@emails);
    
    return $person;
  }

=head1 DESCRIPTION

XXX

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new L<Rose::HTML::Form::Repeatable> object based on PARAMS, where PARAMS are name/value pairs.  Any object method is a valid parameter name.

=back

=head1 OBJECT METHODS

=over 4

=item B<xxx ARGS>

XXX

=back

=head1 AUTHOR

John C. Siracusa (siracusa@gmail.com)

=head1 COPYRIGHT

Copyright (c) 2008 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
