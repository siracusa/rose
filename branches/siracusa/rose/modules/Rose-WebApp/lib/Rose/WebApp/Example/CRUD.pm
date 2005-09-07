package Rose::WebApp::Example::CRUD;

use strict;

use Rose::DB::Object::Manager;
use Rose::WebApp::Example::CRUD::Form::Search::Auto;
use Rose::WebApp::Example::CRUD::Form::New::Auto;
use Rose::WebApp::Example::CRUD::Form::Edit::Auto;

use Rose::WebApp;
our @ISA = qw(Rose::WebApp);

our $VERSION = '0.01';

our $Debug = 0;

__PACKAGE__->use_features(qw(self-starter self-config));

use Rose::Object::MakeMethods::Generic
(
  scalar =>
  [
    'title',
    'object_name_singular',
    'object_name_plural',
    'object_class',
    'object_manager_class',
    'style_sheet_uris',
  ],

  'scalar --get_set_init' =>
  [
    'search_form_class',
    'new_form_class',
    'edit_form_class',
  ],
);

sub init
{
  my($self) = shift;

  #
  # URI dispatch
  #

  $self->uri_dispatch(
  {
    ''     => 'list_page',
    '/new' => 'new_page',
  });

  $self->action_uri_dispatch(
  {
    '/create' => 'create',
    '/update' => 'update',
  });

  #
  # Forms
  #

  $self->forms(
  {
    search_form =>
    [
      class         => $self->search_form_class,
      action_uri    => 'list',
      view_path     => '/rose/webapp/example/table_editor/form/search.mc',
      build_on_init => 0,
      app           => $self,
    ],

    edit_form =>
    [
      class         => $self->edit_form_class,
      action_uri    => $self->relative_action_uri('update'),
      view_path     => '/rose/webapp/example/table_editor/form/edit.mc',
      build_on_init => 0,
      clear_on_init => 1,
      app           => $self,
      hidden_field_names     => [ $self->edit_form_hidden_field_names ],
      write_once_field_names => [ $self->write_once_field_names ],
    ],

    new_form =>
    [
      class         => $self->new_form_class,
      action_uri    => $self->relative_action_uri('create'),
      view_path     => '/rose/webapp/example/table_editor/form/new.mc',
      build_on_init => 0,
      reset_on_init => 1,
      app           => $self,
      hidden_field_names         => [ $self->new_form_hidden_field_names ],
      auto_populated_field_names => [ $self->auto_populated_field_names ],
    ],
  });

  # Build forms
  foreach my $form_name (qw(search_form edit_form new_form))
  {
    $self->form($form_name)->build_form();
  }

  #
  # Pages
  #

  $self->pages(
  {
    list_page =>
    {
      path  => '/rose/webapp/example/table_editor/list.html',
      uri   => 'list',
      form_names => [ 'search_form' ],
    },

    new_page => 
    {
      path  => '/rose/webapp/example/table_editor/new.html',
      uri   => 'new',
      form_names => [ 'new_form' ],
    },

    edit_page => 
    {
      path  => '/rose/webapp/example/table_editor/edit.html',
      uri   => 'edit',
      form_names => [ 'edit_form' ],
    },
  });

  $self->SUPER::init(@_);
}

sub init_search_form_class { 'Rose::WebApp::Example::CRUD::Form::Search::Auto' }
sub init_new_form_class    { 'Rose::WebApp::Example::CRUD::Form::Edit::Auto' }
sub init_edit_form_class   { 'Rose::WebApp::Example::CRUD::Form::New::Auto' }

sub init_default_form_action_method { $Debug ? 'get' : 'post' }

sub object_name          { 'object'  }
sub object_name_plural   { shift->object_name_singular . 's' }
sub object_name_singular { shift->object_name(@_) }
sub object_manager_class { 'Rose::DB::Object::Manager' }
sub object_class         { die "You must override object_class() in your subclass, ", ref $_[0] }

