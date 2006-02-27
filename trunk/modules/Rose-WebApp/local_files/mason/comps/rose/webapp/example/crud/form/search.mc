<!-- start /rose/webapp/example/crud/form/search.mc -->
<div class="search">
<% $form->start_html %>

<table class="form">
<%perl>
foreach my $row (@$rows)
{
  $m->print("<tr>\n");

  foreach my $item (@$row)
  {
    my $started = 0;

    foreach my $field (ref $item ? @$item : $item)
    {
      my $label_td = '';
      my $field_td = '';

      if(ref $field eq 'HASH')
      {
        if(ref $field->{'label_td_attrs'})
        {
          $label_td = join(' ', map { "$_=$field->{'label_td_attrs'}{$_}" } 
                               keys %{$field->{'label_td_attrs'}});
        }

        if(ref $field->{'field_td_attrs'})
        {
          $field_td = join(' ', map { "$_=$field->{'field_td_attrs'}{$_}" } 
                               keys %{$field->{'field_td_attrs'}});
        }

        $field = $field->{'name'};
      }

      if($form->field($field)->label)
      {
        if($started)
        {
          $m->print(' ', $form->field($field)->xhtml_label);
        }
        else
        {
          $m->print('<td ', $label_td, 'class="label">',
                    $form->field($field)->xhtml_label,
                    "</td>\n");
        }
      }

      if($started)
      {
        $m->print(' ', $form->field($field)->xhtml);
      }
      else
      {
        $m->print('<td ', $field_td, 'class="field">',
                  $form->field($field)->xhtml);
      }

      $started++;
    }

    $m->print("</td>\n");
  }

  $m->print("</tr>\n");
}
</%perl>
</table>

<% $form->end_html %>
</div>
<!-- end /rose/webapp/example/crud/form/search.mc -->
<%args>
$rows => undef
</%args>
<%init>
my $form = $ARGS{'html_form'};

unless($rows)
{
  my @columns = $form->search_columns;

  while(@columns)
  {
    push(@$rows, [ grep { defined } shift(@columns), shift(@columns) ]);
  }

  push(@$rows, [ 'sort',  [ 'per_page', 'list_button' ] ]);
}
</%init>