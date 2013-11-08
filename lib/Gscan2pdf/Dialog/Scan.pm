package Gscan2pdf::Dialog::Scan;

use warnings;
use strict;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gscan2pdf::Dialog;
use feature "switch";
use Data::Dumper;

# need to register this with Glib before we can use it below
BEGIN {
 use Gscan2pdf::Scanner::Options;
 Glib::Type->register_enum( 'Gscan2pdf::Scanner::Dialog::Side',
  qw(facing reverse) );
}

# from http://gtk2-perl.sourceforge.net/doc/subclassing_widgets_in_perl.html
use Glib::Object::Subclass Gscan2pdf::Dialog::, signals => {
 'new-scan' => {
  param_types => ['Glib::UInt'],    # page number
 },
 'changed-device' => {
  param_types => ['Glib::String'],    # device name
 },
 'changed-device-list' => {
  param_types => ['Glib::Scalar'],    # array of hashes with device info
 },
 'changed-num-pages' => {
  param_types => ['Glib::UInt'],      # new number of pages to scan
 },
 'changed-page-number-start' => {
  param_types => ['Glib::UInt'],      # new start page
 },
 'changed-page-number-increment' => {
  param_types => ['Glib::Int'],       # new increment
 },
 'changed-side-to-scan' => {
  param_types => ['Glib::String'],    # facing or reverse
 },
 'changed-scan-option' => {
  param_types => [ 'Glib::Scalar', 'Glib::Scalar' ],    # name, value
 },
 'changed-option-visibility' => {
  param_types => ['Glib::Scalar'],    # array of options to hide
 },
 'changed-current-scan-options' => {
  param_types => ['Glib::Scalar'],    # profile array
 },
 'reloaded-scan-options' => {},
 'changed-profile'       => {
  param_types => ['Glib::Scalar'],    # name
 },
 'added-profile' => {
  param_types => [ 'Glib::Scalar', 'Glib::Scalar' ],    # name, profile array
 },
 'removed-profile' => {
  param_types => ['Glib::Scalar'],                      # name
 },
 'changed-paper' => {
  param_types => ['Glib::Scalar'],                      # name
 },
 'changed-paper-formats' => {
  param_types => ['Glib::Scalar'],                      # formats
 },
 'started-process' => {
  param_types => ['Glib::Scalar'],                      # message
 },
 'changed-progress' => {
  param_types => [ 'Glib::Scalar', 'Glib::Scalar' ],    # progress, message
 },
 'finished-process' => {
  param_types => ['Glib::String'],                      # process name
 },
 'process-error' => {
  param_types => [ 'Glib::String', 'Glib::String' ]
  ,    # process name, error message
 },
 show                  => \&show,
 'clicked-scan-button' => {},
  },
  properties => [
 Glib::ParamSpec->string(
  'device',                  # name
  'Device',                  # nick
  'Device name',             # blurb
  '',                        # default
  [qw/readable writable/]    # flags
 ),
 Glib::ParamSpec->scalar(
  'device-list',                             # name
  'Device list',                             # nick
  'Array of hashes of available devices',    # blurb
  [qw/readable writable/]                    # flags
 ),
 Glib::ParamSpec->scalar(
  'dir',                                     # name
  'Directory',                               # nick
  'Directory in which to store scans',       # blurb
  [qw/readable writable/]                    # flags
 ),
 Glib::ParamSpec->scalar(
  'logger',                                  # name
  'Logger',                                  # nick
  'Log::Log4perl::get_logger object',        # blurb
  [qw/readable writable/]                    # flags
 ),
 Glib::ParamSpec->scalar(
  'profile',                                 # name
  'Profile',                                 # nick
  'Name of current profile',                 # blurb
  [qw/readable writable/]                    # flags
 ),
 Glib::ParamSpec->string(
  'paper',                                      # name
  'Paper',                                      # nick
  'Name of currently selected paper format',    # blurb
  '',                                           # default
  [qw/readable writable/]                       # flags
 ),
 Glib::ParamSpec->scalar(
  'paper-formats',                                                   # name
  'Paper formats',                                                   # nick
  'Hash of arrays defining paper formats, e.g. A4, Letter, etc.',    # blurb
  [qw/readable writable/]                                            # flags
 ),
 Glib::ParamSpec->int(
  'num-pages',                        # name
  'Number of pages',                  # nickname
  'Number of pages to be scanned',    # blurb
  0,                                  # min 0 implies all
  999,                                # max
  1,                                  # default
  [qw/readable writable/]             # flags
 ),
 Glib::ParamSpec->int(
  'max-pages',                        # name
  'Maximum number of pages',          # nickname
'Maximum number of pages that can be scanned with current page-number-start and page-number-increment'
  ,                                   # blurb
  -1,                                 # min -1 implies all
  999,                                # max
  0,                                  # default
  [qw/readable writable/]             # flags
 ),
 Glib::ParamSpec->int(
  'page-number-start',                          # name
  'Starting page number',                       # nickname
  'Page number of first page to be scanned',    # blurb
  1,                                            # min
  999,                                          # max
  1,                                            # default
  [qw/readable writable/]                       # flags
 ),
 Glib::ParamSpec->int(
  'page-number-increment',                                           # name
  'Page number increment',                                           # nickname
  'Amount to increment page number when scanning multiple pages',    # blurb
  -99,                                                               # min
  99,                                                                # max
  1,                                                                 # default
  [qw/readable writable/]                                            # flags
 ),
 Glib::ParamSpec->enum(
  'side-to-scan',                                                    # name
  'Side to scan',                                                    # nickname
  'Either facing or reverse',                                        # blurb
  'Gscan2pdf::Scanner::Dialog::Side',                                # type
  'facing',                                                          # default
  [qw/readable writable/]                                            # flags
 ),
 Glib::ParamSpec->object(
  'available-scan-options',                                          # name
  'Scan options available',                                          # nickname
  'Scan options currently available, whether active, selected, or not',  # blurb
  'Gscan2pdf::Scanner::Options',    # package
  [qw/readable writable/]           # flags
 ),
 Glib::ParamSpec->scalar(
  'current-scan-options',                               # name
  'Current scan options',                               # nick
  'Array of scan options making up current profile',    # blurb
  [qw/readable writable/]                               # flags
 ),
 Glib::ParamSpec->scalar(
  'visible-scan-options',                                  # name
  'Visible scan options',                                  # nick
  'Hash of scan options to show or hide from the user',    # blurb
  [qw/readable writable/]                                  # flags
 ),
  ];

