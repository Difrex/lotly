# Author: Denis Zheleztsov <difrex.punk@gmail.com> (c) 2016
# License: GPL3

package LOTLY::PACKAGES::Db;

use LOTLY::PRINTER;

sub new {
    my $class = shift;

    my $config = shift;

    my $self = {
        _config  => $config,
        _printer => LOTLY::PRINTER->new($config)
    };

    bless $self, $class;

    return $self;
}

sub rebuild_db {
    my ($self)  = @_;
    my $config  = $self->{_config};
    my $printer = $self->{_printer};

    # Mini dinstall configuration
    my $mini_dinstall      = $config->{system}->{mini_dinstall_path};
    my $mini_dinstall_conf = $config->{mini_dinstall_conf};

    my @stop_cmd  = split / /, $config->{system}->{mini_dinstall_stop};
    my @start_cmd = split / /, $config->{system}->{mini_dinstall_start};
    my @rebuild_cmd
        = ( $mini_dinstall, '-b', '--no-db', '-c', $mini_dinstall_conf );

    # Stop mini-dinstall service
    my $stop_state = stop_mini_dinstall( $printer, @stop_cmd );
    if ( $stop_state->{status} != 200 ) {
        return $stop_state;
    }
    else {
        $printer->ok("mini-dinstall stoped");
    }

    # Rebuild mini-dinstall database
    # mini-dinstall -b --no-db -c /srv/mini-dinstall.conf
    my $rebuild_state = rebuild_mini_dinstall_db($printer, @rebuild_cmd);
    if ( $rebuild_state->{status} != 200 ) {
        return $rebuild_state;
    }
    else {
        $printer->ok("mini-dinstall database rebuilded");
    }

    # Start mini-dinstall service
    return start_mini_dinstall($printer, @start_cmd);
}

sub rebuild_mini_dinstall_db {
    my ( $printer, @rebuild_cmd ) = @_;

    system(@rebuild_cmd) == 0
        or $printer->warning("Rebuild of mini-dinstall database failed")
        and return { status => 500 };

    return { status => 200 };
}

sub stop_mini_dinstall {
    my ( $printer, @stop_cmd ) = @_;

    system(@stop_cmd) == 0
        or $printer->warning("Cannot stop mini-dinstall")
        and return { status => 500 };

    return { status => 200 };
}

sub start_mini_dinstall {
    my ( $printer, @start_cmd ) = @_;

    system(@start_cmd) == 0
        or $printer->warning("Cannot start mini-dinstall")
        and return { status => 500 };

    return { status => 200 };
}

1;
