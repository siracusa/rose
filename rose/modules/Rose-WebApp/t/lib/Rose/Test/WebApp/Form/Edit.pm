package Rose::Test::WebApp::Form::Edit;

use strict;

use Rose::HTML::Form;
our @ISA = qw(Rose::HTML::Form);

use Rose::HTML::Form::Field::Text;
use Rose::HTML::Form::Field::Email;
use Rose::HTML::Form::Field::Submit;

sub build_form
{
  my($self) = shift;

  my %fields;

  $fields{'name'} =
    Rose::HTML::Form::Field::Text->new(name     => 'name',
                                       label    => 'Name',
                                       size     => 25,
                                       required => 1);

  $fields{'email'} =
    Rose::HTML::Form::Field::Email->new(name  => 'email',
                                        label => 'Email',
                                        size  => 50);

  $fields{'submit_button'} =
    Rose::HTML::Form::Field::Submit->new(name => 'submit');

  $self->add_fields(%fields);
}

1;
