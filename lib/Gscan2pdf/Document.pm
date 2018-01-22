package Gscan2pdf::Document;

use strict;
use warnings;
use feature 'switch';
no if $] >= 5.018, warnings => 'experimental::smartmatch';

use threads;
use threads::shared;
use Thread::Queue;

use Gscan2pdf::Scanner::Options;
use Gscan2pdf::Page;
use Gscan2pdf::Tesseract;
use Gscan2pdf::Ocropus;
use Gscan2pdf::Cuneiform;
use Gscan2pdf::NetPBM;
use Gscan2pdf::Translation '__';    # easier to extract strings with xgettext
use Glib 1.210 qw(TRUE FALSE)
  ; # To get TRUE and FALSE. 1.210 necessary for Glib::SOURCE_REMOVE and Glib::SOURCE_CONTINUE
use Socket;
use FileHandle;
use Image::Magick;
use File::Temp;        # To create temporary files
use File::Basename;    # Split filename into dir, file, ext
use File::Copy;
use Storable qw(store retrieve);
use Archive::Tar;      # For session files
use Proc::Killfam;
use IPC::Open3 'open3';
use Symbol;            # for gensym
use Try::Tiny;
use Set::IntSpan 1.10;               # For size method for page numbering issues
use PDF::API2;
use English qw( -no_match_vars );    # for $PROCESS_ID, $INPUT_RECORD_SEPARATOR
                                     # $CHILD_ERROR
use POSIX qw(:sys_wait_h strftime);
use Data::UUID;
use Date::Calc qw(Add_Delta_Days Date_to_Time Today);
use version;
use Readonly;
Readonly our $POINTS_PER_INCH             => 72;
Readonly my $STRING_FORMAT                => 8;
Readonly my $_POLL_INTERVAL               => 100;     # ms
Readonly my $THUMBNAIL                    => 100;     # pixels
Readonly my $_100PERCENT                  => 100;
Readonly my $YEAR                         => 5;
Readonly my $BOX_TOLERANCE                => 5;
Readonly my $BITS_PER_BYTE                => 8;
Readonly my $ALL_PENDING_ZOMBIE_PROCESSES => -1;
Readonly my $INFINITE                     => -1;
Readonly my $NOT_FOUND                    => -1;
Readonly my $PROCESS_FAILED               => -1;
Readonly my $SIGNAL_MASK                  => 127;
Readonly my $MONTHS_PER_YEAR              => 12;
Readonly my $DAYS_PER_MONTH               => 31;
Readonly my $ID_URI                       => 0;
Readonly my $ID_PAGE                      => 1;
Readonly my $STRFTIME_YEAR_OFFSET         => -1900;
Readonly my $STRFTIME_MONTH_OFFSET        => -1;

BEGIN {
    use Exporter ();
    our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

    $VERSION = '1.8.10';

    use base qw(Exporter Gtk2::Ex::Simple::List);
    %EXPORT_TAGS = ();    # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK = qw();

    # define hidden string column for page data
    Gtk2::Ex::Simple::List->add_column_type(
        'hstring',
        type => 'Glib::Scalar',
        attr => 'hidden'
    );
}
our @EXPORT_OK;

my $jobs_completed = 0;
my $jobs_total     = 0;
my $uuid_object    = Data::UUID->new;
my $EMPTY          = q{};
my $SPACE          = q{ };
my $PERCENT        = q{%};
my ( $_self, $logger, $paper_sizes, %callback );

my %format = (
    'pnm' => 'Portable anymap',
    'ppm' => 'Portable pixmap format (color)',
    'pgm' => 'Portable graymap format (gray scale)',
    'pbm' => 'Portable bitmap format (black and white)',
);

sub setup {
    ( my $class, $logger ) = @_;
    $_self = {};
    Gscan2pdf::Page->set_logger($logger);

    $_self->{requests} = Thread::Queue->new;
    $_self->{return}   = Thread::Queue->new;
    share $_self->{progress};
    share $_self->{message};
    share $_self->{process_name};
    share $_self->{cancel};
    $_self->{cancel} = FALSE;

    $_self->{thread} = threads->new( \&_thread_main, $_self );
    return;
}

sub new {
    my ( $class, %options ) = @_;
    my $self = Gtk2::Ex::Simple::List->new(
        q{#}             => 'int',
        __('Thumbnails') => 'pixbuf',
        'Page Data'      => 'hstring',
    );
    $self->get_selection->set_mode('multiple');
    $self->set_headers_visible(FALSE);
    $self->set_reorderable(TRUE);
    for ( keys %options ) {
        $self->{$_} = $options{$_};
    }

    # Default thumbnail sizes
    if ( not defined( $self->{heightt} ) ) { $self->{heightt} = $THUMBNAIL }
    if ( not defined( $self->{widtht} ) )  { $self->{widtht}  = $THUMBNAIL }

    bless $self, $class;
    Glib::Timeout->add( $_POLL_INTERVAL, \&check_return_queue, $self );

    my $target_entry = {
        target => 'Glib::Scalar',    # some string representing the drag type
        flags  => 'same-widget',     # Gtk2::TargetFlags
        info   => $ID_PAGE,          # some app-defined integer identifier
    };
    $self->drag_source_set( 'button1-mask', [ 'copy', 'move' ], $target_entry );
    $self->drag_dest_set(
        [ 'drop', 'motion', 'highlight' ],
        [ 'copy', 'move' ],
    );
    my $target_list = Gtk2::TargetList->new();
    $target_list->add_uri_targets($ID_URI);
    $target_list->add_table($target_entry);
    $self->drag_dest_set_target_list($target_list);

    $self->signal_connect(
        'drag-data-get' => sub {
            my ( $tree, $context, $sel ) = @_;
            $sel->set( $sel->target, $STRING_FORMAT, 'data' );
        }
    );

    $self->signal_connect( 'drag-data-delete' => \&delete_selection );

    $self->signal_connect(
        'drag-data-received' => \&drag_data_received_callback );

    # Callback for dropped signal.
    $self->signal_connect(
        drag_drop => sub {
            my ( $tree, $context, $x, $y, $when ) = @_;
            if ( my $targ = $context->targets ) {
                $tree->drag_get_data( $context, $targ, $when );
                return TRUE;
            }
            return FALSE;
        }
    );

    # Set the page number to be editable
    $self->set_column_editable( 0, TRUE );

    # Set-up the callback when the page number has been edited.
    $self->{row_changed_signal} = $self->get_model->signal_connect(
        'row-changed' => sub {
            $self->get_model->signal_handler_block(
                $self->{row_changed_signal} );

            # Sort pages
            $self->manual_sort_by_column(0);

            # And make sure there are no duplicates
            $self->renumber;
            $self->get_model->signal_handler_unblock(
                $self->{row_changed_signal} );
        }
    );

    return $self;
}

# Set the paper sizes in the manager and worker threads

sub set_paper_sizes {
    ( my $class, $paper_sizes ) = @_;
    _enqueue_request( 'paper_sizes', { paper_sizes => $paper_sizes } );
    return;
}

sub quit {
    _enqueue_request('quit');
    $_self->{thread}->join();
    $_self->{thread} = undef;
    return;
}

# Kill all running processes

sub cancel {
    my ( $self, $cancel_callback, $process_callback ) = @_;

    # Empty process queue first to stop any new process from starting
    $logger->info('Emptying process queue');
    while ( $_self->{requests}->dequeue_nb ) { }
    $jobs_completed = 0;
    $jobs_total     = 0;

    # Then send the thread a cancel signal
    # to stop it going beyond the next break point
    $_self->{cancel} = TRUE;

    # Kill all running processes in the thread
    for my $pidfile ( keys %{ $self->{running_pids} } ) {
        my $pid = slurp($pidfile);
        if ( $pid ne $EMPTY ) {
            if ( $pid == 1 ) { next }
            if ( defined $process_callback ) {
                $process_callback->($pid);
            }
            $logger->info("Killing PID $pid");
            local $SIG{HUP} = 'IGNORE';
            killfam 'HUP', ($pid);
            delete $self->{running_pids}{$pidfile};
        }
    }

    my $uuid = $uuid_object->create_str;
    $callback{$uuid}{cancelled} = $cancel_callback;

    # Add a cancel request to ensure the reply is not blocked
    $logger->info('Requesting cancel');
    my $sentinel = _enqueue_request( 'cancel', { uuid => $uuid } );
    return $self->_monitor_process( sentinel => $sentinel, uuid => $uuid );
}

sub create_pidfile {
    my ( $self, %options ) = @_;
    my $pidfile;
    try {
        $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );
    }
    catch {
        $logger->error("Caught error writing to $self->{dir}: $_");
        if ( $options{error_callback} ) {
            $options{error_callback}
              ->("Error: unable to write to $self->{dir}.");
        }
    };
    return $pidfile;
}

# To avoid race condtions importing multiple files,
# run get_file_info on all files first before checking for errors and importing

sub import_files {
    my ( $self, %options ) = @_;

    my @info;
    for my $i ( 0 .. $#{ $options{paths} } ) {
        my $path = $options{paths}->[$i];

        # File in which to store the process ID
        # so that it can be killed if necessary
        my $pidfile = $self->create_pidfile(%options);
        if ( not defined $pidfile ) { return }

        my $uuid = $self->_note_callbacks(%options);
        $callback{$uuid}{finished} = sub {
            my ($info) = @_;
            $logger->debug("In finished_callback for $path");
            push @info, $info;
            if ( $i == $#{ $options{paths} } ) {
                $self->_get_file_info_finished_callback(
                    \@info,
                    uuid => $uuid,
                    %options
                );
            }
        };
        my $sentinel =
          _enqueue_request( 'get-file-info',
            { path => $path, pidfile => "$pidfile", uuid => $uuid } );

        $self->_monitor_process(
            sentinel => $sentinel,
            pidfile  => $pidfile,
            info     => TRUE,
            uuid     => $uuid,
        );
    }
    return;
}

sub _get_file_info_finished_callback {
    my ( $self, $info, %options ) = @_;
    if ( @{$info} > 1 ) {
        for ( @{$info} ) {
            if ( $_->{format} eq 'session file' ) {
                $logger->error(
'Cannot open a session file at the same time as another file.'
                );
                if ( $options{error_callback} ) {
                    $options{error_callback}->(
                        __(
'Error: cannot open a session file at the same time as another file.'
                        )
                    );
                }
                return;
            }
            elsif ( $_->{pages} > 1 ) {
                $logger->error(
'Cannot import a multipage file at the same time as another file.'
                );
                if ( $options{error_callback} ) {
                    $options{error_callback}->(
                        __(
'Error: import a multipage file at the same time as another file.'
                        )
                    );
                }
                return;
            }
        }
        my $main_uuid         = $options{uuid};
        my $finished_callback = $options{finished_callback};
        delete $options{paths};
        delete $options{finished_callback};
        for my $i ( 0 .. $#{$info} ) {
            if ( $i == $#{$info} ) {
                $options{finished_callback} = $finished_callback;
            }
            $self->import_file(
                info  => $info->[$i],
                first => 1,
                last  => 1,
                %options
            );
        }
    }
    elsif ( $info->[0]{format} eq 'session file' ) {
        $self->open_session_file( info => $info->[0]{path}, %options );
    }
    else {
        my $first_page = 1;
        my $last_page  = $info->[0]{pages};
        if ( $options{pagerange_callback} and $last_page > 1 ) {
            ( $first_page, $last_page ) =
              $options{pagerange_callback}->( $info->[0] );
        }
        $self->import_file(
            info  => $info->[0],
            first => $first_page,
            last  => $last_page,
            %options
        );
    }
    return;
}

# Because the finished, error and cancelled callbacks are triggered by the
# return queue, note them here for the return queue to use.

sub _note_callbacks {
    my ( $self, %options ) = @_;
    my $uuid = $uuid_object->create_str;
    $callback{$uuid}{queued}    = $options{queued_callback};
    $callback{$uuid}{started}   = $options{started_callback};
    $callback{$uuid}{running}   = $options{running_callback};
    $callback{$uuid}{finished}  = $options{finished_callback};
    $callback{$uuid}{error}     = $options{error_callback};
    $callback{$uuid}{cancelled} = $options{cancelled_callback};
    $callback{$uuid}{display}   = $options{display_callback};
    if ( $options{mark_saved} ) {
        $callback{$uuid}{mark_saved} = sub {

            # list_of_pages is frozen,
            # so find the original pages from their uuids
            for ( @{ $options{list_of_pages} } ) {
                my $page = $self->find_page_by_uuid( $_->{uuid} );
                $self->{data}[$page][2]->{saved} = TRUE;
            }
        };
    }
    return $uuid;
}

sub import_file {
    my ( $self, %options ) = @_;

    # File in which to store the process ID
    # so that it can be killed if necessary
    my $pidfile = $self->create_pidfile(%options);
    if ( not defined $pidfile ) { return }
    my $dirname = $EMPTY;
    if ( defined $self->{dir} ) { $dirname = "$self->{dir}" }

    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'import-file',
        {
            info    => $options{info},
            first   => $options{first},
            last    => $options{last},
            dir     => $dirname,
            pidfile => "$pidfile",
            uuid    => $uuid,
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        pidfile  => $pidfile,
        uuid     => $uuid,
    );
}

sub _post_process_scan {
    my ( $self, $page, %options ) = @_;
    if ( $options{rotate} ) {
        $self->rotate(
            angle             => $options{rotate},
            page              => $page,
            queued_callback   => $options{queued_callback},
            started_callback  => $options{started_callback},
            finished_callback => sub {
                delete $options{rotate};
                my $finished_page = $self->find_page_by_uuid( $page->{uuid} );
                $self->_post_process_scan( $self->{data}[$finished_page][2],
                    %options );
            },
            error_callback   => $options{error_callback},
            display_callback => $options{display_callback},
        );
        return;
    }
    if ( $options{unpaper} ) {
        $self->unpaper(
            page    => $page,
            options => {
                command   => $options{unpaper}->get_cmdline,
                direction => $options{unpaper}->get_option('direction'),
            },
            queued_callback   => $options{queued_callback},
            started_callback  => $options{started_callback},
            finished_callback => sub {
                delete $options{unpaper};
                my $finished_page = $self->find_page_by_uuid( $page->{uuid} );
                $self->_post_process_scan( $self->{data}[$finished_page][2],
                    %options );
            },
            error_callback   => $options{error_callback},
            display_callback => $options{display_callback},
        );
        return;
    }
    if ( $options{udt} ) {
        $self->user_defined(
            page              => $page,
            command           => $options{udt},
            queued_callback   => $options{queued_callback},
            started_callback  => $options{started_callback},
            finished_callback => sub {
                delete $options{udt};
                my $finished_page = $self->find_page_by_uuid( $page->{uuid} );
                $self->_post_process_scan( $self->{data}[$finished_page][2],
                    %options );
            },
            error_callback   => $options{error_callback},
            display_callback => $options{display_callback},
        );
        return;
    }
    if ( $options{ocr} ) {
        $self->ocr_pages(
            [$page],
            threshold         => $options{threshold},
            engine            => $options{engine},
            language          => $options{language},
            queued_callback   => $options{queued_callback},
            started_callback  => $options{started_callback},
            finished_callback => sub {
                delete $options{ocr};
                $self->_post_process_scan( undef, %options )
                  ;    # to fire finished_callback
            },
            error_callback   => $options{error_callback},
            display_callback => $options{display_callback},
        );
        return;
    }
    if ( $options{finished_callback} ) { $options{finished_callback}->() }
    return;
}

# Take new scan, pad it if necessary, display it,
# and set off any post-processing chains

