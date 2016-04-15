# Author: Denis Zheleztsov <difrex.punk@gmail.com> (c) 2016
# License: GPL3

package LOTLY::PACKAGES::Move;

use LOTLY::PRINTER;
use LOTLY::GPG;
use JSON;

sub new {
    my $class = shift;

    my $config = shift;
    
    my $self = {
        _config  => $config,
        _printer => LOTLY::PRINTER->new($config),
        _gpg     => LOTLY::GPG->new()
    };

    bless $self, $class;

    return $self;
}

# Move or copy package
sub move_package {
    my ( $self, $move_conf ) = @_;
    my $config             = $self->{_config};
    my $printer            = $self->{_printer};
    my $gpg                = $self->{_gpg};
    my $mini_dinstall_conf = $config->{mini_dinstall_conf};
    my $archivedir         = $mini_dinstall_conf->{DEFAULT}->{archivedir};

    # Locate changes
    my $changes = locate_changes( $self, $move_conf );
    if ( $changes->{status} != 200 ) {
        return $changes->{status};
    }
    my $changes_data = get_changes_data( $self, $changes->{path} );

    # Verify changes
    my $verify = $gpg->verify($changes_data);

    if ( $verify->{status} != 200 ) {
        $printer->warning( $verify->{message} );
        return $verify->{status};
    }
    else {
        # Copy or move
        # Cut \n
        chomp( $verify->{data} );

        my @files_list  = get_files_list( $verify->{data} );
        my $new_changes = sign_changes( $self,
            new_changes( $verify->{data}, $move_conf ) );

        if ( $new_changes->{status} != 200 ) {
            $printer->warning( $new_changes->{message} );
            return $new_changes->{status};
        }

        $printer->ok("New changes file signed");

        if ( $move_conf->{type} eq 'move' ) {
            my $move_state = move( $self, $move_conf, $changes->{changes},
                $new_changes->{data}, @files_list );
            return $move_state->{status};
        }
        elsif ( $move_conf->{type} eq 'copy' ) {
            my $copy_state = copy( $self, $move_conf, $changes->{changes},
                $new_changes->{data}, @files_list );
            return $copy_state->{status};
        }
        else {
            $printer->warning("Unknown move type");
            return 500;
        }
    }
}

# Move package
sub move {
    my ( $self, $move_conf, $changes_file, $changes, @files_list ) = @_;
    my $config             = $self->{_config};
    my $printer            = $self->{_printer};
    my $mini_dinstall_conf = $config->{mini_dinstall_conf};
    my $archivedir         = $mini_dinstall_conf->{DEFAULT}->{archivedir};

    my $source_dir      = $archivedir . '/' . $move_conf->{source};
    my $destination_dir = $archivedir . '/' . $move_conf->{destination};
    my $changes_file_path
        = $archivedir . '/' . $move_conf->{source} . '/' . $changes_file;

    my $copy_state
        = copy( $self, $move_conf, $changes_file, $changes, @files_list );

    return { status => 500 } if $copy_state->{status} != 200;

    # Remove files
    for my $file (@files_list) {
        my $src_file = $source_dir . '/' . $file;
        my @rm_cmd = ( 'rm', '-f', $src_file );
        system(@rm_cmd) == 0
            or $printer->warning("Cannot remove file $file: $!")
            and rollback( $destination_dir, @files_list )
            and return { status => 500 };
        $printer->ok("- $file $move_conf->{source}");
    }

    # Remove old changes file
    my @rm_changes_cmd = ( 'rm', '-f', $changes_file_path );
    system(@rm_changes_cmd) == 0
        or $printer->warning(
        "Cannot remove old changes file $changes_file_path: $!");
    $printer->ok("Old changes file $changes_file_path removed");

    return { status => 200 };
}

