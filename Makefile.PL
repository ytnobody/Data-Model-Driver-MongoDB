use inc::Module::Install;
name 'Data-Model-Driver-MongoDB';
all_from 'lib/Data/Model/Driver/MongoDB.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
