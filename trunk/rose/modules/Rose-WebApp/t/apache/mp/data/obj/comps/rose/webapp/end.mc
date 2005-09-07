# MASON COMPILER ID: 2097!27633
package HTML::Mason::Commands;
use strict;
use vars qw($m $app $r);
HTML::Mason::Component::FileBased->new(
'code' => sub {
$m->debug_hook( $m->current_comp->path ) if ( %DB:: );

#line 1 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/end.mc
$m->print( '</body>
</html>
' );
return undef;
},
'compiler_id' => '2097!27633',
'load_time' => 1111175573,
'object_size' => 320,

)
;