# Copy package
sub copy {
    my ( $self, $move_conf, $changes_file, $changes, @files_list ) = @_;
    my $config             = $self->{_config};
    my $printer            = $self->{_printer};
    my $mini_dinstall_conf = $config->{mini_dinstall_conf};
    my $archivedir         = $mini_dinstall_conf->{DEFAULT}->{archivedir};

    my $source_dir      = $archivedir . '/' . $move_conf->{source};
    my $destination_dir = $archivedir . '/' . $move_conf->{destination};
    my $changes_file_path
        = $archivedir . '/' . $move_conf->{source} . '/' . $changes_file;
    my $new_changes_file_path
        = $archivedir . '/' . $move_conf->{destination} . '/' . $changes_file;

    # Backup old changes file
    my @backup_cp = ( 'cp', $changes_file_path, $changes_file_path . '.bak' );
    system(@backup_cp) == 0
        or $printer->warning("Cannot create backup: $!")
        and return { status => 500 };
    $printer->ok("Create backup $changes_file_path.bak");

    # Copy files
    for my $file (@files_list) {
        my $src_file = $source_dir . '/' . $file;
        my $dst_file = $destination_dir . '/' . $file;
        my @cp_cmd   = ( 'cp', $src_file, $dst_file );
        system(@cp_cmd) == 0
            or $printer->warning("Cannot copy file $src_file: $!")
            and rollback( $destination_dir, @files_list )
            and return { status => 500 };
        $printer->ok("+ $file $move_conf->{destination}");
    }

    # Write new changes file
    open my $fh, '>', $new_changes_file_path
        or $printer->warning(
        "Cannot open file $new_changes_file_path for write: $!")
        and rollback( $destination_dir, @files_list )
        and return
        { status => 500 };
    print $fh $changes;
    close $fh;
    $printer->ok("New changes file $new_changes_file_path saved");

    # Remove backup
    my @rm_changes_cmd = ( 'rm', '-f', $changes_file_path . '.bak' );
    system(@rm_changes_cmd) == 0
        or
        $printer->warning("Cannot remove backup $changes_file_path.bak: $!");
    $printer->ok("Backup removed");

    return { status => 200 };
}

# Rollback changes
sub rollback {
    my ( $destination_dir, @files_list ) = @_;

    # TODO: write it
}

# Sign new changes with lotly key
sub sign_changes {
    my ( $self, $data ) = @_;
    my $gpg = $self->{_gpg};

    return $gpg->sign($data);
}

# Replace source distribution
sub new_changes {
    my ( $data, $move_conf ) = @_;

    my $distr_source      = 'Distribution: ' . $move_conf->{source};
    my $distr_destination = 'Distribution: ' . $move_conf->{destination};

    $data =~ s/$distr_source/$distr_destination/g;
    $data
        =~ s/(.+\(\d.+\)) $move_conf->{source};/$1 $move_conf->{destination};/g;

    return $data;
}

# Return files list from changes file
sub get_files_list {
    my $data = shift;

    my @files_list;
    my $sw = 0;
    for my $line ( split /\n/, $data ) {
        if ( $line =~ /Files:/ ) {
            $sw = 1;
            next;
        }

        if ( $sw == 1 ) {
            @file_desc = split / /, $line;
            push @files_list, $file_desc[5] if $file_desc[5] =~ /\./;
        }
    }
    use Data::Dumper;
    print Dumper @files_list;
    return @files_list;
}

# Get changes file plain text data
sub get_changes_data {
    my ( $self, $changes_file_path ) = @_;
    my $printer = $self->{_printer};

    open my $fh, '<', $changes_file_path
        or $printer->error("Cannot open changes file: $!");
    my $data;
    while (<$fh>) {
        $data .= $_;
    }
    close $fh;

    return $data;
}

# Locate changes file
sub locate_changes {
    my ( $self, $move_conf ) = @_;
    my $config             = $self->{_config};
    my $printer            = $self->{_printer};
    my $mini_dinstall_conf = $config->{mini_dinstall_conf};

    # Locate changes file
    my $repo_dir = $mini_dinstall_conf->{DEFAULT}->{archivedir} . '/'
        . $move_conf->{source};

    my $name_version = $move_conf->{name} . '_' . $move_conf->{version};

    my $changes_file;
    opendir my $repo_dir_dh, $repo_dir
        or $printer->error("Cannot open repo dir: $!");
    while ( my $file = readdir $repo_dir_dh ) {
        if ( $file =~ /$name_version.+\.changes$/ ) {
            $changes_file = $file;
            last;
        }
    }
    closedir $repo_dir_dh;

    $printer->warning("changes file not found") and return { status => 500 }
        if !($changes_file);

    if ( -e $repo_dir . '/' . $changes_file ) {
        $printer->ok( $changes_file . " found" );
        return {
            status  => 200,
            changes => $changes_file,
            path    => $repo_dir . '/' . $changes_file
        };
    }
    else {
        $printer->warning("changes file not found");
        return { status => 500 };
    }
}

1;
