# MASON COMPILER ID: 2097!27633
package HTML::Mason::Commands;
use strict;
use vars qw($m $app $r);
HTML::Mason::Component::FileBased->new(
'code' => sub {
$m->debug_hook( $m->current_comp->path ) if ( %DB:: );

#line 1 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callone.mc
$m->print( '<p>Callone.mc:</p>

<p>&lt;&amp; \'one.mc\' &amp;&gt; - ' );
#line 3 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callone.mc
$m->comp(   'one.mc'   
); #line 3 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callone.mc
$m->print( '</p>

<p>$m-&gt;comp(\'one.mc\') - ' );
#line 5 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callone.mc
$m->print(  $m->comp('one.mc')  );
#line 5 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/callone.mc
$m->print( '</p>
' );
return undef;
},
'compiler_id' => '2097!27633',
'load_time' => 1121524228,
'object_size' => 893,

)
;