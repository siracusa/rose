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
