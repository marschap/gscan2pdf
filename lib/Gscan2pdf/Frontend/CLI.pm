package Gscan2pdf::Frontend::CLI;

use strict;
use warnings;
use feature 'switch';
no if $] >= 5.018, warnings => 'experimental::smartmatch';

use Locale::gettext 1.05;    # For translations
use Carp;
use Text::ParseWords;
use Glib qw(TRUE FALSE);
use POSIX qw(locale_h :signal_h :errno_h :sys_wait_h);
use Proc::Killfam;
use IPC::Open3;
use IO::Handle;
use Gscan2pdf::NetPBM;
use Gscan2pdf::Scanner::Options;
use Cwd;
use File::Spec;
use Readonly;
Readonly my $_POLL_INTERVAL               => 100;    # ms
Readonly my $_100                         => 100;
Readonly my $_SANE_STATUS_EOF             => 5;      # or we could use Sane
Readonly my $_1KB                         => 1024;
Readonly my $ALL_PENDING_ZOMBIE_PROCESSES => -1;

our $VERSION = '1.3.8';

my $EMPTY = q{};
my $COMMA = q{,};
my ( $_self, $logger, $d );
my $mess_warmingup1 =
  qr/Scanner[ ]warming[ ]up[ ]-[ ]waiting[ ]\d*[ ]seconds/xsm;
my $mess_warmingup2 = qr/wait[ ]for[ ]lamp[ ]warm-up/xsm;
my $mess_warmingup  = qr/$mess_warmingup1|$mess_warmingup2/xsm;
my $page_no         = qr/page[ ](\d*)/xsm;

sub setup {
    ( my $class, $logger ) = @_;
    $_self = {};
    $d     = Locale::gettext->domain(Glib::get_application_name);
    return;
}

sub get_devices {
    my ( $class, %options ) = @_;

    _watch_cmd(
        cmd =>
"$options{prefix} scanimage --formatted-device-list=\"'%i','%d','%v','%m','%t'%n\"",
        started_callback  => $options{started_callback},
        running_callback  => $options{running_callback},
        finished_callback => sub {
            my ( $output, $error ) = @_;
            if ( defined $options{finished_callback} ) {
                $options{finished_callback}
                  ->( Gscan2pdf::Frontend::CLI->parse_device_list($output) );
            }
        }
    );
    return;
}

sub parse_device_list {
    my ( $class, $output ) = @_;

    my (@device_list);

    if ( defined $output ) { $logger->info($output) }

    # parse out the device and model names
    my @words =
      parse_line( $COMMA, 0, substr $output, 0, index( $output, "'\n" ) + 1 );
    while (@words) {
        $output = substr $output, index( $output, "'\n" ) + 2, length $output;
        shift @words;
        push @device_list,
          {
            name   => shift @words,
            vendor => shift @words,
            model  => shift @words,
            type   => shift @words
          };
        @words = parse_line( $COMMA, 0, substr $output,
            0, index( $output, "'\n" ) + 1 );
    }

    return \@device_list;
}

sub find_scan_options {
    my ( $class, %options ) = @_;

    if ( not defined $options{prefix} ) { $options{prefix} = $EMPTY }
    if ( not defined $options{frontend} or $options{frontend} eq $EMPTY ) {
        $options{frontend} = 'scanimage';
    }

    # Get output from scanimage or scanadf.
    # Inverted commas needed for strange characters in device name
    my $cmd = _create_scanimage_cmd( \%options );

    _watch_cmd(
        cmd               => $cmd,
        started_callback  => $options{started_callback},
        running_callback  => $options{running_callback},
        finished_callback => sub {
            my ( $output, $error ) = @_;
            if ( defined $error and $error =~ /^$options{frontend}:[ ](.*)/xsm )
            {
                $error = $1;
            }
            if ( defined $error and defined $options{error_callback} ) {
                $options{error_callback}->($error);
            }
            my $options = Gscan2pdf::Scanner::Options->new_from_data($output);
            $_self->{device_name} = Gscan2pdf::Scanner::Options->device;
            if ( defined $options{finished_callback} ) {
                $options{finished_callback}->($options);
            }
        }
    );
    return;
}

# Select wrapper method for _scanadf() and _scanimage()

sub scan_pages {
    my ( $class, %options ) = @_;

    if ( not defined $options{prefix} ) { $options{prefix} = $EMPTY }

    if (
        defined $options{frontend}
        and (  $options{frontend} eq 'scanadf'
            or $options{frontend} eq 'scanadf-perl' )
      )
    {
        _scanadf(%options);
    }
    else {
        _scanimage(%options);
    }
    return;
}

# Carry out the scan with scanimage and the options passed.

