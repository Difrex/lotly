# Author: Denis Zheleztsov <difrex.punk@gmail.com> (c) 2015-2016
# License: GPL3

package LOTLY::CONFIG;

use Config::Tiny;
use LOTLY::PRINTER;
use JSON;

sub new {
    my $class = shift;

    # Search config file
    # This is for testing only
    # In production config files must be placed in /etc/lotly
    my $printer = LOTLY::PRINTER->new();

    my $config;
    if ( -e '/etc/lotly/config.json' ) {
        $config = '/etc/lotly/config.json';
    }
    else {
        $config = 'conf/config.json';
    }

    my $self = { _file => $config, _printer => $printer };

    bless $self, $class;
    return $self;
}

# Load config
sub load {
    my ($self) = @_;
    my $printer = $self->{_printer};

    local $/;
    open my $fh, '<', $self->{_file}
        or $printer->error("Cannot open file: $!");

    my $json = <$fh>;
    my $conf = decode_json($json);
    close $fh;

    my $mini_dinstall_conf
        = load_minidinstall_conf( $conf->{mini_dinstall_conf}, $printer );

    $conf->{mini_dinstall_conf} = $mini_dinstall_conf;

    return $conf;
}

# Load mini-dinstall configuration
sub load_minidinstall_conf {
    my ( $conf, $printer ) = @_;

    my $tiny = Config::Tiny->new();
    $config = $tiny->read($conf)
        or $printer->error("Cannot load mini-dinstall configuration: $!");

    return $config;
}

1;
