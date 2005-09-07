<p>Callapp.mc:</p>

<p><% '$app->do_parts_middle2()' |h %> -
% $app->do_parts_middle2();
</p>

<p><% q($app->show_comp('one');) |h %> -
% $app->show_comp('one');
</p>

<p><% q($app->show_comp(name => 'one', comp_args => { foo => 6 });) |h %> -
% $app->show_comp(name => 'one', comp_args => { foo => 6 });
</p>

<p><% q($app->output_comp($app->root_uri . '/one.mc', foo => 7);) |h %> -
% $app->output_comp($app->root_uri . '/one.mc', foo => 7);
</p>

<p><% q($app->show_comp(path => $app->root_uri . '/one.mc', foo => 7);) |h %> -
% $app->show_comp(path => $app->root_uri . '/one.mc', foo => 7);
</p>

<p><% q($app->param('a')) |h %> = <% $app->param('a') |h %></p>