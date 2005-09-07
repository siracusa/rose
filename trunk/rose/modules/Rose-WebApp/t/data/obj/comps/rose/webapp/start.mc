# MASON COMPILER ID: 2097!27633
package HTML::Mason::Commands;
use strict;
use vars qw($m $app $r);
HTML::Mason::Component::FileBased->new(
'code' => sub {
$m->debug_hook( $m->current_comp->path ) if ( %DB:: );

#line 1 /Users/john/Documents/Perl/Rose/Rose/modules/Rose-WebApp/t/comps/rose/webapp/start.mc
$m->print( '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Rose::Test::WebApp</title>
</head>
<body>
' );
return undef;
},
'compiler_id' => '2097!27633',
'load_time' => 1121440277,
'object_size' => 489,

)
;