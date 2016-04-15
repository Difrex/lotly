# Author: Denis Zheleztsov <difrex.punk@gmail.com> (c) 2016
# License: GPL3

package LOTLY::PRINTER::Elasticsearch;

use Search::Elasticsearch;

sub new {
    my $class = shift;

    my $self = { _config => shift };

    bless $self, $class;

    return $self;
}

# Write document to Elasticsearch
sub write_doc {
    my ( $self, $doc ) = @_;
    my $config = $self->{_config};
    my $index  = $config->{output}->{elasticsearch}->{index};
    my @hosts  = $config->{output}->{elasticsearch}->{hosts};

    # Connect to elasticsearch
    my $e = Search::Elasticsearch->new( nodes => @hosts );

    # Write document
    $e->index(
        type      => 'logs',
        index     => $index,
        body      => $doc
    );
}

1;