sub import_scan {
    my ( $self, %options ) = @_;

    # Interface to frontend
    open my $fh, '<', $options{filename}    ## no critic (RequireBriefOpen)
      or die "can't open $options{filename}: $ERRNO\n";

    # Read without blocking
    my $size = 0;
    Glib::IO->add_watch(
        fileno($fh),
        [ 'in', 'hup' ],
        sub {
            my ( $fileno, $condition ) = @_;
            if ( $condition & 'in' ) { # bit field operation. >= would also work
                if ( $size == 0 ) {
                    $size = Gscan2pdf::NetPBM::file_size_from_header(
                        $options{filename} );
                    $logger->info("Header suggests $size");
                    return Glib::SOURCE_CONTINUE if ( $size == 0 );
                    close $fh
                      or
                      $logger->warn("Error closing $options{filename}: $ERRNO");
                }
                my $filesize = -s $options{filename};
                $logger->info("Expecting $size, found $filesize");
                if ( $size > $filesize ) {
                    my $pad = $size - $filesize;
                    open my $fh, '>>', $options{filename}
                      or die "cannot open >> $options{filename}: $ERRNO\n";
                    my $data = $EMPTY;
                    for ( 1 .. $pad * $BITS_PER_BYTE ) {
                        $data .= '1';
                    }
                    printf {$fh} pack sprintf( 'b%d', length $data ), $data;
                    close $fh
                      or
                      $logger->warn("Error closing $options{filename}: $ERRNO");
                    $logger->info("Padded $pad bytes");
                }
                my $page = Gscan2pdf::Page->new(
                    filename   => $options{filename},
                    resolution => $options{resolution},
                    format     => 'Portable anymap',
                    delete     => $options{delete},
                    dir        => $options{dir},
                );
                my $index = $self->add_page( 'none', $page, $options{page} );
                if ( $index == $NOT_FOUND and $options{error_callback} ) {
                    $options{error_callback}->( __('Unable to load image') );
                }
                else {
                    if ( $options{display_callback} ) {
                        $options{display_callback}->();
                    }
                    $self->_post_process_scan( $page, %options );
                }
                return Glib::SOURCE_REMOVE;
            }
            return Glib::SOURCE_CONTINUE;
        }
    );

    return;
}

sub _throw_error {
    my ( $uuid, $message ) = @_;
    if ( defined $callback{$uuid}{error} ) {
        $callback{$uuid}{error}->($message);
        delete $callback{$uuid}{error};
    }
    return;
}

sub check_return_queue {
    my ($self) = @_;
    while ( defined( my $data = $_self->{return}->dequeue_nb() ) ) {
        if ( not defined $data->{type} ) {
            $logger->error("Bad data bundle $data in return queue.");
            next;
        }

        # if we have pressed the cancel button, ignore everything in the returns
        # queue until it flags cancelled.
        if ( $_self->{cancel} ) {
            if ( $data->{type} eq 'cancelled' ) {
                $_self->{cancel} = FALSE;
                if ( defined $callback{ $data->{uuid} }{cancelled} ) {
                    $callback{ $data->{uuid} }{cancelled}->( $data->{info} );
                    delete $callback{ $data->{uuid} };
                }
            }
            else {
                next;
            }
        }

        if ( not defined $data->{uuid} ) {
            $logger->error('Bad uuid in return queue.');
            next;
        }
        given ( $data->{type} ) {
            when ('file-info') {
                if ( not defined $data->{info} ) {
                    $logger->error('Bad file info in return queue.');
                    next;
                }
                if ( defined $callback{ $data->{uuid} }{finished} ) {
                    $callback{ $data->{uuid} }{finished}->( $data->{info} );
                    delete $callback{ $data->{uuid} };
                }
            }
            when ('page') {
                if ( defined $data->{page} ) {
                    delete $data->{page}{saved};    # Remove saved tag
                    $self->add_page( $data->{uuid}, $data->{page},
                        $data->{info} );
                }
                else {
                    $logger->error('Bad page in return queue.');
                }
            }
            when ('error') {
                _throw_error( $data->{uuid}, $data->{message} );
            }
            when ('finished') {
                if ( defined $callback{ $data->{uuid} }{started} ) {
                    $callback{ $data->{uuid} }{started}->(
                        undef, $_self->{process_name},
                        $jobs_completed, $jobs_total, $data->{message},
                        $_self->{progress}
                    );
                    delete $callback{ $data->{uuid} }{started};
                }
                if ( defined $callback{ $data->{uuid} }{mark_saved} ) {
                    $callback{ $data->{uuid} }{mark_saved}->();
                    delete $callback{ $data->{uuid} }{mark_saved};
                }
                if ( defined $callback{ $data->{uuid} }{finished} ) {
                    $callback{ $data->{uuid} }{finished}->( $data->{message} );
                    delete $callback{ $data->{uuid} };
                }
                if ( $_self->{requests}->pending == 0 ) {
                    $jobs_completed = 0;
                    $jobs_total     = 0;
                }
                else {
                    $jobs_completed++;
                }
            }
        }
    }
    return Glib::SOURCE_CONTINUE;
}

# Check how many pages could be scanned

sub pages_possible {
    my ( $self, $start, $step ) = @_;
    my $i = $#{ $self->{data} };

    # Empty document and negative step
    if ( $i < 0 and $step < 0 ) {
        return -$start / $step;
    }

    # Empty document, or start page after end of document, allow infinite pages
    elsif ( ( $i < 0 or $self->{data}[$i][0] < $start )
        and $step > 0 )
    {
        return $INFINITE;
    }

    # track backwards to find index before which start page would be inserted
    while ( $i > 0 and $self->{data}[ $i - 1 ][0] > $start ) {
        --$i;
    }

    # scan in appropriate direction, looking for position for last page
    my $n = 0;
    while (TRUE) {

        # fallen off bottom of index
        if ( $i < 0 ) {    ## no critic (ProhibitCascadingIfElse)
            return $n;
        }

        # fallen off top of index
        elsif ( $i > $#{ $self->{data} } ) {
            return $INFINITE;
        }

        # Settings take us into negative page range
        elsif ( $start + $n * $step < 1 ) {
            return $n;
        }

        # Found existing page
        elsif ( $self->{data}[$i][0] == $start + $n * $step ) {
            return $n;
        }

        # increment index
        elsif ( $step > 1 and $self->{data}[$i][0] < $start + $n * $step ) {
            ++$i;
            ++$n;
        }

        # decrement index
        elsif ( $step < 0 and $self->{data}[$i][0] > $start + $n * $step ) {
            --$i;
            ++$n;
        }

        # Try one more page
        else {
            ++$n;
        }
    }
    return;
}

