package Gscan2pdf::Frontend::Sane;

use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Queue;

use Glib qw(TRUE FALSE);
use Sane;

my $_POLL_INTERVAL;
my $_self;
my $buffer_size = ( 32 * 1024 );    # default size
my ( $prog_name, $d, $logger );

sub setup {
 ( my $class, $prog_name, $d, $logger ) = @_;
 $_POLL_INTERVAL = 100;             # ms
 $_self          = {};

 $_self->{requests} = Thread::Queue->new;
 share $_self->{device_list};
 share $_self->{device_name};

 # $_self->{device_handle} explicitly not shared
 share $_self->{status};
 share $_self->{abort_scan};
 share $_self->{scan_progress};

 $_self->{thread} = threads->new( \&_thread_main, $_self );
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
 return \$sentinel;
}

sub _when_ready {
 my ( $sentinel, $ready_callback, $not_ready_callback ) = @_;
 Glib::Timeout->add(
  $_POLL_INTERVAL,
  sub {
   if ($$sentinel) {
    $ready_callback->();
    return Glib::SOURCE_REMOVE;
   }
   else {
    if ( defined $not_ready_callback ) {
     $not_ready_callback->();
    }
    return Glib::SOURCE_CONTINUE;
   }
  }
 );
 return;
}

sub quit {
 _enqueue_request('quit');
 $_self->{thread}->join();
 $_self->{thread} = undef;
 return;
}

sub get_devices {
 my ( $class, $started_callback, $running_callback, $finished_callback ) = @_;

 my $sentinel = _enqueue_request('get-devices');

 my $started;
 _when_ready(
  $sentinel,
  sub {
   $started_callback->() unless ($started);
   $finished_callback->( $_self->{device_list} );
  },
  sub {
   unless ($started) {
    $started_callback->();
    $started = 1;
   }
   $running_callback->();
  }
 );
 return;
}

sub is_connected {
 return defined $_self->{device_name};
}

sub device {
 return $_self->{device_name};
}

sub open_device {
 my ( $class, $device, $started_callback, $running_callback, $finished_callback,
  $error_callback )
   = @_;

 my $sentinel = _enqueue_request( 'open', { device_name => $device } );

 my $started;
 _when_ready(
  $sentinel,
  sub {
   $started_callback->() unless ($started);
   if ( $_self->{status} == SANE_STATUS_GOOD ) {
    $finished_callback->();
   }
   else {
    $error_callback->( Sane::strstatus( $_self->{status} ) );
   }
  },
  sub {
   unless ($started) {
    $started_callback->();
    $started = 1;
   }
   $running_callback->();
  }
 );
 return;
}

sub find_scan_options {
 my (
  $class,             $started_callback, $running_callback,
  $finished_callback, $error_callback
 ) = @_;

 my $options : shared;
 my $sentinel = _enqueue_request( 'get-options', { options => \$options } );

 my $started;
 _when_ready(
  $sentinel,
  sub {
   $started_callback->() unless ($started);
   if ( $_self->{status} == SANE_STATUS_GOOD ) {
    $finished_callback->($options);
   }
   else {
    $error_callback->( Sane::strstatus( $_self->{status} ) );
   }
  },
  sub {
   unless ($started) {
    $started_callback->();
    $started = 1;
   }
   $running_callback->();
  }
 );
 return;
}

sub set_option {
 my ( $class, $i, $val, $started_callback, $running_callback,
  $finished_callback )
   = @_;

 my $options : shared;
 my $sentinel = _enqueue_request(
  'set-option',
  {
   index       => $i,
   value       => $val,
   new_options => \$options
  }
 );

 my $started;
 _when_ready(
  $sentinel,
  sub {
   $started_callback->() unless ($started);
   $finished_callback->($options);
  },
  sub {
   unless ($started) {
    $started_callback->();
    $started = 1;
   }
   $running_callback->();
  }
 );
 return;
}

sub _new_page {
 my ( $dir, $format, $n ) = @_;
 my $path = sprintf $format, $n;
 return _enqueue_request( 'scan-page',
  { path => File::Spec->catdir( $dir, $path ) } );
}

