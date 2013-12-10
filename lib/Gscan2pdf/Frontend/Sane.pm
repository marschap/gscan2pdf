package Gscan2pdf::Frontend::Sane;

use strict;
use warnings;
use feature "switch";

use threads;
use threads::shared;
use Thread::Queue;

use Glib qw(TRUE FALSE);
use Sane;
use Readonly;
Readonly my $BUFFER_SIZE    => ( 32 * 1024 );     # default size
Readonly my $_POLL_INTERVAL => 100;               # ms
Readonly my $_8_BIT         => 8;
Readonly my $MAXVAL_8_BIT   => 2**$_8_BIT - 1;
Readonly my $_16_BIT        => 16;
Readonly my $MAXVAL_16_BIT  => 2**$_16_BIT - 1;

our $VERSION = '1.2.0';

my $_self;
my ( $prog_name, $logger );

sub setup {
 ( my $class, $logger ) = @_;
 $_self     = {};
 $prog_name = Glib::get_application_name;

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
   if ( ${$sentinel} ) {
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
   if ( not $started ) { $started_callback->() }
   $finished_callback->( $_self->{device_list} );
  },
  sub {
   if ( not $started ) {
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
   if ( not $started and defined( $options{started_callback} ) ) {
    $options{started_callback}->();
   }
   if ( $_self->{status} == SANE_STATUS_GOOD ) {
    if ( defined $options{finished_callback} ) {
     $options{finished_callback}->();
    }
   }
   else {
    if ( defined $options{error_callback} ) {
     $options{error_callback}->( Sane::strstatus( $_self->{status} ) );
    }
   }
  },
  sub {
   if ( not $started ) {
    if ( defined $options{started_callback} ) { $options{started_callback}->() }
    $started = 1;
   }
   if ( defined $options{running_callback} ) { $options{running_callback}->() }
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
   if ( not $started ) { $started_callback->() }
   if ( $_self->{status} == SANE_STATUS_GOOD ) {
    $finished_callback->($option_array);
   }
   else {
    $error_callback->( Sane::strstatus( $_self->{status} ) );
   }
  },
  sub {
   if ( not $started ) {
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
   if ( not $started and defined( $options{started_callback} ) ) {
    $options{started_callback}->();
   }
   if ( defined $options{finished_callback} ) {
    $options{finished_callback}->($option_array);
   }
  },
  sub {
   if ( not $started ) {
    if ( defined $options{started_callback} ) { $options{started_callback}->() }
    $started = 1;
   }
   if ( defined $options{running_callback} ) { $options{running_callback}->() }
  }
 );
 return;
}

sub _new_page {
 my ( $dir, $format, $n ) = @_;
 my $path = sprintf $format, $n;
 if ( defined $dir ) { $path = File::Spec->catdir( $dir, $path ) }
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
   if ( ${$sentinel} ) {

    # Check status of scan
    if (
         defined( $options{new_page_callback} )
     and not $_self->{abort_scan}
     and ( $_self->{status} == SANE_STATUS_GOOD
      or $_self->{status} == SANE_STATUS_EOF )
      )
    {
     $options{new_page_callback}->( $options{start} );
    }

    # Stop the process unless everything OK and more scans required
    if (
        $_self->{abort_scan}
     or ( $options{npages} and ++$n > $options{npages} )
     or ( $_self->{status} != SANE_STATUS_GOOD
      and $_self->{status} != SANE_STATUS_EOF )
      )
    {
     _enqueue_request('cancel');
     if ( _scanned_enough_pages( $options{npages}, $n ) ) {
      if ( defined $options{finished_callback} ) {
       $options{finished_callback}->();
      }
     }
     else {
      if ( defined $options{error_callback} ) {
       $options{error_callback}->( Sane::strstatus( $_self->{status} ) );
      }
     }
     return Glib::SOURCE_REMOVE;
    }

    $options{start} += $options{step};
    $sentinel = _new_page( $options{dir}, $options{format}, $options{start} );
    return Glib::SOURCE_CONTINUE;
   }
   else {
    if ( not $started ) {
     if ( defined $options{started_callback} ) {
      $options{started_callback}->();
     }
     $started = 1;
    }
    if ( defined $options{running_callback} ) {
     $options{running_callback}->( $_self->{scan_progress} );
    }
    return Glib::SOURCE_CONTINUE;
   }
  }
 );
 return;
}

