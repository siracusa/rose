% unless($auto_hide && $pages <= 1)
% {
<div class="pages-nav">
<& '/number_line.mc', page => $page, per_page => $per_page, total => $total, max_pages => $max_pages, flat => $flat &>
<span class="summary"><% $num1 |nc %> - <% $num2 |nc %> of <% $total |nc %></span>
</div>
% }
<%args>
$uri       => Rose::URI->new(GVX::G3Admin::WebSite->requested_uri_with_query)
$page      => 1
$max_pages => 15
$flat      => 1
$auto_hide => 0
$per_page
$total
</%args>
<%init>
my $pages = $total / $per_page;
$pages++  if($pages > 1 && int $pages != $pages);
$pages = int($pages);

#return ''  unless($pages > 1);

$max_pages = 10  if($page > $max_pages);

my $num1 = ($page * $per_page) - $per_page + 1;
my $num2 = $page * $per_page;

$num2 = $total  if($num2 > $total);
</%init>