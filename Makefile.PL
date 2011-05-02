use inc::Module::Install;
name 'Data-Model-Driver-MongoDB';
all_from 'lib/Data/Model/Driver/MongoDB.pm';

requires 'Data::Model' => 0.00007;
requires 'MongoDB';
requires 'Carp';
requires 'parent';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
test_requires 'Test::Exception';
test_requires 'Test::TCP';
test_requires 'File::Remove';
auto_set_repository;
auto_include;
auto_install;
WriteAll;
