# Author: Denis Zheleztsov <difrex.punk@gmail.com> (c) 2016
# License: GPL3

package LOTLY::PRINTER;

use LOTLY::PRINTER::File;

use Term::ANSIColor;

sub new {
    my $class = shift;

    my $config = shift;
    my $self   = {
        _config => $config,
        _file   => LOTLY::PRINTER::File->new($config)
    };

    bless $self, $class;

    return $self;
}

# Print green OK message
sub ok {
    my ( $self, $message ) = @_;
    my $config   = $self->{_config};
    my $file     = $self->{_file};
    my $out_type = $config->{output_type};

    my $ok = '[ ' . colored( 'OK', 'green' ) . ' ] ';
    my $timestamp = '[ ' . localtime( time() ) . ' ] ';
    if ( $out_type eq 'std' ) {
        print STDOUT $ok . $timestamp . $message . "\n";
    }
    elsif ( $out_type eq 'elasticsearch' ) {
        eval {
            require LOTLY::PRINTER::Elasticsearch;
            my $elastic = LOTLY::PRINTER::Elasticsearch->new($config);
            $elastic->write_doc(
                {   message  => $message,
                    date     => time(),
                    loglevel => 'info'
                }
            );
        };
        if ($@) {
            print "You need install LOTLY::PRINTER::Elasticsearch\n";
            exit(2);
        }
    }
    elsif ( $out_type eq 'file' ) {
        $file->log( $ok . $timestamp . $message . "\n" );
    }
}

# Print yellow WARNING message
sub warning {
    my ( $self, $message ) = @_;
    my $config   = $self->{_config};
    my $out_type = $config->{output_type};

    my $warning = '[ ' . colored( 'WARNING', 'yellow' ) . ' ] ';
    my $timestamp = '[ ' . localtime( time() ) . ' ] ';
    if ( $out_type eq 'std' ) {
        print STDERR $warning . $timestamp . $message . "\n";
    }
    elsif ( $out_type eq 'elasticsearch' ) {
        eval {
            require LOTLY::PRINTER::Elasticsearch;
            my $elastic = LOTLY::PRINTER::Elasticsearch->new($config);
            $elastic->write_doc(
                {   message  => $message,
                    date     => time(),
                    loglevel => 'warning'
                }
            );
        };
        if ($@) {
            print "You need install LOTLY::PRINTER::Elasticsearch\n";
            exit(2);
        }
    }
    elsif ( $out_type eq 'file' ) {
        $file->err( $warning . $timestamp . $message . "\n" );
    }
}

# Print error RED message
sub error {
    my ( $self, $message ) = @_;

    my $error = '[ ' . colored( 'ERROR', 'red' ) . ' ] ';
    my $timestamp = '[ ' . localtime( time() ) . ' ] ';
    if ( $out_type eq 'std' ) {
        print STDERR $error . $timestamp . $message . "\n";

        exit(2);
    }
    elsif ( $out_type eq 'elasticsearch' ) {
        eval {
            require LOTLY::PRINTER::Elasticsearch;
            my $elastic = LOTLY::PRINTER::Elasticsearch->new($config);
            $elastic->write_doc(
                {   message  => $message,
                    date     => time(),
                    loglevel => 'error'
                }
            );
        };
        if ($@) {
            print "You need install LOTLY::PRINTER::Elasticsearch\n";
            exit(2);
        }
    }
    elsif ( $out_type eq 'file' ) {
        $file->err( $error . $timestamp . $message . "\n" );

        exit(2);
    }
}

1;
