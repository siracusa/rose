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
