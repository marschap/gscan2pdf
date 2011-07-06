package Gscan2pdf::Document;

use strict;
use warnings;

use Gtk2::Ex::Simple::List;
use Gscan2pdf::Frontend::Scanimage;
use Gscan2pdf::Frontend::Sane;
use Gscan2pdf::Page;
use Glib qw(TRUE FALSE);
use Gtk2 -init;
use Socket;
use FileHandle;
use Image::Magick;
use File::Temp;    # To create temporary files
use File::Copy;
use Readonly;
Readonly our $POINTS_PER_INCH => 72;

BEGIN {
 use Exporter ();
 our ( $VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS );

 @ISA    = qw(Exporter Gtk2::Ex::Simple::List);
 @EXPORT = qw();
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

sub new {
 my $class = shift;
 my $self  = Gtk2::Ex::Simple::List->new(
  '#'                         => 'int',
  $main::d->get('Thumbnails') => 'pixbuf',
  'Page Data'                 => 'hstring',
 );
 $self->get_selection->set_mode('multiple');
 $self->set_headers_visible(FALSE);
 $self->set_reorderable(TRUE);

 bless( $self, $class );
 return $self;
}

sub get_file_info {
 my ( $self, $path, $finished_callback, $not_finished_callback,
  $error_callback ) = @_;
 my $sentinel =
   Gscan2pdf::_enqueue_request( 'get-file-info', { path => $path } );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $finished_callback->();
  },
  sub {
   $not_finished_callback->();
  }
 );
 return;
}

sub import_file {
 my ( $self, $info, $first, $last, $finished_callback, $not_finished_callback,
  $error_callback )
   = @_;
 my $sentinel =
   Gscan2pdf::_enqueue_request( 'import-file',
  { info => $info, first => $first, last => $last } );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->fetch_file;
   $finished_callback->();
  },
  sub {
   $self->fetch_file;
   $not_finished_callback->();
  }
 );
 return;
}

sub fetch_file {
 my ($self) = @_;
 while ( $Gscan2pdf::_self->{data_queue}->pending ) {
  my $page = $Gscan2pdf::_self->{data_queue}->dequeue;
  $self->add_page( $page->thaw );
 }
 return;
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

# Take new scan and display it

sub add_page {
 my ( $self, $page, $pagenum, $success_cb ) = @_;

 # Add to the page list
 $pagenum = $#{ $self->{data} } + 2 if ( not defined($pagenum) );

 # Block the row-changed signal whilst adding the scan (row) and sorting it.
 $self->get_model->signal_handler_block( $self->{row_changed_signal} )
   if defined( $self->{row_changed_signal} );
 my $thumb = get_pixbuf( $page->{filename}, $main::heightt, $main::widtht );
 push @{ $self->{data} }, [ $pagenum, $thumb, $page ];
 $main::logger->info(
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

# return array index of pages depending on which radiobutton is active

sub get_page_index {
 my ($self) = @_;
 if ( $main::SETTING{'Page range'} eq 'all' ) {
  return 0 .. $#{ $self->{data} };
 }
 elsif ( $main::SETTING{'Page range'} eq 'selected' ) {
  return $self->get_selected_indices;
 }
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
  $main::logger->warn( 'Warning: ' . "$@" );
  eval {
   $pixbuf =
     Gtk2::Gdk::Pixbuf->new_from_file_at_scale( $filename, $width, $height,
    TRUE );
  };
  $main::logger->info("Got $filename on second attempt")
    unless ($@);
 }

 return $pixbuf;
}

sub save_pdf {
 my ( $self, $path, $list_of_pages, $metadata, $options, $finished_callback,
  $not_finished_callback, $error_callback )
   = @_;

 for my $i ( 0 .. $#{$list_of_pages} ) {
  $list_of_pages->[$i] =
    $list_of_pages->[$i]->freeze;   # sharing File::Temp objects causes problems
 }
 my $sentinel = Gscan2pdf::_enqueue_request(
  'save-pdf',
  {
   path          => $path,
   list_of_pages => $list_of_pages,
   metadata      => $metadata,
   options       => $options,
  }
 );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $finished_callback->();
  },
  sub {
   $not_finished_callback->();
  }
 );
 return;
}