sub find_page_by_uuid {
    my ( $self, $uuid ) = @_;
    my $i = 0;
    while ( $i <= $#{ $self->{data} } and $self->{data}[$i][2]{uuid} ne $uuid )
    {
        $i++;
    }
    if ( $i <= $#{ $self->{data} } ) { return $i }
    return;
}

# Add a new page to the document

sub add_page {
    my ( $self, $process_uuid, $page, $ref ) = @_;
    my ( $i, $pagenum, $new, @page );

    # This is really hacky to allow import_scan() to specify the page number
    if ( ref($ref) ne 'HASH' ) {
        $pagenum = $ref;
        undef $ref;
    }
    for my $uuid ( ( $ref->{replace}, $ref->{'insert-after'} ) ) {
        if ( defined $uuid ) {
            $i = $self->find_page_by_uuid($uuid);
            if ( not defined $i ) {
                $logger->error("Requested page $uuid does not exist.");
                return $NOT_FOUND;
            }
            last;
        }
    }

    # Move the temp file from the thread to a temp object that will be
    # automatically cleared up
    if ( ref( $page->{filename} ) eq 'File::Temp' ) {
        $new = $page;
    }
    else {
        try {
            $new = $page->thaw;
        }
        catch {
            _throw_error( $process_uuid,
                "Caught error writing to $self->{dir}: $_" );
        };
        if ( not defined $new ) { return }
    }

    # Block the row-changed signal whilst adding the scan (row) and sorting it.
    if ( defined $self->{row_changed_signal} ) {
        $self->get_model->signal_handler_block( $self->{row_changed_signal} );
    }
    my $thumb =
      get_pixbuf( $new->{filename}, $self->{heightt}, $self->{widtht} );
    my $resolution = $new->resolution($paper_sizes);

    if ( defined $i ) {
        if ( defined $ref->{replace} ) {
            $self->{data}[$i][1] = $thumb;
            $self->{data}[$i][2] = $new;
            $pagenum             = $self->{data}[$i][0];
            $logger->info(
"Replaced $self->{data}[$i][2]->{filename} at page $pagenum with $new->{filename}, resolution $resolution"
            );
        }
        elsif ( defined $ref->{'insert-after'} ) {
            $pagenum = $self->{data}[$i][0] + 1;
            splice @{ $self->{data} }, $i + 1, 0, [ $pagenum, $thumb, $new ];
            $logger->info(
"Inserted $new->{filename} at page $pagenum with resolution $resolution"
            );
        }
    }
    else {
        # Add to the page list
        if ( not defined $pagenum ) { $pagenum = $#{ $self->{data} } + 2 }
        push @{ $self->{data} }, [ $pagenum, $thumb, $new ];
        $logger->info(
"Added $page->{filename} at page $pagenum with resolution $resolution"
        );
    }

    # Block selection_changed_signal
    # to prevent its firing changing pagerange to all
    if ( defined $self->{selection_changed_signal} ) {
        $self->get_selection->signal_handler_block(
            $self->{selection_changed_signal} );
    }
    $self->get_selection->unselect_all;
    $self->manual_sort_by_column(0);
    if ( defined $self->{selection_changed_signal} ) {
        $self->get_selection->signal_handler_unblock(
            $self->{selection_changed_signal} );
    }
    if ( defined $self->{row_changed_signal} ) {
        $self->get_model->signal_handler_unblock( $self->{row_changed_signal} );
    }

    # Due to the sort, must search for new page
    $page[0] = 0;

    # $page[0] < $#{$self -> {data}} needed to prevent infinite loop in case of
    # error importing.
    while ( $page[0] < $#{ $self->{data} }
        and $self->{data}[ $page[0] ][0] != $pagenum )
    {
        ++$page[0];
    }

    $self->select(@page);

    if ( defined $callback{$process_uuid}{display} ) {
        $callback{$process_uuid}{display}->( $self->{data}[$i][2] );
    }
    return $page[0];
}

# Helpers:
sub compare_numeric_col { ## no critic (RequireArgUnpacking, RequireFinalReturn)
    $_[0] <=> $_[1];
}

sub compare_text_col {    ## no critic (RequireArgUnpacking, RequireFinalReturn)
    $_[0] cmp $_[1];
}

# Manual one-time sorting of the simplelist's data

sub manual_sort_by_column {
    my ( $self, $sortcol ) = @_;

    # The sort function depends on the column type
    my %sortfuncs = (
        'Glib::Scalar' => \&compare_text_col,
        'Glib::String' => \&compare_text_col,
        'Glib::Int'    => \&compare_numeric_col,
        'Glib::Double' => \&compare_numeric_col,
    );

    # Remember, this relies on the fact that simplelist keeps model
    # and view column indices aligned.
    my $sortfunc = $sortfuncs{ $self->get_model->get_column_type($sortcol) };

    # Deep copy the tied data so we can sort it.
    # Otherwise, very bad things happen.
    my @data = map { [ @{$_} ] } @{ $self->{data} };
    @data = sort { $sortfunc->( $a->[$sortcol], $b->[$sortcol] ) } @data;

    @{ $self->{data} } = @data;
    return;
}

# Returns the pixbuf scaled to fit in the given box

sub get_pixbuf {
    my ( $filename, $height, $width ) = @_;

    my $pixbuf;
    try {
        $pixbuf =
          Gtk2::Gdk::Pixbuf->new_from_file_at_scale( $filename, $width, $height,
            TRUE );
    }
    catch {
        $logger->warn("Caught error getting pixbuf: $_");
    };
    return $pixbuf;
}

sub drag_data_received_callback {    ## no critic (ProhibitManyArgs)
    my ( $tree, $context, $x, $y, $data, $info, $time ) = @_;

    if ( $info == $ID_URI ) {
        my @uris = $data->get_uris;
        for (@uris) {
            s{^file://}{}gxsm;
        }
        $tree->import_files( paths => \@uris );
        $context->drag_drop_succeeded;
    }
    elsif ( $info == $ID_PAGE ) {
        my ( $path, $how ) = $tree->get_dest_row_at_pos( $x, $y );
        if ( defined $path ) { $path = $path->to_string }
        my $delete =
          $context->action == 'move'; ## no critic (ProhibitMismatchedOperators)

        # This callback is fired twice, seemingly once for the drop flag,
        # and once for the copy flag. If the drop flag is disabled, the URI
        # drop does not work. If the copy flag is disabled, the drag-with-copy
        # does not work. Therefore if copying, create a hash of the drop times
        # and ignore the second drop.
        if ( not $delete ) {
            if ( defined $tree->{drops}{$time} ) {
                delete $tree->{drops};
                $context->finish( 1, $delete, $time );
                return;
            }
            else {
                $tree->{drops}{$time} = 1;
            }
        }

        my @rows = $tree->get_selected_indices or return;
        my $selection = $tree->copy_selection( not $delete );

        # pasting without updating the selection
        # in order not to defeat the finish() call below.
        $tree->paste_selection( $selection, $path, $how );

        $context->finish( 1, $delete, $time );
    }
    else {
        $context->abort;
    }
    return;
}

# Cut the selection

sub cut_selection {
    my ($self) = @_;
    my $data = $self->copy_selection(FALSE);
    $self->delete_selection_extra;
    return $data;
}

# Copy the selection

sub copy_selection {
    my ( $self, $clone ) = @_;
    my @rows = $self->get_selection->get_selected_rows or return;
    my $model = $self->get_model;
    my @data;
    for (@rows) {
        my $iter = $model->get_iter($_);
        my @info = $model->get($iter);
        my $new  = $info[2]->clone($clone);
        push @data, [ $info[0], $info[1], $new ];
    }
    $logger->info( 'Copied ', $clone ? 'and cloned ' : $EMPTY,
        $#data + 1, ' pages' );
    return \@data;
}

# Paste the selection

sub paste_selection {
    my ( $self, $data, $path, $how, $select_new_pages ) = @_;

    # Block row-changed signal so that the list can be updated before the sort
    # takes over.
    if ( defined $self->{row_changed_signal} ) {
        $self->get_model->signal_handler_block( $self->{row_changed_signal} );
    }

    my $dest;
    if ( defined $path ) {
        if ( $how eq 'after' or $how eq 'into-or-after' ) {
            $path++;
        }
        splice @{ $self->{data} }, $path, 0, @{$data};
        $dest = $path;
    }
    else {
        $dest = $#{ $self->{data} } + 1;
        push @{ $self->{data} }, @{$data};
    }

    # Update the start spinbutton if necessary
    $self->renumber;
    $self->get_model->signal_emit( 'row-changed', Gtk2::TreePath->new,
        $self->get_model->get_iter_first );

    # Select the new pages
    if ($select_new_pages) {
        my @selection;
        for ( $dest .. $dest + $#{$data} ) {
            push @selection, $_;
        }
        $self->get_selection->unselect_all;
        $self->select(@selection);
    }

    if ( defined $self->{row_changed_signal} ) {
        $self->get_model->signal_handler_unblock( $self->{row_changed_signal} );
    }

    $self->save_session;

    $logger->info( 'Pasted ', $#{$data} + 1, " pages at position $dest" );
    return;
}

# Delete the selected scans

sub delete_selection {
    my ($self) = @_;
    my $model  = $self->get_model;
    my @rows   = $self->get_selection->get_selected_rows;
    for ( reverse @rows ) {
        my $iter = $model->get_iter($_);
        $model->remove($iter);
    }
    return;
}

sub delete_selection_extra {
    my ($self) = @_;

    my @page   = $self->get_selected_indices;
    my $npages = $#page + 1;
    if ( defined $self->{selection_changed_signal} ) {
        $self->get_selection->signal_handler_block(
            $self->{selection_changed_signal} );
    }
    $self->delete_selection;
    if ( defined $self->{selection_changed_signal} ) {
        $self->get_selection->signal_handler_unblock(
            $self->{selection_changed_signal} );
    }

    # Select nearest page to last current page
    if ( @{ $self->{data} } and @page ) {

        # Select just the first one
        @page = ( $page[0] );
        if ( $page[0] > $#{ $self->{data} } ) {
            $page[0] = $#{ $self->{data} };
        }
        $self->select(@page);
    }

    # Select nothing
    elsif ( @{ $self->{data} } ) {
        $self->select;
    }

    # No pages left, and having blocked the selection_changed_signal,
    # we've got to clear the image
    else {
        $self->get_selection->signal_emit('changed');
    }

    $self->save_session;
    $logger->info("Deleted $npages pages");
    return;
}

sub save_pdf {
    my ( $self, %options ) = @_;

    for my $i ( 0 .. $#{ $options{list_of_pages} } ) {
        $options{list_of_pages}->[$i] =
          $options{list_of_pages}->[$i]
          ->freeze;    # sharing File::Temp objects causes problems
    }

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = $self->create_pidfile(%options);
    if ( not defined $pidfile ) { return }

    $options{mark_saved} = TRUE;
    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'save-pdf',
        {
            path          => $options{path},
            list_of_pages => $options{list_of_pages},
            metadata      => $options{metadata},
            options       => $options{options},
            dir           => "$self->{dir}",
            pidfile       => "$pidfile",
            uuid          => $uuid,
        }
    );

    return $self->_monitor_process(
        sentinel => $sentinel,
        pidfile  => $pidfile,
        uuid     => $uuid,
    );
}

sub save_djvu {
    my ( $self, %options ) = @_;

    for my $i ( 0 .. $#{ $options{list_of_pages} } ) {
        $options{list_of_pages}->[$i] =
          $options{list_of_pages}->[$i]
          ->freeze;    # sharing File::Temp objects causes problems
    }

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = $self->create_pidfile(%options);
    if ( not defined $pidfile ) { return }

    $options{mark_saved} = TRUE;
    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'save-djvu',
        {
            path          => $options{path},
            list_of_pages => $options{list_of_pages},
            metadata      => $options{metadata},
            options       => $options{options},
            dir           => "$self->{dir}",
            pidfile       => "$pidfile",
            uuid          => $uuid,
        }
    );

    return $self->_monitor_process(
        sentinel => $sentinel,
        pidfile  => $pidfile,
        uuid     => $uuid,
    );
}

sub save_tiff {
    my ( $self, %options ) = @_;

    for my $i ( 0 .. $#{ $options{list_of_pages} } ) {
        $options{list_of_pages}->[$i] =
          $options{list_of_pages}->[$i]
          ->freeze;    # sharing File::Temp objects causes problems
    }

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = $self->create_pidfile(%options);
    if ( not defined $pidfile ) { return }

    $options{mark_saved} = TRUE;
    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'save-tiff',
        {
            path          => $options{path},
            list_of_pages => $options{list_of_pages},
            options       => $options{options},
            dir           => "$self->{dir}",
            pidfile       => "$pidfile",
            uuid          => $uuid,
        }
    );

    return $self->_monitor_process(
        sentinel => $sentinel,
        pidfile  => $pidfile,
        uuid     => $uuid,
    );
}

sub rotate {
    my ( $self, %options ) = @_;
    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'rotate',
        {
            angle => $options{angle},
            page  => $options{page}->freeze,
            dir   => "$self->{dir}",
            uuid  => $uuid,
        }
    );

    return $self->_monitor_process(
        sentinel => $sentinel,
        uuid     => $uuid,
    );
}

sub save_image {
    my ( $self, %options ) = @_;

    for my $i ( 0 .. $#{ $options{list_of_pages} } ) {
        $options{list_of_pages}->[$i] =
          $options{list_of_pages}->[$i]
          ->freeze;    # sharing File::Temp objects causes problems
    }

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = $self->create_pidfile(%options);
    if ( not defined $pidfile ) { return }

    $options{mark_saved} = TRUE;
    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'save-image',
        {
            path          => $options{path},
            list_of_pages => $options{list_of_pages},
            options       => $options{options},
            pidfile       => "$pidfile",
            uuid          => $uuid,
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        pidfile  => $pidfile,
        uuid     => $uuid,
    );
}

# Check that all pages have been saved

sub scans_saved {
    my ($self) = @_;
    for ( @{ $self->{data} } ) {
        if ( not $_->[2]{saved} ) { return FALSE }
    }
    return TRUE;
}

sub save_text {
    my ( $self, %options ) = @_;

    for my $i ( 0 .. $#{ $options{list_of_pages} } ) {
        $options{list_of_pages}->[$i] =
          $options{list_of_pages}->[$i]
          ->freeze;    # sharing File::Temp objects causes problems
    }
    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'save-text',
        {
            path          => $options{path},
            list_of_pages => $options{list_of_pages},
            options       => $options{options},
            uuid          => $uuid,
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        uuid     => $uuid,
    );
}

sub save_hocr {
    my ( $self, %options ) = @_;

    for my $i ( 0 .. $#{ $options{list_of_pages} } ) {
        $options{list_of_pages}->[$i] =
          $options{list_of_pages}->[$i]
          ->freeze;    # sharing File::Temp objects causes problems
    }
    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'save-hocr',
        {
            path          => $options{path},
            list_of_pages => $options{list_of_pages},
            options       => $options{options},
            uuid          => $uuid,
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        uuid     => $uuid,
    );
}

sub analyse {
    my ( $self, %options ) = @_;
    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'analyse',
        {
            page => $options{page}->freeze,
            uuid => $uuid
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        uuid     => $uuid,
    );
}

sub threshold {
    my ( $self, %options ) = @_;
    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'threshold',
        {
            threshold => $options{threshold},
            page      => $options{page}->freeze,
            dir       => "$self->{dir}",
            uuid      => $uuid,
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        uuid     => $uuid,
    );
}

sub brightness_contrast {
    my ( $self, %options ) = @_;
    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'brightness-contrast',
        {
            page       => $options{page}->freeze,
            brightness => $options{brightness},
            contrast   => $options{contrast},
            dir        => "$self->{dir}",
            uuid       => $uuid
        }
    );

    return $self->_monitor_process(
        sentinel => $sentinel,
        uuid     => $uuid,
    );
}

sub negate {
    my ( $self, %options ) = @_;
    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'negate',
        {
            page => $options{page}->freeze,
            dir  => "$self->{dir}",
            uuid => $uuid
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        uuid     => $uuid,
    );
}

sub unsharp {
    my ( $self, %options ) = @_;
    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'unsharp',
        {
            page      => $options{page}->freeze,
            radius    => $options{radius},
            sigma     => $options{sigma},
            gain      => $options{gain},
            threshold => $options{threshold},
            dir       => "$self->{dir}",
            uuid      => $uuid,
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        uuid     => $uuid,
    );
}

sub crop {
    my ( $self, %options ) = @_;
    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'crop',
        {
            page => $options{page}->freeze,
            x    => $options{x},
            y    => $options{y},
            w    => $options{w},
            h    => $options{h},
            dir  => "$self->{dir}",
            uuid => $uuid,
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        uuid     => $uuid,
    );
}

sub to_png {
    my ( $self, %options ) = @_;
    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'to-png',
        {
            page => $options{page}->freeze,
            dir  => "$self->{dir}",
            uuid => $uuid
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        uuid     => $uuid,
    );
}

sub tesseract {
    my ( $self, %options ) = @_;

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = $self->create_pidfile(%options);
    if ( not defined $pidfile ) { return }

    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'tesseract',
        {
            page      => $options{page}->freeze,
            language  => $options{language},
            threshold => $options{threshold},
            pidfile   => "$pidfile",
            uuid      => $uuid,
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        pidfile  => $pidfile,
        uuid     => $uuid,
    );
}

sub ocropus {
    my ( $self, %options ) = @_;

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = $self->create_pidfile(%options);
    if ( not defined $pidfile ) { return }

    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'ocropus',
        {
            page      => $options{page}->freeze,
            language  => $options{language},
            threshold => $options{threshold},
            pidfile   => "$pidfile",
            uuid      => $uuid,
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        pidfile  => $pidfile,
        uuid     => $uuid,
    );
}

sub cuneiform {
    my ( $self, %options ) = @_;

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = $self->create_pidfile(%options);
    if ( not defined $pidfile ) { return }

    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'cuneiform',
        {
            page      => $options{page}->freeze,
            language  => $options{language},
            threshold => $options{threshold},
            pidfile   => "$pidfile",
            uuid      => $uuid,
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        pidfile  => $pidfile,
        uuid     => $uuid,
    );
}

sub gocr {
    my ( $self, %options ) = @_;

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = $self->create_pidfile(%options);
    if ( not defined $pidfile ) { return }

    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'gocr',
        {
            page      => $options{page}->freeze,
            threshold => $options{threshold},
            pidfile   => "$pidfile",
            uuid      => $uuid,
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        pidfile  => $pidfile,
        uuid     => $uuid,
    );
}

# Wrapper for the various ocr engines

sub ocr_pages {
    my ( $self, $pages, %options ) = @_;
    for my $page ( @{$pages} ) {
        $options{page} = $page;
        if ( $options{engine} eq 'gocr' ) {
            $self->gocr(%options);
        }
        elsif ( $options{engine} eq 'tesseract' ) {
            $self->tesseract(%options);
        }
        elsif ( $options{engine} eq 'ocropus' ) {
            $self->ocropus(%options);
        }
        else {    # cuneiform
            $self->cuneiform(%options);
        }
    }
    return;
}

sub unpaper {
    my ( $self, %options ) = @_;

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = $self->create_pidfile(%options);
    if ( not defined $pidfile ) { return }

    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'unpaper',
        {
            page    => $options{page}->freeze,
            options => $options{options},
            pidfile => "$pidfile",
            dir     => "$self->{dir}",
            uuid    => $uuid,
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        pidfile  => $pidfile,
        uuid     => $uuid,
    );
}

sub user_defined {
    my ( $self, %options ) = @_;

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = $self->create_pidfile(%options);
    if ( not defined $pidfile ) { return }

    my $uuid     = $self->_note_callbacks(%options);
    my $sentinel = _enqueue_request(
        'user-defined',
        {
            page    => $options{page}->freeze,
            command => $options{command},
            dir     => "$self->{dir}",
            pidfile => "$pidfile",
            uuid    => $uuid,
        }
    );
    return $self->_monitor_process(
        sentinel => $sentinel,
        pidfile  => $pidfile,
        uuid     => $uuid,
    );
}

# Dump $self to a file.
# If a filename is given, zip it up as a session file

sub save_session {
    my ( $self, $filename ) = @_;

    my ( %session, @filenamelist );
    for my $i ( 0 .. $#{ $self->{data} } ) {
        $session{ $self->{data}[$i][0] }{filename} =
          $self->{data}[$i][2]{filename}->filename;
        push @filenamelist, $self->{data}[$i][2]{filename}->filename;
        for my $key ( keys %{ $self->{data}[$i][2] } ) {
            if ( $key ne 'filename' ) {
                $session{ $self->{data}[$i][0] }{$key} =
                  $self->{data}[$i][2]{$key};
            }
        }
    }
    push @filenamelist, File::Spec->catfile( $self->{dir}, 'session' );
    my @selection = $self->get_selected_indices;
    @{ $session{selection} } = @selection;
    store( \%session, File::Spec->catfile( $self->{dir}, 'session' ) );
    if ( defined $filename ) {
        my $tar = Archive::Tar->new;
        $tar->add_files(@filenamelist);
        $tar->write( $filename, TRUE, $EMPTY );
    }
    return;
}

sub open_session_file {
    my ( $self, %options ) = @_;
    if ( not defined $options{info} ) {
        if ( $options{error_callback} ) {
            $options{error_callback}->('Error: session file not supplied.');
        }
        return;
    }
    my $tar          = Archive::Tar->new( $options{info}, TRUE );
    my @filenamelist = $tar->list_files;
    my @sessionfile  = grep { /\/session$/xsm } @filenamelist;
    my $sesdir =
      File::Spec->catfile( $self->{dir}, dirname( $sessionfile[0] ) );
    for (@filenamelist) {
        $tar->extract_file( $_, File::Spec->catfile( $sesdir, basename($_) ) );
    }
    $self->open_session( dir => $sesdir, delete => TRUE, %options );
    if ( $options{finished_callback} ) { $options{finished_callback}->() }
    return;
}

sub open_session {
    my ( $self, %options ) = @_;
    if ( not defined $options{dir} ) {
        if ( $options{error_callback} ) {
            $options{error_callback}->('Error: session folder not defined');
        }
        return;
    }
    my $sessionfile = File::Spec->catfile( $options{dir}, 'session' );
    if ( not -r $sessionfile ) {
        if ( $options{error_callback} ) {
            $options{error_callback}->("Error: Unable to read $sessionfile");
        }
        return;
    }
    my $sessionref = retrieve($sessionfile);
    my %session    = %{$sessionref};

    # Block the row-changed signal whilst adding the scan (row) and sorting it.
    if ( defined $self->{row_changed_signal} ) {
        $self->get_model->signal_handler_block( $self->{row_changed_signal} );
    }
    my @selection = @{ $session{selection} };
    delete $session{selection};
    for my $pagenum ( sort { $a <=> $b } ( keys %session ) ) {

        # don't reuse session directory
        $session{$pagenum}{dir}    = $self->{dir};
        $session{$pagenum}{delete} = $options{delete};

        # correct the path now that it is relative to the current session dir
        if ( $options{dir} ne $self->{dir} ) {
            $session{$pagenum}{filename} =
              File::Spec->catfile( $options{dir},
                basename( $session{$pagenum}{filename} ) );
        }

        # Populate the SimpleList
        try {
            my $page = Gscan2pdf::Page->new( %{ $session{$pagenum} } );

            # at some point the main window widget was being stored on the
            # Page object. Restoring this and dumping it via Dumper segfaults.
            if ( defined $page->{window} ) { delete $page->{window} }
            my $thumb =
              get_pixbuf( $page->{filename}, $self->{heightt},
                $self->{widtht} );
            push @{ $self->{data} }, [ $pagenum, $thumb, $page ];
        }
        catch {
            if ( $options{error_callback} ) {
                $options{error_callback}->(
                    sprintf __('Error importing page %d. Ignoring.'), $pagenum
                );
            }
        };
    }
    if ( defined $self->{row_changed_signal} ) {
        $self->get_model->signal_handler_unblock( $self->{row_changed_signal} );
    }
    $self->select(@selection);
    return;
}

# Renumber pages

sub renumber {
    my ( $self, $start, $step, $selection ) = @_;

    if ( defined $self->{row_changed_signal} ) {
        $self->get_model->signal_handler_block( $self->{row_changed_signal} );
    }
    if ( defined $start ) {
        if ( not defined $step )      { $step      = 1 }
        if ( not defined $selection ) { $selection = 'all' }

        my @selection;
        if ( $selection eq 'selected' ) {
            @selection = $self->get_selected_indices;
        }
        else {
            @selection = 0 .. $#{ $self->{data} };
        }

        for (@selection) {
            $self->{data}[$_][0] = $start;
            $start += $step;
        }
    }

    # If $start and $step are undefined, just make sure that the numbering is
    # ascending.
    else {
        for ( 1 .. $#{ $self->{data} } ) {
            if ( $self->{data}[$_][0] <= $self->{data}[ $_ - 1 ][0] ) {
                $self->{data}[$_][0] = $self->{data}[ $_ - 1 ][0] + 1;
            }
        }
    }
    if ( defined $self->{row_changed_signal} ) {
        $self->get_model->signal_handler_unblock( $self->{row_changed_signal} );
    }
    return;
}

# Check if $start and $step give duplicate page numbers

sub valid_renumber {
    my ( $self, $start, $step, $selection ) = @_;
    $logger->debug(
"Checking renumber validity of: start $start, step $step, selection $selection"
    );

    return FALSE if ( $step == 0 );

    # if we are renumbering all pages, just make sure the numbers stay positive
    if ( $selection eq 'all' ) {
        return ( $start + $#{ $self->{data} } * $step > 0 ) ? TRUE : FALSE
          if ( $step < 0 );
        return TRUE;
    }

    # Get list of pages not in selection
    my @selected = $self->get_selected_indices;
    my @all      = ( 0 .. $#{ $self->{data} } );

    # Convert the indices to sets of page numbers
    @selected = $self->index2page_number(@selected);
    @all      = $self->index2page_number(@all);
    my $selected     = Set::IntSpan->new( \@selected );
    my $all          = Set::IntSpan->new( \@all );
    my $not_selected = $all->diff($selected);
    $logger->debug("Page numbers not selected: $not_selected");

    # Create a set from the current settings
    my $current = Set::IntSpan->new;
    for ( 0 .. $#selected ) { $current->insert( $start + $step * $_ ) }
    $logger->debug("Current setting would create page numbers: $current");

    # Are any of the new page numbers the same as those not selected?
    return FALSE if ( $current->intersect($not_selected)->size );
    return TRUE;
}

# helper function to return an array of page numbers given an array of page indices

sub index2page_number {
    my ( $self, @index ) = @_;
    for (@index) {
        $_ = ${ $self->{data} }[$_][0];
    }
    return @index;
}

# return array index of pages depending on which radiobutton is active

sub get_page_index {
    my ( $self, $page_range, $error_callback ) = @_;
    my @index;
    if ( $page_range eq 'all' ) {
        if ( @{ $self->{data} } ) {
            return 0 .. $#{ $self->{data} };
        }
        else {
            $error_callback->( __('No pages to process') );
            return;
        }
    }
    elsif ( $page_range eq 'selected' ) {
        @index = $self->get_selected_indices;
        if ( @index == 0 ) {
            $error_callback->( __('No pages selected') );
            return;
        }
    }
    return @index;
}

# Have to roll my own slurp sub to support utf8

sub slurp {
    my ($file) = @_;

    local $INPUT_RECORD_SEPARATOR = undef;
    my ($text);

    if ( ref($file) eq 'GLOB' ) {
        $text = <$file>;
    }
    else {
        open my $fh, '<:encoding(UTF8)', $file
          or die "Error: cannot open $file\n";
        $text = <$fh>;
        close $fh or die "Error: cannot close $file\n";
    }
    return $text;
}

sub exec_command {
    my ( $cmd, $pidfile ) = @_;

    # remove empty arguments in $cmd
    my $i = 0;
    while ( $i <= $#{$cmd} ) {
        if ( not defined $cmd->[$i] or $cmd->[$i] eq $EMPTY ) {
            splice @{$cmd}, $i, 1;
        }
        else {
            ++$i;
        }
    }
    if ( defined $logger ) { $logger->info( join $SPACE, @{$cmd} ) }

    # we create a symbol for the err because open3 will not do that for us
    my $err = gensym();
    my ( $pid, $reader );
    try {
        $pid = open3( undef, $reader, $err, @{$cmd} );
    }
    catch {
        $pid = 0;
    };
    if ( $pid == 0 ) {
        return $PROCESS_FAILED, undef,
          join( $SPACE, @{$cmd} ) . ': command not found';
    }
    if ( defined $logger ) { $logger->info("Spawned PID $pid") }

    if ( defined $pidfile ) {
        open my $fh, '>', $pidfile or return $PROCESS_FAILED;
        $fh->print($pid);
        close $fh or return $PROCESS_FAILED;
    }

    waitpid $ALL_PENDING_ZOMBIE_PROCESSES, WNOHANG;
    my $child_exit_status = $CHILD_ERROR >> $BITS_PER_BYTE;
    return $child_exit_status, slurp($reader), slurp($err);
}

# wrapper for _program_version below

sub program_version {
    my ( $stream, $regex, $cmd ) = @_;
    return _program_version( $stream, $regex,
        Gscan2pdf::Document::exec_command($cmd) );
}

# Check exec_command output for version number
# Don't call exec_command directly to allow us to test output we can't reproduce.

sub _program_version {
    my ( $stream, $regex, @output ) = @_;
    my ( $status, $out,   $err )    = @output;
    my $output = $stream eq 'stdout' ? $out : $err;
    if ( defined $output and $output =~ $regex ) { return $1 }
    if ( $status == $PROCESS_FAILED ) {
        $logger->info($err);
        return $PROCESS_FAILED;
    }
    $logger->info("Unable to parse version string from: '$output'");
    return;
}

# Check that a command exists

sub check_command {
    my ($cmd) = @_;
    my ( undef, $exe ) = exec_command( [ 'which', $cmd ] );
    return ( defined $exe and $exe ne $EMPTY ? TRUE : FALSE );
}

# Compute a timestamp

sub timestamp {
    my @time = localtime;

    # return a time which can be string-wise compared
    return sprintf '%04d%02d%02d%02d%02d%02d', reverse @time[ 0 .. $YEAR ];
}

sub text_to_date {
    my ( $text, $thisyear, $thismonth, $thisday ) = @_;
    my ( $year, $month, $day );
    if ( defined $text and $text =~ /^(\d+)?-?(\d+)?-?(\d+)?$/smx ) {
        ( $year, $month, $day ) = ( $1, $2, $3 );
    }
    if ( not defined $year ) { $year = $thisyear }
    if ( not defined $month or $month < 1 or $month > $MONTHS_PER_YEAR ) {
        $month = $thismonth;
    }
    if ( not defined $day or $day < 1 or $day > $DAYS_PER_MONTH ) {
        $day = $thisday;
    }
    return $year, $month, $day;
}

sub expand_metadata_pattern {
    my (%data) = @_;
    my ( $dyear, $dmonth, $dday ) =
      text_to_date( $data{docdate}, @{ $data{today_and_now} } );
    my ( $tyear, $tmonth, $tday, $thour, $tmin, $tsec ) =
      @{ $data{today_and_now} };
    if ( not defined $thour ) { $thour = 0 }
    if ( not defined $tmin )  { $tmin  = 0 }
    if ( not defined $tsec )  { $tsec  = 0 }

    # Expand author and title
    $data{template} =~ s/%Da/$data{author}/gsm;
    $data{template} =~ s/%Dt/$data{title}/gsm;

    # Expand convert %Dx code to %x, convert using strftime and replace
    while ( $data{template} =~ /%D([[:alpha:]])/smx ) {
        my $code     = $1;
        my $template = "$PERCENT$code";
        my $result   = POSIX::strftime(
            $template, $tsec, $tmin, $thour, $dday,
            $dmonth + $STRFTIME_MONTH_OFFSET,
            $dyear + $STRFTIME_YEAR_OFFSET
        );
        $data{template} =~ s/%D$code/$result/gsmx;
    }

    # Expand basic strftime codes
    $data{template} = POSIX::strftime(
        $data{template}, $tsec, $tmin, $thour, $tday,
        $tmonth + $STRFTIME_MONTH_OFFSET,
        $tyear + $STRFTIME_YEAR_OFFSET
    );

    # avoid leading and trailing whitespace in expanded filename template
    $data{template} =~ s/^\s*(.*?)\s*$/$1/xsm;

    if ( $data{convert_whitespace} ) { $data{template} =~ s/\s/_/gsm }

    return $data{template};
}

# Normally, it would be more sensible to put this in main::, but in order to
# run unit tests on the sub, it has been moved here.

sub collate_metadata {
    my ($settings) = @_;
    my %metadata;
    for my $key (qw/author title subject keywords/) {
        if ( defined $settings->{$key} ) {
            $metadata{$key} = $settings->{$key};
        }
    }
    $metadata{date} = [ Add_Delta_Days( Today(), $settings->{'date offset'} ) ];
    return \%metadata;
}

sub prepare_output_metadata {
    my ( $type, $metadata ) = @_;
    my %h;

    if ( $type eq 'PDF' or $type eq 'DjVu' ) {
        my $dateformat =
          $type eq 'PDF'
          ? "D:%4i%02i%02i000000+00'00'"
          : '%4i-%02i-%02i 00:00:00+00:00';
        my ( $year, $month, $day ) = @{ $metadata->{date} };
        $h{CreationDate} = sprintf $dateformat, $year, $month, $day;
        $h{ModDate}      = $h{CreationDate};
        $h{Creator}      = "gscan2pdf v$Gscan2pdf::Document::VERSION";
        if ( $type eq 'DjVu' ) { $h{Producer} = 'djvulibre' }
        for my $key (qw/author title subject keywords/) {
            if ( defined $metadata->{$key} ) {
                $h{ ucfirst $key } = $metadata->{$key};
            }
        }
    }

    return \%h;
}

# Set session dir

sub set_dir {
    my ( $self, $dir ) = @_;
    $self->{dir} = $dir;
    return;
}

sub _enqueue_request {
    my ( $action, $data ) = @_;
    my $sentinel : shared = 0;
    $_self->{requests}->enqueue(
        {
            action   => $action,
            sentinel => \$sentinel,
            ( $data ? %{$data} : () )
        }
    );
    $jobs_total++;
    return \$sentinel;
}

sub _monitor_process {
    my ( $self, %options ) = @_;

    if ( defined $options{pidfile} ) {
        $self->{running_pids}{"$options{pidfile}"} = "$options{pidfile}";
    }

    if ( $callback{ $options{uuid} }{queued} ) {
        $callback{ $options{uuid} }{queued}->(
            process_name   => $_self->{process_name},
            jobs_completed => $jobs_completed,
            jobs_total     => $jobs_total
        );
    }

    Glib::Timeout->add(
        $_POLL_INTERVAL,
        sub {
            if ( ${ $options{sentinel} } == 2 ) {
                $self->_monitor_process_finished_callback( \%options );
                return Glib::SOURCE_REMOVE;
            }
            elsif ( ${ $options{sentinel} } == 1 ) {
                $self->_monitor_process_running_callback( \%options );
                return Glib::SOURCE_CONTINUE;
            }
            return Glib::SOURCE_CONTINUE;
        }
    );
    return $options{pidfile};
}

sub _monitor_process_running_callback {
    my ( $self, $options ) = @_;
    if ( $_self->{cancel} ) { return }
    if ( $callback{ $options->{uuid} }{started} ) {
        $callback{ $options->{uuid} }{started}->(
            1, $_self->{process_name},
            $jobs_completed, $jobs_total, $_self->{message}, $_self->{progress}
        );
        delete $callback{ $options->{uuid} }{started};
    }
    if ( $callback{ $options->{uuid} }{running} ) {
        $callback{ $options->{uuid} }{running}->(
            process        => $_self->{process_name},
            jobs_completed => $jobs_completed,
            jobs_total     => $jobs_total,
            message        => $_self->{message},
            progress       => $_self->{progress}
        );
    }
    return;
}

sub _monitor_process_finished_callback {
    my ( $self, $options ) = @_;
    if ( $_self->{cancel} ) { return }
    if ( $callback{ $options->{uuid} }{started} ) {
        $callback{ $options->{uuid} }{started}->(
            undef, $_self->{process_name},
            $jobs_completed, $jobs_total, $_self->{message}, $_self->{progress}
        );
        delete $callback{ $options->{uuid} }{started};
    }
    if ( $_self->{status} ) {
        if ( $callback{ $options->{uuid} }{error} ) {
            $callback{ $options->{uuid} }{error}->( $_self->{message} );
        }
        return;
    }
    $self->check_return_queue;
    if ( defined $options->{pidfile} ) {
        delete $self->{running_pids}{"$options->{pidfile}"};
    }
    return;
}

sub _thread_main {
    my ($self) = @_;

    while ( my $request = $self->{requests}->dequeue ) {
        $self->{process_name} = $request->{action};

        # Signal the sentinel that the request was started.
        ${ $request->{sentinel} }++;

        given ( $request->{action} ) {
            when ('analyse') {
                _thread_analyse( $self, $request->{page}, $request->{uuid} );
            }

            when ('brightness-contrast') {
                _thread_brightness_contrast(
                    $self,
                    page       => $request->{page},
                    brightness => $request->{brightness},
                    contrast   => $request->{contrast},
                    dir        => $request->{dir},
                    uuid       => $request->{uuid}
                );
            }

            when ('cancel') {
                $self->{return}->enqueue(
                    { type => 'cancelled', uuid => $request->{uuid} } );
            }

            when ('crop') {
                _thread_crop(
                    $self,
                    page => $request->{page},
                    x    => $request->{x},
                    y    => $request->{y},
                    w    => $request->{w},
                    h    => $request->{h},
                    dir  => $request->{dir},
                    uuid => $request->{uuid},
                );
            }

            when ('cuneiform') {
                _thread_cuneiform(
                    $self,
                    page      => $request->{page},
                    language  => $request->{language},
                    threshold => $request->{threshold},
                    pidfile   => $request->{pidfile},
                    uuid      => $request->{uuid}
                );
            }

            when ('get-file-info') {
                _thread_get_file_info( $self, $request->{path},
                    $request->{pidfile}, $request->{uuid} );
            }

            when ('gocr') {
                _thread_gocr( $self, $request->{page}, $request->{threshold},
                    $request->{pidfile}, $request->{uuid} );
            }

            when ('import-file') {
                _thread_import_file(
                    $self,
                    info    => $request->{info},
                    first   => $request->{first},
                    last    => $request->{last},
                    dir     => $request->{dir},
                    pidfile => $request->{pidfile},
                    uuid    => $request->{uuid}
                );
            }

            when ('negate') {
                _thread_negate(
                    $self,           $request->{page},
                    $request->{dir}, $request->{uuid}
                );
            }

            when ('ocropus') {
                _thread_ocropus(
                    $self,
                    page      => $request->{page},
                    language  => $request->{language},
                    threshold => $request->{threshold},
                    pidfile   => $request->{pidfile},
                    uuid      => $request->{uuid}
                );
            }

            when ('paper_sizes') {
                _thread_paper_sizes( $self, $request->{paper_sizes} );
            }

            when ('quit') {
                last;
            }

            when ('rotate') {
                _thread_rotate(
                    $self,           $request->{angle}, $request->{page},
                    $request->{dir}, $request->{uuid}
                );
            }

            when ('save-djvu') {
                _thread_save_djvu(
                    $self,
                    path          => $request->{path},
                    list_of_pages => $request->{list_of_pages},
                    metadata      => $request->{metadata},
                    options       => $request->{options},
                    dir           => $request->{dir},
                    pidfile       => $request->{pidfile},
                    uuid          => $request->{uuid}
                );
            }

            when ('save-hocr') {
                _thread_save_hocr( $self, $request->{path},
                    $request->{list_of_pages},
                    $request->{options}, $request->{uuid} );
            }

            when ('save-image') {
                _thread_save_image(
                    $self,
                    path          => $request->{path},
                    list_of_pages => $request->{list_of_pages},
                    pidfile       => $request->{pidfile},
                    options       => $request->{options},
                    uuid          => $request->{uuid}
                );
            }

            when ('save-pdf') {
                _thread_save_pdf(
                    $self,
                    path          => $request->{path},
                    list_of_pages => $request->{list_of_pages},
                    metadata      => $request->{metadata},
                    options       => $request->{options},
                    dir           => $request->{dir},
                    pidfile       => $request->{pidfile},
                    uuid          => $request->{uuid}
                );
            }

            when ('save-text') {
                _thread_save_text( $self, $request->{path},
                    $request->{list_of_pages},
                    $request->{options}, $request->{uuid} );
            }

            when ('save-tiff') {
                _thread_save_tiff(
                    $self,
                    path          => $request->{path},
                    list_of_pages => $request->{list_of_pages},
                    options       => $request->{options},
                    dir           => $request->{dir},
                    pidfile       => $request->{pidfile},
                    uuid          => $request->{uuid}
                );
            }

            when ('tesseract') {
                _thread_tesseract(
                    $self,
                    page      => $request->{page},
                    language  => $request->{language},
                    threshold => $request->{threshold},
                    pidfile   => $request->{pidfile},
                    uuid      => $request->{uuid}
                );
            }

            when ('threshold') {
                _thread_threshold( $self, $request->{threshold},
                    $request->{page}, $request->{dir}, $request->{uuid} );
            }

            when ('to-png') {
                _thread_to_png(
                    $self,           $request->{page},
                    $request->{dir}, $request->{uuid}
                );
            }

            when ('unpaper') {
                _thread_unpaper(
                    $self,
                    page    => $request->{page},
                    options => $request->{options},
                    pidfile => $request->{pidfile},
                    dir     => $request->{dir},
                    uuid    => $request->{uuid}
                );
            }

            when ('unsharp') {
                _thread_unsharp(
                    $self,
                    page      => $request->{page},
                    radius    => $request->{radius},
                    sigma     => $request->{sigma},
                    gain      => $request->{gain},
                    threshold => $request->{threshold},
                    dir       => $request->{dir},
                    uuid      => $request->{uuid},
                );
            }

            when ('user-defined') {
                _thread_user_defined(
                    $self,
                    page    => $request->{page},
                    command => $request->{command},
                    dir     => $request->{dir},
                    pidfile => $request->{pidfile},
                    uuid    => $request->{uuid}
                );
            }

            default {
                $logger->info(
                    'Ignoring unknown request ' . $request->{action} );
                next;
            }
        }

        # Signal the sentinel that the request was completed.
        ${ $request->{sentinel} }++;

        undef $self->{process_name};
    }
    return;
}

sub _thread_throw_error {
    my ( $self, $uuid, $message ) = @_;
    $self->{return}->enqueue(
        {
            type    => 'error',
            uuid    => $uuid,
            message => $message
        }
    );
    return;
}

sub _thread_get_file_info {
    my ( $self, $filename, $pidfile, $uuid, %info ) = @_;

    if ( not -e $filename ) {
        _thread_throw_error( $self, $uuid, sprintf __('File %s not found'),
            $filename );
        return;
    }

    $logger->info("Getting info for $filename");
    ( undef, my $format ) = exec_command( [ 'file', '-b', $filename ] );
    chomp $format;
    $logger->info("Format: '$format'");

    given ($format) {
        when ('very short file (no magic)') {
            _thread_throw_error( $self, $uuid,
                sprintf __('Error importing zero-length file %s.'), $filename );
            return;
        }
        when (/gzip[ ]compressed[ ]data/xsm) {
            $info{path}   = $filename;
            $info{format} = 'session file';
            $self->{return}->enqueue(
                { type => 'file-info', uuid => $uuid, info => \%info } );
            return;
        }
        when (/DjVu/xsm) {

            # Dig out the number of pages
            ( undef, my $info ) =
              exec_command( [ 'djvudump', $filename ], $pidfile );
            $logger->info($info);
            return if $_self->{cancel};

            my $pages = 1;
            if ( $info =~ /\s(\d+)\s+page/xsm ) {
                $pages = $1;
            }

            # Dig out and the resolution of each page
            my (@ppi);
            $info{format} = 'DJVU';
            while ( $info =~ /\s(\d+)\s+dpi(.*)/xsm ) {
                push @ppi, $1;
                $info = $2;
                $logger->info("Page $#ppi is $ppi[$#ppi] ppi");
            }
            if ( $pages != @ppi ) {
                _thread_throw_error(
                    $self, $uuid,
                    __(
'Unknown DjVu file structure. Please contact the author.'
                    )
                );
                return;
            }
            $info{ppi}   = \@ppi;
            $info{pages} = $pages;
            $info{path}  = $filename;
            $self->{return}->enqueue(
                { type => 'file-info', uuid => $uuid, info => \%info } );
            return;
        }
        when (/PDF[ ]document/xsm) {
            $format = 'Portable Document Format';
            ( undef, my $info ) =
              exec_command( [ 'pdfinfo', $filename ], $pidfile );
            return if $_self->{cancel};
            $logger->info($info);
            $info{pages} = 1;
            if ( $info =~ /Pages:\s+(\d+)/xsm ) {
                $info{pages} = $1;
            }
            $logger->info("$info{pages} pages");
            my $float = qr{\d+(?:[.]\d*)?}xsm;
            if ( $info =~ /Page\ssize:\s+($float)\s+x\s+($float)\s+(\w+)/xsm ) {
                $info{page_size} = [ $1, $2, $3 ];
                $logger->info("Page size: $1 x $2 $3");
            }
        }

        # A JPEG which I was unable to reproduce as a test case had what
        # seemed to be a TIFF thumbnail which file -b reported, and therefore
        # gscan2pdf attempted to import it as a TIFF. Therefore forcing the text
        # to appear at the beginning of the file -b output.
        when (/^TIFF[ ]image[ ]data/xsm) {
            $format = 'Tagged Image File Format';
            ( undef, my $info ) =
              exec_command( [ 'tiffinfo', $filename ], $pidfile );
            return if $_self->{cancel};
            $logger->info($info);

            # Count number of pages
            $info{pages} = () = $info =~ /TIFF[ ]Directory[ ]at[ ]offset/xsmg;
            $logger->info("$info{pages} pages");
        }
        default {

            # Get file type
            my $image = Image::Magick->new;
            my $e     = $image->Read($filename);
            if ("$e") {
                $logger->error($e);
                _thread_throw_error( $self, $uuid,
                    sprintf __('%s is not a recognised image type'),
                    $filename );
                return;
            }
            return if $_self->{cancel};
            $format = $image->Get('format');
            if ( not defined $format ) {
                _thread_throw_error( $self, $uuid,
                    sprintf __('%s is not a recognised image type'),
                    $filename );
                return;
            }
            $logger->info("Format $format");
            $info{pages} = 1;
        }
    }
    $info{format} = $format;
    $info{path}   = $filename;
    $self->{return}
      ->enqueue( { type => 'file-info', uuid => $uuid, info => \%info } );
    return;
}

sub _thread_import_file {
    my ( $self, %options ) = @_;
    my $PNG = qr/Portable[ ]Network[ ]Graphics/xsm;
    my $JPG = qr/Joint[ ]Photographic[ ]Experts[ ]Group[ ]JFIF[ ]format/xsm;
    my $GIF = qr/CompuServe[ ]graphics[ ]interchange[ ]format/xsm;

    given ( $options{info}->{format} ) {
        when ('DJVU') {

            # Extract images from DjVu
            if ( $options{last} >= $options{first} and $options{first} > 0 ) {
                for my $i ( $options{first} .. $options{last} ) {
                    $self->{progress} =
                      ( $i - 1 ) / ( $options{last} - $options{first} + 1 );
                    $self->{message} =
                      sprintf __('Importing page %i of %i'),
                      $i, $options{last} - $options{first} + 1;

                    my ( $tif, $txt, $error );
                    try {
                        $tif = File::Temp->new(
                            DIR    => $options{dir},
                            SUFFIX => '.tif',
                            UNLINK => FALSE
                        );
                        exec_command(
                            [
                                'ddjvu',    '-format=tiff',
                                "-page=$i", $options{info}->{path},
                                $tif
                            ],
                            $options{pidfile}
                        );
                        ( undef, $txt ) = exec_command(
                            [
                                'djvused', $options{info}->{path},
                                '-e',      "select $i; print-txt"
                            ],
                            $options{pidfile}
                        );
                    }
                    catch {
                        if ( defined $tif ) {
                            $logger->error("Caught error creating $tif: $_");
                            _thread_throw_error( $self, $options{uuid},
                                "Error: unable to write to $tif." );
                        }
                        else {
                            $logger->error(
                                "Caught error writing to $options{dir}: $_");
                            _thread_throw_error( $self, $options{uuid},
                                "Error: unable to write to $options{dir}." );
                        }
                        $error = TRUE;
                    };
                    return if ( $_self->{cancel} or $error );
                    my $page = Gscan2pdf::Page->new(
                        filename   => $tif,
                        dir        => $options{dir},
                        delete     => TRUE,
                        format     => 'Tagged Image File Format',
                        resolution => $options{info}->{ppi}[ $i - 1 ],
                    );
                    try {
                        $page->import_djvutext($txt);
                    }
                    catch {
                        $logger->error(
                            "Caught error parsing DjVU text layer: $_");
                        _thread_throw_error( $self, $options{uuid},
                            'Error: parsing DjVU text layer' );
                    };
                    $self->{return}->enqueue(
                        {
                            type => 'page',
                            uuid => $options{uuid},
                            page => $page->freeze
                        }
                    );
                }
            }
        }
        when ('Portable Document Format') {
            _thread_import_pdf( $self, %options );
        }
        when ('Tagged Image File Format') {

            # Split the tiff into its pages and import them individually
            if ( $options{last} >= $options{first} and $options{first} > 0 ) {
                for my $i ( $options{first} - 1 .. $options{last} - 1 ) {
                    $self->{progress} =
                      $i / ( $options{last} - $options{first} + 1 );
                    $self->{message} =
                      sprintf __('Importing page %i of %i'),
                      $i, $options{last} - $options{first} + 1;

                    my ( $tif, $error );
                    try {
                        $tif = File::Temp->new(
                            DIR    => $options{dir},
                            SUFFIX => '.tif',
                            UNLINK => FALSE
                        );
                        exec_command(
                            [ 'tiffcp', "$options{info}->{path},$i", $tif ],
                            $options{pidfile} );
                    }
                    catch {
                        if ( defined $tif ) {
                            $logger->error("Caught error creating $tif: $_");
                            _thread_throw_error( $self, $options{uuid},
                                "Error: unable to write to $tif." );
                        }
                        else {
                            $logger->error(
                                "Caught error writing to $options{dir}: $_");
                            _thread_throw_error( $self, $options{uuid},
                                "Error: unable to write to $options{dir}." );
                        }
                        $error = TRUE;
                    };
                    return if ( $_self->{cancel} or $error );
                    my $page = Gscan2pdf::Page->new(
                        filename => $tif,
                        dir      => $options{dir},
                        delete   => TRUE,
                        format   => $options{info}->{format},
                    );
                    $self->{return}->enqueue(
                        {
                            type => 'page',
                            uuid => $options{uuid},
                            page => $page->freeze
                        }
                    );
                }
            }
        }
        when (/(?:$PNG|$JPG|$GIF)/xsm) {
            try {
                my $page = Gscan2pdf::Page->new(
                    filename => $options{info}->{path},
                    dir      => $options{dir},
                    format   => $options{info}->{format},
                );
                $self->{return}->enqueue(
                    {
                        type => 'page',
                        uuid => $options{uuid},
                        page => $page->freeze
                    }
                );
            }
            catch {
                $logger->error("Caught error writing to $options{dir}: $_");
                _thread_throw_error( $self, $options{uuid},
                    "Error: unable to write to $options{dir}." );
            };
        }

   # only 1-bit Portable anymap is properly supported, so convert ANY pnm to png
        default {
            try {
                my $page = Gscan2pdf::Page->new(
                    filename => $options{info}->{path},
                    dir      => $options{dir},
                    format   => $options{info}->{format},
                );
                $self->{return}->enqueue(
                    {
                        type => 'page',
                        uuid => $options{uuid},
                        page => $page->to_png($paper_sizes)->freeze
                    }
                );
            }
            catch {
                $logger->error("Caught error writing to $options{dir}: $_");
                _thread_throw_error( $self, $options{uuid},
                    "Error: unable to write to $options{dir}." );
            };
        }
    }
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'import-file',
            uuid    => $options{uuid},
        }
    );
    return;
}

sub _thread_import_pdf {
    my ( $self, %options ) = @_;
    my $warning_flag;

    # Extract images from PDF
    if ( $options{last} >= $options{first} and $options{first} > 0 ) {
        for my $i ( $options{first} .. $options{last} ) {

            my ( $status, $out, $err ) = exec_command(
                [
                    'pdfimages', '-f', $i, '-l', $i, $options{info}->{path},
                    'x'
                ],
                $options{pidfile}
            );
            return if $_self->{cancel};
            if ($status) {
                _thread_throw_error( $self, $options{uuid},
                    __('Error extracting images from PDF') );
            }

            my $html =
              File::Temp->new( DIR => $options{dir}, SUFFIX => '.html' );
            ( $status, $out, $err ) = exec_command(
                [
                    'pdftotext', '-bbox', '-f', $i, '-l', $i,
                    $options{info}->{path}, $html
                ],
                $options{pidfile}
            );
            return if $_self->{cancel};
            if ($status) {
                _thread_throw_error( $self, $options{uuid},
                    __('Error extracting text layer from PDF') );
            }

            # Import each image
            my @images = glob 'x-??*.???';
            if ( @images != 1 ) { $warning_flag = TRUE }
            for (@images) {
                my ($ext) = /([^.]+)$/xsm;
                try {
                    my $page = Gscan2pdf::Page->new(
                        filename => $_,
                        dir      => $options{dir},
                        delete   => TRUE,
                        format   => $format{$ext},
                        size     => $options{info}{page_size},
                    );
                    $page->import_pdftotext( slurp($html) );
                    $self->{return}->enqueue(
                        {
                            type => 'page',
                            uuid => $options{uuid},
                            page => $page->to_png($paper_sizes)->freeze
                        }
                    );
                }
                catch {
                    $logger->error("Caught error importing PDF: $_");
                    _thread_throw_error( $self, $options{uuid},
                        __('Error importing PDF') );
                };
            }
        }

        if ($warning_flag) {
            _thread_throw_error( $self, $options{uuid}, __(<<'EOS') );
Warning: gscan2pdf expects one image per page, but this was not satisfied. It is probable that the PDF has not been correcly imported.

If you wish to add scans to an existing PDF, use the prepend/append to PDF options in the Save dialogue.
EOS
        }
    }
    return;
}

sub _thread_save_pdf {
    my ( $self, %options ) = @_;

    my $pagenr = 0;
    my ( $cache, $resolution );

    # Create PDF with PDF::API2
    $self->{message} = __('Setting up PDF');
    my $filename = $options{path};
    if (   defined $options{options}{prepend}
        or defined $options{options}{append}
        or defined $options{options}{ps} )
    {
        $filename = File::Temp->new( DIR => $options{dir}, SUFFIX => '.pdf' );
    }
    my $pdf = PDF::API2->new( -file => $filename );

    if ( defined $options{metadata} ) {
        my $metadata = prepare_output_metadata( 'PDF', $options{metadata} );
        $pdf->info( %{$metadata} );
    }
    $cache->{core} = $pdf->corefont('Times-Roman');
    if ( defined $options{options}->{font} ) {
        $cache->{ttf} =
          $pdf->ttfont( $options{options}->{font}, -unicodemap => 1 );
        $logger->info("Using $options{options}->{font} for non-ASCII text");
    }

    for my $pagedata ( @{ $options{list_of_pages} } ) {
        ++$pagenr;
        $self->{progress} = $pagenr / ( $#{ $options{list_of_pages} } + 2 );
        $self->{message} = sprintf __('Saving page %i of %i'),
          $pagenr, $#{ $options{list_of_pages} } + 1;
        my $status =
          _add_page_to_pdf( $self, $pdf, $pagedata, $cache, %options );
        if ( not defined $resolution ) { $resolution = $pagedata->resolution }
        return if ( $status or $_self->{cancel} );
    }

    $self->{message} = __('Closing PDF');
    $logger->info('Closing PDF');
    $pdf->save;
    $pdf->end;

    if (   defined $options{options}{prepend}
        or defined $options{options}{append} )
    {
        return if _append_pdf( $self, $filename, %options );
    }
    elsif ( defined $options{options}{set_timestamp}
        and $options{options}{set_timestamp} )
    {
        _set_timestamp( $self, $filename, $options{uuid},
            @{ $options{metadata}{date} } );
    }

    if ( defined $options{options}->{ps} ) {
        $self->{message} = __('Converting to PS');

        my @cmd =
          ( $options{options}->{pstool}, $filename, $options{options}->{ps} );
        my ( $status, undef, $error ) =
          exec_command( \@cmd, $options{pidfile} );
        if ( $status or $error ) {
            $logger->info($error);
            _thread_throw_error( $self, $options{uuid},
                sprintf __('Error converting PDF to PS: %s'), $error );
            return;
        }
        _post_save_hook( $options{options}->{ps}, %{ $options{options} } );
    }
    else {
        _post_save_hook( $filename, %{ $options{options} } );
    }

    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'save-pdf',
            uuid    => $options{uuid},
        }
    );
    return;
}

sub _append_pdf {
    my ( $self, $filename, %options ) = @_;
    my ( $bak, $file1, $file2, $out, $message );
    if ( defined $options{options}{prepend} ) {
        $file1   = $filename;
        $file2   = "$options{options}{prepend}.bak";
        $bak     = $file2;
        $out     = $options{options}{prepend};
        $message = __('Error prepending PDF: %s');
        $logger->info('Prepending PDF');
    }
    else {
        $file2   = $filename;
        $file1   = "$options{options}{append}.bak";
        $bak     = $file1;
        $out     = $options{options}{append};
        $message = __('Error appending PDF: %s');
        $logger->info('Appending PDF');
    }

    if ( not move( $out, $bak ) ) {
        _thread_throw_error( $self, $options{uuid},
            __('Error creating backup of PDF') );
        return;
    }

    my ( $status, undef, $error ) =
      exec_command( [ 'pdfunite', $file1, $file2, $out ], $options{pidfile} );
    if ($status) {
        $logger->info($error);
        _thread_throw_error( $self, $options{uuid}, sprintf $message, $error );
        return $status;
    }
}

sub _set_timestamp {
    my ( $self, $filename, $uuid, @date ) = @_;
    try {
        my $time = Date_to_Time( @date, 0, 0, 0 );
        utime $time, $time, $filename;
    }
    catch {
        $logger->error('Unable to set file timestamp for dates prior to 1970');
        _thread_throw_error( $self, $uuid,
            __('Unable to set file timestamp for dates prior to 1970') );
    };
    return;
}

sub _add_page_to_pdf {
    my ( $self, $pdf, $pagedata, $cache, %options ) = @_;
    my $filename = $pagedata->{filename};
    my $image    = Image::Magick->new;
    my $status   = $image->Read($filename);
    return if $_self->{cancel};
    if ("$status") { $logger->warn($status) }

    # Get the size and resolution. Resolution is dots per inch, width
    # and height are in inches.
    my $w = $image->Get('width') / $pagedata->{resolution};
    my $h = $image->Get('height') / $pagedata->{resolution};
    $pagedata->{w} = $w;
    $pagedata->{h} = $h;

    # Automatic mode
    my $type;
    if ( not defined( $options{options}->{compression} )
        or $options{options}->{compression} eq 'auto' )
    {
        $pagedata->{depth} = $image->Get('depth');
        $logger->info("Depth of $filename is $pagedata->{depth}");
        if ( $pagedata->{depth} == 1 ) {
            $pagedata->{compression} = 'png';
        }
        else {
            $type = $image->Get('type');
            $logger->info("Type of $filename is $type");
            if ( $type =~ /TrueColor/xsm ) {
                $pagedata->{compression} = 'jpg';
            }
            else {
                $pagedata->{compression} = 'png';
            }
        }
        $logger->info("Selecting $pagedata->{compression} compression");
    }
    else {
        $pagedata->{compression} = $options{options}->{compression};
    }

    my ( $format, $output_resolution, $error );
    try {
        ( $filename, $format, $output_resolution ) =
          _convert_image_for_pdf( $self, $pagedata, $image, %options );
    }
    catch {
        $logger->error("Caught error converting image: $_");
        _thread_throw_error( $self, $options{uuid},
            "Caught error converting image: $_." );
        $error = TRUE;
    };
    if ($error) { return 1 }

    $logger->info(
        'Defining page at ',
        $w * $POINTS_PER_INCH,
        'pt x ', $h * $POINTS_PER_INCH, 'pt'
    );
    my $page = $pdf->page;
    $page->mediabox( $w * $POINTS_PER_INCH, $h * $POINTS_PER_INCH );

    if ( defined( $pagedata->{hocr} ) ) {
        $logger->info('Embedding OCR output behind image');
        _add_text_to_pdf( $page, $pagedata, $pagedata->boxes, $cache->{ttf},
            $cache->{core} );
    }

    # Add scan
    my $gfx = $page->gfx;
    my ( $imgobj, $msg );
    try {
        given ($format) {
            when ('png') {
                $imgobj = $pdf->image_png($filename);
            }
            when ('jpg') {
                $imgobj = $pdf->image_jpeg($filename);
            }
            when (/^p[bn]m$/xsm) {
                $imgobj = $pdf->image_pnm($filename);
            }
            when ('gif') {
                $imgobj = $pdf->image_gif($filename);
            }
            when ('tif') {
                $imgobj = $pdf->image_tiff($filename);
            }
            default {
                $msg = "Unknown format $format file $filename";
            }
        }
    }
    catch { $msg = $_ };
    return if $_self->{cancel};
    if ($msg) {
        $logger->warn($msg);
        _thread_throw_error( $self, $options{uuid},
            sprintf __('Error creating PDF image object: %s'), $msg );
        return 1;
    }

    try {
        $gfx->image(
            $imgobj, 0, 0,
            $w * $POINTS_PER_INCH,
            $h * $POINTS_PER_INCH
        );
    }
    catch {
        $logger->warn($_);
        _thread_throw_error( $self, $options{uuid},
            sprintf __('Error embedding file image in %s format to PDF: %s'),
            $format, $_ );
        $error = TRUE;
    };
    if ($error) { return 1 }

    $logger->info("Added $filename at $output_resolution PPI");
    return;
}

# Convert file if necessary

sub _convert_image_for_pdf {
    my ( $self, $pagedata, $image, %options ) = @_;
    my $filename    = $pagedata->{filename};
    my $compression = $pagedata->{compression};

    my $format;
    if ( $filename =~ /[.](\w*)$/xsm ) {
        $format = $1;
    }

    # The output resolution is normally the same as the input
    # resolution.
    my $output_resolution = $pagedata->{resolution};

    if (   ( $compression ne 'none' and $compression ne $format )
        or $options{options}->{downsample}
        or $compression eq 'jpg' )
    {
        if ( $compression !~ /(?:jpg|png)/xsm and $format ne 'tif' ) {
            my $ofn = $filename;
            $filename =
              File::Temp->new( DIR => $options{dir}, SUFFIX => '.tif' );
            $logger->info("Converting $ofn to $filename");
        }
        elsif ( $compression =~ /(?:jpg|png)/xsm ) {
            my $ofn = $filename;
            $filename = File::Temp->new(
                DIR    => $options{dir},
                SUFFIX => ".$compression"
            );
            $logger->info("Converting $ofn to $filename");
        }

        if ( $options{options}->{downsample} ) {
            $output_resolution = $options{options}->{'downsample dpi'};
            my $w_pixels = $pagedata->{w} * $output_resolution;
            my $h_pixels = $pagedata->{h} * $output_resolution;

            $logger->info("Resizing $filename to $w_pixels x $h_pixels");
            my $status =
              $image->Sample( width => $w_pixels, height => $h_pixels );
            if ("$status") { $logger->warn($status) }
        }
        if ( defined( $options{options}->{quality} ) and $compression eq 'jpg' )
        {
            my $status = $image->Set( quality => $options{options}->{quality} );
            if ("$status") { $logger->warn($status) }
        }

        $format =
          _write_image_object( $image, $filename, $format, $pagedata,
            $options{options}->{downsample} );

        if ( $compression !~ /(?:jpg|png)/xsm ) {
            my $filename2 =
              File::Temp->new( DIR => $options{dir}, SUFFIX => '.tif' );
            my $error =
              File::Temp->new( DIR => $options{dir}, SUFFIX => '.txt' );
            ( my $status, undef, $error ) = exec_command(
                [ 'tiffcp', '-c', $compression, $filename, $filename2 ],
                $options{pidfile} );
            return if $_self->{cancel};
            if ($status) {
                $logger->info($error);
                _thread_throw_error( $self, $options{uuid},
                    sprintf __('Error compressing image: %s'), $error );
                return;
            }
            $filename = $filename2;
        }
    }
    return $filename, $format, $output_resolution;
}

sub _write_image_object {
    my ( $image, $filename, $format, $pagedata, $downsample ) = @_;
    my $compression = $pagedata->{compression};
    if (   ( $compression !~ /(?:jpg|png)/xsm and $format ne 'tif' )
        or ( $compression =~ /(?:jpg|png)/xsm )
        or $downsample )
    {
        $logger->info("Writing temporary image $filename");

        # Reset depth because of ImageMagick bug
        # <https://github.com/ImageMagick/ImageMagick/issues/277>
        $image->Set( 'depth', $image->Get('depth') );
        my $status = $image->Write( filename => $filename );
        return if $_self->{cancel};
        if ("$status") { $logger->warn($status) }
        if ( $filename =~ /[.](\w*)$/xsm ) {
            $format = $1;
        }
    }
    return $format;
}

# Add OCR as text behind the scan

sub _add_text_to_pdf {
    my ( $pdf_page, $gs_page, $boxes, $ttfcache, $corecache ) = @_;
    my $h          = $gs_page->{h};
    my $w          = $gs_page->{w};
    my $resolution = $gs_page->{resolution};
    my $font;
    my $text = $pdf_page->text;
    for my $box ( @{$boxes} ) {
        if ( defined $box->{contents} ) {
            _add_text_to_pdf( $pdf_page, $gs_page, $box->{contents}, $ttfcache,
                $corecache );
        }
        my ( $x1, $y1, $x2, $y2 ) = @{ $box->{bbox} };
        my $txt = $box->{text};
        if ( not defined $txt ) { next }
        if ( $txt =~ /([[:^ascii:]])/xsm and defined $ttfcache ) {
            if ( defined $1 ) {
                $logger->debug("non-ascii text is '$1' in '$txt'");
            }
            $font = $ttfcache;
        }
        else {
            $font = $corecache;
        }
        if ( $x1 == 0 and $y1 == 0 and not defined $x2 ) {
            ( $x2, $y2 ) = ( $w * $resolution, $h * $resolution );
        }
        if (    abs( $h * $resolution - $y2 + $y1 ) > $BOX_TOLERANCE
            and abs( $w * $resolution - $x2 + $x1 ) > $BOX_TOLERANCE )
        {

            # Box is smaller than the page. We know the text position.
            # Set the text position.
            # Translate x1 and y1 to inches and then to points. Invert the
            # y coordinate (since the PDF coordinates are bottom to top
            # instead of top to bottom) and subtract $size, since the text
            # will end up above the given point instead of below.
            my $size = ( $y2 - $y1 ) / $resolution * $POINTS_PER_INCH;
            $text->font( $font, $size );
            $text->translate( $x1 / $resolution * $POINTS_PER_INCH,
                ( $h - ( $y1 / $resolution ) ) * $POINTS_PER_INCH - $size );
            $text->text( $txt, utf8 => 1 );
        }
        else {
            my $size = 1;
            $text->font( $font, $size );
            _wrap_text_to_page( $txt, $size, $text, $h, $w );
        }
    }
    return;
}

# Box is the same size as the page. We don't know the text position.
# Start at the top of the page (PDF coordinate system starts
# at the bottom left of the page)

sub _wrap_text_to_page {
    my ( $txt, $size, $text_box, $h, $w ) = @_;
    my $y = $h * $POINTS_PER_INCH - $size;
    for my $line ( split /\n/xsm, $txt ) {
        my $x = 0;

        # Add a word at a time in order to linewrap
        for my $word ( split $SPACE, $line ) {
            if ( length($word) * $size + $x > $w * $POINTS_PER_INCH ) {
                $x = 0;
                $y -= $size;
            }
            $text_box->translate( $x, $y );
            if ( $x > 0 ) { $word = $SPACE . $word }
            $x += $text_box->text( $word, utf8 => 1 );
        }
        $y -= $size;
    }
    return;
}

sub _post_save_hook {
    my ( $filename, %options ) = @_;
    if ( defined $options{post_save_hook} ) {
        my $command = $options{post_save_hook};
        $command =~ s/%i/"$filename"/gxsm;
        if ( not defined $options{post_save_hook_options}
            or $options{post_save_hook_options} ne 'fg' )
        {
            $command .= ' &';
        }
        $logger->info($command);
        system $command;
    }
    return;
}

sub _thread_save_djvu {
    my ( $self, %options ) = @_;

    my $page = 0;
    my @filelist;

    for my $pagedata ( @{ $options{list_of_pages} } ) {
        ++$page;
        $self->{progress} = $page / ( $#{ $options{list_of_pages} } + 2 );
        $self->{message} = sprintf __('Writing page %i of %i'),
          $page, $#{ $options{list_of_pages} } + 1;

        my $filename = $pagedata->{filename};

        my ( $djvu, $error );
        try {
            $djvu = File::Temp->new( DIR => $options{dir}, SUFFIX => '.djvu' );
        }
        catch {
            $logger->error("Caught error writing DjVu: $_");
            _thread_throw_error( $self, $options{uuid},
                "Caught error writing DjVu: $_." );
            $error = TRUE;
        };
        if ($error) { return }

        # Check the image depth to decide what sort of compression to use
        my $image = Image::Magick->new;
        my $e     = $image->Read($filename);
        if ("$e") {
            $logger->error($e);
            _thread_throw_error( $self, $options{uuid},
                "Error reading $filename: $e." );
            return;
        }
        my $depth = $image->Get('depth');
        my $class = $image->Get('class');
        my $compression;

        # Get the size
        $pagedata->{w}           = $image->Get('width');
        $pagedata->{h}           = $image->Get('height');
        $pagedata->{pidfile}     = $options{pidfile};
        $pagedata->{page_number} = $page;

        # c44 can only use pnm and jpg
        my $format;
        if ( $filename =~ /[.](\w*)$/xsm ) {
            $format = $1;
        }
        if ( $depth > 1 ) {
            $compression = 'c44';
            if ( $format !~ /(?:pnm|jpg)/xsm ) {
                my $pnm =
                  File::Temp->new( DIR => $options{dir}, SUFFIX => '.pnm' );
                $e = $image->Write( filename => $pnm );
                if ("$e") {
                    $logger->error($e);
                    _thread_throw_error( $self, $options{uuid},
                        "Error writing $pnm: $e." );
                    return;
                }
                $filename = $pnm;
            }
        }

        # cjb2 can only use pnm and tif
        else {
            $compression = 'cjb2';
            if ( $format !~ /(?:pnm|tif)/xsm
                or ( $format eq 'pnm' and $class ne 'PseudoClass' ) )
            {
                my $pbm =
                  File::Temp->new( DIR => $options{dir}, SUFFIX => '.pbm' );
                $e = $image->Write( filename => $pbm );
                if ("$e") {
                    $logger->error($e);
                    _thread_throw_error( $self, $options{uuid},
                        "Error writing $pbm: $e." );
                    return;
                }
                $filename = $pbm;
            }
        }

        # Create the djvu
        my ($status) = exec_command(
            [
                $compression,                   '-dpi',
                int( $pagedata->{resolution} ), $filename,
                $djvu
            ],
            $options{pidfile}
        );
        my $size =
          -s "$djvu"; # quotes needed to prevent -s clobbering File::Temp object
        return if $_self->{cancel};
        if ( $status != 0 or not $size ) {
            $logger->error(
"Error writing image for page $page of DjVu (process returned $status, image size $size)"
            );
            _thread_throw_error( $self, $options{uuid},
                __('Error writing DjVu') );
            return;
        }
        push @filelist, $djvu;
        _add_text_to_djvu( $self, $djvu, $options{dir}, $pagedata,
            $options{uuid} );
    }
    $self->{progress} = 1;
    $self->{message}  = __('Merging DjVu');
    my ( $status, $out, $err ) =
      exec_command( [ 'djvm', '-c', $options{path}, @filelist ],
        $options{pidfile} );
    return if $_self->{cancel};
    if ($status) {
        $logger->error('Error merging DjVu');
        _thread_throw_error( $self, $options{uuid}, __('Error merging DjVu') );
    }
    _add_metadata_to_djvu( $self, %options );

    if ( defined $options{options}{set_timestamp}
        and $options{options}{set_timestamp} )
    {
        _set_timestamp( $self, $options{path}, $options{uuid},
            @{ $options{metadata}{date} } );
    }

    _post_save_hook( $options{path}, %{ $options{options} } );

    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'save-djvu',
            uuid    => $options{uuid},
        }
    );
    return;
}

