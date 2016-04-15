# Author: Denis Zheleztsov <difrex.punk@gmail.com> (c) 2016
# License: GPL3

package LOTLY::PRINTER::File;

sub new {
    my $class = shift;

    my $config = shift;
    my $log    = $config->{output}->{file}->{log};
    my $err    = $config->{output}->{file}->{err};

    my $self = {
        _log => $log,
        _err => $err
    };

    bless $self, $class;

    return $self;
}

sub log {
    my ( $self, $message ) = @_;
    my $log = $self->{_log};

    open my $fh, '>>', $log or die "Cannot open file $log for write: $!\n";
    print $fh $message;
    close $fh;
}

sub err {
    my ( $self, $message ) = @_;
    my $err = $self->{_err};

    open my $fh, '>>', $err or die "Cannot open file $err for write: $!\n";
    print $fh $message;
    close $fh;
}

1;
