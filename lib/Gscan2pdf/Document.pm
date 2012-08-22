package Gscan2pdf::Document;

use strict;
use warnings;
use feature "switch";

use threads;
use threads::shared;
use Thread::Queue;

use Gtk2::Ex::Simple::List;
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
use Archive::Tar;            # For session files
use Proc::Killfam;
use Locale::gettext 1.05;    # For translations
use IPC::Open3 'open3';
use Symbol;                  # for gensym
use Try::Tiny;
use Readonly;
Readonly our $POINTS_PER_INCH => 72;

BEGIN {
 use Exporter ();
 our ( $VERSION, @ISA, @EXPORT_OK, %EXPORT_TAGS );

 @ISA = qw(Exporter Gtk2::Ex::Simple::List);
 %EXPORT_TAGS = ();          # eg: TAG => [ qw!name1 name2! ],

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

my $_POLL_INTERVAL = 100;    # ms
my $_PID           = 0;      # flag to identify which process to cancel

my $jobs_completed = 0;
my $jobs_total     = 0;
my ( $_self, $d, $logger, $paper_sizes );

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
 share $_self->{dir};
 share $_self->{cancel};

 $_self->{thread} = threads->new( \&_thread_main, $_self );
 return;
}

sub new {
 my ( $class, %options ) = @_;
 my $self = Gtk2::Ex::Simple::List->new(
  '#'                   => 'int',
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
 $self->{heightt} = 100 unless ( defined $self->{heightt} );
 $self->{widtht}  = 100 unless ( defined $self->{widtht} );

 bless( $self, $class );
 return $self;
}

sub set_paper_sizes {
 ( my $class, $paper_sizes ) = @_;
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
 $self->{cancel_cb}{$pid} = $callback
   if ( defined $self->{running_pids}{$pid} );
 return;
}

sub get_file_info {
 my ( $self, %options ) = @_;

# File in which to store the subprocess ID so that it can be killed if necessary
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel =
   _enqueue_request( 'get-file-info',
  { path => $options{path}, pid => "$pidfile" } );

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

 # File in which to store the process ID so that it can be killed if necessary
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel = _enqueue_request(
  'import-file',
  {
   info  => $options{info},
   first => $options{first},
   last  => $options{last},
   pid   => "$pidfile"
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
   $self->add_page( $page->thaw );
   ++$i;
  }
 }
 elsif ( defined( my $page = $_self->{page_queue}->dequeue_nb() ) ) {
  $self->add_page( $page->thaw );
  ++$i;
 }
 return $i;
}

sub get_resolution {
 my $image = shift;
 my $resolution;
 my $format = $image->Get('format');

 # Imagemagick always reports PNMs as 72ppi
 if ( $format ne 'Portable anymap' ) {
  $resolution = $image->Get('x-resolution');
  return $resolution if ($resolution);

  $resolution = $image->Get('y-resolution');
  return $resolution if ($resolution);
 }

 # Guess the resolution from the shape
 my $height = $image->Get('height');
 my $width  = $image->Get('width');
 my $ratio  = $height / $width;
 $ratio = 1 / $ratio if ( $ratio < 1 );
 $resolution = $POINTS_PER_INCH;

 # FIXME: add test to make sure this is working
 for ( keys %$paper_sizes ) {
  if ( $paper_sizes->{$_}{x} > 0
   and abs( $ratio - $paper_sizes->{$_}{y} / $paper_sizes->{$_}{x} ) < 0.02 )
  {
   $resolution = int(
    ( ( $height > $width ) ? $height : $width ) / $paper_sizes->{$_}{y} * 25.4 +
      0.5 );
  }
 }
 return $resolution;
}

# Check how many pages could be scanned

sub pages_possible {
 my ( $self, $start, $step ) = @_;
 my $n = 0;
 my $i = $#{ $self->{data} };
 while (TRUE) {

  # Settings take us into negative page range
  if ( $start + $n * $step < 1 ) {    ## no critic (ProhibitCascadingIfElse)
   return $n;
  }

  # Empty document and negative step
  elsif ( $i < 0 and $step < 0 ) {
   return -$start / $step;
  }

  # Checked beyond end of document, allow infinite pages
  elsif ( $i > $#{ $self->{data} } or $i < 0 ) {
   return -1;
  }

  # Found existing page
  elsif ( $self->{data}[$i][0] == $start + $n * $step ) {
   return $n;
  }

  # Current page doesn't exist, check for at least one more
  elsif ( $n == 0 ) {
   ++$n;
  }

  # In the middle of the document, scan back to find page nearer start
  elsif ( $self->{data}[$i][0] > $start + $n * $step and $i > 0 ) {
   --$i;
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
 $pagenum = $#{ $self->{data} } + 2 if ( not defined($pagenum) );

 # Block the row-changed signal whilst adding the scan (row) and sorting it.
 $self->get_model->signal_handler_block( $self->{row_changed_signal} )
   if defined( $self->{row_changed_signal} );
 my $thumb = get_pixbuf( $page->{filename}, $self->{heightt}, $self->{widtht} );
 push @{ $self->{data} }, [ $pagenum, $thumb, $page ];
 $logger->info(
  "Added $page->{filename} at page $pagenum with resolution $page->{resolution}"
 );

# Block selection_changed_signal to prevent its firing changing pagerange to all
 $self->get_selection->signal_handler_block( $self->{selection_changed_signal} )
   if defined( $self->{selection_changed_signal} );
 $self->get_selection->unselect_all;
 $self->manual_sort_by_column(0);
 $self->get_selection->signal_handler_unblock(
  $self->{selection_changed_signal} )
   if defined( $self->{selection_changed_signal} );
 $self->get_model->signal_handler_unblock( $self->{row_changed_signal} )
   if defined( $self->{row_changed_signal} );

 my @page;

 # Due to the sort, must search for new page
 $page[0] = 0;

 # $page[0] < $#{$self -> {data}} needed to prevent infinite loop in case of
 # error importing.
 ++$page[0]
   while ( $page[0] < $#{ $self->{data} }
  and $self->{data}[ $page[0] ][0] != $pagenum );

 $self->select(@page);

 $success_cb->() if ($success_cb);

 return $page[0];
}

# Helpers:
sub compare_numeric_col { $_[0] <=> $_[1] }    ## no critic
sub compare_text_col    { $_[0] cmp $_[1] }    ## no critic

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
 my @data = map { [@$_] } @{ $self->{data} };
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
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel = _enqueue_request(
  'save-pdf',
  {
   path          => $options{path},
   list_of_pages => $options{list_of_pages},
   metadata      => $options{metadata},
   options       => $options{options},
   pid           => "$pidfile"
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
   pid           => "$pidfile"
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
   pid           => "$pidfile"
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

 my $sentinel =
   _enqueue_request( 'rotate',
  { angle => $options{angle}, page => $options{page}->freeze } );

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
 $i++
   while ( $i <= $#{ $self->{data} }
  and $self->{data}[$i][2]{filename} ne $data->{old}{filename} );

 # if found, replace with new one
 if ( $i <= $#{ $self->{data} } ) {

# Move the temp file from the thread to a temp object that will be automatically cleared up
  my $new = $data->{new}->thaw;

  $self->get_model->signal_handler_block( $self->{row_changed_signal} )
    if defined( $self->{row_changed_signal} );
  $self->{data}[$i][1] =
    get_pixbuf( $new->{filename}, $self->{heightt}, $self->{widtht} );
  $self->{data}[$i][2] = $new;
  push @out, $new;

  if ( defined $data->{new2} ) {
   $new = $data->{new2}->thaw;
   splice @{ $self->{data} }, $i + 1, 0,
     [
    $self->{data}[$i][0] + 1,
    get_pixbuf( $new->{filename}, $self->{heightt}, $self->{widtht} ), $new
     ];
   push @out, $new;
  }

  $self->get_model->signal_handler_unblock( $self->{row_changed_signal} )
    if defined( $self->{row_changed_signal} );
  my @selected = $self->get_selected_indices;
  $self->select(@selected) if ( @selected and $i == $selected[0] );
  $display_callback->( $self->{data}[$i][2] ) if ($display_callback);
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
   pid           => "$pidfile"
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

 my $sentinel =
   _enqueue_request( 'threshold',
  { threshold => $options{threshold}, page => $options{page}->freeze } );

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
   _enqueue_request( 'negate', { page => $options{page}->freeze } );

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
   threshold => $options{threshold}
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
   h    => $options{h}
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
   _enqueue_request( 'to-png', { page => $options{page}->freeze } );

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
   page     => $options{page}->freeze,
   language => $options{language},
   pid      => "$pidfile"
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
   page     => $options{page}->freeze,
   language => $options{language},
   pid      => "$pidfile"
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
   page     => $options{page}->freeze,
   language => $options{language},
   pid      => "$pidfile"
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

 my $sentinel =
   _enqueue_request( 'gocr',
  { page => $options{page}->freeze, pid => "$pidfile" } );

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
   pid     => "$pidfile"
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
   pid     => "$pidfile"
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
 my ( $self, $dir, $filename ) = @_;

 my ( %session, @filenamelist );
 for my $i ( 0 .. $#{ $self->{data} } ) {
  $session{ $self->{data}[$i][0] }{filename} =
    $self->{data}[$i][2]{filename}->filename;
  push @filenamelist, $self->{data}[$i][2]{filename}->filename;
  for my $key ( keys( %{ $self->{data}[$i][2] } ) ) {
   $session{ $self->{data}[$i][0] }{$key} = $self->{data}[$i][2]{$key}
     unless ( $key eq 'filename' );
  }
 }
 push @filenamelist, File::Spec->catfile( $dir, 'session' );
 my @selection = $self->get_selected_indices;
 @{ $session{selection} } = @selection;
 store( \%session, File::Spec->catfile( $dir, 'session' ) );
 if ( defined $filename ) {
  my $tar = Archive::Tar->new;
  $tar->add_files(@filenamelist);
  $tar->write( $filename, TRUE, '' );
 }
 return;
}

sub open_session {
 my ( $self, $dir, $filename, @filenamelist ) = @_;
 if ( defined $filename ) {
  my $tar = Archive::Tar->new( $filename, TRUE );
  @filenamelist = $tar->list_files;
  $tar->extract;
  $dir = dirname( $filenamelist[0] );
 }
 my $sessionref = retrieve( File::Spec->catfile( $dir, 'session' ) );
 my %session = %$sessionref;

 # Block the row-changed signal whilst adding the scan (row) and sorting it.
 $self->get_model->signal_handler_block( $self->{row_changed_signal} )
   if defined( $self->{row_changed_signal} );
 my @selection = @{ $session{selection} };
 delete $session{selection};
 for my $pagenum ( sort { $a <=> $b } ( keys(%session) ) ) {

# If we are opening a session file, then the session directory will be different
# If this is a crashed session, then we can use the same one
  unless ( defined( $session{$pagenum}{dir} )
   and $session{$pagenum}{dir} eq $dir )
  {
   $session{$pagenum}{filename} =
     File::Spec->catfile( $dir, basename( $session{$pagenum}{filename} ) );
   $session{$pagenum}{dir} = $dir;
  }

  # Populate the SimpleList
  my $page = Gscan2pdf::Page->new( %{ $session{$pagenum} } );
  my $thumb =
    get_pixbuf( $page->{filename}, $self->{heightt}, $self->{widtht} );
  push @{ $self->{data} }, [ $pagenum, $thumb, $page ];
 }
 $self->get_model->signal_handler_unblock( $self->{row_changed_signal} )
   if defined( $self->{row_changed_signal} );
 $self->select(@selection);
 return;
}

sub convert_to_png {
 my ($filename) = @_;
 my $image      = Image::Magick->new;
 my $x          = $image->Read($filename);
 $logger->warn($x) if "$x";
 return if $_self->{cancel};

 # FIXME: most of the time we already know this -
 # pull it from $page->{resolution} rather than asking IM
 my $density = get_resolution($image);

 # Write the png
 my $png =
   File::Temp->new( DIR => $_self->{dir}, SUFFIX => '.png', UNLINK => FALSE );
 $image->Write(
  units    => 'PixelsPerInch',
  density  => $density,
  filename => $png
 );
 return $png;
}

# Have to roll my own slurp sub to support utf8

sub slurp {
 my ($file) = @_;

 local ($/);
 my ($text);

 if ( ref($file) eq 'GLOB' ) {
  $text = <$file>;
 }
 else {
  open my $fh, '<:encoding(UTF8)', $file or die "Error: cannot open $file\n";
  $text = <$fh>;
  close $fh;
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

# Compute a timestamp

sub timestamp {
 my @time = localtime();

 # return a time which can be string-wise compared
 return sprintf( "%04d%02d%02d%02d%02d%02d",
  $time[5], $time[4], $time[3], $time[2], $time[1], $time[0] );
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
 my $started_flag;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 $options{queued_callback}
   ->( $_self->{process_name}, $jobs_completed, $jobs_total )
   if ( $options{queued_callback} );
 _when_ready(
  $options{sentinel},
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     if ( defined $options{pidfile} ) {
      _cancel_process( slurp( $options{pidfile} ) );
     }
     else {
      _cancel_process();
     }
     $options{cancelled_callback}->() if ( $options{cancelled_callback} );
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $self->fetch_file( $options{add} ) if ( $options{add} );
   $started_flag = $options{started_callback}->(
    1, $_self->{process_name},
    $jobs_completed, $jobs_total, $_self->{message}, $_self->{progress}
   ) if ( $options{started_callback} and not $started_flag );
   $options{running_callback}->(
    1, $_self->{process_name},
    $jobs_completed, $jobs_total, $_self->{message}, $_self->{progress}
   ) if ( $options{running_callback} );
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     if ( defined $options{pidfile} ) {
      _cancel_process( slurp( $options{pidfile} ) );
     }
     else {
      _cancel_process();
     }
     $options{cancelled_callback}->() if ( $options{cancelled_callback} );
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $options{started_callback}->()
     if ( $options{started_callback} and not $started_flag );
   if ( $_self->{status} ) {
    $options{error_callback}->() if ( $options{error_callback} );
    return;
   }
   $options{add} -= $self->fetch_file if ( $options{add} );
   my $data;
   if ( $options{info} ) {
    $data = $_self->{info_queue}->dequeue;
   }
   elsif ( $options{update_slist} ) {
    $data = $self->update_page( $options{display_callback} );
   }
   $options{finished_callback}->( $data, $_self->{requests}->pending )
     if $options{finished_callback};
   delete $self->{cancel_cb}{$pid};
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub _cancel_process {
 my ($pid) = @_;

 # Empty process queue first to stop any new process from starting
 $logger->info("Emptying process queue");
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

sub _when_ready {
 my ( $sentinel, $pending_callback, $running_callback, $finished_callback ) =
   @_;
 Glib::Timeout->add(
  $_POLL_INTERVAL,
  sub {
   if ( $$sentinel == 2 ) {
    $jobs_completed++;
    $finished_callback->() if ($finished_callback);
    return Glib::SOURCE_REMOVE;
   }
   elsif ( $$sentinel == 1 ) {
    $running_callback->() if ($running_callback);
    return Glib::SOURCE_CONTINUE;
   }
   $pending_callback->() if ($pending_callback);
   return Glib::SOURCE_CONTINUE;
  }
 );
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
     h    => $request->{h}
    );
   }

   when ('cuneiform') {
    _thread_cuneiform( $self, $request->{page}, $request->{language},
     $request->{pid} );
   }

   when ('get-file-info') {
    _thread_get_file_info( $self, $request->{path}, $request->{pid} );
   }

   when ('gocr') {
    _thread_gocr( $self, $request->{page}, $request->{pid} );
   }

   when ('import-file') {
    _thread_import_file(
     $self,            $request->{info}, $request->{first},
     $request->{last}, $request->{pid}
    );
   }

   when ('negate') {
    _thread_negate( $self, $request->{page} );
   }

   when ('ocropus') {
    _thread_ocropus( $self, $request->{page}, $request->{language},
     $request->{pid} );
   }

   when ('quit') {
    last;
   }

   when ('rotate') {
    _thread_rotate( $self, $request->{angle}, $request->{page} );
   }

   when ('save-djvu') {
    _thread_save_djvu( $self, $request->{path}, $request->{list_of_pages},
     $request->{pid} );
   }

   when ('save-image') {
    _thread_save_image( $self, $request->{path}, $request->{list_of_pages},
     $request->{pid} );
   }

   when ('save-pdf') {
    _thread_save_pdf(
     $self,
     path          => $request->{path},
     list_of_pages => $request->{list_of_pages},
     metadata      => $request->{metadata},
     options       => $request->{options},
     pidfile       => $request->{pid}
    );
   }

   when ('save-text') {
    _thread_save_text( $self, $request->{path}, $request->{list_of_pages} );
   }

   when ('save-tiff') {
    _thread_save_tiff(
     $self,
     path          => $request->{path},
     list_of_pages => $request->{list_of_pages},
     options       => $request->{options},
     ps            => $request->{ps},
     pidfile       => $request->{pid}
    );
   }

   when ('tesseract') {
    _thread_tesseract( $self, $request->{page}, $request->{language},
     $request->{pid} );
   }

   when ('threshold') {
    _thread_threshold( $self, $request->{threshold}, $request->{page} );
   }

   when ('to-png') {
    _thread_to_png( $self, $request->{page} );
   }

   when ('unpaper') {
    _thread_unpaper( $self, $request->{page}, $request->{options},
     $request->{pid} );
   }

   when ('unsharp') {
    _thread_unsharp(
     $self,
     page      => $request->{page},
     radius    => $request->{radius},
     sigma     => $request->{sigma},
     amount    => $request->{amount},
     threshold => $request->{threshold}
    );
   }

   when ('user-defined') {
    _thread_user_defined( $self, $request->{page}, $request->{command},
     $request->{pid} );
   }

   default {
    $logger->info( "Ignoring unknown request " . $request->{action} );
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

 $logger->info("Getting info for $filename");
 my $format = `file -b "$filename"`;

 if ( $format =~ /gzip\ compressed\ data/x ) {
  $info{path}   = $filename;
  $info{format} = 'session file';
  $self->{info_queue}->enqueue( \%info );
  return;
 }
 elsif ( $format =~ /DjVu/x ) {

  # Dig out the number of pages
  my $cmd = "djvudump \"$filename\"";
  $logger->info($cmd);
  my $info = `echo $$ > $pidfile;$cmd`;
  return if $_self->{cancel};
  $logger->info($info);

  my $pages = 1;
  if ( $info =~ /\s(\d+)\s+page/x ) {
   $pages = $1;
  }

  # Dig out and the resolution of each page
  my (@ppi);
  $info{format} = 'DJVU';
  while ( $info =~ /\s(\d+)\s+dpi/x ) {
   push @ppi, $1;
   $logger->info("Page $#ppi is $ppi[$#ppi] ppi");
   $info = substr( $info, index( $info, " dpi" ) + 4, length($info) );
  }
  if ( $pages != @ppi ) {
   $self->{status} = 1;
   $self->{message} =
     $d->get('Unknown DjVu file structure. Please contact the author.');
   return;
  }
  $info{ppi}   = \@ppi;
  $info{pages} = $pages;
  $info{path}  = $filename;
  $self->{info_queue}->enqueue( \%info );
  return;
 }

 # Get file type
 my $image = Image::Magick->new;
 my $x     = $image->Read($filename);
 return if $_self->{cancel};
 $logger->warn($x) if "$x";

 $format = $image->Get('format');
 $logger->info("Format $format") if ( defined $format );
 undef $image;

 if ( not defined($format) ) {
  $self->{status} = 1;
  $self->{message} =
    sprintf( $d->get("%s is not a recognised image type"), $filename );
  return;
 }
 elsif ( $format eq 'Portable Document Format' ) {
  my $cmd = "pdfinfo \"$filename\"";
  $logger->info($cmd);
  my $info = `echo $$ > $pidfile;$cmd`;
  return if $_self->{cancel};
  $logger->info($info);
  my $pages = 1;
  if ( $info =~ /Pages:\s+(\d+)/x ) {
   $pages = $1;
  }
  $logger->info("$pages pages");
  $info{pages} = $pages;
 }
 elsif ( $format eq 'Tagged Image File Format' ) {
  my $cmd = "tiffinfo \"$filename\"";
  $logger->info($cmd);
  my $info = `echo $$ > $pidfile;$cmd`;
  return if $_self->{cancel};
  $logger->info($info);

  # Count number of pages and their resolutions
  my @ppi;
  while ( $info =~ /Resolution:\ (\d*)/x ) {
   push @ppi, $1;
   $info = substr( $info, index( $info, 'Resolution' ) + 10, length($info) );
  }
  my $pages = @ppi;
  $logger->info("$pages pages");
  $info{pages} = $pages;
 }
 else {
  $info{pages} = 1;
 }
 $info{format} = $format;
 $info{path}   = $filename;
 $self->{info_queue}->enqueue( \%info );
 return;
}

sub _thread_import_file {
 my ( $self, $info, $first, $last, $pidfile ) = @_;

 given ( $info->{format} ) {
  when ('DJVU') {

   # Extract images from DjVu
   if ( $last >= $first and $first > 0 ) {
    for ( my $i = $first ; $i <= $last ; $i++ ) {
     $self->{progress} = ( $i - 1 ) / ( $last - $first + 1 );
     $self->{message} =
       sprintf( $d->get("Importing page %i of %i"), $i, $last - $first + 1 );
     my $tif = File::Temp->new(
      DIR    => $self->{dir},
      SUFFIX => '.tif',
      UNLINK => FALSE
     );
     my $cmd = "ddjvu -format=tiff -page=$i \"$info->{path}\" $tif";
     $logger->info($cmd);
     system("echo $$ > $pidfile;$cmd");
     return if $_self->{cancel};
     my $page = Gscan2pdf::Page->new(
      filename   => $tif,
      dir        => $self->{dir},
      delete     => TRUE,
      format     => 'Tagged Image File Format',
      resolution => $info->{ppi}[ $i - 1 ],
     );
     $self->{page_queue}->enqueue( $page->freeze );
    }
   }
  }
  when ('Portable Document Format') {

   # Extract images from PDF
   if ( $last >= $first and $first > 0 ) {
    my $cmd = "pdfimages -f $first -l $last \"$info->{path}\" x";
    $logger->info($cmd);
    my $status = system("echo $$ > $pidfile;$cmd");
    return if $_self->{cancel};
    if ($status) {
     $self->{status}  = 1;
     $self->{message} = $d->get('Error extracting images from PDF');
    }

    # Import each image
    my @images = glob('x-???.???');
    my $i      = 0;
    foreach (@images) {
     my $png  = convert_to_png($_);
     my $page = Gscan2pdf::Page->new(
      filename => $png,
      dir      => $self->{dir},
      delete   => TRUE,
      format   => 'Portable Network Graphics',
     );
     $self->{page_queue}->enqueue( $page->freeze );
    }
   }
  }
  when ('Tagged Image File Format') {

   # Split the tiff into its pages and import them individually
   if ( $last >= $first and $first > 0 ) {
    for ( my $i = $first - 1 ; $i < $last ; $i++ ) {
     $self->{progress} = $i / ( $last - $first + 1 );
     $self->{message} =
       sprintf( $d->get("Importing page %i of %i"), $i, $last - $first + 1 );
     my $tif = File::Temp->new(
      DIR    => $self->{dir},
      SUFFIX => '.tif',
      UNLINK => FALSE
     );
     my $cmd = "tiffcp \"$info->{path}\",$i $tif";
     $logger->info($cmd);
     system("echo $$ > $pidfile;$cmd");
     return if $_self->{cancel};
     my $page = Gscan2pdf::Page->new(
      filename => $tif,
      dir      => $self->{dir},
      delete   => TRUE,
      format   => $info->{format},
     );
     $self->{page_queue}->enqueue( $page->freeze );
    }
   }
  }

  # only 1-bit Portable anymap is properly supported, so convert ANY pnm to png
  when (
/(?:Portable\ Network\ Graphics|Joint\ Photographic\ Experts\ Group\ JFIF\ format|CompuServe\ graphics\ interchange\ format)/x
    )
  {
   my $page = Gscan2pdf::Page->new(
    filename => $info->{path},
    dir      => $self->{dir},
    format   => $info->{format},
   );
   $self->{page_queue}->enqueue( $page->freeze );
  }
  default {
   my $png = convert_to_png( $info->{path} );
   return if $_self->{cancel};
   my $page = Gscan2pdf::Page->new(
    filename => $png,
    dir      => $self->{dir},
    format   => 'Portable Network Graphics',
   );
   $self->{page_queue}->enqueue( $page->freeze );
  }
 }
 return;
}

sub _thread_save_pdf {
 my ( $self, %options ) = @_;

 my $page = 0;
 my $ttfcache;

 # Create PDF with PDF::API2
 $self->{message} = $d->get('Setting up PDF');
 my $pdf = PDF::API2->new( -file => $options{path} );
 $pdf->info( %{ $options{metadata} } ) if defined( $options{metadata} );

 my $corecache = $pdf->corefont('Times-Roman');
 $ttfcache = $pdf->ttfont( $options{options}->{font}, -unicodemap => 1 )
   if ( defined $options{options}->{font} );

 foreach my $pagedata ( @{ $options{list_of_pages} } ) {
  ++$page;
  $self->{progress} = $page / ( $#{ $options{list_of_pages} } + 2 );
  $self->{message} = sprintf( $d->get("Saving page %i of %i"),
   $page, $#{ $options{list_of_pages} } + 1 );

  my $filename = $pagedata->{filename};
  my $image    = Image::Magick->new;
  my $x        = $image->Read($filename);
  return if $_self->{cancel};
  $logger->warn($x) if "$x";

  # Get the size and resolution. Resolution is dots per inch, width
  # and height are in inches.
  my $resolution = $pagedata->{resolution};
  my $w          = $image->Get('width') / $resolution;
  my $h          = $image->Get('height') / $resolution;

  # The output resolution is normally the same as the input
  # resolution.
  my $output_resolution = $resolution;

  # Automatic mode
  my $depth;
  my $compression;
  my $type;
  if ( not defined( $options{options}->{compression} )
   or $options{options}->{compression} eq 'auto' )
  {
   $depth = $image->Get('depth');
   $logger->info("Depth of $filename is $depth");
   if ( $depth == 1 ) {
    $compression = 'lzw';
   }
   else {
    $type = $image->Get('type');
    $logger->info("Type of $filename is $type");
    if ( $type =~ /TrueColor/x ) {
     $compression = 'jpg';
    }
    else {
     $compression = 'png';
    }
   }
   $logger->info("Selecting $compression compression");
  }
  else {
   $compression = $options{options}->{compression};
  }

  # Convert file if necessary
  my $format;
  if ( $filename =~ /\.(\w*)$/x ) {
   $format = $1;
  }
  if (( $compression ne 'none' and $compression ne $format )
   or $options{options}->{downsample}
   or $compression eq 'jpg' )
  {
   if ( $compression !~ /(?:jpg|png)/x and $format ne 'tif' ) {
    my $ofn = $filename;
    $filename = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.tif' );
    $logger->info("Converting $ofn to $filename");
   }
   elsif ( $compression =~ /(?:jpg|png)/x ) {
    my $ofn = $filename;
    $filename = File::Temp->new(
     DIR    => $self->{dir},
     SUFFIX => ".$compression"
    );
    $logger->info("Converting $ofn to $filename");
   }

   $depth = $image->Get('depth') if ( not defined($depth) );
   if ( $options{options}->{downsample} ) {
    $output_resolution = $options{options}->{'downsample dpi'};
    my $w_pixels = $w * $output_resolution;
    my $h_pixels = $h * $output_resolution;

    $logger->info("Resizing $filename to $w_pixels x $h_pixels");
    $x = $image->Resize( width => $w_pixels,, height => $h_pixels );
    $logger->warn($x) if "$x";
   }
   $x = $image->Set( quality => $options{options}->{quality} )
     if ( defined( $options{options}->{quality} ) and $compression eq 'jpg' );
   $logger->warn($x) if "$x";

   if (( $compression !~ /(?:jpg|png)/x and $format ne 'tif' )
    or ( $compression =~ /(?:jpg|png)/x )
    or $options{options}->{downsample} )
   {

# depth required because resize otherwise increases depth to maintain information
    $logger->info("Writing temporary image $filename with depth $depth");
    $x = $image->Write( filename => $filename, depth => $depth );
    return if $_self->{cancel};
    $logger->warn($x) if "$x";
    if ( $filename =~ /\.(\w*)$/x ) {
     $format = $1;
    }
   }

   if ( $compression !~ /(?:jpg|png)/x ) {
    my $filename2 = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.tif' );
    my $error     = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.txt' );
    my $cmd = "tiffcp -c $compression $filename $filename2";
    $logger->info($cmd);
    my $status = system("echo $$ > $options{pidfile};$cmd 2>$error");
    return if $_self->{cancel};
    if ($status) {
     my $output = slurp($error);
     $logger->info($output);
     $self->{status} = 1;
     $self->{message} =
       sprintf( $d->get("Error compressing image: %s"), $output );
     return;
    }
    $filename = $filename2;
   }
  }

  $logger->info(
   "Defining page at ",
   $w * $POINTS_PER_INCH,
   "pt x ", $h * $POINTS_PER_INCH, "pt"
  );
  my $page = $pdf->page;
  $page->mediabox( $w * $POINTS_PER_INCH, $h * $POINTS_PER_INCH );

  # Add OCR as text behind the scan
  if ( defined( $pagedata->{hocr} ) ) {
   $logger->info('Embedding OCR output behind image');
   $logger->info("Using $options{options}->{font} for non-ASCII text")
     if ( defined $options{options}->{font} );
   my $font;
   my $text = $page->text;
   for my $box ( $pagedata->boxes ) {
    my ( $x1, $y1, $x2, $y2, $txt ) = @$box;
    if ( $txt =~ /([[:^ascii:]])/x and defined( $options{options}->{font} ) ) {
     $logger->debug("non-ascii text is '$1' in '$txt'") if ( defined $1 );
     $font = $ttfcache;
    }
    else {
     $font = $corecache;
    }
    ( $x2, $y2 ) = ( $w * $resolution, $h * $resolution )
      if ( $x1 == 0 and $y1 == 0 and not defined($x2) );
    if ( abs( $h * $resolution - $y2 + $y1 ) > 5
     and abs( $w * $resolution - $x2 + $x1 ) > 5 )
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

     # Box is the same size as the page. We don't know the text position.
     # Start at the top of the page (PDF coordinate system starts
     # at the bottom left of the page)
     my $size = 1;
     $text->font( $font, $size );
     my $y = $h * $POINTS_PER_INCH - $size;
     foreach my $line ( split( "\n", $txt ) ) {
      my $x = 0;

      # Add a word at a time in order to linewrap
      foreach my $word ( split( ' ', $line ) ) {
       if ( length($word) * $size + $x > $w * $POINTS_PER_INCH ) {
        $x = 0;
        $y -= $size;
       }
       $text->translate( $x, $y );
       $word = ' ' . $word if ( $x > 0 );
       $x += $text->text( $word, utf8 => 1 );
      }
      $y -= $size;
     }
    }
   }
  }

  # Add scan
  my $gfx = $page->gfx;
  my $imgobj;
  my $msg;
  if ( $format eq 'png' ) {
   try { $imgobj = $pdf->image_png($filename) } catch { $msg = $_ };
  }
  elsif ( $format eq 'jpg' ) {
   try { $imgobj = $pdf->image_jpeg($filename) } catch { $msg = $_ };
  }
  elsif ( $format eq 'pnm' ) {
   try { $imgobj = $pdf->image_pnm($filename) } catch { $msg = $_ };
  }
  elsif ( $format eq 'gif' ) {
   try { $imgobj = $pdf->image_gif($filename) } catch { $msg = $_ };
  }
  elsif ( $format eq 'tif' ) {
   try { $imgobj = $pdf->image_tiff($filename) } catch { $msg = $_ };
  }
  else {
   $msg = "Unknown format $format file $filename";
  }
  return if $_self->{cancel};
  if ($msg) {
   $logger->warn($msg);
   $self->{status} = 1;
   $self->{message} =
     sprintf( $d->get("Error creating PDF image object: %s"), $msg );
   return;
  }
  else {
   try {
    $gfx->image( $imgobj, 0, 0, $w * $POINTS_PER_INCH, $h * $POINTS_PER_INCH );
   }
   catch {
    $logger->warn($_);
    $self->{status} = 1;
    $self->{message} =
      sprintf( $d->get("Error embedding file image in %s format to PDF: %s"),
     $format, $_ );
   }
   finally {
    $logger->info("Adding $filename at $output_resolution PPI") unless (@_);
   };
  }
  return if $_self->{cancel};
 }
 $self->{message} = $d->get('Closing PDF');
 $pdf->save;
 $pdf->end;
 return;
}

sub _thread_save_djvu {
 my ( $self, $path, $list_of_pages, $pidfile ) = @_;

 my $page = 0;
 my @filelist;

 foreach my $pagedata ( @{$list_of_pages} ) {
  ++$page;
  $self->{progress} = $page / ( $#{$list_of_pages} + 2 );
  $self->{message} =
    sprintf( $d->get("Writing page %i of %i"), $page, $#{$list_of_pages} + 1 );

  my $filename = $pagedata->{filename};
  my $djvu = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.djvu' );

  # Check the image depth to decide what sort of compression to use
  my $image = Image::Magick->new;
  my $x     = $image->Read($filename);
  $logger->warn($x) if "$x";
  my $depth = $image->Get('depth');
  my $class = $image->Get('class');
  my $compression;

  # c44 can only use pnm and jpg
  my $format;
  if ( $filename =~ /\.(\w*)$/x ) {
   $format = $1;
  }
  if ( $depth > 1 ) {
   $compression = 'c44';
   if ( $format !~ /(?:pnm|jpg)/x ) {
    my $pnm = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pnm' );
    $x = $image->Write( filename => $pnm );
    $logger->warn($x) if "$x";
    $filename = $pnm;
   }
  }

  # cjb2 can only use pnm and tif
  else {
   $compression = 'cjb2';
   if ( $format !~ /(?:pnm|tif)/x
    or ( $format eq 'pnm' and $class ne 'PseudoClass' ) )
   {
    my $pbm = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pbm' );
    $x = $image->Write( filename => $pbm );
    $logger->warn($x) if "$x";
    $filename = $pbm;
   }
  }

  # Create the djvu
  my $resolution = $pagedata->{resolution};
  my $cmd = sprintf "$compression -dpi %d $filename $djvu", $resolution;
  $logger->info($cmd);
  my ( $status, $size ) =
    ( system("echo $$ > $pidfile;$cmd"), -s "$djvu" )
    ;    # quotes needed to prevent -s clobbering File::Temp object
  return if $_self->{cancel};
  unless ( $status == 0 and $size ) {
   $self->{status}  = 1;
   $self->{message} = $d->get('Error writing DjVu');
   $logger->error(
"Error writing image for page $page of DjVu (process returned $status, image size $size)"
   );
   return;
  }
  push @filelist, $djvu;

  # Add OCR to text layer
  if ( defined( $pagedata->{hocr} ) ) {

   # Get the size
   my $w = $image->Get('width');
   my $h = $image->Get('height');

   # Open djvusedtxtfile
   my $djvusedtxtfile =
     File::Temp->new( DIR => $self->{dir}, SUFFIX => '.txt' );
   open my $fh, ">:utf8", $djvusedtxtfile    ## no critic
     or croak( sprintf( $d->get("Can't open file: %s"), $djvusedtxtfile ) );
   print $fh "(page 0 0 $w $h\n";

   # Write the text boxes
   for my $box ( $pagedata->boxes ) {
    my ( $x1, $y1, $x2, $y2, $txt ) = @$box;
    ( $x2, $y2 ) = ( $w * $resolution, $h * $resolution )
      if ( $x1 == 0 and $y1 == 0 and not defined($x2) );

    # Escape any inverted commas
    $txt =~ s/\\/\\\\/gx;
    $txt =~ s/"/\\\"/gx;
    printf $fh "\n(line %d %d %d %d \"%s\")", $x1, $h - $y2, $x2,
      $h - $y1, $txt;
   }
   print $fh ")";
   close $fh;

   # Write djvusedtxtfile
   my $cmd = "djvused '$djvu' -e 'select 1; set-txt $djvusedtxtfile' -s";
   $logger->info($cmd);
   my $status = system("echo $$ > $pidfile;$cmd");
   return if $_self->{cancel};
   if ($status) {
    $self->{status}  = 1;
    $self->{message} = $d->get('Error adding text layer to DjVu');
    $logger->error("Error adding text layer to DjVu page $page");
   }
  }
 }
 $self->{progress} = 1;
 $self->{message}  = $d->get('Closing DjVu');
 my $cmd = "djvm -c '$path' @filelist";
 $logger->info($cmd);
 my $status = system("echo $$ > $pidfile;$cmd");
 return if $_self->{cancel};
 if ($status) {
  $self->{status}  = 1;
  $self->{message} = $d->get('Error closing DjVu');
  $logger->error("Error closing DjVu");
 }
 return;
}

sub _thread_save_tiff {
 my ( $self, %options ) = @_;

 my $page = 0;
 my @filelist;

 foreach my $pagedata ( @{ $options{list_of_pages} } ) {
  ++$page;
  $self->{progress} = ( $page - 1 ) / ( $#{ $options{list_of_pages} } + 2 );
  $self->{message} = sprintf( $d->get("Converting image %i of %i to TIFF"),
   $page, $#{ $options{list_of_pages} } + 1 );

  my $filename = $pagedata->{filename};
  if (
   $filename !~ /\.tif/x
   or ( defined( $options{options}->{compression} )
    and $options{options}->{compression} eq 'jpeg' )
    )
  {
   my $tif = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.tif' );
   my $resolution = $pagedata->{resolution};

   # Convert to tiff
   my $depth = '';
   $depth = '-depth 8'
     if ( defined( $options{options}->{compression} )
    and $options{options}->{compression} eq 'jpeg' );

   my $cmd =
     "convert -units PixelsPerInch -density $resolution $depth $filename $tif";
   $logger->info($cmd);
   my $status = system("echo $$ > $options{pidfile};$cmd");
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

 my $compression = "";
 if ( defined $options{options}->{compression} ) {
  $compression = "-c $options{options}->{compression}";
  $compression .= ":$options{options}->{quality}" if ( $compression eq 'jpeg' );
 }

 # Create the tiff
 $self->{progress} = 1;
 $self->{message}  = $d->get('Concatenating TIFFs');
 my $rows = '';
 $rows = '-r 16'
   if ( defined( $options{options}->{compression} )
  and $options{options}->{compression} eq 'jpeg' );
 my $cmd = "tiffcp $rows $compression @filelist '$options{path}'";
 $logger->info($cmd);
 my $out = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.stdout' );
 my $status = system("echo $$ > $options{pidfile};$cmd 2>$out");
 return if $_self->{cancel};

 if ($status) {
  my $output = slurp($out);
  $logger->info($output);
  $self->{status} = 1;
  $self->{message} = sprintf( $d->get("Error compressing image: %s"), $output );
  return;
 }
 if ( defined $options{ps} ) {
  $self->{message} = $d->get('Converting to PS');

  # Note: -a option causes tiff2ps to generate multiple output
  # pages, one for each page in the input TIFF file.  Without it, it
  # only generates output for the first page.
  my $cmd = "tiff2ps -a $options{path} > '$options{ps}'";
  $logger->info($cmd);
  my $output = `$cmd`;
 }
 return;
}

sub _thread_rotate {
 my ( $self, $angle, $page ) = @_;
 my $filename = $page->{filename};
 $logger->info("Rotating $filename by $angle degrees");

 # Rotate with imagemagick
 my $image = Image::Magick->new;
 my $x     = $image->Read($filename);
 return if $_self->{cancel};
 $logger->warn($x) if "$x";

 # workaround for those versions of imagemagick that produce 16bit output
 # with rotate
 my $depth = $image->Get('depth');
 $x = $image->Rotate($angle);
 return if $_self->{cancel};
 $logger->warn($x) if "$x";
 my $suffix;
 if ( $filename =~ /\.(\w*)$/x ) {
  $suffix = $1;
 }
 $filename = File::Temp->new(
  DIR    => $self->{dir},
  SUFFIX => '.' . $suffix,
  UNLINK => FALSE
 );
 $x = $image->Write( filename => $filename, depth => $depth );
 return if $_self->{cancel};
 $logger->warn($x) if "$x";
 my $new = $page->freeze;
 $new->{filename}   = $filename->filename;    # can't queue File::Temp objects
 $new->{dirty_time} = timestamp();            #flag as dirty
 my %data = ( old => $page, new => $new );
 $self->{page_queue}->enqueue( \%data );
 return;
}

sub _thread_save_image {
 my ( $self, $path, $list_of_pages, $pidfile ) = @_;

 if ( @{$list_of_pages} == 1 ) {
  my $cmd =
"convert $list_of_pages->[0]{filename} -density $list_of_pages->[0]{resolution} '$path'";
  $logger->info($cmd);
  my $status = system("echo $$ > $pidfile;$cmd");
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
   my $cmd = sprintf "convert %s -density %d \"%s\"",
     $_->{filename}, $_->{resolution},
     $current_filename;
   my $status = system("echo $$ > $pidfile;$cmd");
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

 unless ( open $fh, ">", $path ) {    ## no critic
  $self->{status} = 1;
  $self->{message} = sprintf( $d->get("Can't open file: %s"), $path );
  return;
 }
 foreach ( @{$list_of_pages} ) {
  print $fh $_->{hocr};
  return if $_self->{cancel};
 }
 close $fh;
 return;
}

sub _thread_analyse {
 my ( $self, $page ) = @_;

 # Identify with imagemagick
 my $image = Image::Magick->new;
 my $x     = $image->Read( $page->{filename} );
 return if $_self->{cancel};
 $logger->warn($x) if "$x";

 my ( $depth, $min, $max, $mean, $stddev ) = $image->Statistics();
 $logger->warn("image->Statistics() failed") unless defined $depth;
 $logger->info("std dev: $stddev mean: $mean");
 return if $_self->{cancel};
 my $maxQ = -1 + ( 1 << $depth );
 $mean = $maxQ ? $mean / $maxQ : 0;
 $stddev = 0 if $stddev eq "nan";

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
 my ( $self, $threshold, $page ) = @_;
 my $filename = $page->{filename};

 my $image = Image::Magick->new;
 my $x     = $image->Read($filename);
 return if $_self->{cancel};
 $logger->warn($x) if "$x";

 # Threshold the image
 $image->BlackThreshold( threshold => $threshold . '%' );
 return if $_self->{cancel};
 $image->WhiteThreshold( threshold => $threshold . '%' );
 return if $_self->{cancel};

 # Write it
 $filename =
   File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pbm', UNLINK => FALSE );
 $x = $image->Write( filename => $filename );
 return if $_self->{cancel};
 $logger->warn($x) if "$x";

 my $new = $page->freeze;
 $new->{filename}   = $filename->filename;    # can't queue File::Temp objects
 $new->{dirty_time} = timestamp();            #flag as dirty
 my %data = ( old => $page, new => $new );
 $self->{page_queue}->enqueue( \%data );
 return;
}

sub _thread_negate {
 my ( $self, $page ) = @_;
 my $filename = $page->{filename};

 my $image = Image::Magick->new;
 my $x     = $image->Read($filename);
 return if $_self->{cancel};
 $logger->warn($x) if "$x";

 my $depth = $image->Get('depth');

 # Negate the image
 $image->Negate;
 return if $_self->{cancel};

 # Write it
 my $suffix;
 if ( $filename =~ /(\.\w*)$/x ) {
  $suffix = $1;
 }
 $filename =
   File::Temp->new( DIR => $self->{dir}, SUFFIX => $suffix, UNLINK => FALSE );
 $x = $image->Write( depth => $depth, filename => $filename );
 return if $_self->{cancel};
 $logger->warn($x) if "$x";
 $logger->info("Negating to $filename");

 my $new = $page->freeze;
 $new->{filename}   = $filename->filename;    # can't queue File::Temp objects
 $new->{dirty_time} = timestamp();            #flag as dirty
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
 $logger->warn($x) if "$x";

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
 if ( $filename =~ /\.(\w*)$/x ) {
  $suffix = $1;
 }
 $filename = File::Temp->new(
  DIR    => $self->{dir},
  SUFFIX => '.' . $suffix,
  UNLINK => FALSE
 );
 $x = $image->Write( filename => $filename );
 return if $_self->{cancel};
 $logger->warn($x) if "$x";
 $logger->info(
"Wrote $filename with unsharp mask: r=$options{radius}, s=$options{sigma}, a=$options{amount}, t=$options{threshold}"
 );

 my $new = $options{page}->freeze;
 $new->{filename}   = $filename->filename;    # can't queue File::Temp objects
 $new->{dirty_time} = timestamp();            #flag as dirty
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
 $logger->warn($e) if "$e";

 # Crop the image
 $e = $image->Crop(
  width  => $options{w},
  height => $options{h},
  x      => $options{x},
  y      => $options{y}
 );
 $image->Set( page => '0x0+0+0' );
 return if $_self->{cancel};
 $logger->warn($e) if "$e";

 # Write it
 my $suffix;
 if ( $filename =~ /\.(\w*)$/x ) {
  $suffix = $1;
 }
 $filename = File::Temp->new(
  DIR    => $self->{dir},
  SUFFIX => '.' . $suffix,
  UNLINK => FALSE
 );
 $logger->info(
  "Cropping $options{w} x $options{h} + $options{x} + $options{y} to $filename"
 );
 $e = $image->Write( filename => $filename );
 return if $_self->{cancel};
 $logger->warn($e) if "$e";

 my $new = $options{page}->freeze;
 $new->{filename}   = $filename->filename;    # can't queue File::Temp objects
 $new->{dirty_time} = timestamp();            #flag as dirty
 my %data = ( old => $options{page}, new => $new );
 $self->{page_queue}->enqueue( \%data );
 return;
}

sub _thread_to_png {
 my ( $self, $page ) = @_;
 my $new = $page->clone;
 $new->{filename} = convert_to_png( $page->{filename} );
 return if $_self->{cancel};
 $new->{format} = 'Tagged Image File Format';
 my %data = ( old => $page, new => $new->freeze );
 $logger->info("Converted $page->{filename} to $data{new}{filename}");
 $self->{page_queue}->enqueue( \%data );
 return;
}

sub _thread_tesseract {
 my ( $self, $page, $language, $pidfile ) = @_;
 my $new = $page->clone;
 ( $new->{hocr}, $new->{warnings} ) =
   Gscan2pdf::Tesseract->hocr( $page->{filename}, $language, $logger,
  $pidfile );
 return if $_self->{cancel};
 $new->{ocr_flag} = 1;              #FlagOCR
 $new->{ocr_time} = timestamp();    #remember when we ran OCR on this page
 my %data = ( old => $page, new => $new );
 $self->{page_queue}->enqueue( \%data );
 return;
}

sub _thread_ocropus {
 my ( $self, $page, $language, $pidfile ) = @_;
 my $new = $page->clone;
 $new->{hocr} =
   Gscan2pdf::Ocropus->hocr( $page->{filename}, $language, $pidfile );
 return if $_self->{cancel};
 $new->{ocr_flag} = 1;              #FlagOCR
 $new->{ocr_time} = timestamp();    #remember when we ran OCR on this page
 my %data = ( old => $page, new => $new );
 $self->{page_queue}->enqueue( \%data );
 return;
}

sub _thread_cuneiform {
 my ( $self, $page, $language, $pidfile ) = @_;
 my $new = $page->clone;
 $new->{hocr} =
   Gscan2pdf::Cuneiform->hocr( $page->{filename}, $language, $pidfile );
 return if $_self->{cancel};
 $new->{ocr_flag} = 1;              #FlagOCR
 $new->{ocr_time} = timestamp();    #remember when we ran OCR on this page
 my %data = ( old => $page, new => $new );
 $self->{page_queue}->enqueue( \%data );
 return;
}

sub _thread_gocr {
 my ( $self, $page, $pidfile ) = @_;
 my $pnm;
 if ( $page->{filename} !~ /\.pnm$/x ) {

  # Temporary filename for new file
  $pnm = File::Temp->new( SUFFIX => '.pnm' );
  my $image = Image::Magick->new;
  $image->Read( $page->{filename} );
  return if $_self->{cancel};
  $image->Write( filename => $pnm );
  return if $_self->{cancel};
 }
 else {
  $pnm = $page->{filename};
 }

 my $new = $page->clone;

 my $cmd = "gocr $pnm";
 $logger->info($cmd);
 $new->{hocr} = `echo $$ > $pidfile;$cmd`;
 return if $_self->{cancel};
 $new->{ocr_flag} = 1;              #FlagOCR
 $new->{ocr_time} = timestamp();    #remember when we ran OCR on this page
 my %data = ( old => $page, new => $new );
 $self->{page_queue}->enqueue( \%data );
 return;
}

sub _thread_unpaper {
 my ( $self, $page, $options, $pidfile ) = @_;
 my $filename = $page->{filename};
 my $in;

 if ( $filename !~ /\.pnm$/x ) {
  my $image = Image::Magick->new;
  my $x     = $image->Read($filename);
  $logger->warn($x) if "$x";
  my $depth = $image->Get('depth');

# Unforunately, -depth doesn't seem to work here, so forcing depth=1 using pbm extension.
  my $suffix = ".pbm";
  $suffix = ".pnm" if ( $depth > 1 );

  # Temporary filename for new file
  $in = File::Temp->new(
   DIR    => $self->{dir},
   SUFFIX => $suffix,
  );

# FIXME: need to -compress Zip from perlmagick       "convert -compress Zip $slist->{data}[$pagenum][2]{filename} $in;";
  $image->Write( filename => $in );
 }
 else {
  $in = $filename;
 }

 my $out = File::Temp->new(
  DIR    => $self->{dir},
  SUFFIX => '.pnm',
  UNLINK => FALSE
 );
 my $out2 = '';
 $out2 = File::Temp->new(
  DIR    => $self->{dir},
  SUFFIX => '.pnm',
  UNLINK => FALSE
 ) if ( $options =~ /--output-pages\ 2\ /x );

 # --overwrite needed because $out exists with 0 size
 my $cmd = sprintf "$options;", $in, $out, $out2;
 $logger->info($cmd);
 system("echo $$ > $pidfile;$cmd");
 return if $_self->{cancel};

 my $new = Gscan2pdf::Page->new(
  filename => $out,
  dir      => $self->{dir},
  delete   => TRUE,
  format   => 'Portable anymap',
 );
 $new->{dirty_time} = timestamp();    #flag as dirty
 my %data = ( old => $page, new => $new->freeze );
 unless ( $out2 eq '' ) {
  my $new = Gscan2pdf::Page->new(
   filename => $out2,
   dir      => $self->{dir},
   delete   => TRUE,
   format   => 'Portable anymap',
  );
  $new->{dirty_time} = timestamp();    #flag as dirty
  $data{new2} = $new->freeze;
 }
 $self->{page_queue}->enqueue( \%data );
 return;
}

sub _thread_user_defined {
 my ( $self, $page, $cmd, $pidfile ) = @_;
 my $in = $page->{filename};
 my $suffix;
 if ( $in =~ /(\.\w*)$/x ) {
  $suffix = $1;
 }
 my $out = File::Temp->new(
  DIR    => $self->{dir},
  SUFFIX => $suffix,
  UNLINK => FALSE
 );

 if ( $cmd =~ s/%o/$out/gx ) {
  $cmd =~ s/%i/$in/gx;
 }
 else {
  unless ( copy( $in, $out ) ) {
   $self->{status}  = 1;
   $self->{message} = $d->get('Error copying page');
   $d->get('Error copying page');
   return;
  }
  $cmd =~ s/%i/$out/gx;
 }
 $cmd =~ s/%r/$page->{resolution}/gx;
 $logger->info($cmd);
 system("echo $$ > $pidfile;$cmd");
 return if $_self->{cancel};

 # Get file type
 my $image = Image::Magick->new;
 my $x     = $image->Read($out);
 $logger->warn($x) if "$x";

 my $new = Gscan2pdf::Page->new(
  filename => $out,
  dir      => $self->{dir},
  delete   => TRUE,
  format   => $image->Get('format'),
 );
 my %data = ( old => $page, new => $new->freeze );
 $self->{page_queue}->enqueue( \%data );
 return;
}

1;

__END__
