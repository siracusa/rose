# MASON COMPILER ID: 2097!27633
package HTML::Mason::Commands;
use strict;
use vars qw($m $app $r);
HTML::Mason::Component::FileBased->new(
'code' => sub {
$m->debug_hook( $m->current_comp->path ) if ( %DB:: );

#line 1 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( '<p>Callapp.mc:</p>

<p>' );
#line 3 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( $m->interp->apply_escapes( (join '', ( '$app->do_parts_middle2()')), 'h' ) );
#line 3 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( ' -
' );
#line 4 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
 $app->do_parts_middle2();
$m->print( '</p>

<p>' );
#line 7 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( $m->interp->apply_escapes( (join '', ( q($app->show_comp('one');))), 'h' ) );
#line 7 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( ' -
' );
#line 8 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
 $app->show_comp('one');
$m->print( '</p>

<p>' );
#line 11 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( $m->interp->apply_escapes( (join '', ( q($app->show_comp(name => 'one', comp_args => { foo => 6 });))), 'h' ) );
#line 11 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( ' -
' );
#line 12 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
 $app->show_comp(name => 'one', comp_args => { foo => 6 });
$m->print( '</p>

<p>' );
#line 15 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( $m->interp->apply_escapes( (join '', ( q($app->output_comp($app->root_uri . '/one.mc', foo => 7);))), 'h' ) );
#line 15 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( ' -
' );
#line 16 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
 $app->output_comp($app->root_uri . '/one.mc', foo => 7);
$m->print( '</p>

<p>' );
#line 19 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( $m->interp->apply_escapes( (join '', ( q($app->show_comp(path => $app->root_uri . '/one.mc', foo => 7);))), 'h' ) );
#line 19 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( ' -
' );
#line 20 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
 $app->show_comp(path => $app->root_uri . '/one.mc', foo => 7);
$m->print( '</p>

<p>' );
#line 23 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( $m->interp->apply_escapes( (join '', ( q($app->param('a')))), 'h' ) );
#line 23 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( ' = ' );
#line 23 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( $m->interp->apply_escapes( (join '', ( $app->param('a'))), 'h' ) );
#line 23 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callapp.mc
$m->print( '</p>' );
return undef;
},
'compiler_id' => '2097!27633',
'load_time' => 1121524863,
'object_size' => 3395,

)
;