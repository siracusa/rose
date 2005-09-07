<!-- start /script.mc -->
<% join("\n", map { qq(<script type="text/javascript" src="$_"></script>) } 
              '/admin/scripts/navigation.js', @script) %>
<!-- end /script.mc -->
<%args>
@script => ()
</%args>