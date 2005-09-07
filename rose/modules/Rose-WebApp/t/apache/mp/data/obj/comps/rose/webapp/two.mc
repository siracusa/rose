# MASON COMPILER ID: 2097!27633
package HTML::Mason::Commands;
use strict;
use vars qw($m $app $r);
HTML::Mason::Component::FileBased->new(
'code' => sub {
my %ARGS;
{ local $^W; %ARGS = @_ unless (@_ % 2); }
$m->debug_hook( $m->current_comp->path ) if ( %DB:: );

#line 1 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/two.mc
$m->print( '<p>Two.mc - ARGS = ' );
#line 1 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/two.mc
$m->print( $m->interp->apply_escapes( (join '', ( Data::Dumper::Dumper(\%ARGS))), 'h' ) );
#line 1 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/two.mc
$m->print( '</p>
' );
return undef;
},
'compiler_id' => '2097!27633',
'load_time' => 1111179547,
'object_size' => 655,

)
;