sub save_djvu {
 my ( $self, $path, $list_of_pages, $finished_callback, $not_finished_callback,
  $error_callback )
   = @_;

 for my $i ( 0 .. $#{$list_of_pages} ) {
  $list_of_pages->[$i] =
    $list_of_pages->[$i]->freeze;   # sharing File::Temp objects causes problems
 }
 my $sentinel = Gscan2pdf::_enqueue_request(
  'save-djvu',
  {
   path          => $path,
   list_of_pages => $list_of_pages
  }
 );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $finished_callback->();
  },
  sub {
   $not_finished_callback->();
  }
 );
 return;
}

sub save_tiff {
 my ( $self, $path, $list_of_pages, $options, $ps, $finished_callback,
  $not_finished_callback, $error_callback )
   = @_;

 for my $i ( 0 .. $#{$list_of_pages} ) {
  $list_of_pages->[$i] =
    $list_of_pages->[$i]->freeze;   # sharing File::Temp objects causes problems
 }
 my $sentinel = Gscan2pdf::_enqueue_request(
  'save-tiff',
  {
   path          => $path,
   list_of_pages => $list_of_pages,
   options       => $options,
   ps            => $ps,
  }
 );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $finished_callback->();
  },
  sub {
   $not_finished_callback->();
  }
 );
 return;
}

sub rotate {
 my ( $self, $angle, $page, $finished_callback, $not_finished_callback,
  $error_callback, $display_callback )
   = @_;

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'rotate',
  { angle => $angle, page => $page->freeze } );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->();
  },
  sub {
   $self->update_page($display_callback);
   $not_finished_callback->();
  }
 );
 return;
}

sub update_page {
 my ( $self, $display_callback ) = @_;
 while ( $Gscan2pdf::_self->{data_queue}->pending ) {
  my $data = $Gscan2pdf::_self->{data_queue}->dequeue;

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
     get_pixbuf( $new->{filename}, $main::heightt, $main::widtht );
   $self->{data}[$i][2] = $new;

   if ( defined $data->{new2} ) {
    $new = $data->{new2}->thaw;
    splice @{ $self->{data} }, $i + 1, 0,
      [
     $self->{data}[$i][0] + 1,
     get_pixbuf( $new->{filename}, $main::heightt, $main::widtht ), $new
      ];
   }

   $self->get_model->signal_handler_unblock( $self->{row_changed_signal} )
     if defined( $self->{row_changed_signal} );
   my @selected = $self->get_selected_indices;
   $self->select(@selected) if ( $i == $selected[0] );
   $display_callback->() if ($display_callback);
  }

 }
 return;
}

sub save_image {
 my ( $self, $path, $list_of_pages, $finished_callback, $not_finished_callback,
  $error_callback )
   = @_;

 for my $i ( 0 .. $#{$list_of_pages} ) {
  $list_of_pages->[$i] =
    $list_of_pages->[$i]->freeze;   # sharing File::Temp objects causes problems
 }
 my $sentinel = Gscan2pdf::_enqueue_request(
  'save-image',
  {
   path          => $path,
   list_of_pages => $list_of_pages
  }
 );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $finished_callback->();
  },
  sub {
   $not_finished_callback->();
  }
 );
 return;
}

sub save_text {
 my ( $self, $path, $list_of_pages, $finished_callback, $not_finished_callback,
  $error_callback )
   = @_;

 for my $i ( 0 .. $#{$list_of_pages} ) {
  $list_of_pages->[$i] =
    $list_of_pages->[$i]->freeze;   # sharing File::Temp objects causes problems
 }
 my $sentinel = Gscan2pdf::_enqueue_request(
  'save-text',
  {
   path          => $path,
   list_of_pages => $list_of_pages
  }
 );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $finished_callback->();
  },
  sub {
   $not_finished_callback->();
  }
 );
 return;
}