my ( $d, $d_sane, $logger );
my $tolerance = 1;

sub INIT_INSTANCE {
 my $self = shift;
 $d      = Locale::gettext->domain(Glib::get_application_name);
 $d_sane = Locale::gettext->domain('sane-backends');
 return $self;
}

sub SET_PROPERTY {
 my ( $self, $pspec, $newval ) = @_;
 my $name   = $pspec->get_name;
 my $oldval = $self->get($name);
 $self->{$name} = $newval;
 if (( defined($newval) and defined($oldval) and $newval ne $oldval )
  or ( defined($newval) xor defined($oldval) ) )
 {
  if ( defined $logger ) {
   $logger->debug(
    "Setting $name from "
      . (
     defined($oldval)
     ? ( ref($oldval) =~ /(?:HASH|ARRAY)/x ? Dumper($oldval) : $oldval )
     : 'undef'
      )
      . ' to '
      . (
     defined($newval)
     ? ( ref($newval) =~ /(?:HASH|ARRAY)/x ? Dumper($newval) : $newval )
     : 'undef'
      )
   );
  }
  given ($name) {
   when ('device') {
    $self->set_device($newval);
    $self->signal_emit( 'changed-device', $newval )
   }
   when ('device_list') {
    $self->set_device_list($newval);
    $self->signal_emit( 'changed-device-list', $newval )
   }
   when ('logger') { $logger = $self->get('logger') }
   when ('num_pages') { $self->signal_emit( 'changed-num-pages', $newval ) }
   when ('page_number_start') {
    $self->signal_emit( 'changed-page-number-start', $newval )
   }
   when ('page_number_increment') {
    $self->signal_emit( 'changed-page-number-increment', $newval )
   }
   when ('side_to_scan') {
    $self->signal_emit( 'changed-side-to-scan', $newval )
   }
   when ('paper') {
    set_combobox_by_text( $self->{combobp}, $newval );
    $self->signal_emit( 'changed-paper', $newval )
   }
   when ('paper_formats') {
    $self->set_paper_formats($newval);
    $self->signal_emit( 'changed-paper-formats', $newval )
   }
   when ('profile') {
    $self->set_profile($newval);
   }

   # This resets all options, so also clear the profile and current-scan-options
   # options, but without setting off their signals
   when ('available_scan_options') {
    $self->{profile}              = undef;
    $self->{current_scan_options} = undef;
    $self->signal_emit('reloaded-scan-options')
   }

   when ('current_scan_options') {
    $self->set_current_scan_options($newval)
   }
   when ('visible_scan_options') {
    $self->signal_emit( 'changed-option-visibility', $newval );
   }
   default {
    $self->SUPER::SET_PROPERTY( $pspec, $newval );
   }
  }
 }
 return;
}