sub default_action { 'list_page' }
sub default_objects_per_page { 25 }

sub new_form_hidden_field_names  { () }
sub edit_form_hidden_field_names { () }

sub new_form_field_names  { map { $_->name } shift->form('new_form')->fields  }
sub edit_form_field_names { map { $_->name } shift->form('edit_form')->fields }

sub write_once_field_names { () }
sub auto_populated_field_names { () }

sub style_name
{
  my($self) = shift;

  return $self->{'style_name'} = shift  if(@_);

  if($self->{'style_name'})
  {
    return $self->{'style_name'};
  }

  my $name = $self->object_name_singular;
  $name =~ s/\s+/-/g;

  return $self->{'style_name'} = $name;
}

sub choose_action
{
  my($self) = shift;

  my $uri = $self->dispatch_uri;

  if($uri =~ m{^/edit/(.+)})
  {
    my @ids = split(',', $1);
    return 'edit_page', { ids => \@ids };
  }

  $self->SUPER::choose_action(@_);
}

sub edit_page
{
  my($self, %args) = @_;

  unless($args{'ids'})
  {
    $args{'ids'} = [ map { $self->param($_) } $self->object_class->meta->primary_key_columns ];
  }

  my $info = $self->get_object_info(%args) or return;

  unless($self->params_exist)
  {
    $self->prepare_edit_form(%$info);
  }

  $self->show_page(name => 'edit_page', page_args => $info);
}

sub edit_object_uri
{
  my($self, $object) = @_;

  my $uri = $self->root_uri . '/edit/' .
     join(',', map { $object->$_() } $object->meta->primary_key_columns);
}

sub prepare_edit_form
{
  my($self, %args) = @_;
  my $form = $self->form('edit_form') or Carp::croak "Missing edit form";

  $form->html_form->init_with_object($args{'object'});
  $form->prepared(1);
}


sub _get_object
{
  my($self, %args) = @_;

  my $ret_object = delete $args{'return_object'};

  my @ids = @{$args{'ids'}};

  my $object_class = $self->object_class;

  my $i = 0;

  my %object_args = map { $_ => $ids[$i++] } $object_class->meta->primary_key_columns;

  my $object = $object_class->new(%object_args);

  my $object_name = $self->object_name_singular;

  my $id_string;

  if(@ids == 1)
  {
    my $col = $object_class->meta->primary_key_columns->[0];

    if($col =~ /_id$/i)
    {
      $id_string = "id $ids[0]";
    }
    else
    {
      $id_string = "$col $ids[0]";
    }
  }
  else
  {
    $id_string = '(' . join(', ', map { "$_ = $object_args{$_}" } keys(%object_args)) . ')';
  }

  unless($object->load)
  {
    if($object->not_found)
    {
      $self->error("No such $object_name $id_string");
    }
    else
    {
      $self->error("Could not load $object_name $id_string - " . $object->error);
    }

    $self->show_page('list_page');
    return;
  }

  return $object  if($ret_object);

  return 
  {
    ids         => \@ids,
    object      => $object,
    object_name => $object_name,
    id_string   => $id_string,
  }
}

sub get_object      { shift->_get_object(@_, return_object => 1) }
sub get_object_info { shift->_get_object(@_) }

sub update
{
  my($self) = shift;

  my $form = $self->prepare_form('edit_form')->html_form;

  if($form->error)
  {
    $self->error($form->error);
    return $self->edit_page();
  }

  my @ids  = map { $form->field($_)->internal_value } $self->object_class->meta->primary_key_columns;
  my $info = $self->get_object_info(ids => \@ids) or return;

  my $object = $form->object_from_form($info->{'object'});

  $self->prepare_updated_object($object);

  if($self->update_object($object))
  {
    $self->message(ucfirst("$info->{'object_name'} $info->{'id_string'} updated successfully."));
  }
  else
  {
    $self->error("Could not update $info->{'object_name'} $info->{'id_string'} - " .
                 $object->error);
  }

  $self->delete_params;
  return $self->edit_page(ids => [ map { $object->$_() } $object->meta->primary_key_columns ]);
}

