# Author: Denis Zheleztsov <difrex.punk@gmail.com> (c) 2015-2016
# License: GPL3

package LOTLY::GPG;

use constant GPG => '/usr/bin/gpg';
use constant SKS => 'sks.example.com';

use LOTLY::CONFIG;

sub new {
    my $class = shift;

    my $self = {
        _gpg_conf => '~/.gnupg/gpg.conf',
        _gpg_dir  => '~/.gnupg/',
        _conf     => LOTLY::CONFIG->new()->load()
    };

    bless $self, $class;

    return $self;
}

# Verify signature
# If signature is valid => detach sign and return data
sub verify {
    my ( $self, $data ) = @_;

    my $verify_cmd = "echo '$data'|" . GPG . ' --verify';
    my $dec_cmd    = "echo '$data'|" . GPG . ' -d';
    if ( system($verify_cmd) == 0 ) {
        my $clear_data = `$dec_cmd`;
        return {
            status => 200,
            data   => $clear_data
        };
    }
    else {
        return {
            status  => 500,
            message => "Cannot verify sign"
        };
    }

}

# Sign key with server private key
sub sign_key {
    my ( $self, $gpgid ) = @_;
    my $config       = $self->{_conf};
    my $server_gpgid = $config->{system}->{gpgid};

    my $sign_cmd
        = GPG
        . ' --default-key '
        . $server_gpgid
        . ' --batch --yes --sign-key '
        . $gpgid;
    if ( system($sign_cmd) == 0 ) {
        return { status => 200 };
    }
    else {
        return { status => 500, message => "Cannot sign key: $gpgid" };
    }
}

# Add public key to gpg config
sub trust_key {
    my ( $self, $gpgid ) = @_;
    my $gpg_conf = $self->{_gpg_conf};

    my $long_gpgid   = get_long_gpgid($gpgid);
    my $trusted_line = "trusted-key " . $long_gpgid;

    # OK. Now we use gnupg configuration file to trust public key
    eval {
        open my $conf, '>>', $gpg_conf or warn "Cannot open gpg config\n";
        print $conf $trusted_line;
        close $conf;

        return { status => 200 };
    };
    if ($@) {
        return { status => 500, message => $@ };
    }
}

# Remove public key from config and trustdb
sub untrust {
    my ( $self, $gpgid ) = @_;
    my $gpg_conf   = $self->{_gpg_conf};
    my $gpg_dir    = $self->{_gpg_dir};
    my $long_gpgid = get_long_gpgid($gpgid);

    eval {
        my $new_config;
        my $back_config;
        open my $r_conf, '<', $gpg_conf or die "Cannot open gpg config: $!\n";
        while (<$r_conf>) {
            $back_config .= $_;
            if ( $_ =~ /$long_gpgid/ ) {
                $back_config .= $_;
                next;
            }
            my $new_config .= $_;
        }

        # Make backup
        open my $backup, '>', $gpg_dir . "backup"
            or die "Cannot open file: $!\n";
        print $backup $back_config;
        close $backup;

        # Write new configuration
        open my $w_conf, '>', $gpg_conf or die "Cannot open file: $!\n";
        print $w_conf $new_config;
        close $w_conf;

        delete_key($long_gpgid);
        return { status => 200 };
    };
    if ($@) {
        return { status => 500, message => $@ };
    }
}

# Delete gpgid from db
sub delete_key {
    my $gpgid = shift;

    my $del_key_cmd = GPG . ' --batch --yes --delete-keys ' . $gpgid;

    system($del_key_cmd) == 0 or warn "Can't delete key $gpgid\n";
}

# End of import
###############

# Recieve public key from SKS
sub recv {
    my $gpgid = shift;

    my @recv_key_cmd = ( GPG, '--keyserver', SKS, '--recv-keys', $gpgid );

    return system(@recv_key_cmd);
}

# Sign data with server key
sub sign {
    my ( $self, $data ) = @_;
    my $config = $self->{_conf};

    my $server_gpgid = $config->{system}->{gpgid};

    # gpg --clearsign --default-key F2875E32
    my $sign_cmd
        = "echo '$data'|"
        . GPG
        . ' --clearsign --default-key '
        . $server_gpgid;

    if ( system($sign_cmd) == 0 ) {
        my $sign = `$sign_cmd`;
        return {
            status => 200,
            data   => $sign
        };
    }
    else {
        return {
            status  => 500,
            message => "Cannot sign"
        };
    }
}

# Decrypt data
sub decrypt {
    my ( $self, $data ) = @_;

    my $dec_cmd = "echo '$data' | " . GPG . ' -d';

    # Verify signed message
    system($dec_cmd) == 0
        or return { state => -1 };

    my $plain = `$dec_cmd`;

    my $dec_cmd_verify = "echo '$plain' | " . GPG . ' -d';
    $plain = `$dec_cmd_verify` if system($dec_cmd_verify) == 0;

    if ($plain) {
        return { state => 0, data => $plain };
    }
    else {
        return { state => -1 };
    }
}

# Encrypt data
sub encrypt {
    my ( $self, $data, $recipient ) = @_;

    # Get key from SKS
    my @recv_key_cmd = ( GPG, '--keyserver', SKS, '--recv-keys', $recipient );
    system(@recv_key_cmd) or warn "$!\n";

    # Encrypt data
    print "Encrypt data for $recipient\n";
    my $enc_cmd
        = "echo '$data' | "
        . GPG . ' -e '
        . ' --recipient '
        . $recipient
        . ' --trust-model always';
    my $cipher = `$enc_cmd`;

    return $cipher;
}

# Armor encrypt
sub encrypt_armor {
    my ( $self, $data, $recipient ) = @_;

    # Get key from SKS
    my @recv_key_cmd = ( GPG, '--keyserver', SKS, '--recv-keys', $recipient );
    system(@recv_key_cmd) or warn "$!\n";

    # Encrypt data
    print "Encrypt data for $recipient\n";
    my $enc_cmd
        = "echo '$data' | "
        . GPG
        . ' -e -a '
        . ' --recipient '
        . $recipient
        . ' --trust-model always';
    my $cipher = `$enc_cmd`;

    return $cipher;
}

# Get long key
sub get_long_gpgid {
    my $gpgid = shift;

    my $listen_cmd      = GPG . ' --list-keys --with-colon ' . $gpgid;
    my $key_description = `$listen_cmd`;

    my @strings = split /\n/, $key_description;
    my @pub     = split /:/,  $strings[1];

    return $pub[4];
}

# Get F.Q.D.N
sub get_fqdn_by_gpgid {
    my ( $self, $gpgid ) = @_;

    # Get key from SKS
    my @recv_key_cmd = ( GPG, '--keyserver', SKS, '--recv-keys', $gpgid );
    system(@recv_key_cmd) == 0 or warn "$!\n";

    # Get info about key
    print "Get key info\n";
    my @key_info_cmd = ( GPG, '--list-key', $gpgid );
    if ( system(@key_info_cmd) == 0 ) {
        my $info_cmd = GPG . ' --list-key ' . $gpgid . ' | grep uid';
        my $uid      = `$info_cmd`;
        $uid =~ s/.+<(.+)>/$1/g;
        my @mail = split /@/, $uid;

        return { status => 200, fqdn => $mail[1] };
    }
    else {
        return { status => 500, message => 'GPG error' };
    }

}

1;