sub show {
 my $self = shift;
 $self->signal_chain_from_overridden;
 $self->{framex}->hide_all;
 return;
}

# Get number of rows in combobox
sub num_rows_combobox {
 my ($combobox) = @_;
 my $i = -1;
 $combobox->get_model->foreach( sub { $i++; return FALSE } );
 return $i;
}

sub set_device {
 my ( $self, $device ) = @_;
 if ( defined($device) and $device ne '' ) {
  my $o;
  my $device_list = $self->get('device_list');
  if ( defined $device_list ) {
   for ( my $i = 0 ; $i < @$device_list ; $i++ ) {
    $o = $i if ( $device eq $device_list->[$i]{name} );
   }

   # Set the device dependent options after the number of pages
   #  to scan so that the source button callback can ghost the
   #  all button.
   # This then fires the callback, updating the options,
   #  so no need to do it further down.
   if ( defined $o ) {
    $self->{combobd}->set_active($o);
   }
   else {
    $self->signal_emit( 'process-error', 'open_device',
     sprintf( $d->get('Error: unknown device: %s'), $device ) );
   }
  }
 }
 return;
}

sub set_device_list {
 my ( $self, $device_list ) = @_;

 # Note any duplicate device names and delete if necessary
 my %seen;
 my $i = 0;
 while ( $i < @$device_list ) {
  $seen{ $device_list->[$i]{name} }++;
  if ( $seen{ $device_list->[$i]{name} } > 1 ) {
   splice @$device_list, $i, 1;
  }
  else {
   $i++;
  }
 }

 # Note any duplicate model names and add the device if necessary
 undef %seen;
 for (@$device_list) {
  $_->{model} = $_->{name} unless ( defined $_->{model} );
  $seen{ $_->{model} }++;
 }
 for (@$device_list) {
  if ( defined $_->{vendor} ) {
   $_->{label} = "$_->{vendor} $_->{model}";
  }
  else {
   $_->{label} = $_->{model};
  }
  $_->{label} .= " on $_->{name}" if ( $seen{ $_->{model} } > 1 );
 }

 $self->{combobd}->signal_handler_block( $self->{combobd_changed_signal} );

 # Remove all entries apart from rescan
 for ( my $j = get_combobox_num_items( $self->{combobd} ) ; $j > 1 ; $j-- ) {
  $self->{combobd}->remove_text(0);
 }

 # read the model names into the combobox
 for ( my $j = 0 ; $j < @$device_list ; $j++ ) {
  $self->{combobd}->insert_text( $j, $device_list->[$j]{label} );
 }

 $self->{combobd}->signal_handler_unblock( $self->{combobd_changed_signal} );
 return;
}

# Add paper size to combobox if scanner large enough

sub set_paper_formats {
 my ( $self, $formats ) = @_;
 $self->{ignored_paper_formats} = ();
 my $options = $self->get('available-scan-options');

 for ( keys %$formats ) {
  if ( defined( $self->{combobp} )
   and $options->supports_paper( $formats->{$_}, $tolerance ) )
  {
   $self->{combobp}->prepend_text($_);
  }
  else {
   push @{ $self->{ignored_paper_formats} }, $_;
  }
 }
 return;
}