sub prepare_updated_object { }

sub update_object
{
  my($self, $object) = @_;

  unless($object->save && $object->db->commit)
  {
    $object->db->rollback;
    return undef;
  }

  return 1;
}

sub create
{
  my($self) = shift;

  my $form = $self->prepare_form('new_form')->html_form;

  if($form->error)
  {
    $self->error($form->error);
    return $self->show_page('new_page');
  }

  my $object = $form->object_from_form($self->object_class);

  $self->prepare_new_object($object);

  if($self->create_object($object))
  {
    my @ids  = map { $object->$_() } $self->object_class->meta->primary_key_columns;
    my $info = $self->get_object_info(ids => \@ids);
    $self->message(ucfirst("$info->{'object_name'} $info->{'id_string'} created successfully."));

    $self->delete_params;
    return $self->edit_page(ids => [ map { $object->$_() } $object->meta->primary_key_columns ]);
  }
  else
  {
    $self->error("Could not create new " . $self->object_name . ' - ' . $object->error);
    return $self->show_page('new_page');
  }
}

sub create_object
{
  my($self, $object) = @_;

  unless($object->save && $object->db->commit)
  {
    $object->db->rollback;
    return undef;
  }

  return 1;
}

sub prepare_new_object { }

sub get_objects
{
  my($self, %args) = @_;

  my $form = $self->prepare_form('search_form')->html_form;

  my $args = $form->manager_args_from_form;

  %args = (%$args, %args);

  my $manager_class = $self->object_manager_class;

  my $object_class = $self->object_class 
    or die "Missing object class for ", ref($self);

  $args{'object_class'} = $object_class;

  my $db = $args{'db'} ||= $object_class->init_db;

  my $page     = $self->param('page') || 1;
  my $per_page = $self->param('per_page') || $self->default_objects_per_page;

  $self->prepare_object_list_args(\%args);

  my($total, @objects);

  eval
  {
    local $Rose::DB::Object::Manager::Debug = $Debug;

    $total = $manager_class->get_objects_count(%args);

    die $manager_class->error  unless(defined $total);

    $args{'limit'} = $per_page;

    if($page > 1)
    {
      $args{'offset'} = ($page - 1) * $per_page;
    }

    my $iterator = $manager_class->get_objects_iterator(%args)
      or die $manager_class->error;

    while(my $object = $iterator->next)
    {
      push(@objects, $object);
    }
  };

  if($@)
  {
    warn $self->error($@);
    return undef;
  }

  return
  {
    objects  => \@objects,
    total    => $total,
    per_page => $per_page,
    page     => $page,
  };
}

sub prepare_object_list_args { }

sub list_page
{
  my($self) = shift;

  if($self->params_exist)
  {
    my $info = $self->get_objects() or return $self->show_page('list_page');
    $info->{$self->object_name_plural} = $info->{'objects'};
    $self->show_page(name => 'list_page', page_args => $info);
  }
  else
  {
    $self->show_page('list_page');
  }
}

1;

__DATA__
---
File: comps/admin/coupon/form/search.mc
Mode: 33188
Type: masoncomps
Lines: 11

<!-- start /admin/coupon/form/search.mc -->
<%perl>
$m->comp('/admin/table_editor/form/search.mc', %ARGS, 
         rows => 
         [
           [ 'code', 'start_date' ],
           [ 'coupon_id', 'end_date' ],
           [ 'sort',  [ 'per_page', 'list_button' ] ],
         ]);
</%perl>
<!-- end /admin/coupon/form/search.mc -->
---
File: comps/admin/coupon/list.mc
Mode: 33188
Type: masoncomps
Lines: 29