sub _scanimage {
    my (%options) = @_;
    if ( not defined $options{frontend} or $options{frontend} eq $EMPTY ) {
        $options{frontend} = 'scanimage';
    }

    my $cmd = _create_scanimage_cmd( \%options, TRUE );

    # flag to ignore error messages after cancelling scan
    $_self->{abort_scan} = FALSE;

    # flag to ignore out of documents message
    # if successfully scanned at least one page
    my $num_scans = 0;

    _watch_cmd(
        cmd              => $cmd,
        dir              => $options{dir},
        started_callback => $options{started_callback},
        err_callback     => sub {
            my ($line) = @_;
            given ($line) {

                # scanimage seems to produce negative progress percentages
                # in some circumstances
                when (/^Progress:[ ](-?\d*[.]\d*)%/xsm) {
                    if ( defined $options{running_callback} ) {
                        $options{running_callback}->( $1 / $_100 );
                    }
                }
                when (/^Scanning[ ](-?\d*)[ ]pages/xsm) {
                    if ( defined $options{running_callback} ) {
                        $options{running_callback}
                          ->( 0, sprintf $d->get('Scanning %i pages...'), $1 );
                    }
                }
                when (/^Scanning[ ]$page_no/xsm) {
                    if ( defined $options{running_callback} ) {
                        $options{running_callback}
                          ->( 0, sprintf $d->get('Scanning page %i...'), $1 );
                    }
                }
                when (
/^Scanned[ ]$page_no [.][ ][(]scanner[ ]status[ ]=[ ](\d)[)]/xsm
                  )
                {
                    my ( $id, $return ) = ( $1, $2 );
                    if ( $return == $_SANE_STATUS_EOF ) {
                        my $timer = Glib::Timeout->add(
                            $_POLL_INTERVAL,
                            sub {
                                my $path =
                                  defined( $options{dir} )
                                  ? File::Spec->catfile( $options{dir},
                                    "out$id.pnm" )
                                  : "out$id.pnm";
                                if ( not -e $path ) {
                                    return Glib::SOURCE_CONTINUE;
                                }
                                if ( defined $options{new_page_callback} ) {
                                    $options{new_page_callback}->( $path, $id );
                                }
                                $num_scans++;
                                return Glib::SOURCE_REMOVE;
                            }
                        );
                    }
                }
                when ($mess_warmingup) {
                    if ( defined $options{running_callback} ) {
                        $options{running_callback}
                          ->( 0, $d->get('Scanner warming up') );
                    }
                }
                when (
/^$options{frontend}:[ ]sane_start:[ ]Document[ ]feeder[ ]out[ ]of[ ]documents/xsm ## no critic (ProhibitComplexRegexes)
                  )
                {
                    if ( defined $options{error_callback}
                        and $num_scans == 0 )
                    {
                        $options{error_callback}
                          ->( $d->get('Document feeder out of documents') );
                    }
                }
                when (
                    $_self->{abort_scan} == TRUE
                      and ( $line =~
qr{^$options{frontend}:[ ]sane_start:[ ]Error[ ]during[ ]device[ ]I/O}xsm
                        or $line =~
                        /^$options{frontend}:[ ]received[ ]signal[ ]2/xsm
                        or $line =~
                        /^$options{frontend}:[ ]trying[ ]to[ ]stop[ ]scanner/xsm
                      )
                  )
                {
                    ;
                }
                when (/^$options{frontend}:[ ]rounded/xsm) {
                    $logger->info( substr $line, 0, index( $line, "\n" ) + 1 );
                }
                when (
/^$options{frontend}:[ ]sane_(?:start|read):[ ]Device[ ]busy/xsm
                  )
                {
                    if ( defined $options{error_callback} ) {
                        $options{error_callback}->( $d->get('Device busy') );
                    }
                }
                when (
/^$options{frontend}:[ ]sane_(?:start|read):[ ]Operation[ ]was[ ]cancelled/xsm
                  )
                {
                    if ( defined $options{error_callback} ) {
                        $options{error_callback}
                          ->( $d->get('Operation cancelled') );
                    }
                }
                default {
                    if ( defined $options{error_callback} ) {
                        $options{error_callback}->(
                            $d->get('Unknown message: ') . substr $line,
                            0, index $line, "\n"
                        );
                    }
                }
            }
        },
        finished_callback => $options{finished_callback}
    );
    return;
}

# Helper sub to create the scanimage command