# Paper editor
sub edit_paper {
 my ($self) = @_;

 my $combobp = $self->{combobp};
 my $options = $self->get('available-scan-options');
 my $formats = $self->get('paper-formats');

 my $window = Gscan2pdf::Dialog->new(
  'transient-for' => $self,
  title           => $d->get('Edit paper size'),
  border_width    => $self->get('border-width'),
 );
 my $vbox = $window->get('vbox');

 # Buttons for SimpleList
 my $hboxl = Gtk2::HBox->new;
 $vbox->pack_start( $hboxl, FALSE, FALSE, 0 );
 my $vboxb = Gtk2::VBox->new;
 $hboxl->pack_start( $vboxb, FALSE, FALSE, 0 );
 my $dbutton = Gtk2::Button->new_from_stock('gtk-add');
 $vboxb->pack_start( $dbutton, TRUE, FALSE, 0 );
 my $rbutton = Gtk2::Button->new_from_stock('gtk-remove');
 $vboxb->pack_end( $rbutton, TRUE, FALSE, 0 );

 # Set up a SimpleList
 my $slist = Gtk2::Ex::Simple::List->new(
  $d->get('Name')   => 'text',
  $d->get('Width')  => 'int',
  $d->get('Height') => 'int',
  $d->get('Left')   => 'int',
  $d->get('Top')    => 'int'
 );
 for ( keys %$formats ) {
  push @{ $slist->{data} },
    [
   $_,                $formats->{$_}{x}, $formats->{$_}{y},
   $formats->{$_}{l}, $formats->{$_}{t}
    ];
 }

 # Set everything to be editable
 for ( 0 .. 4 ) {
  $slist->set_column_editable( $_, TRUE );
 }
 $slist->get_column(0)->set_sort_column_id(0);

 # Add button callback
 $dbutton->signal_connect(
  clicked => sub {
   my @rows = $slist->get_selected_indices;
   $rows[0] = 0 if ( !@rows );
   my $name    = $slist->{data}[ $rows[0] ][0];
   my $version = 2;
   my $i       = 0;
   while ( $i < @{ $slist->{data} } ) {
    if ( $slist->{data}[$i][0] eq "$name ($version)" ) {
     ++$version;
     $i = 0;
    }
    else {
     ++$i;
    }
   }
   my @line = [
    "$name ($version)",
    $slist->{data}[ $rows[0] ][1],
    $slist->{data}[ $rows[0] ][2],
    $slist->{data}[ $rows[0] ][3],
    $slist->{data}[ $rows[0] ][4]
   ];
   splice @{ $slist->{data} }, $rows[0] + 1, 0, @line;
  }
 );

 # Remove button callback
 $rbutton->signal_connect(
  clicked => sub {
   my @rows = $slist->get_selected_indices;
   if ( $#rows == $#{ $slist->{data} } ) {
    main::show_message_dialog( $window, 'error', 'close',
     $d->get('Cannot delete all paper sizes') );
   }
   else {
    while (@rows) {
     splice @{ $slist->{data} }, shift(@rows), 1;
    }
   }
  }
 );

 # Set-up the callback to check that no two Names are the same
 $slist->get_model->signal_connect(
  'row-changed' => sub {
   my ( $model, $path, $iter ) = @_;
   for ( my $i = 0 ; $i < @{ $slist->{data} } ; $i++ ) {
    if ( $i != $path->to_string
     and $slist->{data}[ $path->to_string ][0] eq $slist->{data}[$i][0] )
    {
     my $name    = $slist->{data}[ $path->to_string ][0];
     my $version = 2;
     if (
      $name =~ /
                     (.*) # name
                     \ \( # space, opening bracket
                     (\d+) # version
                     \) # closing bracket
                   /x
       )
     {
      $name    = $1;
      $version = $2 + 1;
     }
     $slist->{data}[ $path->to_string ][0] = "$name ($version)";
     return;
    }
   }
  }
 );
 $hboxl->pack_end( $slist, FALSE, FALSE, 0 );

 # Buttons
 my $hboxb = Gtk2::HBox->new;
 $vbox->pack_start( $hboxb, FALSE, FALSE, 0 );
 my $abutton = Gtk2::Button->new_from_stock('gtk-apply');
 $abutton->signal_connect(
  clicked => sub {
   my %formats;
   for ( my $i = 0 ; $i < @{ $slist->{data} } ; $i++ ) {
    $formats{ $slist->{data}[$i][0] }{x} = $slist->{data}[$i][1];
    $formats{ $slist->{data}[$i][0] }{y} = $slist->{data}[$i][2];
    $formats{ $slist->{data}[$i][0] }{l} = $slist->{data}[$i][3];
    $formats{ $slist->{data}[$i][0] }{t} = $slist->{data}[$i][4];
   }

   # Remove all formats, leaving Manual and Edit
   $combobp->remove_text(0) while ( $combobp->get_active > 1 );

   # Add new definitions
   $self->set( 'paper-formats', \%formats );
   main::show_message_dialog(
    $window,
    'warning',
    'close',
    $d->get(
'The following paper sizes are too big to be scanned by the selected device:'
      )
      . ' '
      . join( ', ', @{ $self->{ignored_paper_formats} } )
     )
     if ( $self->{ignored_paper_formats}
    and @{ $self->{ignored_paper_formats} } );

   # Set the combobox back from Edit to the previous value
   set_combobox_by_text( $combobp, $self->get('paper') );

   $window->destroy;
  }
 );
 $hboxb->pack_start( $abutton, TRUE, FALSE, 0 );
 my $cbutton = Gtk2::Button->new_from_stock('gtk-cancel');
 $cbutton->signal_connect(
  clicked => sub {

   # Set the combobox back from Edit to the previous value
   set_combobox_by_text( $combobp, $self->get('paper') );

   $window->destroy;
  }
 );
 $hboxb->pack_end( $cbutton, TRUE, FALSE, 0 );
 $window->show_all;
 return;
}

