use strict;
use Test::More;
use Test::Exception;
use FindBin;
use t::Util;
use lib ( "$FindBin::Bin/lib" );
use MySchema;
use Data::Model::Driver::MongoDB;

my ( $server, $guard ) = run_test_server();

my $mongodb = Data::Model::Driver::MongoDB->new(
    host => 'localhost',
    port => $server->port,
    db => 'mytest',
);

my $c = MySchema->new;

$c->set_base_driver( $mongodb );

{
    my @data = (
        { name => 'bob', age => 30 },
        { name => 'john', age => 28 },
        { name => 'cathy', age => 29 },
        { name => 'mascha', age => 28 },
        { name => 'victor', age => 30 },
        { name => 'vladmir', age => 24 },
        { name => 'aya', age => 26 },
        { name => 'sam', age => 28 },
        { name => 'billy', age => 27 },
        { name => 'ken', age => 29 },
    );

    $c->set( people => $_ ) for @data;
}

{
    my $rtn = $c->get( people => { where => [ age => 28 ] } );
    isa_ok $rtn, 'Data::Model::Iterator';
    my @exception = qw/ john mascha sam /;
    while ( my $rec = $rtn->next ) {
        isa_ok $rec, 'MySchema::people';
        is $rec->name, shift @exception;
    }
}

{
    my @member = qw/ bob victor aya ken vladmir /;
    my @id_list;
    push @id_list, $c->get( people => { where => [ name => $_ ] } )->next->id for @member;
    my @rows = $c->lookup_multi( people => \@id_list );
    for ( @rows ) {
        isa_ok $_, 'MySchema::people';
        is $_->name, shift @member;
    }
}

{
    my @rows = $c->get( people => { where => [ age => { '>' =>  28 } ] } );
    ok @rows < 1, 'Searching with range of values is not works.'; 
}

undef $server;

done_testing();
