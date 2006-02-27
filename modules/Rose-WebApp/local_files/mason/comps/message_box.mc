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
