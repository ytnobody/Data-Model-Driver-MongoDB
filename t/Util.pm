package t::Util;
use strict;
use warnings;
use Path::Class;
use FindBin;
use Exporter 'import';
use Test::TCP;
use Guard;

our @EXPORT = qw( run_test_server );
our $db_path = "$FindBin::Bin/db";

sub create_db_path {
    dir( $db_path )->mkpath( 1, 0755 );
}

sub run_test_server {
    create_db_path();
    return (
        Test::TCP->new(
            code => sub {
                my $port = shift;
                exec 'mongod', '--dbpath' => $db_path, '--bind_ip' => '127.0.0.1', '--port' => $port;
            },
        ),
        guard { dir($db_path)->rmtree }
    );
}

1;

