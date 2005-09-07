<%perl>
my $line;

my $pages = $total / $per_page;
$pages++  if($pages > 1 && int $pages != $pages);
$pages = int($pages);

return ''  unless($pages > 1);

$uri = Rose::URI->new($uri)  unless(ref $uri);

$line = '<div class="number-line">'  unless($nodiv);

my($start, $end, $line_set);

my $line_sets = $pages / $max_pages;
$line_sets++  if($line_sets > 1 && int $line_sets != $line_sets);
$line_sets = int($line_sets);

if($pages > $max_pages)
{
  if($page <= $max_pages)
  {
    $line_set = 1;
  }
  else
  {
    $line_set = $page / $max_pages;
    $line_set++  if($line_set > 1 && int $line_set != $line_set);
    $line_set = int($line_set);
  }

  $start = (($line_set - 1) * $max_pages) + 1;
  $end = (($line_set - 1) * $max_pages) + $max_pages;
  $end = $pages  if($end > $pages);
}
else
{
  $line_set = 1;
  $start = 1;
  $end   = $pages;
}

if($line_set > 1)
{
  $uri->query_param(page => (($line_set - 1) * $max_pages) - $max_pages + 1);
  $line .=  qq(<a href=") . Apache::Util::escape_html($uri) . q(">&laquo;</a> );
}

if($flat)
{
  if($page > 1)
  {
    $uri->query_param(page => $page - 1);
    $line .=  qq(<a href=") . Apache::Util::escape_html($uri) . q(">&laquo; prev</a> );
  }
}

$line .= ' ... '  if($line_set > 1);

for(my $i = $start; $i <= $end; $i++)
{
  if($i == $page)
  {
    $line .= qq(<span class="selected">$i</span> );
  }
  else
  {
    $uri->query_param(page => $i);
    $line .= qq(<a href=") . Apache::Util::escape_html($uri) . qq(">$i</a> );
  }
}

$line .= ' ... '  if($line_set < $line_sets);

unless($flat)
{
  if($line_set < $line_sets)
  {
    $uri->query_param(page => ($line_set * $max_pages) + 1);
    $line .=  qq( <a href=") . Apache::Util::escape_html($uri) . q(">&raquo;</a>);
  }

 if($page > 1)
  {
    $uri->query_param(page => $page - 1);
    $line .=  qq(<br><a href=") . Apache::Util::escape_html($uri) . q(">&laquo; prev</a> );
  }
}

if($flat)
{
  if($page < $pages)
  {
    $uri->query_param(page => $page + 1);
    $line .=  qq( <a href=") . Apache::Util::escape_html($uri) . q(">next &raquo;</a> );
  }

  if($line_set < $line_sets)
  {
    $uri->query_param(page => ($line_set * $max_pages) + 1);
    $line .=  qq( <a href=") . Apache::Util::escape_html($uri) . q(">&raquo;</a>);
  }
}
else
{
  if($page < $pages)
  {
    $uri->query_param(page => $page + 1);
    $line .=  (($page > 1) ? ' | ' : '<br>') .
      qq(<a href=") . Apache::Util::escape_html($uri) . q(">next &raquo;</a> );
  }
}

$line .= '</div>'  unless($nodiv);

$m->print($line);
</%perl>
<%args>
$uri       => Rose::URI->new($site->requested_uri_with_query)
$page      => 1
$max_pages => 30
$per_page
$total
$nodiv => 0
$flat  => 0
</%args>