sub scan_pages {
 my (
  $class,             $dir,              $format,
  $npages,            $n,                $step,
  $started_callback,  $running_callback, $finished_callback,
  $new_page_callback, $error_callback
 ) = @_;

 $_self->{status}        = SANE_STATUS_GOOD;
 $_self->{abort_scan}    = 0;
 $_self->{scan_progress} = 0;
 my $sentinel = _new_page( $dir, $format, $n );

 my $n2      = 1;
 my $npages2 = $npages;

 my $started;
 Glib::Timeout->add(
  $_POLL_INTERVAL,
  sub {
   if ( not $$sentinel ) {
    unless ($started) {
     $started_callback->();
     $started = 1;
    }
    $running_callback->( $_self->{scan_progress} );
    return Glib::SOURCE_CONTINUE;
   }
   else {

    # Check status of scan
    if ($_self->{status} == SANE_STATUS_GOOD
     or $_self->{status} == SANE_STATUS_EOF )
    {
     $new_page_callback->($n);
    }

    # Stop the process unless everything OK and more scans required
    unless (
     ( $npages == -1 or --$npages )
     and ( $_self->{status} == SANE_STATUS_GOOD
      or $_self->{status} == SANE_STATUS_EOF )
      )
    {
     _enqueue_request('cancel');
     if (
         $_self->{status} == SANE_STATUS_GOOD
      or $_self->{status} == SANE_STATUS_EOF
      or ( $_self->{status} == SANE_STATUS_NO_DOCS
       and $npages < 1
       and $n2 > 1 )
       )
     {
      $finished_callback->();
     }
     else {
      $error_callback->( Sane::strstatus( $_self->{status} ) );
     }
     return Glib::SOURCE_REMOVE;
    }

    $n += $step;
    $n2++;
    $sentinel = _new_page( $dir, $format, $n );
    return Glib::SOURCE_CONTINUE;
   }
  }
 );
 return;
}

sub _thread_main {
 my ($self) = @_;

 while ( my $request = $self->{requests}->dequeue ) {
  if ( $request->{action} eq 'quit' ) {
   last;
  }

  elsif ( $request->{action} eq 'get-devices' ) {
   _thread_get_devices($self);
  }

  elsif ( $request->{action} eq 'open' ) {
   _thread_open_device( $self, $request->{device_name} );
  }

  elsif ( $request->{action} eq 'get-options' ) {
   _thread_get_options( $self, $request->{options} );
  }

  elsif ( $request->{action} eq 'set-option' ) {
   _thread_set_option( $self, $request->{index}, $request->{value},
    $request->{new_options} );
  }

  elsif ( $request->{action} eq 'scan-page' ) {
   _thread_scan_page( $self, $request->{path} );
  }

  elsif ( $request->{action} eq 'cancel' ) {
   _thread_cancel($self);
  }

  else {
   $logger->info( "Ignoring unknown request " . $request->{action} );
   next;
  }

  # Store the current status in the shared status variable.  Otherwise, the
  # main thread has no way to access this thread's $Sane::STATUS.  Numerify to
  # please thread::shared.
  $self->{status} = $Sane::STATUS + 0;

  # Signal the sentinel that the request was completed.
  ${ $request->{sentinel} }++;
 }
 return;
}

sub _thread_get_devices {
 my ($self) = @_;
 my @devices = Sane->get_devices;
 $self->{device_list} = shared_clone \@devices;
 return;
}

sub _thread_open_device {
 my ( $self, $device_name ) = @_;

 # close the handle
 undef $self->{device_handle} if ( defined( $self->{device_handle} ) );

 $self->{device_handle} = Sane::Device->open($device_name);
 if ( $Sane::STATUS != SANE_STATUS_GOOD ) {
  $logger->error("opening device: $Sane::STATUS");
  return;
 }
 else {
  $self->{device_name} = $device_name;
 }
 return;
}

sub _thread_get_options {
 my ( $self, $options ) = @_;
 my @options;

 # We got a device, find out how many options it has:
 my $num_dev_options = $self->{device_handle}->get_option(0);
 if ( $Sane::STATUS != SANE_STATUS_GOOD ) {
  $logger->error("unable to determine option count");
  return;
 }
 for ( my $i = 1 ; $i < $num_dev_options ; ++$i ) {
  my $opt = $self->{device_handle}->get_option_descriptor($i);
  $options[$i] = $opt;
  $opt->{val} = $self->{device_handle}->get_option($i)
    if (
   not(( $opt->{cap} & SANE_CAP_INACTIVE )
    or ( $opt->{type} == SANE_TYPE_BUTTON )
    or ( $opt->{type} == SANE_TYPE_GROUP ) )
    );
 }

 $$options = shared_clone \@options;
 return;
}