<!-- start /admin/coupon/list.mc -->
<table cellspacing="0" cellpadding="3" width="100%">
<tr class="header">
<th>Id</th>
<th>Code</th>
<th>Start Date</th>
<th>End Date</th>
<th>Migrate</th>
<th>Clone</th>
</tr>
%
% my $i = 0;
%
% foreach my $coupon (@$objects)
% {
<tr class="coupon row-<% $i++ % 2 ? 'odd' : 'even' %>">
<td class="id first"><% $coupon->id |h %></td>
<td class="code"><a href="<% $app->edit_object_uri($coupon) %>"><% $coupon->code |h %></a></td>
<td class="start-date"><% $coupon->start_date(format => '%b %d %Y %H:%M') |h %></td>
<td class="end-date"><% $coupon->end_date(format => '%b %d %Y %H:%M') |h %></td>
<td class="migrate">Migrate</td>
<td class="clone last">Clone</td>
</tr>
% }
</table>
<!-- end /admin/coupon/list.mc -->
<%args>
$objects
</%args>
---
File: comps/admin/coupon/navbar.mc
Mode: 33188
Type: masoncomps
Lines: 6

<!-- start /admin/coupon/navbar.mc -->
<div class="nav">
<a href="/admin/coupon">Find Coupons</a> |
<a href="/admin/coupon/new">New Coupon</a>
</div>
<!-- end /admin/coupon/navbar.mc -->
---
File: comps/admin/messages.mc
Mode: 33188
Type: masoncomps
Lines: 9

<!-- start /admin/messages.mc -->
% $m->comp('/error_box.mc', message => $error)  if($error);
% $m->comp('/message_box.mc', message => $message)  if($message);
% $m->print('<br/>')  if($error || $message);
<!-- end /admin/messages.mc -->
<%args>
$error   => undef
$message => undef
</%args>
---
File: comps/admin/table_editor/form/edit.mc
Mode: 33188
Type: masoncomps
Lines: 62

<!-- start /admin/table_editor/form/edit.mc -->
<div class="edit">
<% $form->start_html %>

% if($form->is_edit_form)
% {
%   foreach my $column ($object->meta->primary_key_columns, $form->hidden_field_names)
%   {
<% $form->field($column)->hidden_field->xhtml_field %>
%   }
% }

<table class="form">
<tr class="header">
<td colspan="2" class="title">
% if($object)
% {
Edit <% $object_name |h %> <% $id_string |h %>
% }
% else
% {
New <% $object_name |h %>
% }
</td></tr>
%
% my $i = 0;
%
% foreach my $field ($form->fields)
% {
%   my $name = $field->name;
%   next  if($pk{$name} || $hide{$name} || $field->isa('Rose::HTML::Form::Field::Submit'));
<tr class="row-<% $i++ % 2 ? 'odd' : 'even' %>">
<td class="label"><% $field->xhtml_label %></td>
<td class="field"><% $field->xhtml %></td>
</tr>
% }
</table>

<div class="buttons">
% if($object)
% {
<% $form->field('update_button')->xhtml_field %>
% }
% else
% {
<% $form->field('create_button')->xhtml_field %>
% }
</div>

<% $form->end_html %>
</div>
<!-- end /admin/table_editor/form/edit.mc -->
<%args>
$object      => undef
$object_name => undef
$id_string   => undef
</%args>
<%init>
my $form = $ARGS{'html_form'};
my %pk = $object ? (map { $_ => 1 } $object->meta->primary_key_columns) : ();
my %hide = map { $_ => 1 } $form->hidden_field_names;
</%init>
---
File: comps/admin/table_editor/form/new.mc
Mode: 33188
Type: masoncomps
Lines: 3

<!-- start /admin/table_editor/form/new.mc -->
<& '/admin/table_editor/form/edit.mc', form_type => 'new', %ARGS &>
<!-- end /admin/table_editor/form/new.mc -->
---
File: comps/admin/table_editor/form/search.mc
Mode: 33188
Type: masoncomps
Lines: 92

