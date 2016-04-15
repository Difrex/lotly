# Author: Denis Zheleztsov <difrex.punk@gmail.com> (c) 2016
# License: GPL3

package LOTLY::PACKAGES;

use LOTLY::PRINTER;
use LOTLY::PACKAGES::Move;
use LOTLY::PACKAGES::Db;
use JSON;

sub new {
    my $class = shift;

    my $config = shift;

    my $self = {
        _config  => $config,
        _printer => LOTLY::PRINTER->new(),
        _db      => LOTLY::PACKAGES::Db->new($config)
    };

    bless $self, $class;

    return $self;
}

# Main function
sub process {
    my ( $self, $ctl ) = @_;
    my $config  = $self->{_config};
    my $printer = $self->{_printer};
    my $db      = $self->{_db};
    my $move    = LOTLY::PACKAGES::Move->new( $self->{_config} );

    # Check file
    my $file = $config->{system}->{watch_dir} . '/' . $ctl->{name};
    my $package_move_conf = validate_json( $self, $file );

    if ($package_move_conf) {
        $printer->ok( "Process " . $ctl->{name} );

        my $state = $move->move_package($package_move_conf);
        if ( $state == 200 ) {
            my $db_state = $db->rebuild_db();
        }
        else {
            remove_invalid( $self, $file ) if $state != 200;
        }

    }
    else {
        # Remove invalid file
        remove_invalid( $self, $file );
    }

}

# Remove invalid file
sub remove_invalid {
    my ( $self, $file ) = @_;
    my $printer = $self->{_printer};

    my @rm_cmd = ( 'rm', '-f', $file ) or $printer->error($!);
    system(@rm_cmd) == 0
        or $printer->warning("Cannot remove invalid file")
        and return undef;
    $printer->warning( 'Invalid file ' . $file . ' removed' );
}

# Validate json structure
sub validate_json {
    my ( $self, $file ) = @_;
    my $printer = $self->{_printer};

    local $/;
    open my $fh, '<', $file
        or $printer->warning("Cannot open file: $!")
        and return undef;
    my $json = <$fh>;

    my $package_move_conf;
    eval {
        $package_move_conf = decode_json($json);
        close $fh;
    };
    if ($@) {
        $printer->warning("Not a json: $@");
        return undef;
    }

    # Check name
    if ( !( $package_move_conf->{name} ) ) {
        $printer->warning("Empty package name");
        return undef;
    }

    # Check version
    if ( !( $package_move_conf->{version} ) ) {
        $printer->warning("Empty package version");
        return undef;
    }

    # Check source
    if ( !( $package_move_conf->{source} ) ) {
        $printer->warning("Empty package source repo");
        return undef;
    }

    # Check destination
    if ( !( $package_move_conf->{destination} ) ) {
        $printer->warning("Empty package destination repo");
        return undef;
    }

    # Check type
    if ( !( $package_move_conf->{type} ) ) {
        $printer->warning(
            "Empty package move type. Should be 'copy' or 'move'");
        return undef;
    }

    return $package_move_conf;
}

1;