sub analyse {
 my ( $self, $page, $finished_callback, $not_finished_callback,
  $error_callback ) = @_;

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'analyse', { page => $page->freeze } );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page();
   $finished_callback->();
  },
  sub {
   $self->update_page();
   $not_finished_callback->();
  }
 );
 return;
}

sub threshold {
 my ( $self, $threshold, $page, $finished_callback, $not_finished_callback,
  $error_callback, $display_callback )
   = @_;

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'threshold',
  { threshold => $threshold, page => $page->freeze } );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->();
  },
  sub {
   $self->update_page($display_callback);
   $not_finished_callback->();
  }
 );
 return;
}

sub negate {
 my ( $self, $page, $finished_callback, $not_finished_callback, $error_callback,
  $display_callback )
   = @_;

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'negate', { page => $page->freeze } );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->();
  },
  sub {
   $self->update_page($display_callback);
   $not_finished_callback->();
  }
 );
 return;
}

sub unsharp {
 my (
  $self,              $page,                  $radius,
  $sigma,             $amount,                $threshold,
  $finished_callback, $not_finished_callback, $error_callback,
  $display_callback
 ) = @_;

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
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->();
  },
  sub {
   $self->update_page($display_callback);
   $not_finished_callback->();
  }
 );
 return;
}

sub crop {
 my ( $self, $page, $x, $y, $w, $h, $finished_callback, $not_finished_callback,
  $error_callback, $display_callback )
   = @_;

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
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->();
  },
  sub {
   $self->update_page($display_callback);
   $not_finished_callback->();
  }
 );
 return;
}

sub to_tiff {
 my ( $self, $page, $finished_callback, $not_finished_callback,
  $error_callback ) = @_;

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'to-tiff', { page => $page->freeze } );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page();
   $finished_callback->();
  },
  sub {
   $self->update_page();
   $not_finished_callback->();
  }
 );
 return;
}

sub tesseract {
 my ( $self, $page, $language, $finished_callback, $not_finished_callback,
  $error_callback, $display_callback )
   = @_;

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'tesseract',
  { page => $page->freeze, language => $language } );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->();
  },
  sub {
   $self->update_page($display_callback);
   $not_finished_callback->();
  }
 );
 return;
}

sub ocropus {
 my ( $self, $page, $language, $finished_callback, $not_finished_callback,
  $error_callback, $display_callback )
   = @_;

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'ocropus',
  { page => $page->freeze, language => $language } );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->();
  },
  sub {
   $self->update_page($display_callback);
   $not_finished_callback->();
  }
 );
 return;
}

sub cuneiform {
 my ( $self, $page, $language, $finished_callback, $not_finished_callback,
  $error_callback, $display_callback )
   = @_;

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'cuneiform',
  { page => $page->freeze, language => $language } );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->();
  },
  sub {
   $self->update_page($display_callback);
   $not_finished_callback->();
  }
 );
 return;
}

sub unpaper {
 my ( $self, $page, $options, $finished_callback, $not_finished_callback,
  $error_callback, $display_callback )
   = @_;

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'unpaper',
  { page => $page->freeze, options => $options } );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->();
  },
  sub {
   $self->update_page($display_callback);
   $not_finished_callback->();
  }
 );
 return;
}

sub user_defined {
 my ( $self, $page, $cmd, $finished_callback, $not_finished_callback,
  $error_callback, $display_callback )
   = @_;

 my $sentinel =
   Gscan2pdf::_enqueue_request( 'user-defined',
  { page => $page->freeze, command => $cmd } );
 Gscan2pdf::_when_ready(
  $sentinel,
  sub {
   if ( $Gscan2pdf::_self->{status} ) {
    $error_callback->();
    return;
   }
   $self->update_page($display_callback);
   $finished_callback->();
  },
  sub {
   $self->update_page($display_callback);
   $not_finished_callback->();
  }
 );
 return;
}

1;

__END__
