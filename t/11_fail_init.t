use strict;
use Test::More;
use Test::Exception;
use Test::TCP;
use File::Remove qw/ remove /;
use FindBin;
use lib ( "$FindBin::Bin/lib" );
use MySchema;
use Data::Model::Driver::MongoDB;

my $mongo_datapath = "$FindBin::Bin/data/db";

my $server = Test::TCP->new( 
    code => sub {
        my $port = shift;
        exec 'mongod', '--dbpath' => $mongo_datapath, '--bind_ip' => '127.0.0.1', '--port' => $port;
    },
);

my $mongodb;

throws_ok {
    $mongodb = Data::Model::Driver::MongoDB->new(
        host => 'localhost',
        port => $server->port,
    );
} qr/^you must give \'db\'/, 'error thrown when db not defined';

undef $server;
remove( \1, $mongo_datapath.'/*.*' );

done_testing();
