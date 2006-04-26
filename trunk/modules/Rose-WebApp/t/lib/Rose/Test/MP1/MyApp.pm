package Rose::Test::MP1::MyApp;

use strict;

use HTML::Mason::Escapes;

use Rose::WebApp::View::Mason;

use Rose::Test::MP1::MySite;
use Rose::Test::MP1::MyApp::Form::Edit;

use Rose::WebApp;
our @ISA = qw(Rose::WebApp);

sub init
{
  my($self) = shift;

  #
  # URI dispatch
  #

  $self->uri_dispatch(
  {
    '/'             => 'default',
    '/parts/flat'   => 'parts_flat',
    '/parts/nest/1' => 'parts_nest1',
    '/parts/nest/2' => 'parts_nest2',
    '/parts/nest/3' => 'parts_nest3',
  });

  $self->action_uri_dispatch(
  {
    '/update' => 'update',
  });

  #
  # Forms
  #

  $self->forms(
  {
    edit_form =>
    {
      html_form_class => 'Rose::Test::WebApp::Form::Edit',
      action_uri => $self->relative_action_uri('update'),
      view_path  => 'form/edit.mc',
    },
  });

  #
  # Pages
  #

  $self->pages(
  {
    edit_page => 
    {
      path  => 'edit.html',
      uri   => 'edit',
      form_names => [ 'edit_form' ],
    },

    test_page => 
    {
      path  => 'test.html',
      uri   => 'test',
    },
  });

  #
  # Comps
  #

  $self->comps(
  {
    default => 
    {
      path => 'default.html',
    },

    start => 
    {
      path => 'start.mc',
    },

    one => 
    {
      path => 'one.mc',
    },

    callone => 
    {
      path => 'callone.mc',
    },

    callapp => 
    {
      path => 'callapp.mc',
    },

    two => 
    {
      path => 'two.mc',
    },

    end => 
    {
      path => 'end.mc',
    },
  });

  $self->view_manager('mason')->mason_interp->set_escape
  (
    h => \&HTML::Mason::Escapes::basic_html_escape,
  );

  $self->SUPER::init(@_);
}

sub action_method_prefix { 'do_' }
sub init_website_class   { 'Rose::Test::MP1::MySite' }
sub init_default_action  { undef }
sub init_comp_error_mode { 'inline' }

sub do_default
{
  my($self) = shift;

  $self->show_comp('default');
}

sub do_parts_flat
{
  my($self) = shift;

  $self->show_comp('start');
  $self->show_comp('one');
  $self->show_comp('two');
  $self->show_comp('end');
}

sub do_parts_nest1
{
  my($self) = shift;

  $self->show_comp('start');
  $self->show_comp('callone');
  $self->show_comp('two');
  $self->show_comp('end');
}

sub do_parts_middle2
{
  my($self) = shift;
#print STDERR "RUN do_parts_middle2()\n";
#$DB::single = 1;
  $self->show_comp('callone');
  $self->show_comp('two');
  return 'ret from do_parts_middle()';
}

sub do_parts_nest2
{
  my($self) = shift;
#print STDERR "RUN do_parts_nest2()\n";
  $self->show_comp('start');
  $self->show_comp('callapp');
  $self->show_comp('end');
}

sub do_parts_nest3
{
  my($self) = shift;

  local $self->{'auto_print'} = 1;

  local $self->{'comp_error_mode'} = $self->param('error_mode') || 'fatal';

  $self->show_comp('start');
  $self->show_comp('one');
  $self->show_comp(path => $self->app_uri('/one_error.mc'));
  $self->show_comp('end');
}

sub update
{
  my($self) = shift;

  my $form = $self->prepare_form('edit_form');

  if($form->error)
  {
    return $self->show_page('edit_page');
  }

  if($form->field('name')->internal_value eq 'redir')
  {
    return $self->redirect_to_page('edit_page');
  }

  return $self->show_page(name => 'edit_page', page_args => { error => 'Hello' });
}

1;