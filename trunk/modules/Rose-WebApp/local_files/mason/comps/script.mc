<!-- start /script.mc -->
<% join("\n", map { qq(<script type="text/javascript" src="$_"></script>) } @script) %>
<!-- end /script.mc -->
<%args>
@script => ()
</%args>