sub _create_scanimage_cmd {
    my ( $options, $scan ) = @_;
    my %options = %{$options};

    if ( not defined $options{frontend} ) {
        $options{frontend} = 'scanimage';
    }

    my $help = $scan ? $EMPTY : '--help';

    # inverted commas needed for strange characters in device name
    my $device = "--device-name='$options{device}'";

    # Add basic options
    my @options;
    for ( @{ $options{options} } ) {
        my ( $key, $value ) = each %{$_};
        if ( $key =~ /^[xytl]$/xsm ) {
            push @options, "-$key $value";
        }
        else {
            push @options, "--$key='$value'";
        }
    }
    if ( not $help ) {
        push @options, '--batch';
        push @options, '--progress';
        if ( defined $options{start} and $options{start} != 0 ) {
            push @options, "--batch-start=$options{start}";
        }
        if ( defined $options{npages} and $options{npages} != 0 ) {
            push @options, "--batch-count=$options{npages}";
        }
        if ( defined $options{step} and $options{step} != 1 ) {
            push @options, "--batch-increment=$options{step}";
        }
    }

    # Create command
    return "$options{prefix} $options{frontend} $help $device @options";
}

# Carry out the scan with scanadf and the options passed.

sub _scanadf {
    my (%options) = @_;

    if ( not defined $options{frontend} ) { $options{frontend} = 'scanadf' }

    # inverted commas needed for strange characters in device name
    my $device = "--device-name='$options{device}'";

    # Add basic options
    my @options;
    if ( defined $options{options} ) { @options = @{ $options{options} } }
    push @options, '--start-count=1';
    if ( $options{npages} != 0 ) {
        push @options, "--end-count=$options{npages}";
    }
    push @options, '-o out%d.pnm';

    # Create command
    my $cmd = "$options{prefix} $options{frontend} $device @options";

    # scanadf doesn't have a progress option, so create a timeout to check
    # the size of the image being currently scanned.
    my $size;
    my $id      = 1;
    my $running = TRUE;
    if ( defined $options{running_callback} ) {
        my $timer = Glib::Timeout->add(
            $_POLL_INTERVAL,
            sub {
                if ($running) {
                    if ( defined $size ) {
                        if ($size) {
                            $options{running_callback}
                              ->( ( -s "out$id.pnm" ) / $size );
                        }
                        else {
                            # Pulse
                            $options{running_callback}->();
                        }
                    }

                    # 50 is enough of the file for the header to be complete
                    elsif ( -e "out$id.pnm"
                        and ( -s "out$id.pnm" ) >
                        50 )    ## no critic (ProhibitMagicNumbers)
                    {
                        $size = Gscan2pdf::NetPBM::file_size_from_header(
                            "out$id.pnm");
                    }
                    else {
                        # Pulse
                        $options{running_callback}->();
                    }
                    return Glib::SOURCE_CONTINUE;
                }
                return Glib::SOURCE_REMOVE;
            }
        );
    }

    _watch_cmd(
        cmd              => $cmd,
        dir              => $options{dir},
        started_callback => $options{started_callback},
        err_callback     => sub {
            my ($line) = @_;
            given ($line) {
                when ($mess_warmingup) {
                    if ( defined $options{running_callback} ) {
                        $options{running_callback}
                          ->( 0, $d->get('Scanner warming up') );
                    }
                }
                when (/^Scanned[ ]document[ ]out(\d*)[.]pnm/xsm) {
                    $id = $1;

                    # Timer will run until callback returns false
                    my $timer = Glib::Timeout->add(
                        $_POLL_INTERVAL,
                        sub {
                            my $path =
                              defined( $options{dir} )
                              ? File::Spec->catfile( $options{dir},
                                "out$id.pnm" )
                              : "out$id.pnm";
                            if ( not -e $path ) {
                                return Glib::SOURCE_CONTINUE;
                            }
                            if ( defined $options{new_page_callback} ) {
                                $options{new_page_callback}->( $path, $id );
                            }
                            return Glib::SOURCE_REMOVE;
                        }
                    );

       # Prevent the Glib::Timeout from checking the size of the file when it is
       # about to be renamed
                    undef $size;

                }
                when (/^Scanned[ ]\d*[ ]pages/xsm) {
                    ;
                }
                when (/^$options{frontend}:[ ]rounded/xsm) {
                    $logger->info( substr $line, 0, index( $line, "\n" ) + 1 );
                }
                when (/^$options{frontend}:[ ]sane_start:[ ]Device[ ]busy/xsm) {
                    if ( defined $options{error_callback} ) {
                        $options{error_callback}->( $d->get('Device busy') );
                    }
                    $running = FALSE;
                }
                when (
/^$options{frontend}:[ ]sane_read:[ ]Operation[ ]was[ ]cancelled/xsm
                  )
                {
                    if ( defined $options{error_callback} ) {
                        $options{error_callback}
                          ->( $d->get('Operation cancelled') );
                    }
                    $running = FALSE;
                }
                default {
                    if ( defined $options{error_callback} ) {
                        $options{error_callback}->(
                            $d->get('Unknown message: ') . substr $line,
                            0, index $line, "\n"
                        );
                    }
                }
            }
        },
        finished_callback => sub {
            if ( defined $options{finished_callback} ) {
                $options{finished_callback}->();
            }
            $running = FALSE;
        }
    );
    return;
}

