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
use File::Temp qw(tempfile tempdir);    # To create temporary files
use File::Copy;
use Readonly;
Readonly our $POINTS_PER_INCH => 72;

BEGIN {
 use Exporter ();
 our ( $VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS );

 @ISA    = qw(Exporter Gtk2::Ex::Simple::List);
 @EXPORT = qw();
 %EXPORT_TAGS = ();                     # eg: TAG => [ qw!name1 name2! ],

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

sub open_socketpair {
 my $child  = FileHandle->new;
 my $parent = FileHandle->new;
 socketpair( $child, $parent, AF_UNIX, SOCK_DGRAM, PF_UNSPEC );
 binmode $child,  ':utf8';
 binmode $parent, ':utf8';
 return ( $child, $parent );
}

sub get_file_info {
 my ( $self, $finished_callback, $not_finished_callback, $error_callback,
  @filename )
   = @_;
 for (@filename) {
  my $sentinel = Gscan2pdf::_enqueue_request( 'get-file-info', { path => $_ } );
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
 }
 return;
}

sub import_file {
 my ( $self, $first, $last, $finished_callback, $not_finished_callback,
  $error_callback )
   = @_;
 my $sentinel =
   Gscan2pdf::_enqueue_request( 'import-file',
  { first => $first, last => $last } );
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
  $self->add_page($page);
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

# Create the PDF

sub create_PDF {
 my ( $self, $filename, $mua_string ) = @_;

 my $dialog = Gtk2::Dialog->new( $main::d->get('Saving PDF') . "...",
  $main::window, 'modal', 'gtk-cancel' => 'cancel' );

 # Set up ProgressBar
 my $pbar = Gtk2::ProgressBar->new;
 $dialog->vbox->add($pbar);

 # Ensure that the dialog box is destroyed when the user responds.
 $dialog->signal_connect(
  response => sub {
   $_[0]->destroy;
   kill_subs();
  }
 );
 $dialog->show_all;

 # Install a handler for child processes
 $SIG{CHLD} = \&sig_child;

 # fill $pagelist with filenames depending on which radiobutton is active
 my @pagelist = $self->get_page_index();

 my ( $child, $parent ) = open_socketpair();
 my $pid = start_process(
  sub {
   my $page = 0;

   # Create PDF with PDF::API2
   send( $parent, '0' . $main::d->get('Setting up PDF'), 0 );
   my $pdf = PDF::API2->new( -file => $filename );
   $pdf->info( get_pdf_metadata() );

   foreach (@pagelist) {
    ++$page;
    send(
     $parent,
     $page / ( $#pagelist + 2 )
       . sprintf( $main::d->get("Saving page %i of %i"), $page,
      $#pagelist + 1 ),
     0
    );

    my $pagedata = $self->{data}[$_][2];
    my $filename = $pagedata->{filename};
    my $image    = Image::Magick->new;
    my $x        = $image->Read($filename);
    $main::logger->warn($x) if "$x";

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
    if ( $main::SETTING{'pdf compression'} eq 'auto' ) {
     $depth = $image->Get('depth');
     $main::logger->info("Depth of $filename is $depth");
     if ( $depth == 1 ) {
      $compression = 'lzw';
     }
     else {
      $type = $image->Get('type');
      $main::logger->info("Type of $filename is $type");
      if ( $type =~ /TrueColor/ ) {
       $compression = 'jpg';
      }
      else {
       $compression = 'png';
      }
     }
     $main::logger->info("Selecting $compression compression");
    }
    else {
     $compression = $main::SETTING{'pdf compression'};
    }

    # Convert file if necessary
    my $format;
    $format = $1 if ( $filename =~ /\.(\w*)$/ );
    if (( $compression ne 'none' and $compression ne $format )
     or $main::SETTING{'downsample'}
     or $compression eq 'jpg' )
    {
     if ( $compression !~ /(jpg|png)/ and $format ne 'tif' ) {
      my $ofn = $filename;
      ( undef, $filename ) =
        tempfile( DIR => $main::SETTING{session}, SUFFIX => '.tif' );
      $main::logger->info("Converting $ofn to $filename");
     }
     elsif ( $compression =~ /(jpg|png)/ ) {
      my $ofn = $filename;
      ( undef, $filename ) = tempfile(
       DIR    => $main::SETTING{session},
       SUFFIX => ".$compression"
      );
      $main::logger->info("Converting $ofn to $filename");
     }

     $depth = $image->Get('depth') if ( not defined($depth) );
     if ( $main::SETTING{'downsample'} ) {
      $output_resolution = $main::SETTING{'downsample dpi'};
      my $w_pixels = $w * $output_resolution;
      my $h_pixels = $h * $output_resolution;

      $main::logger->info("Resizing $filename to $w_pixels x $h_pixels");
      $x = $image->Resize( width => $w_pixels,, height => $h_pixels );
      $main::logger->warn($x) if "$x";
     }
     $x = $image->Set( quality => $main::SETTING{quality} )
       if ( $compression eq 'jpg' );
     $main::logger->warn($x) if "$x";

     if (( $compression !~ /(jpg|png)/ and $format ne 'tif' )
      or ( $compression =~ /(jpg|png)/ )
      or $main::SETTING{'downsample'} )
     {

# depth required because resize otherwise increases depth to maintain information
      $main::logger->info(
       "Writing temporary image $filename with depth $depth");
      $x = $image->Write( filename => $filename, depth => $depth );
      $main::logger->warn($x) if "$x";
      $format = $1 if ( $filename =~ /\.(\w*)$/ );
     }

     if ( $compression !~ /(jpg|png)/ ) {
      my ( undef, $filename2 ) =
        tempfile( DIR => $main::SETTING{session}, SUFFIX => '.tif' );
      my $cmd = "tiffcp -c $compression $filename $filename2";
      $main::logger->info($cmd);
      my $status = system("$cmd 2>$main::SETTING{session}/tiffcp.stdout");
      if ( $status != 0 ) {
       my $output = slurp("$main::SETTING{session}/tiffcp.stdout");
       $main::logger->info($output);
       send(
        $parent,
        '-1' . sprintf( $main::d->get("Error compressing image: %s"), $output ),
        0
       );
      }
      $filename = $filename2;
     }
    }

    $main::logger->info(
     "Defining page at ",
     $w * $POINTS_PER_INCH,
     "pt x ", $h * $POINTS_PER_INCH, "pt"
    );
    my $page = $pdf->page;
    $page->mediabox( $w * $POINTS_PER_INCH, $h * $POINTS_PER_INCH );

    # Add OCR as text behind the scan
    if ( defined( $pagedata->{buffer} ) ) {
     $main::logger->info("Embedding OCR output behind image");
     my $font   = $pdf->corefont('Times-Roman');
     my $text   = $page->text;
     my $canvas = $pagedata->{buffer};
     my $root   = $canvas->get_root_item;
     my $n      = $root->get_n_children;
     for ( my $i = 0 ; $i < $n ; $i++ ) {
      my $group = $root->get_child($i);
      if ( $group->isa('Goo::Canvas::Group') ) {
       my $bounds = $group->get_bounds;
       my ( $x1, $y1, $x2, $y2 ) =
         ( $bounds->x1 + 1, $bounds->y1 + 1, $bounds->x2 - 1, $bounds->y2 - 1 );
       my $n = $group->get_n_children;
       for ( my $i = 0 ; $i < $n ; $i++ ) {
        my $item = $group->get_child($i);
        if ( $item->isa('Goo::Canvas::Text') ) {
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
          $text->text( $item->get('text') );
         }
         else {

          # Box is the same size as the page. We don't know the text position.
          # Start at the top of the page (PDF coordinate system starts
          # at the bottom left of the page)
          my $size = 1;
          $text->font( $font, $size );
          my $y = $h * $POINTS_PER_INCH;
          foreach my $line ( split( "\n", $item->get('text') ) ) {
           my $x = 0;

           # Add a word at a time in order to linewrap
           foreach my $word ( split( ' ', $line ) ) {
            if ( length($word) * $size + $x > $w * $POINTS_PER_INCH ) {
             $x = 0;
             $y -= $size;
            }
            $text->translate( $x, $y );
            $word = ' ' . $word if ( $x > 0 );
            $x += $text->text($word);
           }
           $y -= $size;
          }
         }
        }
       }
      }
     }
    }

    # Add scan
    my $gfx = $page->gfx;
    my $imgobj;
    my $msg;
    if ( $format eq 'png' ) {
     eval { $imgobj = $pdf->image_png($filename) };
     $msg = "$@";
    }
    elsif ( $format eq 'jpg' ) {
     eval { $imgobj = $pdf->image_jpeg($filename) };
     $msg = "$@";
    }
    elsif ( $format eq 'pnm' ) {
     eval { $imgobj = $pdf->image_pnm($filename) };
     $msg = "$@";
    }
    elsif ( $format eq 'gif' ) {
     eval { $imgobj = $pdf->image_gif($filename) };
     $msg = "$@";
    }
    elsif ( $format eq 'tif' ) {
     eval { $imgobj = $pdf->image_tiff($filename) };
     $msg = "$@";
    }
    else {
     $msg = "Unknown format $format file $filename";
    }
    if ($msg) {
     $main::logger->warn($msg);
     send(
      $parent,
      '-1'
        . sprintf( $main::d->get("Error creating PDF image object: %s"), $msg ),
      0
     );
    }
    else {
     eval {
      $gfx->image( $imgobj, 0, 0, $w * $POINTS_PER_INCH,
       $h * $POINTS_PER_INCH );
     };
     if ($@) {
      $main::logger->warn($@);
      send(
       $parent,
       '-1'
         . sprintf(
        $main::d->get("Error embedding file image in %s format to PDF: %s"),
        $format, $@
         ),
       0
      );
     }
     else {
      $main::logger->info("Adding $filename at $output_resolution PPI");
     }
    }
   }
   send( $parent, '1' . $main::d->get('Closing PDF'), 0 );
   $pdf->save;
   $pdf->end;
   send( $parent, '2', 0 );
  }
 );

 $main::helperTag{$pid} = Glib::IO->add_watch(
  $child->fileno(),
  [ 'in', 'hup' ],
  sub {
   my ( $fileno, $condition ) = @_;

   my $line;
   if ( $condition & 'in' ) {    # bit field operation. >= would also work
    recv( $child, $line, 1000, 0 );
    if ( $line =~ /(-?\d*\.?\d*)(.*)/ ) {
     my $fraction = $1;
     my $text     = $2;
     if ( $fraction == -1 ) {
      show_message_dialog( $main::window, 'error', 'close', $text );
     }
     elsif ( $fraction > 1 ) {
      $dialog->destroy;
      mark_pages(@pagelist);

      # create email if required
      if ( defined $mua_string ) {
       show_message_dialog( $main::window, 'error', 'close',
        $main::d->get('Error creating email') )
         if ( system($mua_string) );
      }

      return FALSE;    # uninstall
     }
     else {
      $pbar->set_fraction($fraction);
      $pbar->set_text($text);
     }
    }
   }

# Can't have elsif here because of the possibility that both in and hup are set.
# Only allow the hup if sure an empty buffer has been read.
   if ( ( $condition & 'hup' ) and ( not defined($line) or $line eq '' ) )
   {                   # bit field operation. >= would also work
    $dialog->destroy;
    return FALSE;      # uninstall
   }
   return TRUE;        # continue without uninstalling
  }
 );
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
   Gscan2pdf::_enqueue_request( 'rotate', { angle => $angle, page => $page } );
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
   $self->get_model->signal_handler_block( $self->{row_changed_signal} )
     if defined( $self->{row_changed_signal} );
   $self->{data}[$i][1] =
     get_pixbuf( $data->{new}{filename}, $main::heightt, $main::widtht );
   $self->{data}[$i][2] = $data->{new} if ( $i <= $#{ $self->{data} } );
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

sub analyse {
 my ( $self, $page, $finished_callback, $not_finished_callback,
  $error_callback ) = @_;

 my $sentinel = Gscan2pdf::_enqueue_request( 'analyse', { page => $page } );
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
  { threshold => $threshold, page => $page } );
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

 my $sentinel = Gscan2pdf::_enqueue_request( 'negate', { page => $page } );
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
   page      => $page,
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
   page => $page,
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

1;

__END__