<!-- start /admin/table_editor/form/search.mc -->
<div class="search">
<% $form->start_html %>

<table class="form">
<%perl>
foreach my $row (@$rows)
{
  $m->print("<tr>\n");

  foreach my $item (@$row)
  {
    my $started = 0;

    foreach my $field (ref $item ? @$item : $item)
    {
      my $label_td = '';
      my $field_td = '';

      if(ref $field eq 'HASH')
      {
        if(ref $field->{'label_td_attrs'})
        {
          $label_td = join(' ', map { "$_=$field->{'label_td_attrs'}{$_}" } 
                               keys %{$field->{'label_td_attrs'}});
        }

        if(ref $field->{'field_td_attrs'})
        {
          $field_td = join(' ', map { "$_=$field->{'field_td_attrs'}{$_}" } 
                               keys %{$field->{'field_td_attrs'}});
        }

        $field = $field->{'name'};
      }

      if($form->field($field)->label)
      {
        if($started)
        {
          $m->print(' ', $form->field($field)->xhtml_label);
        }
        else
        {
          $m->print('<td ', $label_td, 'class="label">',
                    $form->field($field)->xhtml_label,
                    "</td>\n");
        }
      }

      if($started)
      {
        $m->print(' ', $form->field($field)->xhtml);
      }
      else
      {
        $m->print('<td ', $field_td, 'class="field">',
                  $form->field($field)->xhtml);
      }

      $started++;
    }

    $m->print("</td>\n");
  }

  $m->print("</tr>\n");
}
</%perl>
</table>

<% $form->end_html %>
</div>
<!-- end /admin/table_editor/form/search.mc -->
<%args>
$rows => undef
</%args>
<%init>
my $form = $ARGS{'html_form'};

unless($rows)
{
  my @columns = $form->search_columns;

  while(@columns)
  {
    push(@$rows, [ grep { defined } shift(@columns), shift(@columns) ]);
  }

  push(@$rows, [ 'sort',  [ 'per_page', 'list_button' ] ]);
}
</%init>
---
File: comps/end.mc
Mode: 33188
Type: masoncomps
Lines: 4

<!-- start /end.mc -->
</body>

</html>
---
File: comps/error_box.mc
Mode: 33188
Type: masoncomps
Lines: 5

<& '/message_box.mc', %ARGS &>
<%init>
$ARGS{'title'} ||= 'error';
$ARGS{'icon'}  ||= '!';
</%init>
---
File: comps/footer.mc
Mode: 33188
Type: masoncomps
Lines: 15

<!-- /footer.mc -->
</div>
% # if(defined $layout && $layout ne 'none')
% # {
% #   $m->comp("/layout/$layout/end.mc", %ARGS);
% # }
<div id="footer">Copyright &copy; Cambridge Interactive Development 1998-<% $Year %>.</div>

<& '/end.mc', %ARGS &>
<%args>
$layout => 'standard'
</%args>
<%once>
my $Year = (localtime(time))[5] + 1900;
</%once>
---
File: comps/head.mc
Mode: 33188
Type: masoncomps
Lines: 15

<!-- start /head.mc -->
<head>
<title><% $page_title |h %></title>
<& $style_comp, %ARGS &>
<& $script_comp, %ARGS &>
<% $head_extra |n %>
</head>
<!-- end /head.mc -->
<%args>
$page_title  => 'Admin Tools'
$head_extra  => ''
$style_comp  => '/style.mc'
$script_comp => '/script.mc'
$no_title_prefix => 0
</%args>
---
File: comps/header.mc
Mode: 33188
Type: masoncomps
Lines: 26