sub _thread_set_option {
 my ( $self, $index, $value, $new_options ) = @_;

 # FIXME: Stringification to force this SV to have a PV slot.  This seems to
 # be necessary to get through Sane.pm's value checks.
 $value = "$value";

 my $info = $self->{device_handle}->set_option( $index, $value );
 $logger->info("sane_set_option returned status $Sane::STATUS with info $info");

 # FIXME: This duplicates _thread_get_options.
 if ( $info & SANE_INFO_RELOAD_OPTIONS ) {
  my $num_dev_options = $self->{device_handle}->get_option(0);
  if ( $Sane::STATUS != SANE_STATUS_GOOD ) {
   $logger->error("unable to determine option count");
   return;
  }

  my @options;
  for ( my $i = 1 ; $i < $num_dev_options ; ++$i ) {
   my $opt = $self->{device_handle}->get_option_descriptor($i);
   $options[$i] = $opt;
   next if ( !( $opt->{cap} & SANE_CAP_SOFT_DETECT ) );

   $opt->{val} = $self->{device_handle}->get_option($i)
     if ( $opt->{type} != SANE_TYPE_BUTTON );
  }

  $$new_options = shared_clone \@options;
 }
 return;
}

sub _thread_write_pnm_header {
 my ( $fh, $format, $width, $height, $depth ) = @_;

 # The netpbm-package does not define raw image data with maxval > 255.
 # But writing maxval 65535 for 16bit data gives at least a chance
 # to read the image.

 if ($format == SANE_FRAME_RED
  or $format == SANE_FRAME_GREEN
  or $format == SANE_FRAME_BLUE
  or $format == SANE_FRAME_RGB )
 {
  printf $fh "P6\n# SANE data follows\n%d %d\n%d\n", $width, $height,
    ( $depth <= 8 ) ? 255 : 65535;
 }
 else {
  if ( $depth == 1 ) {
   printf $fh "P4\n# SANE data follows\n%d %d\n", $width, $height;
  }
  else {
   printf $fh "P5\n# SANE data follows\n%d %d\n%d\n", $width, $height,
     ( $depth <= 8 ) ? 255 : 65535;
  }
 }
 return;
}