sub _write_file {
    my ( $self, $fh, $filename, $data, $uuid ) = @_;
    if ( not print {$fh} $data ) {
        _thread_throw_error( $self, $uuid,
            sprintf __("Can't write to file: %s"), $filename );
        return FALSE;
    }
    return TRUE;
}

# Add OCR to text layer

sub _add_text_to_djvu {
    my ( $self, $djvu, $dir, $pagedata, $uuid ) = @_;
    if ( defined( $pagedata->{hocr} ) ) {
        my $txt = $pagedata->djvu_text;
        if ( $txt eq $EMPTY ) { return }

        # Write djvusedtxtfile
        my $djvusedtxtfile = File::Temp->new( DIR => $dir, SUFFIX => '.txt' );
        $logger->debug( $pagedata->{hocr} );
        $logger->debug( $pagedata->djvu_text );
        open my $fh, '>:encoding(UTF8)', $djvusedtxtfile
          or croak( sprintf __("Can't open file: %s"), $djvusedtxtfile );
        _write_file( $self, $fh, $djvusedtxtfile, $txt, $uuid )
          or return;
        close $fh
          or croak( sprintf __("Can't close file: %s"), $djvusedtxtfile );

        # Run djvusedtxtfile
        my @cmd =
          ( 'djvused', $djvu, '-e', "select 1; set-txt $djvusedtxtfile", '-s' );
        my ($status) = exec_command( \@cmd, $pagedata->{pidfile} );
        return if $_self->{cancel};
        if ($status) {
            $logger->error(
                "Error adding text layer to DjVu page $pagedata->{page_number}"
            );
            _thread_throw_error( $self, $uuid,
                __('Error adding text layer to DjVu') );
        }
    }
    return;
}