<& '/start.mc', %ARGS &>
<div id="header">
<table cellpadding="0" cellspacing="0">
<tr valign="middle">
<td class="logo" rowspan="2"><a href="<% GVX::G3Admin::WebSite->site_url %>"><img 
src="/images/gv_logo.gif" width="42" height="42" alt="Grand Virtual" border="0"/></a></td>
<td class="date">Current Date: <b><% $date %></b></td>
<td class="title" align="center"><a href="/">Admin Toolbox</a></td>
<td class="user-info" align="right">Current User: <b><a onclick="var w=window.open(&quot;/user-manage?referer=javascript:window.close()&quot;,&quot;pwd_window&quot;,&quot;center=yes,resizable=yes,width=600,height=590,toolbar=yes,scrollbars=yes&quot;);w.focus();" 
title="Account Management" href="#"><% $ENV{'REMOTE_USER'} |h %></a></b></td>
</tr>
<tr><td colspan="3" class="nav"><% GVX::G3Admin::WebSite->navigation_html %></td></tr>
</table>
% #if(defined $layout && $layout ne 'none')
% #{
% #  $m->comp("/layout/$layout/start.mc", %ARGS);
% #}
</div>
<div id="body">
<!-- end /header.mc -->
<%args>
$layout => 'standard'
</%args>
<%init>
my $date = DateTime->now(time_zone => 'local')->strftime('%A %B %d, %Y');
</%init>
---
File: comps/message_box.mc
Mode: 33188
Type: masoncomps
Lines: 31

<!-- start /message_box.mc -->
<table align="center" class="message-box" bgcolor="#e0e0e0" border="0" cellpadding="3" cellspacing="0" width="<% $width %>">
<tr><td bgcolor="#000033" class="title"><% $title |h %></td></tr>
<tr>
<td class="body">

<table border="0" cellpadding="6">
<tr>
% if(length $icon)
% {
<td align="center"><% $icon %></td>
% }
<td><% $message %></td></tr>
</table>
</td></tr></table>
<!-- end /message_box.mc -->
<%args>
$title => 'message',
$escape_html => 1
$message => ''
$icon    => undef
$width   => '60%'
</%args>
<%init>
$message = Apache::Util::escape_html($message)  if($escape_html && $message !~ m{</?[^>]+>});

unless(length $icon > 1 || length $icon == 0)
{
  $icon = qq(<b class="icon">$icon</b>);
}
</%init>
---
File: comps/number_line.mc
Mode: 33188
Type: masoncomps
Lines: 127

<%perl>
my $line;

my $pages = $total / $per_page;
$pages++  if($pages > 1 && int $pages != $pages);
$pages = int($pages);

return ''  unless($pages > 1);

$uri = Rose::URI->new($uri)  unless(ref $uri);

$line = '<div class="number-line">'  unless($nodiv);

my($start, $end, $line_set);

my $line_sets = $pages / $max_pages;
$line_sets++  if($line_sets > 1 && int $line_sets != $line_sets);
$line_sets = int($line_sets);

if($pages > $max_pages)
{
  if($page <= $max_pages)
  {
    $line_set = 1;
  }
  else
  {
    $line_set = $page / $max_pages;
    $line_set++  if($line_set > 1 && int $line_set != $line_set);
    $line_set = int($line_set);
  }

  $start = (($line_set - 1) * $max_pages) + 1;
  $end = (($line_set - 1) * $max_pages) + $max_pages;
  $end = $pages  if($end > $pages);
}
else
{
  $line_set = 1;
  $start = 1;
  $end   = $pages;
}

if($line_set > 1)
{
  $uri->query_param(page => (($line_set - 1) * $max_pages) - $max_pages + 1);
  $line .=  qq(<a href=") . Apache::Util::escape_html($uri) . q(">&laquo;</a> );
}

if($flat)
{
  if($page > 1)
  {
    $uri->query_param(page => $page - 1);
    $line .=  qq(<a href=") . Apache::Util::escape_html($uri) . q(">&laquo; prev</a> );
  }
}

$line .= ' ... '  if($line_set > 1);

for(my $i = $start; $i <= $end; $i++)
{
  if($i == $page)
  {
    $line .= qq(<span class="selected">$i</span> );
  }
  else
  {
    $uri->query_param(page => $i);
    $line .= qq(<a href=") . Apache::Util::escape_html($uri) . qq(">$i</a> );
  }
}

