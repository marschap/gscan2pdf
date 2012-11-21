package Gscan2pdf::Frontend::Sane;

use strict;
use warnings;
use feature "switch";

use threads;
use threads::shared;
use Thread::Queue;

use Glib qw(TRUE FALSE);
use Sane;

my $_POLL_INTERVAL;
my $_self;
my $buffer_size = ( 32 * 1024 );    # default size
my ( $prog_name, $logger );

sub setup {
 ( my $class, $logger ) = @_;
 $_POLL_INTERVAL = 100;                          # ms
 $_self          = {};
 $prog_name      = Glib::get_application_name;

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
 my ( $class, %options ) = @_;

 my $sentinel =
   _enqueue_request( 'open', { device_name => $options{device_name} } );

 my $started;
 _when_ready(
  $sentinel,
  sub {
   $options{started_callback}->()
     if ( not $started and defined( $options{started_callback} ) );
   if ( $_self->{status} == SANE_STATUS_GOOD ) {
    $options{finished_callback}->() if ( defined $options{finished_callback} );
   }
   else {
    $options{error_callback}->( Sane::strstatus( $_self->{status} ) )
      if ( defined $options{error_callback} );
   }
  },
  sub {
   unless ($started) {
    $options{started_callback}->() if ( defined $options{started_callback} );
    $started = 1;
   }
   $options{running_callback}->() if ( defined $options{running_callback} );
  }
 );
 return;
}