sub _add_metadata_to_djvu {
    my ( $self, %options ) = @_;
    if ( $options{metadata} and %{ $options{metadata} } ) {

        # Open djvusedmetafile
        my $djvusedmetafile =
          File::Temp->new( DIR => $options{dir}, SUFFIX => '.txt' );
        open my $fh, '>:encoding(UTF8)',    ## no critic (RequireBriefOpen)
          $djvusedmetafile
          or croak( sprintf __("Can't open file: %s"), $djvusedmetafile );
        _write_file( $self, $fh, $djvusedmetafile, "(metadata\n",
            $options{uuid} )
          or return;

        # Write the metadata
        my $metadata = prepare_output_metadata( 'DjVu', $options{metadata} );
        for my $key ( keys %{$metadata} ) {
            my $val = $metadata->{$key};

            # backslash-escape any double quotes and bashslashes
            $val =~ s/\\/\\\\/gxsm;
            $val =~ s/"/\\\"/gxsm;
            _write_file( $self, $fh, $djvusedmetafile, "$key \"$val\"\n",
                $options{uuid} )
              or return;
        }
        _write_file( $self, $fh, $djvusedmetafile, ')', $options{uuid} )
          or return;
        close $fh
          or croak( sprintf __("Can't close file: %s"), $djvusedmetafile );

        # Write djvusedmetafile
        my @cmd = (
            'djvused', $options{path}, '-e', "set-meta $djvusedmetafile", '-s',
        );
        my ($status) = exec_command( \@cmd, $options{pidfile} );
        return if $_self->{cancel};
        if ($status) {
            $logger->error('Error adding metadata info to DjVu file');
            _thread_throw_error( $self, $options{uuid},
                __('Error adding metadata to DjVu') );
        }
    }
    return;
}

