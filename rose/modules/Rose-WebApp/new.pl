use lib 'lib';

use Rose::WebApp::Example::CRUD;

#print Rose::WebApp::Example::CRUD->archive_files(dir => 'files', type => 'htdocs');

#print Rose::WebApp::Example::CRUD->archive_files(dir => 'files/comps', prefix => 'files', type => 'masoncomps');

print Rose::WebApp::Example::CRUD->extract_files(type => 'masoncomps', dest => '/tmp', verbose => 2);