$line .= ' ... '  if($line_set < $line_sets);

unless($flat)
{
  if($line_set < $line_sets)
  {
    $uri->query_param(page => ($line_set * $max_pages) + 1);
    $line .=  qq( <a href=") . Apache::Util::escape_html($uri) . q(">&raquo;</a>);
  }

 if($page > 1)
  {
    $uri->query_param(page => $page - 1);
    $line .=  qq(<br><a href=") . Apache::Util::escape_html($uri) . q(">&laquo; prev</a> );
  }
}

if($flat)
{
  if($page < $pages)
  {
    $uri->query_param(page => $page + 1);
    $line .=  qq( <a href=") . Apache::Util::escape_html($uri) . q(">next &raquo;</a> );
  }

  if($line_set < $line_sets)
  {
    $uri->query_param(page => ($line_set * $max_pages) + 1);
    $line .=  qq( <a href=") . Apache::Util::escape_html($uri) . q(">&raquo;</a>);
  }
}
else
{
  if($page < $pages)
  {
    $uri->query_param(page => $page + 1);
    $line .=  (($page > 1) ? ' | ' : '<br>') .
      qq(<a href=") . Apache::Util::escape_html($uri) . q(">next &raquo;</a> );
  }
}

$line .= '</div>'  unless($nodiv);

$m->print($line);
</%perl>
<%args>
$uri       => Rose::URI->new($site->requested_uri_with_query)
$page      => 1
$max_pages => 30
$per_page
$total
$nodiv => 0
$flat  => 0
</%args>
---
File: comps/pages_nav.mc
Mode: 33188
Type: masoncomps
Lines: 30

% unless($auto_hide && $pages <= 1)
% {
<div class="pages-nav">
<& '/number_line.mc', page => $page, per_page => $per_page, total => $total, max_pages => $max_pages, flat => $flat &>
<span class="summary"><% $num1 |nc %> - <% $num2 |nc %> of <% $total |nc %></span>
</div>
% }
<%args>
$uri       => Rose::URI->new(GVX::G3Admin::WebSite->requested_uri_with_query)
$page      => 1
$max_pages => 15
$flat      => 1
$auto_hide => 0
$per_page
$total
</%args>
<%init>
my $pages = $total / $per_page;
$pages++  if($pages > 1 && int $pages != $pages);
$pages = int($pages);

#return ''  unless($pages > 1);

$max_pages = 10  if($page > $max_pages);

my $num1 = ($page * $per_page) - $per_page + 1;
my $num2 = $page * $per_page;

$num2 = $total  if($num2 > $total);
</%init>
---
File: comps/script.mc
Mode: 33188
Type: masoncomps
Lines: 7

<!-- start /script.mc -->
<% join("\n", map { qq(<script type="text/javascript" src="$_"></script>) } 
              '/admin/scripts/navigation.js', @script) %>
<!-- end /script.mc -->
<%args>
@script => ()
</%args>
---
File: comps/start.mc
Mode: 33188
Type: masoncomps
Lines: 18

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<& $head_comp, %ARGS &>
<body<% $body_html %>>
<!-- end /start.mc -->
<%args>
$head_comp => '/head.mc'
</%args>
<%init>
my $body_html = '';

if(exists $ARGS{'body'})
{
  my $body = $ARGS{'body'};
  $body_html = ' ' . join(' ', map { qq($_=") . Apache::Util::escape_html($body->{$_}) . '"' }
                               keys(%$body));
}
</%init>
---
File: comps/style.mc
Mode: 33188
Type: masoncomps
Lines: 6

<!-- start /style.mc -->
<% join("\n", map { qq(<link rel="stylesheet" type="text/css" href="$_"/>) } '/admin/style/admin.css', @style) %>
<!-- end /style.mc -->
<%args>
@style => ()
</%args>

