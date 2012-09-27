package Gscan2pdf::Frontend::CLI;

use strict;
use warnings;

use Carp;
use Text::ParseWords;
use Glib qw(TRUE FALSE);
use POSIX qw(locale_h :signal_h :errno_h :sys_wait_h);

my $_POLL_INTERVAL;
my $_self;
my ( $prog_name, $logger, $prefix );

sub setup {
 ( my $class, $logger, $prefix ) = @_;
 $_POLL_INTERVAL = 100;                          # ms
 $_self          = {};
 $prog_name      = Glib::get_application_name;
 return;
}

sub get_devices {
 my ( $class, %options ) = @_;
 my $running = TRUE;

 _run_cmd(
"$prefix scanimage --formatted-device-list=\"'%i','%d','%v','%m','%t'%n\" 2>/dev/null",
  $options{running_callback},
  sub {
   my ($output) = @_;
   $options{finished_callback}
     ->( Gscan2pdf::Frontend::CLI->parse_device_list($output) )
     if ( defined $options{finished_callback} );
  }
 );
 return;
}

sub parse_device_list {
 my ( $class, $output ) = @_;

 my (@device_list);

 $logger->info($output) if ( defined($output) );

 # parse out the device and model names
 my @words =
   &parse_line( ',', 0, substr( $output, 0, index( $output, "'\n" ) + 1 ) );
 while ( @words == 5 ) {
  $output = substr( $output, index( $output, "'\n" ) + 2, length($output) );
  push @device_list,
    {
   name   => $words[1],
   vendor => $words[2],
   model  => $words[3],
   type   => $words[4]
    };
  @words =
    &parse_line( ',', 0, substr( $output, 0, index( $output, "'\n" ) + 1 ) );
 }

 return \@device_list;
}

sub find_scan_options {
 my ( $class, %options ) = @_;

 # Get output from scanimage or scanadf.
 # Inverted commas needed for strange characters in device name
 my $cmd =
"$options{'scan prefix'} $options{frontend} --help --device-name='$options{device}'";
 $cmd .= " --mode='$options{mode}'" if ( defined $options{mode} );
 _run_cmd(
  $cmd,
  $options{running_callback},
  sub {
   my ($output) = @_;
   $options{finished_callback}->($output)
     if ( defined $options{finished_callback} );
  }
 );
 return;
}

sub _run_cmd {
 my ( $cmd, $running_callback, $finished_callback ) = @_;
 my $running = TRUE;

 # Timer will run until callback returns false
 my $timer = Glib::Timeout->add(
  $_POLL_INTERVAL,
  sub {
   if ($running) {
    $running_callback->() if ( defined $running_callback );
    return Glib::SOURCE_CONTINUE;
   }
   else {
    return Glib::SOURCE_REMOVE;
   }
  }
 );

 $logger->info($cmd);

 # Interface to frontend
 my $pid = open my $read, '-|', $cmd    ## no critic (RequireBriefOpen)
   or croak "can't open pipe: $!";
 $logger->info("Forked PID $pid");

 # Read without blocking
 my $output = '';
 Glib::IO->add_watch(
  fileno($read),
  [ 'in', 'hup' ],
  sub {
   my ( $fileno, $condition ) = @_;
   my ($line);
   if ( $condition & 'in' ) {    # bit field operation. >= would also work
    sysread $read, $line, 1024;
    $output .= $line;
   }

# Can't have elsif here because of the possibility that both in and hup are set.
# Only allow the hup if sure an empty buffer has been read.
   if ( ( $condition & 'hup' ) and ( not defined($line) or $line eq '' ) )
   {                             # bit field operation. >= would also work
    close $read;
    $logger->info('Waiting to reap process');
    $pid = waitpid( -1, &WNOHANG );    # So we don't leave zombies
    $logger->info("Reaped PID $pid");
    $running = FALSE;

    $finished_callback->($output) if ( defined $finished_callback );
    return Glib::SOURCE_REMOVE;
   }
   return Glib::SOURCE_CONTINUE;
  }
 );
 return;
}

1;

__END__
