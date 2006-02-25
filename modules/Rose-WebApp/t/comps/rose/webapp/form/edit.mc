% if($error)
% {
<p class="error"><% $error |h %></p>
%}

<% $form->start_html %>

<table>
<tr>
<td><% $form->field('name')->html_label %></td>
<td><% $form->field('name')->html %></td>
</tr>
<tr>
<td><% $form->field('email')->html_label %></td>
<td><% $form->field('email')->html %></td>
</tr>
<tr>
<td colspan="2"><% $form->field('submit_button')->html %></td>
</tr>
</table>

<% $form->end_html %>
<%args>
$error => ''
</%args>
<%init>
my $form = $ARGS{'html_form'};

</%init>