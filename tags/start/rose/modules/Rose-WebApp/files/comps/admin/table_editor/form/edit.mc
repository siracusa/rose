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