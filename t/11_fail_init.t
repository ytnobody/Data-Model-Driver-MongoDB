use strict;
use Test::More;
use Test::Exception;
use FindBin;
use t::Util;
use lib ( "$FindBin::Bin/lib" );
use MySchema;
use Data::Model::Driver::MongoDB;

my ( $server, $guard ) = run_test_server();

my $mongodb;

throws_ok {
    $mongodb = Data::Model::Driver::MongoDB->new(
        host => 'localhost',
        port => $server->port,
    );
} qr/^you must give \'db\'/, 'error thrown when db not defined';

undef $server;

done_testing();