sub _thread_scan_page_to_fh {
 my ( $device, $fh ) = @_;
 my $first_frame = 1;
 my $offset      = 0;
 my $must_buffer = 0;
 my $min         = 0xff;
 my $max         = 0;
 my %image;
 my @format_name = ( "gray", "RGB", "red", "green", "blue" );
 my $total_bytes = 0;

 my $parm;
 {
  do {    # extra braces to get last to work.
   if ( !$first_frame ) {
    $device->start;
    if ( $Sane::STATUS != SANE_STATUS_GOOD ) {
     $logger->info("$prog_name: sane_start: $Sane::STATUS");
     goto cleanup;
    }
   }

   $parm = $device->get_parameters;
   if ( $Sane::STATUS != SANE_STATUS_GOOD ) {
    $logger->info("$prog_name: sane_get_parameters: $Sane::STATUS");
    goto cleanup;
   }

   if ($first_frame) {
    if ( $parm->{lines} >= 0 ) {
     $logger->info(
      sprintf "$prog_name: scanning image of size %dx%d pixels at "
        . "%d bits/pixel",
      $parm->{pixels_per_line},
      $parm->{lines},
      8 * $parm->{bytes_per_line} / $parm->{pixels_per_line}
     );
    }
    else {
     $logger->info(
      sprintf "$prog_name: scanning image %d pixels wide and "
        . "variable height at %d bits/pixel",
      $parm->{pixels_per_line},
      8 * $parm->{bytes_per_line} / $parm->{pixels_per_line}
     );
    }

    $logger->info(
     sprintf "$prog_name: acquiring %s frame",
     $parm->{format} <= SANE_FRAME_BLUE
     ? $format_name[ $parm->{format} ]
     : "Unknown"
    );
   }

   if ($first_frame) {
    if ($parm->{format} == SANE_FRAME_RED
     or $parm->{format} == SANE_FRAME_GREEN
     or $parm->{format} == SANE_FRAME_BLUE )
    {
     die unless ( $parm->{depth} == 8 );
     $must_buffer = 1;
     $offset      = $parm->{format} - SANE_FRAME_RED;
    }
    elsif ( $parm->{format} == SANE_FRAME_RGB ) {
     die unless ( ( $parm->{depth} == 8 ) || ( $parm->{depth} == 16 ) );
    }
    if ($parm->{format} == SANE_FRAME_RGB
     or $parm->{format} == SANE_FRAME_GRAY )
    {
     die
       unless ( ( $parm->{depth} == 1 )
      || ( $parm->{depth} == 8 )
      || ( $parm->{depth} == 16 ) );
     if ( $parm->{lines} < 0 ) {
      $must_buffer = 1;
      $offset      = 0;
     }
     else {
      _thread_write_pnm_header( $fh, $parm->{format}, $parm->{pixels_per_line},
       $parm->{lines}, $parm->{depth} );
     }
    }
   }
   else {
    die
      unless ( $parm->{format} >= SANE_FRAME_RED
     && $parm->{format} <= SANE_FRAME_BLUE );
    $offset = $parm->{format} - SANE_FRAME_RED;
    $image{x} = $image{y} = 0;
   }
   my $hundred_percent = $parm->{bytes_per_line} * $parm->{lines} * (
    ( $parm->{format} == SANE_FRAME_RGB || $parm->{format} == SANE_FRAME_GRAY )
    ? 1
    : 3
   );

   while (1) {
    $device->cancel if ( $_self->{abort_scan} );
    my ( $buffer, $len ) = $device->read($buffer_size);
    $total_bytes += $len;
    my $progr = $total_bytes / $hundred_percent;
    $progr = 1 if ( $progr > 1 );
    $_self->{scan_progress} = $progr;

    if ( $Sane::STATUS != SANE_STATUS_GOOD ) {
     $logger->info( sprintf "$prog_name: min/max graylevel value = %d/%d",
      $min, $max )
       if ( $parm->{depth} == 8 );
     if ( $Sane::STATUS != SANE_STATUS_EOF ) {
      $logger->info("$prog_name: sane_read: $Sane::STATUS");
      return;
     }
     last;
    }

    if ($must_buffer) {

     # We're either scanning a multi-frame image or the
     # scanner doesn't know what the eventual image height
     # will be (common for hand-held scanners).  In either
     # case, we need to buffer all data before we can write
     # the image
     if ($parm->{format} == SANE_FRAME_RED
      or $parm->{format} == SANE_FRAME_GREEN
      or $parm->{format} == SANE_FRAME_BLUE )
     {
      for ( my $i = 0 ; $i < $len ; ++$i ) {
       $image{data}[ $offset + 3 * $i ] = substr( $buffer, $i, 1 );
      }
      $offset += 3 * $len;
     }
     elsif ( $parm->{format} == SANE_FRAME_RGB
      or $parm->{format} == SANE_FRAME_GRAY )
     {
      for ( my $i = 0 ; $i < $len ; ++$i ) {
       $image{data}[ $offset + $i ] = substr( $buffer, $i, 1 );
      }
      $offset += $len;
     }
    }
    else {    # ! must_buffer
     print $fh $buffer;
    }
   }
   $first_frame = 0;
  } while ( !$parm->{last_frame} );
 }

 if ($must_buffer) {
  if ( $parm->{lines} > 0 ) {
   $image{height} = $parm->{lines};
  }
  else {
   $image{height} = @{ $image{data} } / $parm->{pixels_per_line};
   $image{height} /= 3
     if ( $parm->{format} == SANE_FRAME_RED
    or $parm->{format} == SANE_FRAME_GREEN
    or $parm->{format} == SANE_FRAME_BLUE );
  }
  _thread_write_pnm_header( $fh, $parm->{format}, $parm->{pixels_per_line},
   $image{height}, $parm->{depth} );
  for ( @{ $image{data} } ) { print $fh; }
 }

cleanup:
 my $expected_bytes = $parm->{bytes_per_line} * $parm->{lines} * (
  ( $parm->{format} == SANE_FRAME_RGB || $parm->{format} == SANE_FRAME_GRAY )
  ? 1
  : 3
 );
 $expected_bytes = 0 if ( $parm->{lines} < 0 );
 if ( $total_bytes > $expected_bytes && $expected_bytes != 0 ) {
  $logger->info(
   sprintf "%s: WARNING: read more data than announced by backend " . "(%u/%u)",
   $prog_name, $total_bytes, $expected_bytes );
 }
 else {
  $logger->info( sprintf "%s: read %u bytes in total",
   $prog_name, $total_bytes );
 }
 return;
}

sub _thread_scan_page {
 my ( $self, $path ) = @_;

 $self->{device_handle}->start;
 $self->{status} = $Sane::STATUS + 0;
 if ( $Sane::STATUS != SANE_STATUS_GOOD ) {
  $logger->info("$prog_name: sane_start: $Sane::STATUS");
  return;
 }

 my $fh;
 if ( not open( $fh, ">", $path ) ) {    ## no critic
  $self->{device_handle}->cancel;
  $self->{status} = SANE_STATUS_ACCESS_DENIED;
  return;
 }

 _thread_scan_page_to_fh( $self->{device_handle}, $fh );
 $self->{status} = $Sane::STATUS + 0;

 close $fh;

 $logger->info( sprintf "Scanned page %s. (scanner status = %d)",
  $path, $Sane::STATUS );

 if ($Sane::STATUS != SANE_STATUS_GOOD
  && $Sane::STATUS != SANE_STATUS_EOF )
 {
  unlink($path);
 }

 return;
}

sub _thread_cancel {
 my ($self) = @_;
 $self->{device_handle}->cancel;
 return;
}

1;

__END__
