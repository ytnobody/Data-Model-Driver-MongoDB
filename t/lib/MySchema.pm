package MySchema;
use warnings;
use strict;
use parent qw/ Data::Model /;
use Data::Model::Schema;

install_model people => schema { 
    key 'id'; 
    columns qw/ id name age /;
};

1;
