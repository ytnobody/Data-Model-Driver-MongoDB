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

my $c = MySchema->new;
my $mongodb;

lives_ok {
    $mongodb = Data::Model::Driver::MongoDB->new(
        host => 'localhost',
        port => $server->port,
        db => 'mytest',
    );
} 'normal connection';

$c->set_base_driver( $mongodb );

for ( qw/ replace / ) {
    dies_ok { $c->$_( 'people' => '---' ) } 
        "method \"$_\" is defined, but not supported in D::M::D::MongoDB ".$Data::Model::Driver::MongoDB::VERSION.".";
}

undef $server;
remove( \1, $mongo_datapath.'/*.*' );

done_testing();
