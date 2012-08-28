use strict;
use Test::More;
use Test::Exception;
use FindBin;
use t::Util;
use lib ( "$FindBin::Bin/lib" );
use MySchema;
use Data::Model::Driver::MongoDB;

my ( $server, $guard ) = run_test_server();

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

done_testing();