sub _thread_save_tiff {
    my ( $self, %options ) = @_;

    my $page = 0;
    my @filelist;

    for my $pagedata ( @{ $options{list_of_pages} } ) {
        ++$page;
        $self->{progress} =
          ( $page - 1 ) / ( $#{ $options{list_of_pages} } + 2 );
        $self->{message} =
          sprintf __('Converting image %i of %i to TIFF'),
          $page, $#{ $options{list_of_pages} } + 1;

        my $filename = $pagedata->{filename};
        if (
            $filename !~ /[.]tif/xsm
            or ( defined( $options{options}->{compression} )
                and $options{options}->{compression} eq 'jpeg' )
          )
        {
            my ( $tif, $error );
            try {
                $tif =
                  File::Temp->new( DIR => $options{dir}, SUFFIX => '.tif' );
            }
            catch {
                $logger->error("Error writing TIFF: $_");
                _thread_throw_error( $self, $options{uuid},
                    "Error writing TIFF: $_." );
                $error = TRUE;
            };
            if ($error) { return }
            my $resolution = $pagedata->{resolution};

            # Convert to tiff
            my @depth;
            if ( defined( $options{options}->{compression} )
                and $options{options}->{compression} eq 'jpeg' )
            {
                @depth = qw(-depth 8);
            }

            my @cmd = (
                'convert', '-units', 'PixelsPerInch', '-density', $resolution,
                @depth, $filename, $tif,
            );
            my ($status) = exec_command( \@cmd, $options{pidfile} );
            return if $_self->{cancel};

            if ($status) {
                $logger->error('Error writing TIFF');
                _thread_throw_error( $self, $options{uuid},
                    __('Error writing TIFF') );
                return;
            }
            $filename = $tif;
        }
        push @filelist, $filename;
    }

    my @compression;
    if ( defined $options{options}->{compression} ) {
        @compression = ( '-c', "$options{options}->{compression}" );
        if ( $options{options}->{compression} eq 'jpeg' ) {
            $compression[1] .= ":$options{options}->{quality}";
            push @compression, qw(-r 16);
        }
    }

    # Create the tiff
    $self->{progress} = 1;
    $self->{message}  = __('Concatenating TIFFs');
    my @cmd = ( 'tiffcp', @compression, @filelist, $options{path} );
    my ( $status, undef, $error ) = exec_command( \@cmd, $options{pidfile} );
    return if $_self->{cancel};

    if ( $status or $error =~ /(?:usage|TIFFOpen):/xsm ) {
        $logger->info($error);
        _thread_throw_error( $self, $options{uuid},
            sprintf __('Error compressing image: %s'), $error );
        return;
    }
    if ( defined $options{options}->{ps} ) {
        $self->{message} = __('Converting to PS');

        # Note: -a option causes tiff2ps to generate multiple output
        # pages, one for each page in the input TIFF file.  Without it, it
        # only generates output for the first page.
        @cmd =
          ( 'tiff2ps', '-a', $options{path}, '-O', $options{options}->{ps} );
        ( $status, undef, $error ) = exec_command( \@cmd, $options{pidfile} );
        if ( $status or $error ) {
            $logger->info($error);
            _thread_throw_error( $self, $options{uuid},
                sprintf __('Error converting TIFF to PS: %s'), $error );
            return;
        }
        _post_save_hook( $options{options}->{ps}, %{ $options{options} } );
    }
    else {
        _post_save_hook( $options{path}, %{ $options{options} } );
    }

    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'save-tiff',
            uuid    => $options{uuid},
        }
    );
    return;
}

