<& '/message_box.mc', %ARGS &>
<%init>
$ARGS{'title'} ||= 'error';
$ARGS{'icon'}  ||= '!';
</%init>