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