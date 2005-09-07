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