# Flag the scan routine to abort

sub cancel_scan {
    $_self->{abort_scan} = TRUE;
    return;
}

sub device {
    return $_self->{device_name};
}

sub _watch_cmd {
    my (%options) = @_;

    my $out_finished = FALSE;
    my $err_finished = FALSE;
    my $error_flag   = FALSE;
    $logger->info( $options{cmd} );

    if ( defined $options{running_callback} ) {
        my $timer = Glib::Timeout->add(
            $_POLL_INTERVAL,
            sub {
                $options{running_callback}->();
                return Glib::SOURCE_REMOVE
                  if ( $out_finished or $err_finished );
                return Glib::SOURCE_CONTINUE;
            }
        );
    }

    # Make sure we are in temp directory
    my $cwd = getcwd;
    if ( defined $options{dir} ) { chdir $options{dir} }

    # Interface to scanimage
    my ( $write, $read );
    my $error = IO::Handle->new;    # this needed because of a bug in open3.
    my $pid = IPC::Open3::open3( $write, $read, $error, $options{cmd} );
    $logger->info("Forked PID $pid");

    # change back to original directory
    chdir $cwd;

    if ( defined $options{started_callback} ) { $options{started_callback}->() }
    if ( $_self->{abort_scan} ) {
        local $SIG{INT} = 'IGNORE';
        $logger->info("Sending INT signal to PID $pid and its children");
        killfam 'INT', ($pid);
    }
    my ( $stdout, $stderr, $error_message );

    _add_watch(
        $read,
        sub {
            my ($line) = @_;
            $stdout .= $line;
            if ( defined $options{out_callback} ) {
                $options{out_callback}->($line);
            }
        },
        sub {

          # Don't flag this until after the callback to avoid the race condition
          # where stdout is truncated by stderr prematurely reaping the process
            $out_finished = TRUE;
        },
        sub {
            ($error_message) = @_;
            $error_flag = TRUE;
        }
    );
    _add_watch(
        $error,
        sub {
            my ($line) = @_;
            $stderr .= $line;
            if ( defined $options{err_callback} ) {
                $options{err_callback}->($line);
            }
        },
        sub {

          # Don't flag this until after the callback to avoid the race condition
          # where stderr is truncated by stdout prematurely reaping the process
            $err_finished = TRUE;
        },
        sub {
            ($error_message) = @_;
            $error_flag = TRUE;
        }
    );

    # Watch for the process to hang up before running the finished callback
    Glib::Child->watch_add(
        $pid,
        sub {

          # Although the process has hung up, we may still have output to read,
          # so wait until the _watch_add flags that the process has ended first.
            my $timer = Glib::Timeout->add(
                $_POLL_INTERVAL,
                sub {
                    if ($error_flag) {
                        if ( defined $options{error_callback} ) {
                            $options{error_callback}->($error_message);
                        }
                        return Glib::SOURCE_REMOVE;
                    }
                    elsif ( $out_finished and $err_finished ) {

                        if ( defined $options{finished_callback} ) {
                            $options{finished_callback}->( $stdout, $stderr );
                        }
                        $logger->info('Waiting to reap process');
                        $logger->info( 'Reaped PID ',
                            waitpid $ALL_PENDING_ZOMBIE_PROCESSES, WNOHANG );
                        return Glib::SOURCE_REMOVE;
                    }
                    return Glib::SOURCE_CONTINUE;
                }
            );
        }
    );
    return;
}

sub _add_watch {
    my ( $fh, $line_callback, $finished_callback, $error_callback ) = @_;
    my $line;
    Glib::IO->add_watch(
        fileno($fh),
        [ 'in', 'hup' ],
        sub {
            my ( $fileno, $condition ) = @_;
            my $buffer;
            if ( $condition & 'in' ) { # bit field operation. >= would also work

                # Only reading one buffer, rather than until sysread gives EOF
                # because things seem to be strange for stderr
                sysread $fh, $buffer, $_1KB;
                if ($buffer) { $line .= $buffer }

                while ( $line =~ /([\r\n])/xsm ) {
                    my $le = $1;
                    if ( defined $line_callback ) {
                        $line_callback->(
                            substr $line, 0, index( $line, $le ) + 1
                        );
                    }
                    $line = substr $line, index( $line, $le ) + 1, length $line;
                }
            }

            # Only allow the hup if sure an empty buffer has been read.
            if (
                ( $condition & 'hup' ) # bit field operation. >= would also work
                and ( not defined $buffer or $buffer eq $EMPTY )
              )
            {
                if ( close $fh ) {
                    $finished_callback->();
                }
                elsif ( defined $error_callback ) {
                    $error_callback->('Error closing filehandle');
                }
                return Glib::SOURCE_REMOVE;
            }
            return Glib::SOURCE_CONTINUE;
        }
    );
    return;
}

1;

__END__
