<!-- start /admin/messages.mc -->
% $m->comp('/error_box.mc', message => $error)  if($error);
% $m->comp('/message_box.mc', message => $message)  if($message);
% $m->print('<br/>')  if($error || $message);
<!-- end /admin/messages.mc -->
<%args>
$error   => undef
$message => undef
</%args>