sub _thread_rotate {
    my ( $self, $angle, $page, $dir, $uuid ) = @_;
    my $filename = $page->{filename};
    $logger->info("Rotating $filename by $angle degrees");

    # Rotate with imagemagick
    my $image = Image::Magick->new;
    my $e     = $image->Read($filename);
    return if $_self->{cancel};
    if ("$e") { $logger->warn($e) }

    # workaround for those versions of imagemagick that produce 16bit output
    # with rotate
    my $depth = $image->Get('depth');
    $e = $image->Rotate($angle);
    if ("$e") {
        $logger->error($e);
        _thread_throw_error( $self, $uuid, "Error rotating: $e." );
        return;
    }
    return if $_self->{cancel};
    my ( $suffix, $error );
    if ( $filename =~ /[.](\w*)$/xsm ) {
        $suffix = $1;
    }
    try {
        $filename = File::Temp->new(
            DIR    => $dir,
            SUFFIX => ".$suffix",
            UNLINK => FALSE
        );
        $e = $image->Write( filename => $filename, depth => $depth );
    }
    catch {
        $logger->error("Error rotating: $_");
        _thread_throw_error( $self, $uuid, "Error rotating: $_." );
        $error = TRUE;
    };
    if ($error) { return }
    return if $_self->{cancel};
    if ("$e") { $logger->warn($e) }
    $page->{filename}   = $filename->filename;
    $page->{dirty_time} = timestamp();           #flag as dirty
    $self->{return}->enqueue(
        {
            type => 'page',
            uuid => $uuid,
            page => $page,
            info => { replace => $page->{uuid} }
        }
    );
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'rotate',
            uuid    => $uuid,
        }
    );
    return;
}

sub _thread_save_image {
    my ( $self, %options ) = @_;

    if ( @{ $options{list_of_pages} } == 1 ) {
        my $status = exec_command(
            [
                'convert',  $options{list_of_pages}->[0]{filename},
                '-density', $options{list_of_pages}->[0]{resolution},
                $options{path}
            ],
            $options{pidfile}
        );
        return if $_self->{cancel};
        if ($status) {
            _thread_throw_error( $self, $options{uuid},
                __('Error saving image') );
        }
        _post_save_hook( $options{list_of_pages}->[0]{filename},
            %{ $options{options} } );
    }
    else {
        my $current_filename;
        my $i = 1;
        for ( @{ $options{list_of_pages} } ) {
            $current_filename = sprintf $options{path}, $i++;
            my $status = exec_command(
                [
                    'convert',  $_->{filename},
                    '-density', $_->{resolution},
                    $current_filename
                ],
                $options{pidfile}
            );
            return if $_self->{cancel};
            if ($status) {
                _thread_throw_error( $self, $options{uuid},
                    __('Error saving image') );
            }
            _post_save_hook( $_->{filename}, %{ $options{options} } );
        }
    }
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'save-image',
            uuid    => $options{uuid},
        }
    );
    return;
}

sub _thread_save_text {
    my ( $self, $path, $list_of_pages, $options, $uuid ) = @_;
    my $fh;
    my $string = $EMPTY;

    for my $page ( @{$list_of_pages} ) {
        $string .= $page->string;
        return if $_self->{cancel};
    }
    if ( not open $fh, '>', $path ) {
        _thread_throw_error( $self, $uuid,
            sprintf __("Can't open file: %s"), $path );
        return;
    }
    _write_file( $self, $fh, $path, $string, $uuid ) or return;
    if ( not close $fh ) {
        _thread_throw_error( $self, $uuid,
            sprintf __("Can't close file: %s"), $path );
    }
    _post_save_hook( $path, %{$options} );
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'save-text',
            uuid    => $uuid,
        }
    );
    return;
}

sub _thread_save_hocr {
    my ( $self, $path, $list_of_pages, $options, $uuid ) = @_;
    my $fh;

    if ( not open $fh, '>', $path ) {    ## no critic (RequireBriefOpen)
        _thread_throw_error( $self, $uuid,
            sprintf __("Can't open file: %s"), $path );
        return;
    }

    my $written_header = FALSE;
    for ( @{$list_of_pages} ) {
        if ( $_->{hocr} =~ /([\s\S]*<body>)([\s\S]*)<\/body>/xsm ) {
            my $header    = $1;
            my $hocr_page = $2;
            if ( not $written_header ) {
                _write_file( $self, $fh, $path, $header, $uuid ) or return;
                $written_header = TRUE;
            }
            _write_file( $self, $fh, $path, $hocr_page, $uuid ) or return;
            return if $_self->{cancel};
        }
    }
    if ($written_header) {
        _write_file( $self, $fh, $path, "</body>\n</html>\n", $uuid ) or return;
    }

    if ( not close $fh ) {
        _thread_throw_error( $self, $uuid,
            sprintf __("Can't close file: %s"), $path );
    }
    _post_save_hook( $path, %{$options} );
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'save-hocr',
            uuid    => $uuid,
        }
    );
    return;
}

sub _thread_analyse {
    my ( $self, $page, $uuid ) = @_;

    # Identify with imagemagick
    my $image = Image::Magick->new;
    my $e     = $image->Read( $page->{filename} );
    if ("$e") {
        $logger->error($e);
        _thread_throw_error( $self, $uuid,
            "Error reading $page->{filename}: $e." );
        return;
    }
    return if $_self->{cancel};

    my ( $depth, $min, $max, $mean, $stddev ) = $image->Statistics();
    if ( not defined $depth ) { $logger->warn('image->Statistics() failed') }
    $logger->info("std dev: $stddev mean: $mean");
    return if $_self->{cancel};
    my $maxq = ( 1 << $depth ) - 1;
    $mean = $maxq ? $mean / $maxq : 0;
    if ( $stddev eq 'nan' ) { $stddev = 0 }

# my $quantum_depth = $image->QuantumDepth;
# warn "image->QuantumDepth failed" unless defined $quantum_depth;
# TODO add any other useful image analysis here e.g. is the page mis-oriented?
#  detect mis-orientation possible algorithm:
#   blur or low-pass filter the image (so words look like ovals)
#   look at few vertical narrow slices of the image and get the Standard Deviation
#   if most of the Std Dev are high, then it might be portrait
# TODO may need to send quantumdepth

    $page->{mean}         = $mean;
    $page->{std_dev}      = $stddev;
    $page->{analyse_time} = timestamp();
    $self->{return}->enqueue(
        {
            type => 'page',
            uuid => $uuid,
            page => $page,
            info => { replace => $page->{uuid} }
        }
    );
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'analyse',
            uuid    => $uuid,
        }
    );
    return;
}

sub _thread_threshold {
    my ( $self, $threshold, $page, $dir, $uuid ) = @_;
    my $filename = $page->{filename};

    my $image = Image::Magick->new;
    my $e     = $image->Read($filename);
    return if $_self->{cancel};
    if ("$e") { $logger->warn($e) }

    # Threshold the image
    $e = $image->BlackThreshold( threshold => "$threshold%" );
    if ("$e") {
        $logger->error($e);
        _thread_throw_error( $self, $uuid, "Error running threshold: $e." );
        return;
    }
    return if $_self->{cancel};
    $e = $image->WhiteThreshold( threshold => "$threshold%" );
    if ("$e") {
        $logger->error($e);
        _thread_throw_error( $self, $uuid, "Error running threshold: $e." );
        return;
    }
    return if $_self->{cancel};

    # Write it
    my $error;
    try {
        $filename =
          File::Temp->new( DIR => $dir, SUFFIX => '.pbm', UNLINK => FALSE );
        $e = $image->Write( filename => $filename );
        if ("$e") { $logger->warn($e) }
    }
    catch {
        $logger->error("Error thesholding: $_");
        _thread_throw_error( $self, $uuid, "Error running threshold: $_." );
        $error = TRUE;
    };
    if ($error) { return }
    return if $_self->{cancel};

    $page->{filename}   = $filename->filename;
    $page->{dirty_time} = timestamp();           #flag as dirty
    $self->{return}->enqueue(
        {
            type => 'page',
            uuid => $uuid,
            page => $page,
            info => { replace => $page->{uuid} }
        }
    );
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'theshold',
            uuid    => $uuid,
        }
    );
    return;
}

sub _thread_brightness_contrast {
    my ( $self, %options ) = @_;
    my $filename = $options{page}{filename};

    my $image = Image::Magick->new;
    my $e     = $image->Read($filename);
    return if $_self->{cancel};
    if ("$e") { $logger->warn($e) }

    my $depth = $image->Get('depth');

    # BrightnessContrast the image
    $image->BrightnessContrast(
        brightness => 2 * $options{brightness} - $_100PERCENT,
        contrast   => 2 * $options{contrast} - $_100PERCENT
    );
    if ("$e") {
        $logger->error($e);
        _thread_throw_error( $self, $options{uuid},
            "Error running BrightnessContrast: $e." );
        return;
    }
    return if $_self->{cancel};

    # Write it
    my $error;
    try {
        my $suffix;
        if ( $filename =~ /([.]\w*)$/xsm ) { $suffix = $1 }
        $filename = File::Temp->new(
            DIR    => $options{dir},
            SUFFIX => $suffix,
            UNLINK => FALSE
        );
        $e = $image->Write( depth => $depth, filename => $filename );
        if ("$e") { $logger->warn($e) }
    }
    catch {
        $logger->error("Error changing brightness / contrast: $_");
        _thread_throw_error( $self, $options{uuid},
            "Error changing brightness / contrast: $_." );
        $error = TRUE;
    };
    if ($error) { return }
    return if $_self->{cancel};
    $logger->info(
"Wrote $filename with brightness / contrast changed to $options{brightness} / $options{contrast}"
    );

    $options{page}{filename}   = $filename->filename;
    $options{page}{dirty_time} = timestamp();           #flag as dirty
    $self->{return}->enqueue(
        {
            type => 'page',
            uuid => $options{uuid},
            page => $options{page},
            info => { replace => $options{page}{uuid} }
        }
    );
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'brightness-contrast',
            uuid    => $options{uuid},
        }
    );
    return;
}

sub _thread_negate {
    my ( $self, $page, $dir, $uuid ) = @_;
    my $filename = $page->{filename};

    my $image = Image::Magick->new;
    my $e     = $image->Read($filename);
    return if $_self->{cancel};
    if ("$e") { $logger->warn($e) }

    my $depth = $image->Get('depth');

    # Negate the image
    $e = $image->Negate;
    if ("$e") {
        $logger->error($e);
        _thread_throw_error( $self, $uuid, "Error negating: $e." );
        return;
    }
    return if $_self->{cancel};

    # Write it
    my $error;
    try {
        my $suffix;
        if ( $filename =~ /([.]\w*)$/xsm ) { $suffix = $1 }
        $filename =
          File::Temp->new( DIR => $dir, SUFFIX => $suffix, UNLINK => FALSE );
        $e = $image->Write( depth => $depth, filename => $filename );
        if ("$e") { $logger->warn($e) }
    }
    catch {
        $logger->error("Error negating: $_");
        _thread_throw_error( $self, $uuid, "Error negating: $_." );
        $error = TRUE;
    };
    if ($error) { return }
    return if $_self->{cancel};
    $logger->info("Negating to $filename");

    $page->{filename}   = $filename->filename;
    $page->{dirty_time} = timestamp();           #flag as dirty
    $self->{return}->enqueue(
        {
            type => 'page',
            uuid => $uuid,
            page => $page,
            info => { replace => $page->{uuid} }
        }
    );
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'negate',
            uuid    => $uuid,
        }
    );
    return;
}