sub find_scan_options {
 my (
  $class,             $started_callback, $running_callback,
  $finished_callback, $error_callback
 ) = @_;

 my $option_array : shared;
 my $sentinel =
   _enqueue_request( 'get-options', { options => \$option_array } );

 my $started;
 _when_ready(
  $sentinel,
  sub {
   $started_callback->() unless ($started);
   if ( $_self->{status} == SANE_STATUS_GOOD ) {
    $finished_callback->($option_array);
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
 my ( $class, %options ) = @_;

 my $option_array : shared;
 my $sentinel = _enqueue_request(
  'set-option',
  {
   index       => $options{index},
   value       => $options{value},
   new_options => \$option_array
  }
 );

 my $started;
 _when_ready(
  $sentinel,
  sub {
   $options{started_callback}->()
     if ( not $started and defined( $options{started_callback} ) );
   $options{finished_callback}->($option_array)
     if ( defined $options{finished_callback} );
  },
  sub {
   unless ($started) {
    $options{started_callback}->() if ( defined $options{started_callback} );
    $started = 1;
   }
   $options{running_callback}->() if ( defined $options{running_callback} );
  }
 );
 return;
}

sub _new_page {
 my ( $dir, $format, $n ) = @_;
 my $path = sprintf $format, $n;
 $path = File::Spec->catdir( $dir, $path ) if ( defined $dir );
 return _enqueue_request( 'scan-page', { path => $path } );
}

sub scan_pages {
 my ( $class, %options ) = @_;

 $_self->{status}        = SANE_STATUS_GOOD;
 $_self->{abort_scan}    = 0;
 $_self->{scan_progress} = 0;
 my $sentinel = _new_page( $options{dir}, $options{format}, $options{start} );

 my $n = 1;
 my $started;
 Glib::Timeout->add(
  $_POLL_INTERVAL,
  sub {
   if ($$sentinel) {

    # Check status of scan
    $options{new_page_callback}->( $options{start} )
      if (
         defined( $options{new_page_callback} )
     and not $_self->{abort_scan}
     and ( $_self->{status} == SANE_STATUS_GOOD
      or $_self->{status} == SANE_STATUS_EOF )
      );

    # Stop the process unless everything OK and more scans required
    if (
        $_self->{abort_scan}
     or ( $options{npages} != -1 and --$options{npages} )
     or ( $_self->{status} != SANE_STATUS_GOOD
      and $_self->{status} != SANE_STATUS_EOF )
      )
    {
     _enqueue_request('cancel');
     if ( _scanned_enough_pages( $options{npages}, $n ) ) {
      $options{finished_callback}->()
        if ( defined $options{finished_callback} );
     }
     else {
      $options{error_callback}->( Sane::strstatus( $_self->{status} ) )
        if ( defined $options{error_callback} );
     }
     return Glib::SOURCE_REMOVE;
    }

    $options{start} += $options{step};
    $n++;
    $sentinel = _new_page( $options{dir}, $options{format}, $options{start} );
    return Glib::SOURCE_CONTINUE;
   }
   else {
    unless ($started) {
     $options{started_callback}->() if ( defined $options{started_callback} );
     $started = 1;
    }
    $options{running_callback}->( $_self->{scan_progress} )
      if ( defined $options{running_callback} );
    return Glib::SOURCE_CONTINUE;
   }
  }
 );
 return;
}

sub _scanned_enough_pages {
 my ( $ntodo, $ndone ) = @_;
 return (
       $_self->{status} == SANE_STATUS_GOOD
    or $_self->{status} == SANE_STATUS_EOF
    or ( $_self->{status} == SANE_STATUS_NO_DOCS
   and $ntodo < 1
   and $ndone > 1 )
 );
}

# Flag the scan routine to abort

sub cancel_scan {

 # Empty process queue first to stop any new process from starting
 $logger->info("Emptying process queue");
 while ( $_self->{requests}->dequeue_nb ) { }

 # Then send the thread a cancel signal
 $_self->{abort_scan} = 1;
 return;
}

sub _thread_main {
 my ($self) = @_;

 while ( my $request = $self->{requests}->dequeue ) {
  given ( $request->{action} ) {
   when ('quit')        { last }
   when ('get-devices') { _thread_get_devices($self) }
   when ('open') { _thread_open_device( $self, $request->{device_name} ) }
   when ('get-options') { _thread_get_options( $self, $request->{options} ) }
   when ('set-option') {
    _thread_set_option( $self, $request->{index}, $request->{value},
     $request->{new_options} )
   }
   when ('scan-page') { _thread_scan_page( $self, $request->{path} ) }
   when ('cancel') { _thread_cancel($self) }
   default {
    $logger->info("Ignoring unknown request $_");
    next;
   }
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
 $logger->debug("opening device: $Sane::STATUS");
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
 $logger->info(
"sane_set_option $index to $value returned status $Sane::STATUS with info $info"
 );

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
   if ( not $first_frame ) {
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

   ( $must_buffer, $offset ) = _initialise_scan( $fh, $first_frame, $parm );
   my $hundred_percent = $parm->{bytes_per_line} * $parm->{lines} * (
    ( $parm->{format} == SANE_FRAME_RGB or $parm->{format} == SANE_FRAME_GRAY )
    ? 1
    : 3
   );

   while (1) {

    # Pick up flag from cancel_scan()
    if ( $_self->{abort_scan} ) {
     $device->cancel;
     $logger->info('Scan cancelled');
     return;
    }

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
     $offset = _buffer_scan( $offset, $parm, \%image, $len, $buffer );
    }
    else {
     print $fh $buffer;
    }
   }
   $first_frame = 0;
  } while ( !$parm->{last_frame} );
 }

 _write_buffer_to_fh( $fh, $parm, \%image ) if ($must_buffer);

cleanup:
 my $expected_bytes = $parm->{bytes_per_line} * $parm->{lines} * (
  ( $parm->{format} == SANE_FRAME_RGB or $parm->{format} == SANE_FRAME_GRAY )
  ? 1
  : 3
 );
 $expected_bytes = 0 if ( $parm->{lines} < 0 );
 if ( $total_bytes > $expected_bytes and $expected_bytes != 0 ) {
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

 unless ( defined $self->{device_handle} ) {
  $logger->info("$prog_name: must open device before starting scan");
  return;
 }
 $self->{device_handle}->start;

 $self->{status} = $Sane::STATUS + 0;
 if ( $Sane::STATUS != SANE_STATUS_GOOD ) {
  $logger->info("$prog_name: sane_start: $Sane::STATUS");
  return;
 }

 my $fh;
 if ( not open( $fh, ">", $path ) ) {    ## no critic (RequireBriefOpen)
  $self->{device_handle}->cancel;
  $self->{status} = SANE_STATUS_ACCESS_DENIED;
  return;
 }

 _thread_scan_page_to_fh( $self->{device_handle}, $fh );
 $self->{status} = $Sane::STATUS + 0;

 close $fh;

 $logger->info( sprintf "Scanned page %s. (scanner status = %d)",
  $path, $Sane::STATUS );

 if ( $Sane::STATUS != SANE_STATUS_GOOD
  and $Sane::STATUS != SANE_STATUS_EOF )
 {
  unlink($path);
 }

 return;
}

sub _thread_cancel {
 my ($self) = @_;
 $self->{device_handle}->cancel if ( defined $self->{device_handle} );
 return;
}

sub _initialise_scan {
 my ( $fh, $first_frame, $parm ) = @_;
 my ( $must_buffer, $offset );
 if ($first_frame) {
  if ($parm->{format} == SANE_FRAME_RED
   or $parm->{format} == SANE_FRAME_GREEN
   or $parm->{format} == SANE_FRAME_BLUE )
  {
   die "Red/Green/Blue frames require depth=8\n"
     unless ( $parm->{depth} == 8 );
   $must_buffer = 1;
   $offset      = $parm->{format} - SANE_FRAME_RED;
  }
  elsif ( $parm->{format} == SANE_FRAME_RGB ) {
   die "RGB frames require depth=8 or 16\n"
     unless ( ( $parm->{depth} == 8 ) or ( $parm->{depth} == 16 ) );
  }
  if ($parm->{format} == SANE_FRAME_RGB
   or $parm->{format} == SANE_FRAME_GRAY )
  {
   die "Valid depths are 1, 8 or 16\n"
     unless ( ( $parm->{depth} == 1 )
    or ( $parm->{depth} == 8 )
    or ( $parm->{depth} == 16 ) );
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
  die "Encountered unknown format\n"
    if ( $parm->{format} < SANE_FRAME_RED
   or $parm->{format} > SANE_FRAME_BLUE );
  $offset = $parm->{format} - SANE_FRAME_RED;
 }
 return ( $must_buffer, $offset );
}

# We're either scanning a multi-frame image or the
# scanner doesn't know what the eventual image height
# will be (common for hand-held scanners).  In either
# case, we need to buffer all data before we can write
# the header
sub _buffer_scan {
 my ( $offset, $parm, $image, $len, $buffer ) = @_;

 # $parm->{format} == SANE_FRAME_RED or SANE_FRAME_GREEN or SANE_FRAME_BLUE
 my $number_frames = 3;
 $number_frames = 1
   if ( $parm->{format} == SANE_FRAME_RGB
  or $parm->{format} == SANE_FRAME_GRAY );

 for ( my $i = 0 ; $i < $len ; ++$i ) {
  $image->{data}[ $offset + $number_frames * $i ] = substr( $buffer, $i, 1 );
 }
 $offset += $number_frames * $len;
 return $offset;
}

sub _write_buffer_to_fh {
 my ( $fh, $parm, $image ) = @_;
 if ( $parm->{lines} > 0 ) {
  $image->{height} = $parm->{lines};
 }
 else {
  $image->{height} = @{ $image->{data} } / $parm->{pixels_per_line};
  $image->{height} /= 3
    if ( $parm->{format} == SANE_FRAME_RED
   or $parm->{format} == SANE_FRAME_GREEN
   or $parm->{format} == SANE_FRAME_BLUE );
 }
 _thread_write_pnm_header( $fh, $parm->{format}, $parm->{pixels_per_line},
  $image->{height}, $parm->{depth} );
 for ( @{ $image->{data} } ) { print $fh; }
 return;
}

1;

__END__
