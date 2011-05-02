package Data::Model::Driver::MongoDB;

use strict;
use warnings;
use parent qw/ Data::Model::Driver /;
our $VERSION = '0.01';

use MongoDB;
use Carp ();
$Carp::Internal{ (__PACKAGE__) } = 1;

sub init {
    my $self = shift;
    my @attr = qw/
        host w wtimeout auto_reconnect auto_connect timeout
        username password db_name query_timeout find_master port
        left_host left_port right_host right_port
    /;
    $self->{ mongodb_config } = {};
    for ( @attr ) {
        $self->{ mongodb_config }->{ $_ } = delete $self->{ $_ } if $self->{ $_ };
    }
    $self->{ mongodb_connection } = $self->_mongodb_connect( %{ $self->{ mongodb_config } } );
    Carp::confess 'you must give \'db\' attribute for instantiate '.__PACKAGE__ unless defined $self->{ db };
}

sub _mongodb_connect {
    my $self = shift;
    my %conf = @_;
    MongoDB::Connection->new( %conf );
}

sub connector { shift->{ mongodb_connection } }

sub _fetch {
    my ( $self, $schema, $query, $multiple ) = @_;
    my $db = $self->{ db };
    my $collection = $schema->model;
    my $res = $multiple ? $self->connector->$db->$collection->find( $query )->all
                        : $self->connector->$db->$collection->find_one( $query )
    ;
    return unless defined $res;
    $res->{ $schema->{ key }->[0] } = $res->{ _id }->to_string;
    return $res;
}

sub _create_data {
    my ( $self, $schema ) = @_;
    my $db = $self->{ db };
    my $collection = $schema->model;
    $self->connector->$db->$collection->insert( {} );
}

sub _update {
    my ( $self, $schema, $query, $columns ) = @_;
    my $db = $self->{ db };
    my $collection = $schema->model;
    $self->connector->$db->$collection->update( $query, $columns );
}

sub _remove_data {
    my ( $self, $schema, $query ) = @_;
    my $db = $self->{ db };
    my $collection = $schema->model;
    $self->connector->$db->$collection->remove( $query );
}


sub lookup {
    my ( $self, $schema, $id ) = @_;
    $self->_fetch( $schema, { $schema->{ key }->[0] => $id->[0] } );
}

sub lookup_multi {
    my ( $self, $schema, $ids ) = @_;
    my %res;
    $res{ $_ } = $self->_fetch( $schema, { $schema->{ key }->[0] => $_ } ) for @{ $ids };
    return \%res;
}

sub get {
    my ( $self, $schema, $query ) = @_;
    $self->_fetch( $schema, $query, 1 );
}

sub set {
    my ( $self, $schema, $prikey, $columns ) = @_;
    my $oid = $self->_create_data( $schema );
    $columns->{ $schema->{ key }->[0] } = $oid->to_string;
    $self->_update( $schema, { _id => $oid }, $columns );
    $self->_fetch( $schema, { _id => $oid } );
}

sub delete {
    my ( $self, $schema, $prikey ) = @_;
    $self->_remove_data( $schema, { _id => MongoDB::OID->new( value => $prikey->[0] ) } );
}

sub update {
    my ( $self, $schema, $prikey_old, $prikey_new, $clumns_old, $columns_new, $columns_backup ) = @_;
    $self->_update( $schema, { _id => MongoDB::OID->new( value => $prikey_old->[0] ) }, $columns_new );
}

sub replace {
}

sub get_multi {
}

sub set_multi {
}

sub delete_multi {
}

1;
__END__

=head1 NAME

Data::Model::Driver::MongoDB - storage driver of Data::Model for MongoDB

=head1 SYNOPSIS

  ### your schema class
  package Oreore::Schema;
  use parent qw/ Data::Model /;
  use Data::Model::Schema;
  
  install_model book => schema {
      key 'id';
      columns qw/ id name price genre note /;
  };
  
  1;

  ### and use it
  use Oreore::Schema;
  use Data::Model::Driver::MongoDB;
  
  my $mongo_db = Data::Model::Driver::MongoDB->new( 
      host => 'localhost',
      port => 25252,
      db => 'my_database',
  );
  
  my $schema = Oreore::Schema->new;
  $schema->set_base_driver( $mongo_db );
  
  my $book = $schema->lookup( book => '4dbe781ebbb7f5362f000000' );


=head1 DESCRIPTION

Now, it's developing. Some undefined logic is there.

=head1 AUTHOR

ytnobody E<lt>ytnobody@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
