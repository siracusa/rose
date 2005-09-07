# MASON COMPILER ID: 2097!27633
package HTML::Mason::Commands;
use strict;
use vars qw($m $app $r);
HTML::Mason::Component::FileBased->new(
'code' => sub {
HTML::Mason::Exception::Params->throw
    ( error =>
      "Odd number of parameters passed to component expecting name/value pairs"
    ) if @_ % 2;
my %ARGS = @_;
my ( $error );
{
    my %pos;
    for ( my $x = 0; $x < @_; $x += 2 )
    {
        $pos{ $_[$x] } = $x + 1;
    }
#line 24 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
     $error = exists $pos{'error'} ? $_[ $pos{'error'} ] :  '';
}
$m->debug_hook( $m->current_comp->path ) if ( %DB:: );

#line 26 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc

my $form = $ARGS{'html_form'};

#line 1 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
 if($error)
 {
$m->print( '<p class="error">' );
#line 3 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print( $m->interp->apply_escapes( (join '', ( $error)), 'h' ) );
#line 3 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print( '</p>
' );
#line 4 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
}
$m->print( '
' );
#line 6 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print(  $form->start_html  );
#line 6 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print( '

<table>
<tr>
<td>' );
#line 10 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print(  $form->field('name')->html_label  );
#line 10 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print( '</td>
<td>' );
#line 11 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print(  $form->field('name')->html  );
#line 11 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print( '</td>
</tr>
<tr>
<td>' );
#line 14 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print(  $form->field('email')->html_label  );
#line 14 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print( '</td>
<td>' );
#line 15 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print(  $form->field('email')->html  );
#line 15 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print( '</td>
</tr>
<tr>
<td colspan="2">' );
#line 18 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print(  $form->field('submit_button')->html  );
#line 18 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print( '</td>
</tr>
</table>

' );
#line 22 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print(  $form->end_html  );
#line 22 /Volumes/JCS/Rose/modules/Rose-WebApp/t/apache/mp/comps/rose/webapp/form/edit.mc
$m->print( '
' );
return undef;
},
'compiler_id' => '2097!27633',
'declared_args' => {
  '$error' => { default => ' \'\'' }
},
'load_time' => 1113488817,
'object_size' => 3130,

)
;