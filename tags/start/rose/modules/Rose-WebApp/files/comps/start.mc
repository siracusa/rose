<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<& $head_comp, %ARGS &>
<body<% $body_html %>>
<!-- end /start.mc -->
<%args>
$head_comp => '/head.mc'
</%args>
<%init>
my $body_html = '';

if(exists $ARGS{'body'})
{
  my $body = $ARGS{'body'};
  $body_html = ' ' . join(' ', map { qq($_=") . Apache::Util::escape_html($body->{$_}) . '"' }
                               keys(%$body));
}
</%init>