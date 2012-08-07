package Gscan2pdf::Document;

use strict;
use warnings;

use Gtk2::Ex::Simple::List;
use Gscan2pdf::Scanner::Options;
use Gscan2pdf::Frontend::Sane;
use Gscan2pdf::Page;
use Glib qw(TRUE FALSE);
use Socket;
use FileHandle;
use Image::Magick;
use File::Temp;        # To create temporary files
use File::Basename;    # Split filename into dir, file, ext
use File::Copy;
use Storable qw(store retrieve);
use Archive::Tar;      # For session files
use Proc::Killfam;
use Readonly;
Readonly our $POINTS_PER_INCH => 72;

my $_POLL_INTERVAL = 100;    # ms
my $_PID           = 0;      # flag to identify which process to cancel

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

my $logger;

sub new {
 my ( $class, %options ) = @_;
 my $d    = Locale::gettext->domain(Glib::get_application_name);
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

sub set_logger {
 ( my $class, $logger ) = @_;
 Gscan2pdf::Page->set_logger($logger);
 return;
}

sub _when_ready {
 my ( $sentinel, $pending_callback, $running_callback, $finished_callback ) =
   @_;
 Glib::Timeout->add(
  $_POLL_INTERVAL,
  sub {
   if ( $$sentinel == 2 ) {
    $Gscan2pdf::jobs_completed++;
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

# Flag the given process to cancel itself

sub cancel {
 my ( $self, $pid, $callback ) = @_;
 $self->{cancel_cb}{$pid} = $callback
   if ( defined $self->{running_pids}{$pid} );
 return;
}

sub get_file_info {
 my ( $self, $path, $queued_callback, $started_callback, $running_callback,
  $finished_callback, $error_callback, $cancelled_callback )
   = @_;
 my $started_flag;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

# File in which to store the subprocess ID so that it can be killed if necessary
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'get-file-info',
  { path => $path, pid => "$pidfile" } );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->() if ($error_callback);
    return;
   }
   $finished_callback->(
    $Gscan2pdf::_self->{info_queue}->dequeue,
    $Gscan2pdf::_self->{requests}->pending
   ) if ($finished_callback);
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub import_file {
 my (
  $self,             $info,              $first,
  $last,             $queued_callback,   $started_callback,
  $running_callback, $finished_callback, $error_callback,
  $cancelled_callback
 ) = @_;
 my $started_flag;
 my $outstanding = $last - $first + 1;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 # File in which to store the process ID so that it can be killed if necessary
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'import-file',
  { info => $info, first => $first, last => $last, pid => "$pidfile" } );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $self->fetch_file($outstanding);
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->() if ($error_callback);
    return;
   }
   $outstanding -= $self->fetch_file;
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if ($finished_callback);
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub fetch_file {
 my ( $self, $n ) = @_;
 my $i = 0;
 if ($n) {
  while ( $i < $n ) {
   my $page = $Gscan2pdf::_self->{page_queue}->dequeue;
   $self->add_page( $page->thaw );
   ++$i;
  }
 }
 elsif ( defined( my $page = $Gscan2pdf::_self->{page_queue}->dequeue_nb() ) ) {
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
 for ( keys %{ $main::SETTING{Paper} } ) {
  if ( $main::SETTING{Paper}{$_}{x} > 0
   and
   abs( $ratio - $main::SETTING{Paper}{$_}{y} / $main::SETTING{Paper}{$_}{x} ) <
   0.02 )
  {
   $resolution =
     int( ( ( $height > $width ) ? $height : $width ) /
      $main::SETTING{Paper}{$_}{y} *
      25.4 + 0.5 );
  }
 }
 return $resolution;
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
 eval {
  $pixbuf =
    Gtk2::Gdk::Pixbuf->new_from_file_at_scale( $filename, $width, $height,
   TRUE );
 };

 # if (Glib::Error::matches ($@, 'Mup::Thing::Error', 'flop')) {
 #  recover_from_a_flop ();
 # }
 if ($@) {
  $logger->warn( 'Warning: ' . "$@" );
  eval {
   $pixbuf =
     Gtk2::Gdk::Pixbuf->new_from_file_at_scale( $filename, $width, $height,
    TRUE );
  };
  $logger->info("Got $filename on second attempt")
    unless ($@);
 }

 return $pixbuf;
}

sub save_pdf {
 my (
  $self,             $path,             $list_of_pages,
  $metadata,         $options,          $queued_callback,
  $started_callback, $running_callback, $finished_callback,
  $error_callback,   $cancelled_callback
 ) = @_;

 for my $i ( 0 .. $#{$list_of_pages} ) {
  $list_of_pages->[$i] =
    $list_of_pages->[$i]->freeze;   # sharing File::Temp objects causes problems
 }
 my $started_flag;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 # File in which to store the process ID so that it can be killed if necessary
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel = Gscan2pdf::_enqueue_request(
  'save-pdf',
  {
   path          => $path,
   list_of_pages => $list_of_pages,
   metadata      => $metadata,
   options       => $options,
   pid           => "$pidfile"
  }
 );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub save_djvu {
 my (
  $self,              $path,             $list_of_pages,
  $queued_callback,   $started_callback, $running_callback,
  $finished_callback, $error_callback,   $cancelled_callback
 ) = @_;

 for my $i ( 0 .. $#{$list_of_pages} ) {
  $list_of_pages->[$i] =
    $list_of_pages->[$i]->freeze;   # sharing File::Temp objects causes problems
 }
 my $started_flag;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 # File in which to store the process ID so that it can be killed if necessary
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel = Gscan2pdf::_enqueue_request(
  'save-djvu',
  {
   path          => $path,
   list_of_pages => $list_of_pages,
   pid           => "$pidfile"
  }
 );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->() if ($error_callback);
    return;
   }
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub save_tiff {
 my (
  $self,             $path,             $list_of_pages,
  $options,          $ps,               $queued_callback,
  $started_callback, $running_callback, $finished_callback,
  $error_callback,   $cancelled_callback
 ) = @_;

 for my $i ( 0 .. $#{$list_of_pages} ) {
  $list_of_pages->[$i] =
    $list_of_pages->[$i]->freeze;   # sharing File::Temp objects causes problems
 }
 my $started_flag;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 # File in which to store the process ID so that it can be killed if necessary
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel = Gscan2pdf::_enqueue_request(
  'save-tiff',
  {
   path          => $path,
   list_of_pages => $list_of_pages,
   options       => $options,
   ps            => $ps,
   pid           => "$pidfile"
  }
 );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub rotate {
 my (
  $self,              $angle,            $page,
  $queued_callback,   $started_callback, $running_callback,
  $finished_callback, $error_callback,   $display_callback,
  $cancelled_callback
 ) = @_;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 my $started_flag;
 my $sentinel =
   Gscan2pdf::_enqueue_request( 'rotate',
  { angle => $angle, page => $page->freeze } );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process;
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process;
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $finished_callback->(
    $self->update_page($display_callback),
    $Gscan2pdf::_self->{requests}->pending
   ) if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub update_page {
 my ( $self, $display_callback ) = @_;
 my (@out);
 my $data = $Gscan2pdf::_self->{page_queue}->dequeue;

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
  $self->select(@selected) if ( $i == $selected[0] );
  $display_callback->( $self->{data}[$i][2] ) if ($display_callback);
 }

 return \@out;
}

sub save_image {
 my (
  $self,              $path,             $list_of_pages,
  $queued_callback,   $started_callback, $running_callback,
  $finished_callback, $error_callback,   $cancelled_callback
 ) = @_;

 for my $i ( 0 .. $#{$list_of_pages} ) {
  $list_of_pages->[$i] =
    $list_of_pages->[$i]->freeze;   # sharing File::Temp objects causes problems
 }
 my $started_flag;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 # File in which to store the process ID so that it can be killed if necessary
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel = Gscan2pdf::_enqueue_request(
  'save-image',
  {
   path          => $path,
   list_of_pages => $list_of_pages,
   pid           => "$pidfile"
  }
 );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub save_text {
 my (
  $self,              $path,             $list_of_pages,
  $queued_callback,   $started_callback, $running_callback,
  $finished_callback, $error_callback,   $cancelled_callback
 ) = @_;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 for my $i ( 0 .. $#{$list_of_pages} ) {
  $list_of_pages->[$i] =
    $list_of_pages->[$i]->freeze;   # sharing File::Temp objects causes problems
 }
 my $started_flag;
 my $sentinel = Gscan2pdf::_enqueue_request(
  'save-text',
  {
   path          => $path,
   list_of_pages => $list_of_pages
  }
 );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   unless ( exists $self->{cancel_cb}{$pid} ) {
    $started_flag = $started_callback->(
     1,                            $Gscan2pdf::_self->{process_name},
     $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
     $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
    ) if ( $started_callback and not $started_flag );
    $running_callback->(
     1,                            $Gscan2pdf::_self->{process_name},
     $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
     $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
    ) if ($running_callback);
   }
  },
  sub {    # finished
   unless ( exists $self->{cancel_cb}{$pid} ) {
    $started_callback->() if ( $started_callback and not $started_flag );
    if ( $Gscan2pdf::_self->{status} ) {
     $error_callback->();
     return;
    }
    $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
      if $finished_callback;
   }
   $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
   delete $self->{cancel_cb}{$pid};
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub analyse {
 my ( $self, $page, $queued_callback, $started_callback, $running_callback,
  $finished_callback, $error_callback, $cancelled_callback )
   = @_;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 my $started_flag;
 my $sentinel =
   Gscan2pdf::_enqueue_request( 'analyse', { page => $page->freeze } );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   unless ( exists $self->{cancel_cb}{$pid} ) {
    $started_flag = $started_callback->(
     1,                            $Gscan2pdf::_self->{process_name},
     $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
     $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
    ) if ( $started_callback and not $started_flag );
    $running_callback->(
     1,                            $Gscan2pdf::_self->{process_name},
     $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
     $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
    ) if ($running_callback);
   }
  },
  sub {    # finished
   unless ( exists $self->{cancel_cb}{$pid} ) {
    $started_callback->() if ( $started_callback and not $started_flag );
    if ( $Gscan2pdf::_self->{status} ) {
     $error_callback->();
     return;
    }
    $self->update_page();
    $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
      if $finished_callback;
   }
   $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
   delete $self->{cancel_cb}{$pid};
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub threshold {
 my (
  $self,              $threshold,        $page,
  $queued_callback,   $started_callback, $running_callback,
  $finished_callback, $error_callback,   $display_callback,
  $cancelled_callback
 ) = @_;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 my $started_flag;
 my $sentinel =
   Gscan2pdf::_enqueue_request( 'threshold',
  { threshold => $threshold, page => $page->freeze } );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process;
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process;
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub negate {
 my (
  $self,             $page,             $queued_callback,
  $started_callback, $running_callback, $finished_callback,
  $error_callback,   $display_callback, $cancelled_callback
 ) = @_;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 my $started_flag;
 my $sentinel =
   Gscan2pdf::_enqueue_request( 'negate', { page => $page->freeze } );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process;
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process;
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub unsharp {
 my (
  $self,              $page,             $radius,
  $sigma,             $amount,           $threshold,
  $queued_callback,   $started_callback, $running_callback,
  $finished_callback, $error_callback,   $display_callback,
  $cancelled_callback
 ) = @_;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 my $started_flag;
 my $sentinel = Gscan2pdf::_enqueue_request(
  'unsharp',
  {
   page      => $page->freeze,
   radius    => $radius,
   sigma     => $sigma,
   amount    => $amount,
   threshold => $threshold
  }
 );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process;
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process;
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub crop {
 my (
  $self,              $page,             $x,
  $y,                 $w,                $h,
  $queued_callback,   $started_callback, $running_callback,
  $finished_callback, $error_callback,   $display_callback,
  $cancelled_callback
 ) = @_;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 my $started_flag;
 my $sentinel = Gscan2pdf::_enqueue_request(
  'crop',
  {
   page => $page->freeze,
   x    => $x,
   y    => $y,
   w    => $w,
   h    => $h
  }
 );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process;
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process;
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub to_png {
 my ( $self, $page, $queued_callback, $started_callback, $running_callback,
  $finished_callback, $error_callback, $cancelled_callback )
   = @_;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 my $started_flag;
 my $sentinel =
   Gscan2pdf::_enqueue_request( 'to-png', { page => $page->freeze } );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process;
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process;
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page();
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub tesseract {
 my (
  $self,              $page,             $language,
  $queued_callback,   $started_callback, $running_callback,
  $finished_callback, $error_callback,   $display_callback,
  $cancelled_callback
 ) = @_;

 my $started_flag;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 # File in which to store the process ID so that it can be killed if necessary
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'tesseract',
  { page => $page->freeze, language => $language, pid => "$pidfile" } );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub ocropus {
 my (
  $self,              $page,             $language,
  $queued_callback,   $started_callback, $running_callback,
  $finished_callback, $error_callback,   $display_callback,
  $cancelled_callback
 ) = @_;

 my $started_flag;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 # File in which to store the process ID so that it can be killed if necessary
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'ocropus',
  { page => $page->freeze, language => $language, pid => "$pidfile" } );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub cuneiform {
 my (
  $self,              $page,             $language,
  $queued_callback,   $started_callback, $running_callback,
  $finished_callback, $error_callback,   $display_callback,
  $cancelled_callback
 ) = @_;

 my $started_flag;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 # File in which to store the process ID so that it can be killed if necessary
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'cuneiform',
  { page => $page->freeze, language => $language, pid => "$pidfile" } );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub gocr {
 my (
  $self,             $page,             $queued_callback,
  $started_callback, $running_callback, $finished_callback,
  $error_callback,   $display_callback, $cancelled_callback
 ) = @_;

 my $started_flag;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 # File in which to store the process ID so that it can be killed if necessary
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'gocr',
  { page => $page->freeze, pid => "$pidfile" } );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub unpaper {
 my (
  $self,              $page,             $options,
  $queued_callback,   $started_callback, $running_callback,
  $finished_callback, $error_callback,   $display_callback,
  $cancelled_callback
 ) = @_;

 my $started_flag;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 # File in which to store the process ID so that it can be killed if necessary
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'unpaper',
  { page => $page->freeze, options => $options, pid => "$pidfile" } );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $finished_callback->(
    $self->update_page($display_callback),
    $Gscan2pdf::_self->{requests}->pending
   ) if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
}

sub user_defined {
 my (
  $self,              $page,             $cmd,
  $queued_callback,   $started_callback, $running_callback,
  $finished_callback, $error_callback,   $display_callback,
  $cancelled_callback
 ) = @_;

 my $started_flag;

 # Get new process ID
 my $pid = ++$_PID;
 $self->{running_pids}{$pid} = 1;

 # File in which to store the process ID so that it can be killed if necessary
 my $pidfile = File::Temp->new( DIR => $self->{dir}, SUFFIX => '.pid' );

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'user-defined',
  { page => $page->freeze, command => $cmd, pid => "$pidfile" } );
 $queued_callback->(
  $Gscan2pdf::_self->{process_name},
  $Gscan2pdf::jobs_completed, $Gscan2pdf::jobs_total
 ) if ($queued_callback);
 _when_ready(
  $sentinel,
  undef,    # pending
  sub {     # running
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );

     # Flag that the callbacks have been done here
     # so they are not repeated here or in finished
     $self->{cancel_cb}{$pid} = 1;
     delete $self->{running_pids}{$pid};
    }
    return;
   }
   $started_flag = $started_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ( $started_callback and not $started_flag );
   $running_callback->(
    1,                            $Gscan2pdf::_self->{process_name},
    $Gscan2pdf::jobs_completed,   $Gscan2pdf::jobs_total,
    $Gscan2pdf::_self->{message}, $Gscan2pdf::_self->{progress}
   ) if ($running_callback);
  },
  sub {    # finished
   if ( exists $self->{cancel_cb}{$pid} ) {
    if ( not defined( $self->{cancel_cb}{$pid} )
     or ref( $self->{cancel_cb}{$pid} ) eq 'CODE' )
    {
     Gscan2pdf::_cancel_process( Gscan2pdf::slurp($pidfile) );
     $cancelled_callback->() if ($cancelled_callback);
     $self->{cancel_cb}{$pid}->() if ( $self->{cancel_cb}{$pid} );
    }
    delete $self->{cancel_cb}{$pid};
    delete $self->{running_pids}{$pid};
    return;
   }
   $started_callback->() if ( $started_callback and not $started_flag );
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->( $Gscan2pdf::_self->{requests}->pending )
     if $finished_callback;
   delete $self->{running_pids}{$pid};
  },
 );
 return $pid;
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
    Gscan2pdf::Document::get_pixbuf( $page->{filename}, $self->{heightt},
   $self->{widtht} );
  push @{ $self->{data} }, [ $pagenum, $thumb, $page ];
 }
 $self->get_model->signal_handler_unblock( $self->{row_changed_signal} )
   if defined( $self->{row_changed_signal} );
 $self->select(@selection);
 return;
}

1;

__END__