sub _scanned_enough_pages {
 my ( $nrequired, $ndone ) = @_;
 return (
       $_self->{status} == SANE_STATUS_GOOD
    or $_self->{status} == SANE_STATUS_EOF
    or ( $_self->{status} == SANE_STATUS_NO_DOCS
   and $nrequired < $ndone )
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
 if ( defined( $self->{device_handle} ) ) { undef $self->{device_handle} }

 $self->{device_handle} = Sane::Device->open($device_name);
 $logger->debug("opening device '$device_name': $Sane::STATUS");
 if ( $Sane::STATUS != SANE_STATUS_GOOD ) {
  $logger->error("opening device '$device_name': $Sane::STATUS");
  return;
 }
 $self->{device_name} = $device_name;
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
 for ( 1 .. $num_dev_options - 1 ) {
  my $opt = $self->{device_handle}->get_option_descriptor($_);
  $options[$_] = $opt;
  if (
   not(( $opt->{cap} & SANE_CAP_INACTIVE )
    or ( $opt->{type} == SANE_TYPE_BUTTON )
    or ( $opt->{type} == SANE_TYPE_GROUP ) )
    )
  {
   $opt->{val} = $self->{device_handle}->get_option($_);
  }
 }

 ${$options} = shared_clone \@options;
 return;
}

sub _thread_set_option {
 my ( $self, $index, $value, $new_options ) = @_;

 # FIXME: Stringification to force this SV to have a PV slot.  This seems to
 # be necessary to get through Sane.pm's value checks.
 $value = "$value";

 my $info = $self->{device_handle}->set_option( $index, $value );
 if ( $logger->is_info ) {
  my $status = $Sane::STATUS;
  my $opt    = $self->{device_handle}->get_option_descriptor($index);
  $logger->info(
"sane_set_option $index ($opt->{name}) to $value returned status $status with info $info"
  );
 }

 # FIXME: This duplicates _thread_get_options.
 if ( $info & SANE_INFO_RELOAD_OPTIONS ) {
  my $num_dev_options = $self->{device_handle}->get_option(0);
  if ( $Sane::STATUS != SANE_STATUS_GOOD ) {
   $logger->error("unable to determine option count");
   return;
  }

  my @options;
  for ( 1 .. $num_dev_options - 1 ) {
   my $opt = $self->{device_handle}->get_option_descriptor($_);
   $options[$_] = $opt;
   if ( not $opt->{cap} & SANE_CAP_SOFT_DETECT ) { next }

   if ( $opt->{type} != SANE_TYPE_BUTTON ) {
    $opt->{val} = $self->{device_handle}->get_option($_);
   }
  }

  ${$new_options} = shared_clone \@options;
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
    ( $depth > $_8_BIT ) ? $MAXVAL_16_BIT : $MAXVAL_8_BIT;
 }
 else {
  if ( $depth == 1 ) {
   printf $fh "P4\n# SANE data follows\n%d %d\n", $width, $height;
  }
  else {
   printf $fh "P5\n# SANE data follows\n%d %d\n%d\n", $width, $height,
     ( $depth > $_8_BIT ) ? $MAXVAL_16_BIT : $MAXVAL_8_BIT;
  }
 }
 return;
}

sub _thread_scan_page_to_fh {
 my ( $device, $fh ) = @_;
 my $first_frame = 1;
 my $offset      = 0;
 my $must_buffer = 0;
 my %image;
 my @format_name = ( "gray", "RGB", "red", "green", "blue" );
 my $total_bytes = 0;

 my ( $parm, $last_frame );
 while ( not $last_frame ) {
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

  _log_frame_info( $first_frame, $parm, \@format_name );
  ( $must_buffer, $offset ) = _initialise_scan( $fh, $first_frame, $parm );
  my $hundred_percent = _scan_data_size($parm);

  while (1) {

   # Pick up flag from cancel_scan()
   if ( $_self->{abort_scan} ) {
    $device->cancel;
    $logger->info('Scan cancelled');
    return;
   }

   my ( $buffer, $len ) = $device->read($BUFFER_SIZE);
   $total_bytes += $len;
   my $progr = $total_bytes / $hundred_percent;
   if ( $progr > 1 ) { $progr = 1 }
   $_self->{scan_progress} = $progr;

   if ( $Sane::STATUS != SANE_STATUS_GOOD ) {
    if ( $parm->{depth} == $_8_BIT ) {
     $logger->info( sprintf "$prog_name: min/max graylevel value = %d/%d",
      $MAXVAL_8_BIT, 0 );
    }
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
  $last_frame  = $parm->{last_frame};
 }

 if ($must_buffer) { _write_buffer_to_fh( $fh, $parm, \%image ) }

cleanup:
 my $expected_bytes =
   $parm->{bytes_per_line} * $parm->{lines} * _number_frames($parm);
 if ( $parm->{lines} < 0 ) { $expected_bytes = 0 }
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

 if ( not defined( $self->{device_handle} ) ) {
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
 if ( defined $self->{device_handle} ) { $self->{device_handle}->cancel }
 return;
}

sub _log_frame_info {
 my ( $first_frame, $parm, $format_name ) = @_;
 if ($first_frame) {
  if ( $parm->{lines} >= 0 ) {
   $logger->info(
    sprintf "$prog_name: scanning image of size %dx%d pixels at "
      . "%d bits/pixel",
    $parm->{pixels_per_line},
    $parm->{lines},
    $_8_BIT * $parm->{bytes_per_line} / $parm->{pixels_per_line}
   );
  }
  else {
   $logger->info(
    sprintf "$prog_name: scanning image %d pixels wide and "
      . "variable height at %d bits/pixel",
    $parm->{pixels_per_line},
    $_8_BIT * $parm->{bytes_per_line} / $parm->{pixels_per_line}
   );
  }

  $logger->info(
   sprintf "$prog_name: acquiring %s frame",
   $parm->{format} <= SANE_FRAME_BLUE
   ? $format_name->[ $parm->{format} ]
   : "Unknown"
  );
 }
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
   if ( $parm->{depth} != $_8_BIT ) {
    die "Red/Green/Blue frames require depth=$_8_BIT\n";
   }
   $must_buffer = 1;
   $offset      = $parm->{format} - SANE_FRAME_RED;
  }
  elsif ( $parm->{format} == SANE_FRAME_RGB ) {
   if ( ( $parm->{depth} != $_8_BIT ) and ( $parm->{depth} != $_16_BIT ) ) {
    die "RGB frames require depth=$_8_BIT or $_16_BIT\n";
   }
  }
  if ($parm->{format} == SANE_FRAME_RGB
   or $parm->{format} == SANE_FRAME_GRAY )
  {
   if ( ( $parm->{depth} != 1 )
    and ( $parm->{depth} != $_8_BIT )
    and ( $parm->{depth} != $_16_BIT ) )
   {
    die "Valid depths are 1, $_8_BIT or $_16_BIT\n";
   }
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

# Return size of final scan (ignoring header)

sub _scan_data_size {
 my ($parm) = @_;
 return $parm->{bytes_per_line} * $parm->{lines} * _number_frames($parm);
}

# Return number of frames

sub _number_frames {
 my ($parm) = @_;
 return (
       $parm->{format} == SANE_FRAME_RGB
    or $parm->{format} == SANE_FRAME_GRAY
   )
   ? 1
   : 3;    ## no critic (ProhibitMagicNumbers)
}

# We're either scanning a multi-frame image or the
# scanner doesn't know what the eventual image height
# will be (common for hand-held scanners).  In either
# case, we need to buffer all data before we can write
# the header

sub _buffer_scan {
 my ( $offset, $parm, $image, $len, $buffer ) = @_;

 my $number_frames = _number_frames($parm);
 for ( 0 .. $len - 1 ) {
  $image->{data}[ $offset + $number_frames * $_ ] = substr( $buffer, $_, 1 );
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
  $image->{height} /= _number_frames($parm);
 }
 _thread_write_pnm_header( $fh, $parm->{format}, $parm->{pixels_per_line},
  $image->{height}, $parm->{depth} );
 for ( @{ $image->{data} } ) { print $fh; }
 return;
}

1;

__END__