sub _thread_unsharp {
    my ( $self, %options ) = @_;
    my $filename = $options{page}->{filename};
    my $version;
    my $image = Image::Magick->new;
    if ( $image->Get('version') =~ /ImageMagick\s([\d.]+)/xsm ) {
        $version = $1;
    }
    $logger->debug("Image::Magick->version $version");
    my $e = $image->Read($filename);
    return if $_self->{cancel};
    if ("$e") { $logger->warn($e) }

    # Unsharp the image
    if ( version->parse("v$version") > version->parse('v7') ) {
        $e = $image->UnsharpMask(
            radius    => $options{radius},
            sigma     => $options{sigma},
            gain      => $options{gain},
            threshold => $options{threshold},
        );
    }
    else {
        $e = $image->UnsharpMask(
            radius    => $options{radius},
            sigma     => $options{sigma},
            amount    => $options{gain},
            threshold => $options{threshold},
        );
    }
    if ("$e") {
        $logger->error($e);
        _thread_throw_error( $self, $options{uuid},
            "Error running unsharp: $e." );
        return;
    }
    return if $_self->{cancel};

    # Write it
    my $error;
    try {
        my $suffix;
        if ( $filename =~ /[.](\w*)$/xsm ) { $suffix = $1 }
        $filename = File::Temp->new(
            DIR    => $options{dir},
            SUFFIX => ".$suffix",
            UNLINK => FALSE
        );
        $e = $image->Write( filename => $filename );
        if ("$e") { $logger->warn($e) }
    }
    catch {
        $logger->error("Error writing image with unsharp mask: $_");
        _thread_throw_error( $self, $options{uuid},
            "Error writing image with unsharp mask: $_." );
        $error = TRUE;
    };
    if ($error) { return }
    return if $_self->{cancel};
    $logger->info(
"Wrote $filename with unsharp mask: radius=$options{radius}, sigma=$options{sigma}, gain=$options{gain}, threshold=$options{threshold}"
    );

    $options{page}{filename}   = $filename->filename;
    $options{page}{dirty_time} = timestamp();           #flag as dirty
    $self->{return}->enqueue(
        {
            type => 'page',
            uuid => $options{uuid},
            page => $options{page},
            info => { replace => $options{page}{uuid} }
        }
    );
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'unsharp',
            uuid    => $options{uuid},
        }
    );
    return;
}

sub _thread_crop {
    my ( $self, %options ) = @_;
    my $filename = $options{page}->{filename};

    my $image = Image::Magick->new;
    my $e     = $image->Read($filename);
    return if $_self->{cancel};
    if ("$e") { $logger->warn($e) }

    # Crop the image
    $e = $image->Crop(
        width  => $options{w},
        height => $options{h},
        x      => $options{x},
        y      => $options{y}
    );
    if ("$e") {
        $logger->error($e);
        _thread_throw_error( $self, $options{uuid}, "Error cropping: $e." );
        return;
    }
    $image->Set( page => '0x0+0+0' );
    return if $_self->{cancel};

    # Write it
    my $error;
    try {
        my $suffix;
        if ( $filename =~ /[.](\w*)$/xsm ) { $suffix = $1 }
        $filename = File::Temp->new(
            DIR    => $options{dir},
            SUFFIX => ".$suffix",
            UNLINK => FALSE
        );
        $e = $image->Write( filename => $filename );
        if ("$e") { $logger->warn($e) }
    }
    catch {
        $logger->error("Error cropping: $_");
        _thread_throw_error( $self, $options{uuid}, "Error cropping: $_." );
        $error = TRUE;
    };
    if ($error) { return }
    $logger->info(
"Cropping $options{w} x $options{h} + $options{x} + $options{y} to $filename"
    );
    return if $_self->{cancel};

    $options{page}{filename}   = $filename->filename;
    $options{page}{dirty_time} = timestamp();           #flag as dirty
    $self->{return}->enqueue(
        {
            type => 'page',
            uuid => $options{uuid},
            page => $options{page},
            info => { replace => $options{page}{uuid} }
        }
    );
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'crop',
            uuid    => $options{uuid},
        }
    );
    return;
}

sub _thread_to_png {
    my ( $self, $page, $dir, $uuid ) = @_;
    my ( $new, $error );
    try {
        $new = $page->to_png($paper_sizes);
    }
    catch {
        $logger->error("Error converting to png: $_");
        _thread_throw_error( $self, $uuid, "Error converting to png: $_." );
        $error = TRUE;
    };
    if ($error) { return }
    return if $_self->{cancel};
    $logger->info("Converted $page->{filename} to $new->{filename}");
    $self->{return}->enqueue(
        {
            type => 'page',
            uuid => $uuid,
            page => $new->freeze,
            info => { replace => $page->{uuid} }
        }
    );
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'to-png',
            uuid    => $uuid,
        }
    );
    return;
}

sub _thread_tesseract {
    my ( $self, %options ) = @_;
    my ( $error, $stderr );
    try {
        ( $options{page}{hocr}, $stderr ) = Gscan2pdf::Tesseract->hocr(
            file      => $options{page}{filename},
            language  => $options{language},
            logger    => $logger,
            threshold => $options{threshold},
            pidfile   => $options{pidfile}
        );
    }
    catch {
        $logger->error("Error processing with tesseract: $_");
        _thread_throw_error( $self, $options{uuid},
            "Error processing with tesseract: $_" );
        $error = TRUE;
    };
    if ($error) { return }
    return if $_self->{cancel};
    if ( defined $stderr and $stderr ne $EMPTY ) {
        _thread_throw_error( $self, $options{uuid},
            "Error processing with tesseract: $stderr" );
    }
    $options{page}{ocr_flag} = 1;    #FlagOCR
    $options{page}{ocr_time} =
      timestamp();                   #remember when we ran OCR on this page
    $self->{return}->enqueue(
        {
            type => 'page',
            uuid => $options{uuid},
            page => $options{page},
            info => { replace => $options{page}{uuid} }
        }
    );
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'tesseract',
            uuid    => $options{uuid},
        }
    );
    return;
}

sub _thread_ocropus {
    my ( $self, %options ) = @_;
    $options{page}{hocr} = Gscan2pdf::Ocropus->hocr(
        file      => $options{page}{filename},
        language  => $options{language},
        logger    => $logger,
        pidfile   => $options{pidfile},
        threshold => $options{threshold}
    );
    return if $_self->{cancel};
    $options{page}{ocr_flag} = 1;    #FlagOCR
    $options{page}{ocr_time} =
      timestamp();                   #remember when we ran OCR on this page
    $self->{return}->enqueue(
        {
            type => 'page',
            uuid => $options{uuid},
            page => $options{page},
            info => { replace => $options{page}{uuid} }
        }
    );
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'ocropus',
            uuid    => $options{uuid},
        }
    );
    return;
}

sub _thread_cuneiform {
    my ( $self, %options ) = @_;
    $options{page}{hocr} = Gscan2pdf::Cuneiform->hocr(
        file      => $options{page}{filename},
        language  => $options{language},
        logger    => $logger,
        pidfile   => $options{pidfile},
        threshold => $options{threshold}
    );
    return if $_self->{cancel};
    $options{page}{ocr_flag} = 1;    #FlagOCR
    $options{page}{ocr_time} =
      timestamp();                   #remember when we ran OCR on this page
    $self->{return}->enqueue(
        {
            type => 'page',
            uuid => $options{uuid},
            page => $options{page},
            info => { replace => $options{page}{uuid} }
        }
    );
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'cuneiform',
            uuid    => $options{uuid},
        }
    );
    return;
}

sub _thread_gocr {
    my ( $self, $page, $threshold, $pidfile, $uuid ) = @_;
    my $pnm;
    if (   ( $page->{filename} !~ /[.]pnm$/xsm )
        or ( defined $threshold and $threshold ) )
    {

        # Temporary filename for new file
        $pnm = File::Temp->new( SUFFIX => '.pnm' );
        my $image = Image::Magick->new;
        $image->Read( $page->{filename} );
        return if $_self->{cancel};

        my $x;
        if ( defined $threshold and $threshold ) {
            $logger->info("thresholding at $threshold to $pnm");
            $image->BlackThreshold( threshold => "$threshold%" );
            return if $_self->{cancel};
            $image->WhiteThreshold( threshold => "$threshold%" );
            return if $_self->{cancel};
            $x = $image->Quantize( colors => 2 );
            return if $_self->{cancel};
            $x = $image->Write( depth => 1, filename => $pnm );
        }
        else {
            $logger->info("writing temporary image $pnm");
            $image->Write( filename => $pnm );
        }
        return if $_self->{cancel};
    }
    else {
        $pnm = $page->{filename};
    }

    # Temporary filename for output
    my $txt = File::Temp->new( SUFFIX => '.txt' );

    # Using temporary txt file, as perl munges charset encoding
    # if text is passed by stdin/stdout
    exec_command( [ 'gocr', $pnm, '-o', $txt ], $pidfile );
    ( $page->{hocr}, undef ) = Gscan2pdf::Document::slurp($txt);

    return if $_self->{cancel};
    $page->{ocr_flag} = 1;              #FlagOCR
    $page->{ocr_time} = timestamp();    #remember when we ran OCR on this page
    $self->{return}->enqueue(
        {
            type => 'page',
            uuid => $uuid,
            page => $page,
            info => { replace => $page->{uuid} }
        }
    );
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'gocr',
            uuid    => $uuid,
        }
    );
    return;
}

sub _thread_unpaper {
    my ( $self, %options ) = @_;
    my $filename = $options{page}{filename};
    my $in;

    try {
        if ( $filename !~ /[.]pnm$/xsm ) {
            my $image = Image::Magick->new;
            my $e     = $image->Read($filename);
            if ("$e") {
                $logger->error($e);
                _thread_throw_error( $self, $options{uuid},
                    "Error reading $filename: $e." );
                return;
            }
            my $depth = $image->Get('depth');

            # Unfortunately, -depth doesn't seem to work here,
            # so forcing depth=1 using pbm extension.
            my $suffix = '.pbm';
            if ( $depth > 1 ) { $suffix = '.pnm' }

            # Temporary filename for new file
            $in = File::Temp->new(
                DIR    => $options{dir},
                SUFFIX => $suffix,
            );

            # FIXME: need to -compress Zip from perlmagick
            # "convert -compress Zip $self->{data}[$pagenum][2]{filename} $in;";
            $logger->debug("Converting $filename -> $in for unpaper");
            $image->Write( filename => $in );
        }
        else {
            $in = $filename;
        }

        my $out = File::Temp->new(
            DIR    => $options{dir},
            SUFFIX => '.pnm',
            UNLINK => FALSE
        );
        my $out2 = $EMPTY;
        if ( $options{options}{command} =~ /--output-pages[ ]2[ ]/xsm ) {
            $out2 = File::Temp->new(
                DIR    => $options{dir},
                SUFFIX => '.pnm',
                UNLINK => FALSE
            );
        }

        # --overwrite needed because $out exists with 0 size
        my @cmd = split $SPACE, sprintf "$options{options}{command}", $in,
          $out, $out2;
        ( undef, my $stdout, my $stderr ) =
          exec_command( \@cmd, $options{pidfile} );
        $logger->info($stdout);
        if ($stderr) {
            $logger->error($stderr);
            _thread_throw_error( $self, $options{uuid},
                "Error running unpaper: $stderr" );
            if ( not -s $out ) { return }
        }
        return if $_self->{cancel};

        $stdout =~ s/Processing[ ]sheet.*[.]pnm\n//xsm;
        if ($stdout) {
            $logger->warn($stdout);
            _thread_throw_error( $self, $options{uuid},
                "Warning running unpaper: $stdout" );
            if ( not -s $out ) { return }
        }

        if (    $options{options}{command} =~ /--output-pages[ ]2[ ]/xsm
            and defined $options{options}{direction}
            and $options{options}{direction} eq 'rtl' )
        {
            ( $out, $out2 ) = ( $out2, $out );
        }

        my $new = Gscan2pdf::Page->new(
            filename => $out,
            dir      => $options{dir},
            delete   => TRUE,
            format   => 'Portable anymap',
        );

        # unpaper doesn't change the resolution, so we can safely copy it
        if ( defined $options{page}{resolution} ) {
            $new->{resolution} = $options{page}{resolution};
        }

        # reuse uuid so that the process chain can find it again
        $new->{uuid}       = $options{page}{uuid};
        $new->{dirty_time} = timestamp();            #flag as dirty
        $self->{return}->enqueue(
            {
                type => 'page',
                uuid => $options{uuid},
                page => $new->freeze,
                info => { replace => $options{page}{uuid} }
            }
        );

        if ( $out2 ne $EMPTY ) {
            my $new2 = Gscan2pdf::Page->new(
                filename => $out2,
                dir      => $options{dir},
                delete   => TRUE,
                format   => 'Portable anymap',
            );

            # unpaper doesn't change the resolution, so we can safely copy it
            if ( defined $options{page}{resolution} ) {
                $new2->{resolution} = $options{page}{resolution};
            }

            $new2->{dirty_time} = timestamp();    #flag as dirty
            $self->{return}->enqueue(
                {
                    type => 'page',
                    uuid => $options{uuid},
                    page => $new2->freeze,
                    info => { 'insert-after' => $new->{uuid} }
                }
            );
        }
    }
    catch {
        $logger->error("Error creating file in $options{dir}: $_");
        _thread_throw_error( $self, $options{uuid},
            "Error creating file in $options{dir}: $_." );
    };
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'unpaper',
            uuid    => $options{uuid},
        }
    );
    return;
}

sub _thread_user_defined {
    my ( $self, %options ) = @_;
    my $in = $options{page}{filename};
    my $suffix;
    if ( $in =~ /([.]\w*)$/xsm ) {
        $suffix = $1;
    }
    try {
        my $out = File::Temp->new(
            DIR    => $options{dir},
            SUFFIX => $suffix,
            UNLINK => FALSE
        );

        if ( $options{command} =~ s/%o/$out/gxsm ) {
            $options{command} =~ s/%i/$in/gxsm;
        }
        else {
            if ( not copy( $in, $out ) ) {
                _thread_throw_error( $self, $options{uuid},
                    __('Error copying page') );
                return;
            }
            $options{command} =~ s/%i/$out/gxsm;
        }
        $options{command} =~ s/%r/$options{page}{resolution}/gxsm;
        exec_command( [ $options{command} ], $options{pidfile} );
        return if $_self->{cancel};

        # Get file type
        my $image = Image::Magick->new;
        my $e     = $image->Read($out);
        if ("$e") {
            $logger->error($e);
            _thread_throw_error( $self, $options{uuid},
                "Error reading $out: $e." );
            return;
        }

        my $new = Gscan2pdf::Page->new(
            filename => $out,
            dir      => $options{dir},
            delete   => TRUE,
            format   => $image->Get('format'),
        );

        # No way to tell what resolution a pnm is,
        # so assume it hasn't changed
        if ( $new->{format} =~ /Portable\s(:?any|bit|gray|pix)map/xsm ) {
            $new->{resolution} = $options{page}{resolution};
        }

        # reuse uuid so that the process chain can find it again
        $new->{uuid} = $options{page}{uuid};
        $self->{return}->enqueue(
            {
                type => 'page',
                uuid => $options{uuid},
                page => $new->freeze,
                info => { replace => $options{page}{uuid} }
            }
        );
    }
    catch {
        $logger->error("Error creating file in $options{dir}: $_");
        _thread_throw_error( $self, $options{uuid},
            "Error creating file in $options{dir}: $_." );
    };
    $self->{return}->enqueue(
        {
            type    => 'finished',
            process => 'user-defined',
            uuid    => $options{uuid},
        }
    );
    return;
}

sub _thread_paper_sizes {
    ( my $self, $paper_sizes ) = @_;
    return;
}

1;

__END__
