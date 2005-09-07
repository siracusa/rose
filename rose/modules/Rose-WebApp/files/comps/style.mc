<!-- start /style.mc -->
<% join("\n", map { qq(<link rel="stylesheet" type="text/css" href="$_"/>) } '/admin/style/admin.css', @style) %>
<!-- end /style.mc -->
<%args>
@style => ()
</%args>
