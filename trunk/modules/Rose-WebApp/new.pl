use Rose::WebApp::SelfConfig;

print Rose::WebApp::SelfConfig->archive_files(
  dir    => 'files/htdocs',
  prefix => 'files',
  type   => 'htdocs'), "\n\nXXXXXXXXXXXXXXXXXX\n\n";

print Rose::WebApp::SelfConfig->archive_files(
  dir    => 'files/mason/comps',
  prefix => 'files',
  type   => 'masoncomps');  