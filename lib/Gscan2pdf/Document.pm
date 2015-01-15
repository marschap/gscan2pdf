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
use Glib 1.210 qw(TRUE FALSE)
  ; # To get TRUE and FALSE. 1.210 necessary for Glib::SOURCE_REMOVE and Glib::SOURCE_CONTINUE
use Socket;
use FileHandle;
use Image::Magick;
use File::Temp;        # To create temporary files
use File::Basename;    # Split filename into dir, file, ext
use File::Copy;
use Storable qw(store retrieve);
use Archive::Tar;                    # For session files
use Proc::Killfam;
use Locale::gettext 1.05;            # For translations
use IPC::Open3 'open3';
use Symbol;                          # for gensym
use Try::Tiny;
use Set::IntSpan 1.10;               # For size method for page numbering issues
use PDF::API2;
use English qw( -no_match_vars );    # for $PROCESS_ID, $INPUT_RECORD_SEPARATOR
use Readonly;
Readonly our $POINTS_PER_INCH => 72;
Readonly my $_POLL_INTERVAL   => 100;    # ms
Readonly my $THUMBNAIL        => 100;    # pixels
Readonly my $YEAR             => 5;
Readonly my $BOX_TOLERANCE    => 5;

BEGIN {
    use Exporter ();
    our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

    $VERSION = '1.2.7';

    use base qw(Exporter Gtk2::Ex::Simple::List);
    %EXPORT_TAGS = ();                   # eg: TAG => [ qw!name1 name2! ],

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

my $_PID           = 0;      # flag to identify which process to cancel
my $jobs_completed = 0;
my $jobs_total     = 0;
my $EMPTY          = q{};
my $SPACE          = q{ };
my ( $_self, $d, $logger, $paper_sizes );

my %format = (
    'pnm' => 'Portable anymap',
    'ppm' => 'Portable pixmap format (color)',
    'pgm' => 'Portable graymap format (gray scale)',
    'pbm' => 'Portable bitmap format (black and white)',
);

sub setup {
    ( my $class, $logger ) = @_;
    $_self = {};
    $d     = Locale::gettext->domain(Glib::get_application_name);
    Gscan2pdf::Page->set_logger($logger);

    $_self->{requests}   = Thread::Queue->new;
    $_self->{info_queue} = Thread::Queue->new;
    $_self->{page_queue} = Thread::Queue->new;
    share $_self->{status};
    share $_self->{message};
    share $_self->{progress};
    share $_self->{process_name};
    share $_self->{cancel};

    $_self->{thread} = threads->new( \&_thread_main, $_self );
    return;
}

sub new {
    my ( $class, %options ) = @_;
    my $self = Gtk2::Ex::Simple::List->new(
        q{#}                  => 'int',
        $d->get('Thumbnails') => 'pixbuf',
        'Page Data'           => 'hstring',
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

# Flag the given process to cancel itself

sub cancel {
    my ( $self, $pid, $callback ) = @_;
    if ( defined $self->{running_pids}{$pid} ) {
        $self->{cancel_cb}{$pid} = $callback;
    }
    return;
}

sub get_file_info {
    my ( $self, %options ) = @_;

    # File in which to store the process ID
    # so that it can be killed if necessary
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
    if ( not defined $pidfile ) { return }

    my $sentinel =
      _enqueue_request( 'get-file-info',
        { path => $options{path}, pidfile => "$pidfile" } );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        pidfile            => $pidfile,
        info               => TRUE,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub import_file {
    my ( $self, %options ) = @_;

    # File in which to store the process ID
    # so that it can be killed if necessary
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
    if ( not defined $pidfile ) { return }
    my $dirname = $EMPTY;
    if ( defined $self->{dir} ) { $dirname = "$self->{dir}" }

    my $sentinel = _enqueue_request(
        'import-file',
        {
            info    => $options{info},
            first   => $options{first},
            last    => $options{last},
            dir     => $dirname,
            pidfile => "$pidfile"
        }
    );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        pidfile            => $pidfile,
        add                => $options{last} - $options{first} + 1,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub fetch_file {
    my ( $self, $n ) = @_;
    my $i = 0;
    if ($n) {
        while ( $i < $n ) {
            my $page = $_self->{page_queue}->dequeue;
            if ( ref($page) eq $EMPTY ) {
                $n = $page;
                return $self->fetch_file($n);
            }
            else {
                $self->add_page( $page->thaw );
                ++$i;
            }
        }
    }
    else {
        while ( defined( my $page = $_self->{page_queue}->dequeue_nb() ) ) {
            if ( ref($page) eq $EMPTY ) {
                $n = $page;
                return $self->fetch_file($n);
            }
            else {
                $self->add_page( $page->thaw );
                ++$i;
            }
        }
    }
    return $i;
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
        return -1;    ## no critic (ProhibitMagicNumbers)
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
            return -1      ## no critic (ProhibitMagicNumbers)
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

        # Current page doesn't exist, check for at least one more
        elsif ( $n == 0 ) {
            ++$n;
        }

        # Try one more page
        else {
            ++$n;
        }
    }
    return;
}

# Add a new page to the document

sub add_page {
    my ( $self, $page, $pagenum, $success_cb ) = @_;

    # Add to the page list
    if ( not defined $pagenum ) { $pagenum = $#{ $self->{data} } + 2 }

    # Block the row-changed signal whilst adding the scan (row) and sorting it.
    if ( defined $self->{row_changed_signal} ) {
        $self->get_model->signal_handler_block( $self->{row_changed_signal} );
    }
    my $thumb =
      get_pixbuf( $page->{filename}, $self->{heightt}, $self->{widtht} );
    my $resolution = $page->resolution($paper_sizes);
    push @{ $self->{data} }, [ $pagenum, $thumb, $page ];
    $logger->info(
        "Added $page->{filename} at page $pagenum with resolution $resolution");

# Block selection_changed_signal to prevent its firing changing pagerange to all
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

    my @page;

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

    if ($success_cb) { $success_cb->() }

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

 # Deep copy the tied data so we can sort it. Otherwise, very bad things happen.
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

sub save_pdf {
    my ( $self, %options ) = @_;

    for my $i ( 0 .. $#{ $options{list_of_pages} } ) {
        $options{list_of_pages}->[$i] =
          $options{list_of_pages}->[$i]
          ->freeze;    # sharing File::Temp objects causes problems
    }

   # File in which to store the process ID so that it can be killed if necessary
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
    if ( not defined $pidfile ) { return }

    my $sentinel = _enqueue_request(
        'save-pdf',
        {
            path          => $options{path},
            list_of_pages => $options{list_of_pages},
            metadata      => $options{metadata},
            options       => $options{options},
            dir           => "$self->{dir}",
            pidfile       => "$pidfile"
        }
    );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        pidfile            => $pidfile,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        finished_callback  => $options{finished_callback},
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
    my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

    my $sentinel = _enqueue_request(
        'save-djvu',
        {
            path          => $options{path},
            list_of_pages => $options{list_of_pages},
            metadata      => $options{metadata},
            dir           => "$self->{dir}",
            pidfile       => "$pidfile"
        }
    );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        pidfile            => $pidfile,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        finished_callback  => $options{finished_callback},
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
    my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

    my $sentinel = _enqueue_request(
        'save-tiff',
        {
            path          => $options{path},
            list_of_pages => $options{list_of_pages},
            options       => $options{options},
            ps            => $options{ps},
            dir           => "$self->{dir}",
            pidfile       => "$pidfile"
        }
    );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        pidfile            => $pidfile,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub rotate {
    my ( $self, %options ) = @_;

    my $sentinel = _enqueue_request(
        'rotate',
        {
            angle => $options{angle},
            page  => $options{page}->freeze,
            dir   => "$self->{dir}"
        }
    );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        update_slist       => TRUE,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        display_callback   => $options{display_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub update_page {
    my ( $self, $display_callback ) = @_;
    my (@out);
    my $data = $_self->{page_queue}->dequeue;

    # find old page
    my $i = 0;
    while ( $i <= $#{ $self->{data} }
        and $self->{data}[$i][2]{filename} ne $data->{old}{filename} )
    {
        $i++;
    }

    # if found, replace with new one
    if ( $i <= $#{ $self->{data} } ) {

# Move the temp file from the thread to a temp object that will be automatically cleared up
        my $new = $data->{new}->thaw;

        if ( defined $self->{row_changed_signal} ) {
            $self->get_model->signal_handler_block(
                $self->{row_changed_signal} );
        }
        my $resolution = $new->resolution($paper_sizes);
        $logger->info(
"Replaced $self->{data}[$i][2]->{filename} at page $self->{data}[$i][0] with $new->{filename}, resolution $resolution"
        );
        $self->{data}[$i][1] =
          get_pixbuf( $new->{filename}, $self->{heightt}, $self->{widtht} );
        $self->{data}[$i][2] = $new;
        push @out, $new;

        if ( defined $data->{new2} ) {
            $new = $data->{new2}->thaw;
            splice @{ $self->{data} }, $i + 1, 0,
              [
                $self->{data}[$i][0] + 1,
                get_pixbuf(
                    $new->{filename}, $self->{heightt}, $self->{widtht}
                ),
                $new
              ];
            $logger->info(
                "Inserted $new->{filename} at page ",
                $self->{data}[ $i + 1 ][0],
                " with  resolution $resolution"
            );
            push @out, $new;
        }

        if ( defined $self->{row_changed_signal} ) {
            $self->get_model->signal_handler_unblock(
                $self->{row_changed_signal} );
        }
        my @selected = $self->get_selected_indices;
        if ( @selected and $i == $selected[0] ) { $self->select(@selected) }
        if ($display_callback) { $display_callback->( $self->{data}[$i][2] ) }
    }

    return \@out;
}

sub save_image {
    my ( $self, %options ) = @_;

    for my $i ( 0 .. $#{ $options{list_of_pages} } ) {
        $options{list_of_pages}->[$i] =
          $options{list_of_pages}->[$i]
          ->freeze;    # sharing File::Temp objects causes problems
    }

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

    my $sentinel = _enqueue_request(
        'save-image',
        {
            path          => $options{path},
            list_of_pages => $options{list_of_pages},
            pidfile       => "$pidfile"
        }
    );
    return $self->_monitor_process(
        sentinel           => $sentinel,
        pidfile            => $pidfile,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub save_text {
    my ( $self, %options ) = @_;

    for my $i ( 0 .. $#{ $options{list_of_pages} } ) {
        $options{list_of_pages}->[$i] =
          $options{list_of_pages}->[$i]
          ->freeze;    # sharing File::Temp objects causes problems
    }
    my $sentinel = _enqueue_request(
        'save-text',
        {
            path          => $options{path},
            list_of_pages => $options{list_of_pages},
        }
    );
    return $self->_monitor_process(
        sentinel           => $sentinel,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub save_hocr {
    my ( $self, %options ) = @_;

    for my $i ( 0 .. $#{ $options{list_of_pages} } ) {
        $options{list_of_pages}->[$i] =
          $options{list_of_pages}->[$i]
          ->freeze;    # sharing File::Temp objects causes problems
    }
    my $sentinel = _enqueue_request(
        'save-hocr',
        {
            path          => $options{path},
            list_of_pages => $options{list_of_pages},
        }
    );
    return $self->_monitor_process(
        sentinel           => $sentinel,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub analyse {
    my ( $self, %options ) = @_;

    my $sentinel =
      _enqueue_request( 'analyse', { page => $options{page}->freeze } );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        update_slist       => TRUE,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub threshold {
    my ( $self, %options ) = @_;

    my $sentinel = _enqueue_request(
        'threshold',
        {
            threshold => $options{threshold},
            page      => $options{page}->freeze,
            dir       => "$self->{dir}"
        }
    );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        update_slist       => TRUE,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        display_callback   => $options{display_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub negate {
    my ( $self, %options ) = @_;

    my $sentinel =
      _enqueue_request( 'negate',
        { page => $options{page}->freeze, dir => "$self->{dir}" } );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        update_slist       => TRUE,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        display_callback   => $options{display_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub unsharp {
    my ( $self, %options ) = @_;

    my $sentinel = _enqueue_request(
        'unsharp',
        {
            page      => $options{page}->freeze,
            radius    => $options{radius},
            sigma     => $options{sigma},
            amount    => $options{amount},
            threshold => $options{threshold},
            dir       => "$self->{dir}",
        }
    );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        update_slist       => TRUE,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        display_callback   => $options{display_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub crop {
    my ( $self, %options ) = @_;

    my $sentinel = _enqueue_request(
        'crop',
        {
            page => $options{page}->freeze,
            x    => $options{x},
            y    => $options{y},
            w    => $options{w},
            h    => $options{h},
            dir  => "$self->{dir}",
        }
    );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        update_slist       => TRUE,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        display_callback   => $options{display_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub to_png {
    my ( $self, %options ) = @_;

    my $sentinel =
      _enqueue_request( 'to-png',
        { page => $options{page}->freeze, dir => "$self->{dir}" } );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        update_slist       => TRUE,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub tesseract {
    my ( $self, %options ) = @_;

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

    my $sentinel = _enqueue_request(
        'tesseract',
        {
            page      => $options{page}->freeze,
            language  => $options{language},
            threshold => $options{threshold},
            pidfile   => "$pidfile",
        }
    );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        update_slist       => TRUE,
        pidfile            => $pidfile,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        display_callback   => $options{display_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub ocropus {
    my ( $self, %options ) = @_;

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

    my $sentinel = _enqueue_request(
        'ocropus',
        {
            page      => $options{page}->freeze,
            language  => $options{language},
            threshold => $options{threshold},
            pidfile   => "$pidfile",
        }
    );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        update_slist       => TRUE,
        pidfile            => $pidfile,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        display_callback   => $options{display_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub cuneiform {
    my ( $self, %options ) = @_;

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

    my $sentinel = _enqueue_request(
        'cuneiform',
        {
            page      => $options{page}->freeze,
            language  => $options{language},
            threshold => $options{threshold},
            pidfile   => "$pidfile",
        }
    );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        update_slist       => TRUE,
        pidfile            => $pidfile,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        display_callback   => $options{display_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub gocr {
    my ( $self, %options ) = @_;

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

    my $sentinel = _enqueue_request(
        'gocr',
        {
            page      => $options{page}->freeze,
            threshold => $options{threshold},
            pidfile   => "$pidfile",
        }
    );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        update_slist       => TRUE,
        pidfile            => $pidfile,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        display_callback   => $options{display_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub unpaper {
    my ( $self, %options ) = @_;

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

    my $sentinel = _enqueue_request(
        'unpaper',
        {
            page    => $options{page}->freeze,
            options => $options{options},
            pidfile => "$pidfile",
            dir     => "$self->{dir}",
        }
    );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        update_slist       => TRUE,
        pidfile            => $pidfile,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        display_callback   => $options{display_callback},
        finished_callback  => $options{finished_callback},
    );
}

sub user_defined {
    my ( $self, %options ) = @_;

   # File in which to store the process ID so that it can be killed if necessary
    my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

    my $sentinel = _enqueue_request(
        'user-defined',
        {
            page    => $options{page}->freeze,
            command => $options{command},
            dir     => "$self->{dir}",
            pidfile => "$pidfile"
        }
    );

    return $self->_monitor_process(
        sentinel           => $sentinel,
        update_slist       => TRUE,
        pidfile            => $pidfile,
        queued_callback    => $options{queued_callback},
        started_callback   => $options{started_callback},
        running_callback   => $options{running_callback},
        error_callback     => $options{error_callback},
        cancelled_callback => $options{cancelled_callback},
        display_callback   => $options{display_callback},
        finished_callback  => $options{finished_callback},
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
    my ( $self, $filename, $error_callback ) = @_;
    if ( not defined $filename ) {
        if ($error_callback) {
            $error_callback->('Error: session file not supplied.');
        }
        return;
    }
    my $tar          = Archive::Tar->new( $filename, TRUE );
    my @filenamelist = $tar->list_files;
    my @sessionfile  = grep { /\/session$/xsm } @filenamelist;
    my $sesdir =
      File::Spec->catfile( $self->{dir}, dirname( $sessionfile[0] ) );
    for (@filenamelist) {
        $tar->extract_file( $_, File::Spec->catfile( $sesdir, basename($_) ) );
    }
    $self->open_session( $sesdir, TRUE, $error_callback );
    return;
}

sub open_session {
    my ( $self, $sesdir, $delete, $error_callback ) = @_;
    if ( not defined $sesdir ) {
        if ($error_callback) {
            $error_callback->('Error: session folder not defined');
        }
        return;
    }
    my $sessionfile = File::Spec->catfile( $sesdir, 'session' );
    if ( not -r $sessionfile ) {
        if ($error_callback) {
            $error_callback->("Error: Unable to read $sessionfile");
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
        $session{$pagenum}{delete} = $delete;

        # correct the path now that it is relative to the current session dir
        if ( $sesdir ne $self->{dir} ) {
            $session{$pagenum}{filename} =
              File::Spec->catfile( $sesdir,
                basename( $session{$pagenum}{filename} ) );
        }

        # Populate the SimpleList
        try {
            my $page = Gscan2pdf::Page->new( %{ $session{$pagenum} } );
            my $thumb =
              get_pixbuf( $page->{filename}, $self->{heightt},
                $self->{widtht} );
            push @{ $self->{data} }, [ $pagenum, $thumb, $page ];
        }
        catch {
            if ($error_callback) {
                $error_callback->(
                    sprintf $d->get('Error importing page %d. Ignoring.'),
                    $pagenum
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
    return;
}

# Check if $start and $step give duplicate page numbers

sub valid_renumber {
    my ( $self, $start, $step, $selection ) = @_;

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

    # Create a set from the current settings
    my $current = Set::IntSpan->new;
    for ( 0 .. $#selected ) { $current->insert( $start + $step * $_ ) }

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
            $error_callback->( $d->get('No pages to process') );
            return;
        }
    }
    elsif ( $page_range eq 'selected' ) {
        @index = $self->get_selected_indices;
        if ( @index == 0 ) {
            $error_callback->( $d->get('No pages selected') );
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

# Wrapper for open3
sub open_three {
    my ($cmd) = @_;

    # we create a symbol for the err because open3 will not do that for us
    my $err = gensym();
    open3( undef, my $reader, $err, $cmd );
    return ( slurp($reader), slurp($err) );
}

# Check that a command exists

sub check_command {
    my ($cmd) = @_;
    return system("which $cmd >/dev/null 2>/dev/null") == 0 ? TRUE : FALSE;
}

# Compute a timestamp

sub timestamp {
    my @time = localtime;

    # return a time which can be string-wise compared
    return sprintf '%04d%02d%02d%02d%02d%02d', reverse @time[ 0 .. $YEAR ];
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
    if ( $_self->{requests}->pending == 0 ) {
        $jobs_completed = 0;
        $jobs_total     = 0;
    }
    $jobs_total++;
    return \$sentinel;
}

sub _monitor_process {
    my ( $self, %options ) = @_;

    # Get new process ID
    my $pid = ++$_PID;
    $self->{running_pids}{$pid} = 1;

    if ( $options{queued_callback} ) {
        $options{queued_callback}->(
            process_name   => $_self->{process_name},
            jobs_completed => $jobs_completed,
            jobs_total     => $jobs_total
        );
    }

    Glib::Timeout->add(
        $_POLL_INTERVAL,
        sub {
            if ( ${ $options{sentinel} } == 2 ) {
                $jobs_completed++;
                $self->_monitor_process_finished_callback( $pid, \%options );
                return Glib::SOURCE_REMOVE;
            }
            elsif ( ${ $options{sentinel} } == 1 ) {
                $self->_monitor_process_running_callback( $pid, \%options );
                return Glib::SOURCE_CONTINUE;
            }
            return Glib::SOURCE_CONTINUE;
        }
    );
    return $pid;
}

sub _monitor_process_running_callback {
    my ( $self, $pid, $options ) = @_;
    if ( exists $self->{cancel_cb}{$pid} ) {
        if ( not defined( $self->{cancel_cb}{$pid} )
            or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
        {
            if ( defined $options->{pidfile} ) {
                _cancel_process( slurp( $options->{pidfile} ) );
            }
            else {
                _cancel_process();
            }
            if ( $options->{cancelled_callback} ) {
                $options->{cancelled_callback}->();
            }
            if ( $self->{cancel_cb}{$pid} ) { $self->{cancel_cb}{$pid}->() }

            # Flag that the callbacks have been done here
            # so they are not repeated here or in finished
            $self->{cancel_cb}{$pid} = 1;
            delete $self->{running_pids}{$pid};
        }
        return;
    }
    if ( $options->{add} ) { $self->fetch_file( $options->{add} ) }
    if ( $options->{started_callback} and not $options->{started_flag} ) {
        $options->{started_flag} = $options->{started_callback}->(
            1, $_self->{process_name},
            $jobs_completed, $jobs_total, $_self->{message}, $_self->{progress}
        );
    }
    if ( $options->{running_callback} ) {
        $options->{running_callback}->(
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
    my ( $self, $pid, $options ) = @_;
    if ( exists $self->{cancel_cb}{$pid} ) {
        if ( not defined( $self->{cancel_cb}{$pid} )
            or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
        {
            if ( defined $options->{pidfile} ) {
                _cancel_process( slurp( $options->{pidfile} ) );
            }
            else {
                _cancel_process();
            }
            if ( $options->{cancelled_callback} ) {
                $options->{cancelled_callback}->();
            }
            if ( $self->{cancel_cb}{$pid} ) { $self->{cancel_cb}{$pid}->() }
        }
        delete $self->{cancel_cb}{$pid};
        delete $self->{running_pids}{$pid};
        return;
    }
    if ( $options->{started_callback} and not $options->{started_flag} ) {
        $options->{started_callback}->();
    }
    if ( $_self->{status} ) {
        if ( $options->{error_callback} ) {
            $options->{error_callback}->( $_self->{message} );
        }
        return;
    }
    if ( $options->{add} ) { $options->{add} -= $self->fetch_file }
    my $data;
    if ( $options->{info} ) {
        $data = $_self->{info_queue}->dequeue;
    }
    elsif ( $options->{update_slist} ) {
        $data = $self->update_page( $options->{display_callback} );
    }
    if ( $options->{finished_callback} ) {
        $options->{finished_callback}->( $data, $_self->{requests}->pending );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
}

sub _cancel_process {
    my ($pid) = @_;

    # Empty process queue first to stop any new process from starting
    $logger->info('Emptying process queue');
    while ( $_self->{requests}->dequeue_nb ) { }

# Then send the thread a cancel signal to stop it going beyond the next break point
    $_self->{cancel} = TRUE;

    # Before killing any process running in the thread
    if ($pid) {
        $logger->info("Killing pid $pid");
        local $SIG{HUP} = 'IGNORE';
        killfam 'HUP', ($pid);
    }
    return;
}

sub _thread_main {
    my ($self) = @_;

    while ( my $request = $self->{requests}->dequeue ) {
        $self->{process_name} = $request->{action};
        undef $_self->{cancel};

        # Signal the sentinel that the request was started.
        ${ $request->{sentinel} }++;

        given ( $request->{action} ) {
            when ('analyse') {
                _thread_analyse( $self, $request->{page} );
            }

            when ('cancel') {
                _thread_cancel($self);
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
                );
            }

            when ('cuneiform') {
                _thread_cuneiform( $self, $request->{page},
                    $request->{language}, $request->{threshold},
                    $request->{pidfile} );
            }

            when ('get-file-info') {
                _thread_get_file_info( $self, $request->{path},
                    $request->{pidfile} );
            }

            when ('gocr') {
                _thread_gocr( $self, $request->{page}, $request->{threshold},
                    $request->{pidfile} );
            }

            when ('import-file') {
                _thread_import_file(
                    $self,
                    info    => $request->{info},
                    first   => $request->{first},
                    last    => $request->{last},
                    dir     => $request->{dir},
                    pidfile => $request->{pidfile}
                );
            }

            when ('negate') {
                _thread_negate( $self, $request->{page}, $request->{dir} );
            }

            when ('ocropus') {
                _thread_ocropus( $self, $request->{page}, $request->{language},
                    $request->{threshold}, $request->{pidfile} );
            }

            when ('paper_sizes') {
                _thread_paper_sizes( $self, $request->{paper_sizes} );
            }

            when ('quit') {
                last;
            }

            when ('rotate') {
                _thread_rotate( $self, $request->{angle}, $request->{page},
                    $request->{dir} );
            }

            when ('save-djvu') {
                _thread_save_djvu(
                    $self,
                    path          => $request->{path},
                    list_of_pages => $request->{list_of_pages},
                    metadata      => $request->{metadata},
                    dir           => $request->{dir},
                    pidfile       => $request->{pidfile}
                );
            }

            when ('save-hocr') {
                _thread_save_hocr( $self, $request->{path},
                    $request->{list_of_pages} );
            }

            when ('save-image') {
                _thread_save_image( $self, $request->{path},
                    $request->{list_of_pages},
                    $request->{pidfile} );
            }

            when ('save-pdf') {
                _thread_save_pdf(
                    $self,
                    path          => $request->{path},
                    list_of_pages => $request->{list_of_pages},
                    metadata      => $request->{metadata},
                    options       => $request->{options},
                    dir           => $request->{dir},
                    pidfile       => $request->{pidfile}
                );
            }

            when ('save-text') {
                _thread_save_text( $self, $request->{path},
                    $request->{list_of_pages} );
            }

            when ('save-tiff') {
                _thread_save_tiff(
                    $self,
                    path          => $request->{path},
                    list_of_pages => $request->{list_of_pages},
                    options       => $request->{options},
                    ps            => $request->{ps},
                    dir           => $request->{dir},
                    pidfile       => $request->{pidfile}
                );
            }

            when ('tesseract') {
                _thread_tesseract( $self, $request->{page},
                    $request->{language}, $request->{threshold},
                    $request->{pidfile} );
            }

            when ('threshold') {
                _thread_threshold( $self, $request->{threshold},
                    $request->{page}, $request->{dir} );
            }

            when ('to-png') {
                _thread_to_png( $self, $request->{page}, $request->{dir} );
            }

            when ('unpaper') {
                _thread_unpaper( $self, $request->{page}, $request->{options},
                    $request->{pidfile}, $request->{dir} );
            }

            when ('unsharp') {
                _thread_unsharp(
                    $self,
                    page      => $request->{page},
                    radius    => $request->{radius},
                    sigma     => $request->{sigma},
                    amount    => $request->{amount},
                    threshold => $request->{threshold},
                    dir       => $request->{dir},
                );
            }

            when ('user-defined') {
                _thread_user_defined(
                    $self,               $request->{page},
                    $request->{command}, $request->{dir},
                    $request->{pidfile}
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

sub _thread_get_file_info {
    my ( $self, $filename, $pidfile, %info ) = @_;

    $self->{status} = 0;
    if ( not -e $filename ) {
        $self->{status} = 1;
        $self->{message} = sprintf $d->get('File %s not found'), $filename;
        return;
    }

    $logger->info("Getting info for $filename");
    ( my $format, undef ) = open_three("file -b \"$filename\"");
    $logger->info($format);

    given ($format) {
        when (/gzip[ ]compressed[ ]data/xsm) {
            $info{path}   = $filename;
            $info{format} = 'session file';
            $self->{info_queue}->enqueue( \%info );
            return;
        }
        when (/DjVu/xsm) {

            # Dig out the number of pages
            my $cmd = "djvudump \"$filename\"";
            $logger->info($cmd);
            ( my $info, undef ) =
              open_three("echo $PROCESS_ID > $pidfile;$cmd");
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
                $self->{status} = 1;
                $self->{message} =
                  $d->get(
                    'Unknown DjVu file structure. Please contact the author.');
                return;
            }
            $info{ppi}   = \@ppi;
            $info{pages} = $pages;
            $info{path}  = $filename;
            $self->{info_queue}->enqueue( \%info );
            return;
        }
        when (/PDF[ ]document/xsm) {
            $format = 'Portable Document Format';
            my $cmd = "pdfinfo \"$filename\"";
            $logger->info($cmd);
            ( my $info, undef ) =
              open_three("echo $PROCESS_ID > $pidfile;$cmd");
            return if $_self->{cancel};
            $logger->info($info);
            my $pages = 1;
            if ( $info =~ /Pages:\s+(\d+)/xsm ) {
                $pages = $1;
            }
            $logger->info("$pages pages");
            $info{pages} = $pages;
        }
        when (/TIFF[ ]image[ ]data/xsm) {
            $format = 'Tagged Image File Format';
            my $cmd = "tiffinfo \"$filename\"";
            $logger->info($cmd);
            ( my $info, undef ) =
              open_three("echo $PROCESS_ID > $pidfile;$cmd");
            return if $_self->{cancel};
            $logger->info($info);

            # Count number of pages
            my $pages = () = $info =~ /TIFF[ ]Directory[ ]at[ ]offset/xsmg;
            $logger->info("$pages pages");
            $info{pages} = $pages;
        }
        default {

            # Get file type
            my $image = Image::Magick->new;
            my $x     = $image->Read($filename);
            return if $_self->{cancel};
            if ("$x") { $logger->warn($x) }

            $format = $image->Get('format');
            if ( not defined $format ) {
                $self->{status}  = 1;
                $self->{message} = sprintf
                  $d->get('%s is not a recognised image type'),
                  $filename;
                return;
            }
            $logger->info("Format $format");
            $info{pages} = 1;
        }
    }
    $info{format} = $format;
    $info{path}   = $filename;
    $self->{info_queue}->enqueue( \%info );
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
                      sprintf $d->get('Importing page %i of %i'),
                      $i, $options{last} - $options{first} + 1;

                    my ( $tif, $error );
                    try {
                        $tif = File::Temp->new(
                            DIR    => $options{dir},
                            SUFFIX => '.tif',
                            UNLINK => FALSE
                        );
                        my $cmd =
"ddjvu -format=tiff -page=$i \"$options{info}->{path}\" $tif";
                        $logger->info($cmd);
                        system "echo $PROCESS_ID > $options{pidfile};$cmd";
                    }
                    catch {
                        if ( defined $tif ) {
                            $logger->error("Caught error creating $tif: $_");
                            $self->{status} = 1;
                            $self->{message} =
                              "Error: unable to write to $tif.";
                        }
                        else {
                            $logger->error(
                                "Caught error writing to $options{dir}: $_");
                            $self->{status} = 1;
                            $self->{message} =
                              "Error: unable to write to $options{dir}.";
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
                    $self->{page_queue}->enqueue( $page->freeze );
                }
            }
        }
        when ('Portable Document Format') {

            # Extract images from PDF
            if ( $options{last} >= $options{first} and $options{first} > 0 ) {
                my $cmd =
"pdfimages -f $options{first} -l $options{last} \"$options{info}->{path}\" x";
                $logger->info($cmd);
                my $status = system "echo $PROCESS_ID > $options{pidfile};$cmd";
                return if $_self->{cancel};
                if ($status) {
                    $self->{status} = 1;
                    $self->{message} =
                      $d->get('Error extracting images from PDF');
                }

                # Import each image
                my @images = glob 'x-???.???';
                $self->{page_queue}->enqueue( $#images + 1 );
                foreach (@images) {
                    my ($ext) = /([^.]+)$/xsm;
                    try {
                        my $page = Gscan2pdf::Page->new(
                            filename => $_,
                            dir      => $options{dir},
                            delete   => TRUE,
                            format   => $format{$ext},
                        );
                        $self->{page_queue}
                          ->enqueue( $page->to_png($paper_sizes)->freeze );
                    }
                    catch {
                        $logger->error(
                            "Caught error extracting images from PDF: $_");
                        $self->{status} = 1;
                        $self->{message} =
                          $d->get('Error extracting images from PDF');
                    };
                }
            }
        }
        when ('Tagged Image File Format') {

            # Split the tiff into its pages and import them individually
            if ( $options{last} >= $options{first} and $options{first} > 0 ) {
                for my $i ( $options{first} - 1 .. $options{last} - 1 ) {
                    $self->{progress} =
                      $i / ( $options{last} - $options{first} + 1 );
                    $self->{message} =
                      sprintf $d->get('Importing page %i of %i'),
                      $i, $options{last} - $options{first} + 1;

                    my ( $tif, $error );
                    try {
                        $tif = File::Temp->new(
                            DIR    => $options{dir},
                            SUFFIX => '.tif',
                            UNLINK => FALSE
                        );
                        my $cmd = "tiffcp \"$options{info}->{path}\",$i $tif";
                        $logger->info($cmd);
                        system "echo $PROCESS_ID > $options{pidfile};$cmd";
                    }
                    catch {
                        if ( defined $tif ) {
                            $logger->error("Caught error creating $tif: $_");
                            $self->{status} = 1;
                            $self->{message} =
                              "Error: unable to write to $tif.";
                        }
                        else {
                            $logger->error(
                                "Caught error writing to $options{dir}: $_");
                            $self->{status} = 1;
                            $self->{message} =
                              "Error: unable to write to $options{dir}.";
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
                    $self->{page_queue}->enqueue( $page->freeze );
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
                $self->{page_queue}->enqueue( $page->freeze );
            }
            catch {
                $logger->error("Caught error writing to $options{dir}: $_");
                $self->{status}  = 1;
                $self->{message} = "Error: unable to write to $options{dir}.";
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
                $self->{page_queue}
                  ->enqueue( $page->to_png($paper_sizes)->freeze );
            }
            catch {
                $logger->error("Caught error writing to $options{dir}: $_");
                $self->{status}  = 1;
                $self->{message} = "Error: unable to write to $options{dir}.";
            };
        }
    }
    return;
}

# Perl-Critic is confused by @_ in finally{} See P::C bug #79138
sub _thread_save_pdf {    ## no critic (RequireArgUnpacking)
    my ( $self, %options ) = @_;

    my $pagenr = 0;
    my $ttfcache;

    # Create PDF with PDF::API2
    $self->{message} = $d->get('Setting up PDF');
    my $pdf = PDF::API2->new( -file => $options{path} );
    if ( defined $options{metadata} ) { $pdf->info( %{ $options{metadata} } ) }

    my $corecache = $pdf->corefont('Times-Roman');
    if ( defined $options{options}->{font} ) {
        $ttfcache = $pdf->ttfont( $options{options}->{font}, -unicodemap => 1 );
        $logger->info("Using $options{options}->{font} for non-ASCII text");
    }

    foreach my $pagedata ( @{ $options{list_of_pages} } ) {
        ++$pagenr;
        $self->{progress} = $pagenr / ( $#{ $options{list_of_pages} } + 2 );
        $self->{message} = sprintf $d->get('Saving page %i of %i'),
          $pagenr, $#{ $options{list_of_pages} } + 1;

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
                $pagedata->{compression} = 'lzw';
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

        my ( $format, $output_resolution );
        try {
            ( $filename, $format, $output_resolution ) =
              _convert_image_for_pdf( $self, $pagedata, $image, %options );
        }
        catch {
            $logger->error("Caught error converting image: $_");
            $self->{status}  = 1;
            $self->{message} = "Caught error converting image: $_.";
        };
        if ( $self->{status} ) { return }

        $logger->info(
            'Defining page at ',
            $w * $POINTS_PER_INCH,
            'pt x ', $h * $POINTS_PER_INCH, 'pt'
        );
        my $page = $pdf->page;
        $page->mediabox( $w * $POINTS_PER_INCH, $h * $POINTS_PER_INCH );

        _add_text_to_pdf( $page, $pagedata, $ttfcache, $corecache );

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
                when ('pnm') {
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
            $self->{status} = 1;
            $self->{message} =
              sprintf $d->get('Error creating PDF image object: %s'), $msg;
            return;
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
            $self->{status}  = 1;
            $self->{message} = sprintf $d->get(
                'Error embedding file image in %s format to PDF: %s'),
              $format, $_;
        };
        if ( $self->{status} ) { return }

        $logger->info("Added $filename at $output_resolution PPI");
        return if $_self->{cancel};
    }
    $self->{message} = $d->get('Closing PDF');
    $pdf->save;
    $pdf->end;
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
            my $cmd = "tiffcp -c $compression $filename $filename2";
            $logger->info($cmd);
            my $status =
              system "echo $PROCESS_ID > $options{pidfile};$cmd 2>$error";
            return if $_self->{cancel};
            if ($status) {
                my $output = slurp($error);
                $logger->info($output);
                $self->{status} = 1;
                $self->{message} =
                  sprintf $d->get('Error compressing image: %s'), $output;
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
    my ( $page, $data, $ttfcache, $corecache ) = @_;
    if ( defined( $data->{hocr} ) ) {
        my $h          = $data->{h};
        my $w          = $data->{w};
        my $resolution = $data->{resolution};

        $logger->info('Embedding OCR output behind image');
        my $font;
        my $text = $page->text;
        for my $box ( $data->boxes ) {
            my ( $x1, $y1, $x2, $y2 ) = @{ $box->{bbox} };
            my $txt = $box->{text};
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
    }
    return;
}

# Box is the same size as the page. We don't know the text position.
# Start at the top of the page (PDF coordinate system starts
# at the bottom left of the page)

sub _wrap_text_to_page {
    my ( $txt, $size, $text_box, $h, $w ) = @_;
    my $y = $h * $POINTS_PER_INCH - $size;
    foreach my $line ( split /\n/xsm, $txt ) {
        my $x = 0;

        # Add a word at a time in order to linewrap
        foreach my $word ( split $SPACE, $line ) {
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

sub _thread_save_djvu {
    my ( $self, %options ) = @_;

    my $page = 0;
    my @filelist;

    foreach my $pagedata ( @{ $options{list_of_pages} } ) {
        ++$page;
        $self->{progress} = $page / ( $#{ $options{list_of_pages} } + 2 );
        $self->{message} = sprintf $d->get('Writing page %i of %i'),
          $page, $#{ $options{list_of_pages} } + 1;

        my $filename = $pagedata->{filename};
        my $djvu = File::Temp->new( DIR => $options{dir}, SUFFIX => '.djvu' );

        # Check the image depth to decide what sort of compression to use
        my $image = Image::Magick->new;
        my $x     = $image->Read($filename);
        if ("$x") { $logger->warn($x) }
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
                $x = $image->Write( filename => $pnm );
                if ("$x") { $logger->warn($x) }
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
                $x = $image->Write( filename => $pbm );
                if ("$x") { $logger->warn($x) }
                $filename = $pbm;
            }
        }

        # Create the djvu
        my $cmd = sprintf "$compression -dpi %d $filename $djvu",
          $pagedata->{resolution};
        $logger->info($cmd);
        my ( $status, $size ) =
          ( system("echo $PROCESS_ID > $options{pidfile};$cmd"), -s "$djvu" )
          ;    # quotes needed to prevent -s clobbering File::Temp object
        return if $_self->{cancel};
        if ( $status != 0 or not $size ) {
            $self->{status}  = 1;
            $self->{message} = $d->get('Error writing DjVu');
            $logger->error(
"Error writing image for page $page of DjVu (process returned $status, image size $size)"
            );
            return;
        }
        push @filelist, $djvu;
        _add_text_to_djvu( $self, $djvu, $options{dir}, $pagedata );
    }
    $self->{progress} = 1;
    $self->{message}  = $d->get('Merging DjVu');
    my $cmd = "djvm -c '$options{path}' @filelist";
    $logger->info($cmd);
    my $status = system "echo $PROCESS_ID > $options{pidfile};$cmd";
    return if $_self->{cancel};
    if ($status) {
        $self->{status}  = 1;
        $self->{message} = $d->get('Error merging DjVu');
        $logger->error('Error merging DjVu');
    }
    _add_metadata_to_djvu( $self, $options{path}, $options{dir},
        $options{pidfile}, $options{metadata} );
    return;
}

sub _write_file {
    my ( $self, $fh, $filename, $data ) = @_;
    if ( not print {$fh} $data ) {
        $self->{status}  = 1;
        $self->{message} = sprintf $d->get("Can't write to file: %s"),
          $filename;
        $self->{status} = 1;
        return FALSE;
    }
    return TRUE;
}

# Add OCR to text layer

sub _add_text_to_djvu {
    my ( $self, $djvu, $dir, $pagedata ) = @_;
    if ( defined( $pagedata->{hocr} ) ) {

        # Get the size
        my $w          = $pagedata->{w};
        my $h          = $pagedata->{h};
        my $resolution = $pagedata->{resolution};

        # Open djvusedtxtfile
        my $djvusedtxtfile = File::Temp->new( DIR => $dir, SUFFIX => '.txt' );
        open my $fh, '>:encoding(UTF8)',    ## no critic (RequireBriefOpen)
          $djvusedtxtfile
          or croak( sprintf $d->get("Can't open file: %s"), $djvusedtxtfile );
        _write_file( $self, $fh, $djvusedtxtfile, "(page 0 0 $w $h\n" )
          or return;

        # Write the text boxes
        for my $box ( $pagedata->boxes ) {
            my ( $x1, $y1, $x2, $y2 ) = @{ $box->{bbox} };
            my $txt = $box->{text};
            if ( $x1 == 0 and $y1 == 0 and not defined $x2 ) {
                ( $x2, $y2 ) = ( $w * $resolution, $h * $resolution );
            }

            # Escape any inverted commas
            $txt =~ s/\\/\\\\/gxsm;
            $txt =~ s/"/\\\"/gxsm;
            printf {$fh} "\n(line %d %d %d %d \"%s\")", $x1, $h - $y2, $x2,
              $h - $y1, $txt;
        }
        _write_file( $self, $fh, $djvusedtxtfile, ')' ) or return;
        close $fh
          or croak( sprintf $d->get("Can't close file: %s"), $djvusedtxtfile );

        # Write djvusedtxtfile
        my $cmd = "djvused '$djvu' -e 'select 1; set-txt $djvusedtxtfile' -s";
        $logger->info($cmd);
        my $status = system "echo $PROCESS_ID > $pagedata->{pidfile};$cmd";
        return if $_self->{cancel};
        if ($status) {
            $self->{status}  = 1;
            $self->{message} = $d->get('Error adding text layer to DjVu');
            $logger->error(
                "Error adding text layer to DjVu page $pagedata->{page_number}"
            );
        }
    }
    return;
}

sub _add_metadata_to_djvu {
    my ( $self, $djvu, $dir, $pidfile, $metadata ) = @_;
    if ( $metadata and %{$metadata} ) {

        # Open djvusedmetafile
        my $djvusedmetafile = File::Temp->new( DIR => $dir, SUFFIX => '.txt' );
        open my $fh, '>:encoding(UTF8)',    ## no critic (RequireBriefOpen)
          $djvusedmetafile
          or croak( sprintf $d->get("Can't open file: %s"), $djvusedmetafile );
        _write_file( $self, $fh, $djvusedmetafile, "(metadata\n" )
          or return;

        # Write the metadata
        for my $key ( keys %{$metadata} ) {
            my $val = $metadata->{$key};

            # backslash-escape any double quotes and bashslashes
            $val =~ s/\\/\\\\/gxsm;
            $val =~ s/"/\\\"/gxsm;
            _write_file( $self, $fh, $djvusedmetafile, "$key \"$val\"\n" );
        }
        _write_file( $self, $fh, $djvusedmetafile, ')' ) or return;
        close $fh
          or croak( sprintf $d->get("Can't close file: %s"), $djvusedmetafile );

        # Write djvusedmetafile
        my $cmd = "djvused '$djvu' -e 'set-meta $djvusedmetafile' -s";
        $logger->info($cmd);
        my $status = system "echo $PROCESS_ID > $pidfile;$cmd";
        return if $_self->{cancel};
        if ($status) {
            $self->{status}  = 1;
            $self->{message} = $d->get('Error adding metadata to DjVu');
            $logger->error('Error adding metadata info to DjVu file');
        }
    }
    return;
}

sub _thread_save_tiff {
    my ( $self, %options ) = @_;

    my $page = 0;
    my @filelist;

    foreach my $pagedata ( @{ $options{list_of_pages} } ) {
        ++$page;
        $self->{progress} =
          ( $page - 1 ) / ( $#{ $options{list_of_pages} } + 2 );
        $self->{message} =
          sprintf $d->get('Converting image %i of %i to TIFF'),
          $page, $#{ $options{list_of_pages} } + 1;

        my $filename = $pagedata->{filename};
        if (
            $filename !~ /[.]tif/xsm
            or ( defined( $options{options}->{compression} )
                and $options{options}->{compression} eq 'jpeg' )
          )
        {
            my $tif = File::Temp->new( DIR => $options{dir}, SUFFIX => '.tif' );
            my $resolution = $pagedata->{resolution};

            # Convert to tiff
            my $depth = $EMPTY;
            if ( defined( $options{options}->{compression} )
                and $options{options}->{compression} eq 'jpeg' )
            {
                $depth = '-depth 8';
            }

            my $cmd =
"convert -units PixelsPerInch -density $resolution $depth $filename $tif";
            $logger->info($cmd);
            my $status = system "echo $PROCESS_ID > $options{pidfile};$cmd";
            return if $_self->{cancel};

            if ($status) {
                $self->{status}  = 1;
                $self->{message} = $d->get('Error writing TIFF');
                return;
            }
            $filename = $tif;
        }
        push @filelist, $filename;
    }

    my $compression = $EMPTY;
    if ( defined $options{options}->{compression} ) {
        $compression = "-c $options{options}->{compression}";
        if ( $compression eq 'jpeg' ) {
            $compression .= ":$options{options}->{quality}";
        }
    }

    # Create the tiff
    $self->{progress} = 1;
    $self->{message}  = $d->get('Concatenating TIFFs');
    my $rows = $EMPTY;
    if ( defined( $options{options}->{compression} )
        and $options{options}->{compression} eq 'jpeg' )
    {
        $rows = '-r 16';
    }
    my $cmd = "tiffcp $rows $compression @filelist '$options{path}'";
    $logger->info($cmd);
    my $out = File::Temp->new( DIR => $options{dir}, SUFFIX => '.stdout' );
    my $status = system "echo $PROCESS_ID > $options{pidfile};$cmd 2>$out";
    return if $_self->{cancel};

    if ($status) {
        my $output = slurp($out);
        $logger->info($output);
        $self->{status}  = 1;
        $self->{message} = sprintf $d->get('Error compressing image: %s'),
          $output;
        return;
    }
    if ( defined $options{ps} ) {
        $self->{message} = $d->get('Converting to PS');

        # Note: -a option causes tiff2ps to generate multiple output
        # pages, one for each page in the input TIFF file.  Without it, it
        # only generates output for the first page.
        $cmd = "tiff2ps -a $options{path} > '$options{ps}'";
        $logger->info($cmd);
        ( my $output, undef ) = open_three($cmd);
    }
    return;
}

sub _thread_rotate {
    my ( $self, $angle, $page, $dir ) = @_;
    my $filename = $page->{filename};
    $logger->info("Rotating $filename by $angle degrees");

    # Rotate with imagemagick
    my $image = Image::Magick->new;
    my $x     = $image->Read($filename);
    return if $_self->{cancel};
    if ("$x") { $logger->warn($x) }

    # workaround for those versions of imagemagick that produce 16bit output
    # with rotate
    my $depth = $image->Get('depth');
    $x = $image->Rotate($angle);
    return if $_self->{cancel};
    if ("$x") { $logger->warn($x) }
    my $suffix;
    if ( $filename =~ /[.](\w*)$/xsm ) {
        $suffix = $1;
    }
    $filename = File::Temp->new(
        DIR    => $dir,
        SUFFIX => ".$suffix",
        UNLINK => FALSE
    );
    $x = $image->Write( filename => $filename, depth => $depth );
    return if $_self->{cancel};
    if ("$x") { $logger->warn($x) }
    my $new = $page->freeze;
    $new->{filename}   = $filename->filename;   # can't queue File::Temp objects
    $new->{dirty_time} = timestamp();           #flag as dirty
    my %data = ( old => $page, new => $new );
    $self->{page_queue}->enqueue( \%data );
    return;
}

sub _thread_save_image {
    my ( $self, $path, $list_of_pages, $pidfile ) = @_;

    # Escape quotes and spaces
    $path =~ s/(['" ])/\\$1/gxsm;

    if ( @{$list_of_pages} == 1 ) {
        my $cmd =
"convert $list_of_pages->[0]{filename} -density $list_of_pages->[0]{resolution} $path";
        $logger->info($cmd);
        my $status = system "echo $PROCESS_ID > $pidfile;$cmd";
        return if $_self->{cancel};
        if ($status) {
            $self->{status}  = 1;
            $self->{message} = $d->get('Error saving image');
        }
    }
    else {
        my $current_filename;
        my $i = 1;
        foreach ( @{$list_of_pages} ) {
            $current_filename = sprintf $path, $i++;
            my $cmd = sprintf 'convert %s -density %d %s',
              $_->{filename}, $_->{resolution},
              $current_filename;
            my $status = system "echo $PROCESS_ID > $pidfile;$cmd";
            return if $_self->{cancel};
            if ($status) {
                $self->{status}  = 1;
                $self->{message} = $d->get('Error saving image');
            }
        }
    }
    return;
}

sub _thread_save_text {
    my ( $self, $path, $list_of_pages, $fh ) = @_;

    if ( not open $fh, '>', $path ) {    ## no critic (RequireBriefOpen)
        $self->{status} = 1;
        $self->{message} = sprintf $d->get("Can't open file: %s"), $path;
        return;
    }
    for my $page ( @{$list_of_pages} ) {

        # Note y value to be able to put line breaks
        # at appropriate positions
        my ( $oldx, $oldy );
        for my $box ( $page->boxes ) {
            my ( $x1, $y1, $x2, $y2 ) = @{ $box->{bbox} };
            my $text = $box->{text};
            if ( defined $oldx and $x1 > $oldx ) {
                _write_file( $self, $fh, $path, $SPACE ) or return;
            }
            if ( defined $oldy and $y1 > $oldy ) {
                _write_file( $self, $fh, $path, "\n" ) or return;
            }
            ( $oldx, $oldy ) = ( $x1, $y1 );
            _write_file( $self, $fh, $path, $text ) or return;
        }
        return if $_self->{cancel};
    }
    if ( not close $fh ) {
        $self->{status} = 1;
        $self->{message} = sprintf $d->get("Can't close file: %s"), $path;
    }
    return;
}

sub _thread_save_hocr {
    my ( $self, $path, $list_of_pages, $fh ) = @_;

    if ( not open $fh, '>', $path ) {    ## no critic (RequireBriefOpen)
        $self->{status} = 1;
        $self->{message} = sprintf $d->get("Can't open file: %s"), $path;
        return;
    }
    foreach ( @{$list_of_pages} ) {
        if ( $_->{hocr} =~ /<body>([\s\S]*)<\/body>/xsm ) {
            _write_file( $self, $fh, $path, $_->{hocr} ) or return;
            return if $_self->{cancel};
        }
    }
    if ( not close $fh ) {
        $self->{status} = 1;
        $self->{message} = sprintf $d->get("Can't close file: %s"), $path;
    }
    return;
}

sub _thread_analyse {
    my ( $self, $page ) = @_;

    # Identify with imagemagick
    my $image = Image::Magick->new;
    my $x     = $image->Read( $page->{filename} );
    return if $_self->{cancel};
    if ("$x") { $logger->warn($x) }

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

    my $new = $page->clone;
    $new->{mean}         = $mean;
    $new->{std_dev}      = $stddev;
    $new->{analyse_time} = timestamp();
    my %data = ( old => $page, new => $new );
    $self->{page_queue}->enqueue( \%data );
    return;
}

sub _thread_threshold {
    my ( $self, $threshold, $page, $dir ) = @_;
    my $filename = $page->{filename};

    my $image = Image::Magick->new;
    my $x     = $image->Read($filename);
    return if $_self->{cancel};
    if ("$x") { $logger->warn($x) }

    # Threshold the image
    $image->BlackThreshold( threshold => "$threshold%" );
    return if $_self->{cancel};
    $image->WhiteThreshold( threshold => "$threshold%" );
    return if $_self->{cancel};

    # Write it
    $filename =
      File::Temp->new( DIR => $dir, SUFFIX => '.pbm', UNLINK => FALSE );
    $x = $image->Write( filename => $filename );
    return if $_self->{cancel};
    if ("$x") { $logger->warn($x) }

    my $new = $page->freeze;
    $new->{filename}   = $filename->filename;   # can't queue File::Temp objects
    $new->{dirty_time} = timestamp();           #flag as dirty
    my %data = ( old => $page, new => $new );
    $self->{page_queue}->enqueue( \%data );
    return;
}

sub _thread_negate {
    my ( $self, $page, $dir ) = @_;
    my $filename = $page->{filename};

    my $image = Image::Magick->new;
    my $x     = $image->Read($filename);
    return if $_self->{cancel};
    if ("$x") { $logger->warn($x) }

    my $depth = $image->Get('depth');

    # Negate the image
    $image->Negate;
    return if $_self->{cancel};

    # Write it
    my $suffix;
    if ( $filename =~ /([.]\w*)$/xsm ) {
        $suffix = $1;
    }
    $filename =
      File::Temp->new( DIR => $dir, SUFFIX => $suffix, UNLINK => FALSE );
    $x = $image->Write( depth => $depth, filename => $filename );
    return if $_self->{cancel};
    if ("$x") { $logger->warn($x) }
    $logger->info("Negating to $filename");

    my $new = $page->freeze;
    $new->{filename}   = $filename->filename;   # can't queue File::Temp objects
    $new->{dirty_time} = timestamp();           #flag as dirty
    my %data = ( old => $page, new => $new );
    $self->{page_queue}->enqueue( \%data );
    return;
}

sub _thread_unsharp {
    my ( $self, %options ) = @_;
    my $filename = $options{page}->{filename};

    my $image = Image::Magick->new;
    my $x     = $image->Read($filename);
    return if $_self->{cancel};
    if ("$x") { $logger->warn($x) }

    # Unsharp the image
    $image->UnsharpMask(
        radius    => $options{radius},
        sigma     => $options{sigma},
        amount    => $options{amount},
        threshold => $options{threshold},
    );
    return if $_self->{cancel};

    # Write it
    my $suffix;
    if ( $filename =~ /[.](\w*)$/xsm ) {
        $suffix = $1;
    }
    $filename = File::Temp->new(
        DIR    => $options{dir},
        SUFFIX => ".$suffix",
        UNLINK => FALSE
    );
    $x = $image->Write( filename => $filename );
    return if $_self->{cancel};
    if ("$x") { $logger->warn($x) }
    $logger->info(
"Wrote $filename with unsharp mask: r=$options{radius}, s=$options{sigma}, a=$options{amount}, t=$options{threshold}"
    );

    my $new = $options{page}->freeze;
    $new->{filename}   = $filename->filename;   # can't queue File::Temp objects
    $new->{dirty_time} = timestamp();           #flag as dirty
    my %data = ( old => $options{page}, new => $new );
    $self->{page_queue}->enqueue( \%data );
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
    $image->Set( page => '0x0+0+0' );
    return if $_self->{cancel};
    if ("$e") { $logger->warn($e) }

    # Write it
    my $suffix;
    if ( $filename =~ /[.](\w*)$/xsm ) {
        $suffix = $1;
    }
    $filename = File::Temp->new(
        DIR    => $options{dir},
        SUFFIX => ".$suffix",
        UNLINK => FALSE
    );
    $logger->info(
"Cropping $options{w} x $options{h} + $options{x} + $options{y} to $filename"
    );
    $e = $image->Write( filename => $filename );
    return if $_self->{cancel};
    if ("$e") { $logger->warn($e) }

    my $new = $options{page}->freeze;
    $new->{filename}   = $filename->filename;   # can't queue File::Temp objects
    $new->{dirty_time} = timestamp();           #flag as dirty
    my %data = ( old => $options{page}, new => $new );
    $self->{page_queue}->enqueue( \%data );
    return;
}

sub _thread_to_png {
    my ( $self, $page, $dir ) = @_;
    my $new = $page->to_png($paper_sizes);
    return if $_self->{cancel};
    my %data = ( old => $page, new => $new->freeze );
    $logger->info("Converted $page->{filename} to $data{new}{filename}");
    $self->{page_queue}->enqueue( \%data );
    return;
}

sub _thread_tesseract {
    my ( $self, $page, $language, $threshold, $pidfile ) = @_;
    my $new = $page->clone;
    ( $new->{hocr}, $new->{warnings} ) = Gscan2pdf::Tesseract->hocr(
        file      => $page->{filename},
        language  => $language,
        logger    => $logger,
        threshold => $threshold,
        pidfile   => $pidfile
    );
    return if $_self->{cancel};
    $new->{ocr_flag} = 1;              #FlagOCR
    $new->{ocr_time} = timestamp();    #remember when we ran OCR on this page
    my %data = ( old => $page, new => $new );
    $self->{page_queue}->enqueue( \%data );
    return;
}

sub _thread_ocropus {
    my ( $self, $page, $language, $threshold, $pidfile ) = @_;
    my $new = $page->clone;
    $new->{hocr} = Gscan2pdf::Ocropus->hocr(
        file      => $page->{filename},
        language  => $language,
        logger    => $logger,
        pidfile   => $pidfile,
        threshold => $threshold
    );
    return if $_self->{cancel};
    $new->{ocr_flag} = 1;              #FlagOCR
    $new->{ocr_time} = timestamp();    #remember when we ran OCR on this page
    my %data = ( old => $page, new => $new );
    $self->{page_queue}->enqueue( \%data );
    return;
}

sub _thread_cuneiform {
    my ( $self, $page, $language, $threshold, $pidfile ) = @_;
    my $new = $page->clone;
    $new->{hocr} = Gscan2pdf::Cuneiform->hocr(
        file      => $page->{filename},
        language  => $language,
        logger    => $logger,
        pidfile   => $pidfile,
        threshold => $threshold
    );
    return if $_self->{cancel};
    $new->{ocr_flag} = 1;              #FlagOCR
    $new->{ocr_time} = timestamp();    #remember when we ran OCR on this page
    my %data = ( old => $page, new => $new );
    $self->{page_queue}->enqueue( \%data );
    return;
}

sub _thread_gocr {
    my ( $self, $page, $threshold, $pidfile ) = @_;
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

    my $new = $page->clone;

    # Temporary filename for output
    my $txt = File::Temp->new( SUFFIX => '.txt' );

    # Using temporary txt file, as perl munges charset encoding
    # if text is passed by stdin/stdout
    my $cmd = "gocr $pnm -o $txt";
    $logger->info($cmd);
    system "echo $PROCESS_ID > $pidfile;$cmd";
    ( $new->{hocr}, undef ) = Gscan2pdf::Document::slurp($txt);

    return if $_self->{cancel};
    $new->{ocr_flag} = 1;              #FlagOCR
    $new->{ocr_time} = timestamp();    #remember when we ran OCR on this page
    my %data = ( old => $page, new => $new );
    $self->{page_queue}->enqueue( \%data );
    return;
}

sub _thread_unpaper {
    my ( $self, $page, $options, $pidfile, $dir ) = @_;
    my $filename = $page->{filename};
    my $in;

    if ( $filename !~ /[.]pnm$/xsm ) {
        my $image = Image::Magick->new;
        my $x     = $image->Read($filename);
        if ("$x") { $logger->warn($x) }
        my $depth = $image->Get('depth');

# Unfortunately, -depth doesn't seem to work here, so forcing depth=1 using pbm extension.
        my $suffix = '.pbm';
        if ( $depth > 1 ) { $suffix = '.pnm' }

        # Temporary filename for new file
        $in = File::Temp->new(
            DIR    => $dir,
            SUFFIX => $suffix,
        );

# FIXME: need to -compress Zip from perlmagick       "convert -compress Zip $slist->{data}[$pagenum][2]{filename} $in;";
        $image->Write( filename => $in );
    }
    else {
        $in = $filename;
    }

    my $out = File::Temp->new(
        DIR    => $dir,
        SUFFIX => '.pnm',
        UNLINK => FALSE
    );
    my $out2 = $EMPTY;
    if ( $options =~ /--output-pages[ ]2[ ]/xsm ) {
        $out2 = File::Temp->new(
            DIR    => $dir,
            SUFFIX => '.pnm',
            UNLINK => FALSE
        );
    }

    # --overwrite needed because $out exists with 0 size
    my $cmd = sprintf "$options;", $in, $out, $out2;
    $logger->info($cmd);
    ( my $info, undef ) = open_three("echo $PROCESS_ID > $pidfile;$cmd");
    $logger->info($info);
    return if $_self->{cancel};

    my $new = Gscan2pdf::Page->new(
        filename => $out,
        dir      => $dir,
        delete   => TRUE,
        format   => 'Portable anymap',
    );

    # unpaper doesn't change the resolution, so we can safely copy it
    if ( defined $page->{resolution} ) {
        $new->{resolution} = $page->{resolution};
    }

    $new->{dirty_time} = timestamp();    #flag as dirty
    my %data = ( old => $page, new => $new->freeze );
    if ( $out2 ne $EMPTY ) {
        my $new2 = Gscan2pdf::Page->new(
            filename => $out2,
            dir      => $dir,
            delete   => TRUE,
            format   => 'Portable anymap',
        );

        # unpaper doesn't change the resolution, so we can safely copy it
        if ( defined $page->{resolution} ) {
            $new2->{resolution} = $page->{resolution};
        }

        $new2->{dirty_time} = timestamp();    #flag as dirty
        $data{new2} = $new2->freeze;
    }
    $self->{page_queue}->enqueue( \%data );
    return;
}

sub _thread_user_defined {
    my ( $self, $page, $cmd, $dir, $pidfile ) = @_;
    my $in = $page->{filename};
    my $suffix;
    if ( $in =~ /([.]\w*)$/xsm ) {
        $suffix = $1;
    }
    my $out = File::Temp->new(
        DIR    => $dir,
        SUFFIX => $suffix,
        UNLINK => FALSE
    );

    if ( $cmd =~ s/%o/$out/gxsm ) {
        $cmd =~ s/%i/$in/gxsm;
    }
    else {
        if ( not copy( $in, $out ) ) {
            $self->{status}  = 1;
            $self->{message} = $d->get('Error copying page');
            $d->get('Error copying page');
            return;
        }
        $cmd =~ s/%i/$out/gxsm;
    }
    $cmd =~ s/%r/$page->{resolution}/gxsm;
    $logger->info($cmd);
    system "echo $PROCESS_ID > $pidfile;$cmd";
    return if $_self->{cancel};

    # Get file type
    my $image = Image::Magick->new;
    my $x     = $image->Read($out);
    if ("$x") { $logger->warn($x) }

    my $new = Gscan2pdf::Page->new(
        filename => $out,
        dir      => $dir,
        delete   => TRUE,
        format   => $image->Get('format'),
    );
    my %data = ( old => $page, new => $new->freeze );
    $self->{page_queue}->enqueue( \%data );
    return;
}

sub _thread_paper_sizes {
    ( my $self, $paper_sizes ) = @_;
    return;
}

1;

__END__