sub add_profile {
 my ( $self, $name, $profile ) = @_;
 if ( defined($name) and defined($profile) ) {
  $self->{profiles}{$name} = ();
  if ( ref($profile) eq 'ARRAY' ) {
   for (@$profile) {
    push @{ $self->{profiles}{$name} }, $_;
   }
  }
  elsif ( ref($profile) eq 'HASH' ) {
   while ( my ( $key, $value ) = each(%$profile) ) {
    push @{ $self->{profiles}{$name} }, { $key => $value };
   }
  }
  $self->{combobsp}->append_text($name);
  $self->signal_emit( 'added-profile', $name, $self->{profiles}{$name} );
 }
 return;
}

sub set_profile {
 my ( $self, $name ) = @_;
 set_combobox_by_text( $self->{combobsp}, $name );
 if ( defined($name) and $name ne '' ) {

  # If we are setting the profile, don't unset the profile name
  $self->{setting_profile} = TRUE;

  # Only emit the changed-profile signal when the GUI has caught up
  my $signal;
  $signal = $self->signal_connect(
   'changed-current-scan-options' => sub {
    $self->{setting_profile} = FALSE;
    $self->signal_emit( 'changed-profile', $name );
    $self->signal_handler_disconnect($signal);
   }
  );

  $self->set( 'current-scan-options', $self->{profiles}{$name} );
 }

 # no need to wait - nothing to do
 else {
  $self->signal_emit( 'changed-profile', $name );
 }
 return;
}

# Remove the profile. If it is active, deselect it first.

sub remove_profile {
 my ( $self, $name ) = @_;
 if ( defined($name) and defined( $self->{profiles}{$name} ) ) {
  my $i = get_combobox_by_text( $self->{combobsp}, $name );
  if ( $i > -1 ) {
   $self->{combobsp}->set_active(-1) if ( $self->{combobsp}->get_active == $i );
   $self->{combobsp}->remove_text($i);
   $self->signal_emit( 'removed-profile', $name );
  }
 }
 return;
}

sub get_combobox_num_items {
 my ($combobox) = @_;
 return unless ( defined $combobox );
 my $i = 0;
 $combobox->get_model->foreach(
  sub {
   ++$i;
   return FALSE;    # continue the foreach()
  }
 );
 return $i;
}

sub get_combobox_by_text {
 my ( $combobox, $text ) = @_;
 return -1 unless ( defined($combobox) and defined($text) );
 my $o = -1;
 my $i = 0;
 $combobox->get_model->foreach(
  sub {
   my ( $model, $path, $iter ) = @_;
   if ( $model->get( $iter, 0 ) eq $text ) {
    $o = $i;
    return TRUE;    # found - stop the foreach()
   }
   else {
    ++$i;
    return FALSE;    # not found - continue the foreach()
   }
  }
 );
 return $o;
}

sub set_combobox_by_text {
 my ( $combobox, $text ) = @_;
 $combobox->set_active( get_combobox_by_text( $combobox, $text ) )
   if ( defined $combobox );
 return;
}

1;

__END__
