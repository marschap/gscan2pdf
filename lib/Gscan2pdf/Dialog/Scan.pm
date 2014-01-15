package Gscan2pdf::Dialog::Scan;

use warnings;
use strict;
use Glib qw(TRUE FALSE);   # To get TRUE and FALSE
use Sane 0.05;             # To get SANE_NAME_PAGE_WIDTH & SANE_NAME_PAGE_HEIGHT
use Gscan2pdf::Dialog;
use feature "switch";
use Data::Dumper;
my (
 $_MAX_PAGES,        $_MAX_INCREMENT, $_DOUBLE_INCREMENT,
 $_CANVAS_SIZE,      $_CANVAS_BORDER, $_CANVAS_POINT_SIZE,
 $_CANVAS_MIN_WIDTH, $_NO_INDEX,      $EMPTY
);

# need to register this with Glib before we can use it below
BEGIN {
 use Gscan2pdf::Scanner::Options;
 Glib::Type->register_enum( 'Gscan2pdf::Scanner::Dialog::Side',
  qw(facing reverse) );
 use Readonly;
 Readonly $_MAX_PAGES         => 999;
 Readonly $_MAX_INCREMENT     => 99;
 Readonly $_DOUBLE_INCREMENT  => 2;
 Readonly $_CANVAS_SIZE       => 200;
 Readonly $_CANVAS_BORDER     => 10;
 Readonly $_CANVAS_POINT_SIZE => 10;
 Readonly $_CANVAS_MIN_WIDTH  => 1;
 Readonly $_NO_INDEX          => -1;
 $EMPTY = q{};
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
  $EMPTY,                    # default
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
  $EMPTY,                                       # default
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
  $_MAX_PAGES,                        # max
  1,                                  # default
  [qw/readable writable/]             # flags
 ),
 Glib::ParamSpec->int(
  'max-pages',                        # name
  'Maximum number of pages',          # nickname
'Maximum number of pages that can be scanned with current page-number-start and page-number-increment'
  ,                                   # blurb
  -1,                                 # min -1 implies all
  $_MAX_PAGES,                        # max
  0,                                  # default
  [qw/readable writable/]             # flags
 ),
 Glib::ParamSpec->int(
  'page-number-start',                          # name
  'Starting page number',                       # nickname
  'Page number of first page to be scanned',    # blurb
  1,                                            # min
  $_MAX_PAGES,                                  # max
  1,                                            # default
  [qw/readable writable/]                       # flags
 ),
 Glib::ParamSpec->int(
  'page-number-increment',                                           # name
  'Page number increment',                                           # nickname
  'Amount to increment page number when scanning multiple pages',    # blurb
  -$_MAX_INCREMENT,                                                  # min
  $_MAX_INCREMENT,                                                   # max
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
 Glib::ParamSpec->float(
  'progress-pulse-step',                                   # name
  'Progress pulse step',                                   # nick
  'Pulse step of progress bar',                            # blurb
  0.0,                                                     # minimum
  1.0,                                                     # maximum
  0.1,                                                     # default_value
  [qw/readable writable/]                                  # flags
 ),
  ];

our $VERSION = '1.2.2';

my ( $d, $d_sane, $logger, $tooltips );
my $tolerance = 1;

sub INIT_INSTANCE {
 my $self = shift;

 my $vbox = $self->get('vbox');
 $tooltips = Gtk2::Tooltips->new;
 $tooltips->enable;

 $d      = Locale::gettext->domain(Glib::get_application_name);
 $d_sane = Locale::gettext->domain('sane-backends');

 # device list
 $self->{hboxd} = Gtk2::HBox->new;
 my $labeld = Gtk2::Label->new( $d->get('Device') );
 $self->{hboxd}->pack_start( $labeld, FALSE, FALSE, 0 );
 $self->{combobd} = Gtk2::ComboBox->new_text;
 $self->{combobd}->append_text( $d->get('Rescan for devices') );

 $self->{combobd_changed_signal} = $self->{combobd}->signal_connect(
  changed => sub {
   my $index       = $self->{combobd}->get_active;
   my $device_list = $self->get('device-list');
   if ( $index > $#{$device_list} ) {
    $self->{combobd}->hide;
    $labeld->hide;
    $self->set( 'device', undef );    # to make sure that the device is reloaded
    $self->get_devices;
   }
   elsif ( $index > $_NO_INDEX ) {
    $self->set( 'device', $device_list->[$index]{name} );
   }
  }
 );
 $self->signal_connect(
  'changed-device' => sub {
   my ( $widget, $device ) = @_;
   my $device_list = $self->get('device-list');
   for ( @{$device_list} ) {
    if ( $_->{name} eq $device ) {
     Gscan2pdf::Dialog::Scan::set_combobox_by_text( $self->{combobd},
      $_->{label} );
     $self->scan_options;
     return;
    }
   }
  }
 );
 $tooltips->set_tip( $self->{combobd},
  $d->get('Sets the device to be used for the scan') );
 $self->{hboxd}->pack_end( $self->{combobd}, FALSE, FALSE, 0 );
 $vbox->pack_start( $self->{hboxd}, FALSE, FALSE, 0 );

 # Notebook to collate options
 $self->{notebook} = Gtk2::Notebook->new;
 $vbox->pack_start( $self->{notebook}, TRUE, TRUE, 0 );

 # Notebook page 1
 my $vbox1 = Gtk2::VBox->new;
 $self->{vbox} = $vbox1;
 $self->{notebook}->append_page( $vbox1, $d->get('Page Options') );

 # Frame for # pages
 my $framen = Gtk2::Frame->new( $d->get('# Pages') );
 $vbox1->pack_start( $framen, FALSE, FALSE, 0 );
 my $vboxn        = Gtk2::VBox->new;
 my $border_width = $self->get('border_width');
 $vboxn->set_border_width($border_width);
 $framen->add($vboxn);

 #the first radio button has to set the group,
 #which is undef for the first button
 # All button
 my $bscanall = Gtk2::RadioButton->new( undef, $d->get('All') );
 $tooltips->set_tip( $bscanall, $d->get('Scan all pages') );
 $vboxn->pack_start( $bscanall, TRUE, TRUE, 0 );
 $bscanall->signal_connect(
  clicked => sub {
   if ( $bscanall->get_active ) { $self->set( 'num-pages', 0 ) }
  }
 );

 # Entry button
 my $hboxn = Gtk2::HBox->new;
 $vboxn->pack_start( $hboxn, TRUE, TRUE, 0 );
 my $bscannum = Gtk2::RadioButton->new( $bscanall->get_group, q{#:} );
 $tooltips->set_tip( $bscannum, $d->get('Set number of pages to scan') );
 $hboxn->pack_start( $bscannum, FALSE, FALSE, 0 );

 # Number of pages
 my $spin_buttonn = Gtk2::SpinButton->new_with_range( 1, $_MAX_PAGES, 1 );
 $tooltips->set_tip( $spin_buttonn, $d->get('Set number of pages to scan') );
 $hboxn->pack_end( $spin_buttonn, FALSE, FALSE, 0 );
 $bscannum->signal_connect(
  clicked => sub {
   if ( $bscannum->get_active ) {
    $self->set( 'num-pages', $spin_buttonn->get_value );
   }
  }
 );
 $self->signal_connect(
  'changed-num-pages' => sub {
   my ( $widget, $value ) = @_;
   if ( $value == 0 ) {
    $bscanall->set_active(TRUE);
   }
   else {
    $spin_buttonn->set_value($value);
   }
  }
 );

 # Actively set a radio button to synchronise GUI and properties
 if ( $self->get('num-pages') > 0 ) {
  $bscannum->set_active(TRUE);
 }
 else {
  $bscanall->set_active(TRUE);
 }

 # Toggle to switch between basic and extended modes
 my $checkx = Gtk2::CheckButton->new( $d->get('Extended page numbering') );
 $vbox1->pack_start( $checkx, FALSE, FALSE, 0 );

 # Frame for extended mode
 $self->{framex} = Gtk2::Frame->new( $d->get('Page number') );
 $vbox1->pack_start( $self->{framex}, FALSE, FALSE, 0 );
 my $vboxx = Gtk2::VBox->new;
 $vboxx->set_border_width($border_width);
 $self->{framex}->add($vboxx);

 # SpinButton for starting page number
 my $hboxxs = Gtk2::HBox->new;
 $vboxx->pack_start( $hboxxs, FALSE, FALSE, 0 );
 my $labelxs = Gtk2::Label->new( $d->get('Start') );
 $hboxxs->pack_start( $labelxs, FALSE, FALSE, 0 );
 my $spin_buttons = Gtk2::SpinButton->new_with_range( 1, $_MAX_PAGES, 1 );
 $hboxxs->pack_end( $spin_buttons, FALSE, FALSE, 0 );
 $spin_buttons->signal_connect(
  'value-changed' => sub {
   $self->set( 'page-number-start', $spin_buttons->get_value );
  }
 );
 $self->signal_connect(
  'changed-page-number-start' => sub {
   my ( $widget, $value ) = @_;
   $spin_buttons->set_value($value);
  }
 );

 # SpinButton for page number increment
 my $hboxi = Gtk2::HBox->new;
 $vboxx->pack_start( $hboxi, FALSE, FALSE, 0 );
 my $labelxi = Gtk2::Label->new( $d->get('Increment') );
 $hboxi->pack_start( $labelxi, FALSE, FALSE, 0 );
 my $spin_buttoni =
   Gtk2::SpinButton->new_with_range( -$_MAX_INCREMENT, $_MAX_INCREMENT, 1 );
 $spin_buttoni->set_value( $self->get('page-number-increment') );
 $hboxi->pack_end( $spin_buttoni, FALSE, FALSE, 0 );
 $spin_buttoni->signal_connect(
  'value-changed' => sub {
   my $value = $spin_buttoni->get_value;
   if ( $value == 0 ) { $value = -$self->get('page-number-increment') }
   $spin_buttoni->set_value($value);
   $self->set( 'page-number-increment', $value );
  }
 );
 $self->signal_connect(
  'changed-page-number-increment' => sub {
   my ( $widget, $value ) = @_;
   $spin_buttoni->set_value($value);
  }
 );

 # Setting this here to fire callback running update_start
 $spin_buttons->set_value( $self->get('page-number-start') );

 # Callback on changing number of pages
 $spin_buttonn->signal_connect(
  'value-changed' => sub {
   $self->set( 'num-pages', $spin_buttonn->get_value );
   $bscannum->set_active(TRUE);    # Set the radiobutton active
  }
 );

 # Frame for standard mode
 my $frames = Gtk2::Frame->new( $d->get('Source document') );
 $vbox1->pack_start( $frames, FALSE, FALSE, 0 );
 my $vboxs = Gtk2::VBox->new;
 $vboxs->set_border_width($border_width);
 $frames->add($vboxs);

 # Single sided button
 my $buttons = Gtk2::RadioButton->new( undef, $d->get('Single sided') );
 $tooltips->set_tip( $buttons, $d->get('Source document is single-sided') );
 $vboxs->pack_start( $buttons, TRUE, TRUE, 0 );
 $buttons->signal_connect(
  clicked => sub {
   $spin_buttoni->set_value(1);
  }
 );

 # Double sided button
 my $buttond =
   Gtk2::RadioButton->new( $buttons->get_group, $d->get('Double sided') );
 $tooltips->set_tip( $buttond, $d->get('Source document is double-sided') );
 $vboxs->pack_start( $buttond, FALSE, FALSE, 0 );

 # Facing/reverse page button
 my $hboxs = Gtk2::HBox->new;
 $vboxs->pack_start( $hboxs, TRUE, TRUE, 0 );
 my $labels = Gtk2::Label->new( $d->get('Side to scan') );
 $hboxs->pack_start( $labels, FALSE, FALSE, 0 );

 my $combobs = Gtk2::ComboBox->new_text;
 for ( ( $d->get('Facing'), $d->get('Reverse') ) ) {
  $combobs->append_text($_);
 }
 $combobs->signal_connect(
  changed => sub {
   $buttond->set_active(TRUE);    # Set the radiobutton active
   $self->set( 'side-to-scan',
    $combobs->get_active == 0 ? 'facing' : 'reverse' );
  }
 );
 $self->signal_connect(
  'changed-side-to-scan' => sub {
   my ( $widget, $value ) = @_;
   $self->set( 'page-number-increment',
    $value eq 'facing' ? $_DOUBLE_INCREMENT : -$_DOUBLE_INCREMENT );
  }
 );
 $tooltips->set_tip( $combobs,
  $d->get('Sets which side of a double-sided document is scanned') );
 $combobs->set_active(0);

 # Have to do this here because setting the facing combobox switches it
 $buttons->set_active(TRUE);
 $hboxs->pack_end( $combobs, FALSE, FALSE, 0 );

 # Have to put the double-sided callback here to reference page side
 $buttond->signal_connect(
  clicked => sub {
   $spin_buttoni->set_value(
    $combobs->get_active == 0 ? $_DOUBLE_INCREMENT : -$_DOUBLE_INCREMENT );
  }
 );

# Have to put the extended pagenumber checkbox here to reference simple controls
 $checkx->signal_connect(
  toggled => \&_extended_pagenumber_checkbox_callback,
  [ $self, $frames, $spin_buttoni, $buttons, $buttond, $combobs ]
 );

 # Scan profiles
 my $framesp = Gtk2::Frame->new( $d->get('Scan profiles') );
 $vbox1->pack_start( $framesp, FALSE, FALSE, 0 );
 my $vboxsp = Gtk2::VBox->new;
 $vboxsp->set_border_width($border_width);
 $framesp->add($vboxsp);
 $self->{combobsp} = Gtk2::ComboBox->new_text;
 $self->{combobsp}->signal_connect(
  changed => sub {
   my $profile = $self->{combobsp}->get_active_text;
   if ( defined $profile ) { $self->set( 'profile', $profile ) }
  }
 );
 $vboxsp->pack_start( $self->{combobsp}, FALSE, FALSE, 0 );
 my $hboxsp = Gtk2::HBox->new;
 $vboxsp->pack_end( $hboxsp, FALSE, FALSE, 0 );

 # Save button
 my $vbutton = Gtk2::Button->new_from_stock('gtk-save');
 $vbutton->signal_connect(
  clicked => sub {
   my $dialog = Gtk2::Dialog->new(
    $d->get('Name of scan profile'), $self,
    'destroy-with-parent',
    'gtk-save'   => 'ok',
    'gtk-cancel' => 'cancel'
   );
   my $hbox  = Gtk2::HBox->new;
   my $label = Gtk2::Label->new( $d->get('Name of scan profile') );
   $hbox->pack_start( $label, FALSE, FALSE, 0 );
   my $entry = Gtk2::Entry->new;
   $entry->set_activates_default(TRUE);
   $hbox->pack_end( $entry, TRUE, TRUE, 0 );
   $dialog->vbox->add($hbox);
   $dialog->set_default_response('ok');
   $dialog->show_all;

   if ( $dialog->run eq 'ok' and $entry->get_text !~ /^\s*$/xsm ) {
    my $profile = $entry->get_text;
    $self->add_profile( $profile, $self->get('current-scan-options') );
    $self->{combobsp}
      ->set_active( get_combobox_num_rows( $self->{combobsp} ) - 1 );
   }
   $dialog->destroy;
  }
 );
 $hboxsp->pack_start( $vbutton, TRUE, TRUE, 0 );

 # Delete button
 my $dbutton = Gtk2::Button->new_from_stock('gtk-delete');
 $dbutton->signal_connect(
  clicked => sub {
   $self->remove_profile( $self->{combobsp}->get_active_text );
  }
 );
 $hboxsp->pack_start( $dbutton, FALSE, FALSE, 0 );

 # HBox for buttons
 my $hboxb = Gtk2::HBox->new;
 $vbox->pack_end( $hboxb, FALSE, FALSE, 0 );

 # Scan button
 $self->{sbutton} = Gtk2::Button->new( $d->get('Scan') );
 $hboxb->pack_start( $self->{sbutton}, TRUE, TRUE, 0 );
 $self->{sbutton}->signal_connect(
  clicked => sub {
   $self->signal_emit('clicked-scan-button');
   $self->scan;
  }
 );
 $self->{sbutton}->grab_focus;

 # Cancel button
 my $cbutton = Gtk2::Button->new_from_stock('gtk-close');
 $hboxb->pack_end( $cbutton, FALSE, FALSE, 0 );
 $cbutton->signal_connect( clicked => sub { $self->hide; } );

 $self->signal_connect(
  check_resize => sub {
   Glib::Idle->add( sub { $self->resize( 1, 1 ); } );
  }
 );
 return $self;
}

sub SET_PROPERTY {
 my ( $self, $pspec, $newval ) = @_;
 my $name   = $pspec->get_name;
 my $oldval = $self->get($name);
 $self->{$name} = $newval;

 # Have to set logger separately as it has already been set in the subclassed
 # widget
 if ( $name eq 'logger' ) {
  $logger = $newval;
  $logger->debug('Set logger in Gscan2pdf::Dialog::Scan');
 }
 elsif ( ( defined($newval) and defined($oldval) and $newval ne $oldval )
  or ( defined($newval) xor defined($oldval) ) )
 {
  if ( defined $logger ) {
   $logger->debug(
    "Setting $name from "
      . (
     defined($oldval)
     ? ( ref($oldval) =~ /(?:HASH|ARRAY)/xsm ? Dumper($oldval) : $oldval )
     : 'undef'
      )
      . ' to '
      . (
     defined($newval)
     ? ( ref($newval) =~ /(?:HASH|ARRAY)/xsm ? Dumper($newval) : $newval )
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
 if ( $self->{combobp}->get_active_text ne $d->get('Manual') ) {
  $self->hide_geometry( $self->get('available-scan-options') );
 }
 return;
}

sub set_device {
 my ( $self, $device ) = @_;
 if ( defined($device) and $device ne $EMPTY ) {
  my $o;
  my $device_list = $self->get('device_list');
  if ( defined $device_list ) {
   for ( 0 .. $#{$device_list} ) {
    if ( $device eq $device_list->[$_]{name} ) { $o = $_ }
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
 while ( $i < @{$device_list} ) {
  $seen{ $device_list->[$i]{name} }++;
  if ( $seen{ $device_list->[$i]{name} } > 1 ) {
   splice @{$device_list}, $i, 1;
  }
  else {
   $i++;
  }
 }

 # Note any duplicate model names and add the device if necessary
 undef %seen;
 for ( @{$device_list} ) {
  if ( not defined( $_->{model} ) ) { $_->{model} = $_->{name} }
  $seen{ $_->{model} }++;
 }
 for ( @{$device_list} ) {
  if ( defined $_->{vendor} ) {
   $_->{label} = "$_->{vendor} $_->{model}";
  }
  else {
   $_->{label} = $_->{model};
  }
  if ( $seen{ $_->{model} } > 1 ) { $_->{label} .= " on $_->{name}" }
 }

 $self->{combobd}->signal_handler_block( $self->{combobd_changed_signal} );

 # Remove all entries apart from rescan
 for ( get_combobox_num_rows( $self->{combobd} ) .. 2 ) {
  $self->{combobd}->remove_text(0);
 }

 # read the model names into the combobox
 for ( 0 .. $#{$device_list} ) {
  $self->{combobd}->insert_text( $_, $device_list->[$_]{label} );
 }

 $self->{combobd}->signal_handler_unblock( $self->{combobd_changed_signal} );
 return;
}

sub pack_widget {
 my ( $self, $widget, $data ) = @_;
 my ( $options, $opt, $hbox, $hboxp ) = @{$data};
 if ( defined $widget ) {
  $opt->{widget} = $widget;
  if ( $opt->{type} == SANE_TYPE_BUTTON or $opt->{max_values} > 1 ) {
   $hbox->pack_end( $widget, TRUE, TRUE, 0 );
  }
  else {
   $hbox->pack_end( $widget, FALSE, FALSE, 0 );
  }
  $tooltips->set_tip( $widget, $d_sane->get( $opt->{desc} ) );

  # Look-up to hide/show the box if necessary
  if ( $self->_geometry_option($opt) ) {
   $options->{box}{ $opt->{name} } = $hbox;
  }

  $self->create_paper_widget( $options, $hboxp );

 }
 else {
  $logger->warn("Unknown type $opt->{type}");
 }
 return;
}

# Add paper size to combobox if scanner large enough

sub set_paper_formats {
 my ( $self, $formats ) = @_;
 $self->{ignored_paper_formats} = ();
 my $options = $self->get('available-scan-options');

 for ( keys %{$formats} ) {
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
 for ( keys %{$formats} ) {
  push @{ $slist->{data} },
    [
   $_,                $formats->{$_}{x}, $formats->{$_}{y},
   $formats->{$_}{l}, $formats->{$_}{t}
    ];
 }

 # Set everything to be editable
 my @columns = $slist->get_columns;
 for ( 0 .. $#columns ) {
  $slist->set_column_editable( $_, TRUE );
 }
 $slist->get_column(0)->set_sort_column_id(0);

 # Add button callback
 $dbutton->signal_connect(
  clicked => sub {
   my @rows = $slist->get_selected_indices;
   if ( not @rows ) { $rows[0] = 0 }
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
   my @line = ("$name ($version)");
   for ( 1 .. $#{ $slist->get_columns } ) {
    push @line, $slist->{data}[ $rows[0] ][$_];
   }
   splice @{ $slist->{data} }, $rows[0] + 1, 0, \@line;
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
   for ( 0 .. $#{ $slist->{data} } ) {
    if ( $_ != $path->to_string
     and $slist->{data}[ $path->to_string ][0] eq $slist->{data}[$_][0] )
    {
     my $name    = $slist->{data}[ $path->to_string ][0];
     my $version = 2;
     if (
      $name =~ /
                     (.*) # name
                     \ \( # space, opening bracket
                     (\d+) # version
                     \) # closing bracket
                   /xsm
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
   for my $i ( 0 .. $#{ $slist->{data} } ) {
    my $j = 0;
    for (qw( x y l t)) {
     $formats{ $slist->{data}[$i][0] }{$_} = $slist->{data}[$i][ ++$j ];
    }
   }

   # Remove all formats, leaving Manual and Edit
   while ( $combobp->get_active > 1 ) { $combobp->remove_text(0) }

   # Add new definitions
   $self->set( 'paper-formats', \%formats );
   if ( $self->{ignored_paper_formats}
    and @{ $self->{ignored_paper_formats} } )
   {
    main::show_message_dialog(
     $window,
     'warning',
     'close',
     $d->get(
'The following paper sizes are too big to be scanned by the selected device:'
       )
       . q{ }
       . join( ', ', @{ $self->{ignored_paper_formats} } )
    );
   }

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
   for ( @{$profile} ) {
    push @{ $self->{profiles}{$name} }, $_;
   }
  }
  elsif ( ref($profile) eq 'HASH' ) {
   while ( my ( $key, $value ) = each( %{$profile} ) ) {
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
 if ( defined($name) and $name ne $EMPTY ) {

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
  if ( $i > $_NO_INDEX ) {
   if ( $self->{combobsp}->get_active == $i ) {
    $self->{combobsp}->set_active($_NO_INDEX);
   }
   $self->{combobsp}->remove_text($i);
   $self->signal_emit( 'removed-profile', $name );
  }
 }
 return;
}

sub get_combobox_num_rows {
 my ($combobox) = @_;
 if ( not defined($combobox) ) { return }
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
 if ( not( defined($combobox) and defined($text) ) ) { return $_NO_INDEX }
 my $o = $_NO_INDEX;
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
 if ( defined $combobox ) {
  $combobox->set_active( get_combobox_by_text( $combobox, $text ) );
 }
 return;
}

sub _extended_pagenumber_checkbox_callback {
 my ( $widget, $data ) = @_;
 my ( $dialog, $frames, $spin_buttoni, $buttons, $buttond, $combobs ) =
   @{$data};
 if ( $widget->get_active ) {
  $frames->hide_all;
  $dialog->{framex}->show_all;
 }
 else {
  if ( $spin_buttoni->get_value == 1 ) {
   $buttons->set_active(TRUE);
  }
  elsif ( $spin_buttoni->get_value > 0 ) {
   $buttond->set_active(TRUE);
   $combobs->set_active(0);
  }
  else {
   $buttond->set_active(TRUE);
   $combobs->set_active(1);
  }
  $frames->show_all;
  $dialog->{framex}->hide_all;
 }
 return;
}

sub multiple_values_button_callback {
 my ( $widget, $data ) = @_;
 my ( $dialog, $opt )  = @{$data};
 if ($opt->{type} == SANE_TYPE_FIXED
  or $opt->{type} == SANE_TYPE_INT )
 {
  if ( $opt->{constraint_type} == SANE_CONSTRAINT_NONE ) {
   main::show_message_dialog(
    $dialog, 'info', 'close',
    $d->get(
'Multiple unconstrained values are not currently supported. Please file a bug.'
    )
   );
  }
  else {
   $dialog->set_options($opt);
  }
 }
 else {
  main::show_message_dialog(
   $dialog, 'info', 'close',
   $d->get(
'Multiple non-numerical values are not currently supported. Please file a bug.'
   )
  );
 }
 return;
}

sub value_for_active_option {
 my ( $self, $value, $opt ) = @_;
 return defined $value and not $opt->{cap} & SANE_CAP_INACTIVE;
}

# display Goo::Canvas with graph

sub set_options {
 my ( $self, $opt ) = @_;

 # Set up the canvas
 my $window = Gscan2pdf::Dialog->new(
  'transient-for' => $self,
  title           => $d_sane->get( $opt->{title} ),
  destroy         => TRUE,
  border_width    => $self->get('border_width'),
 );
 my $vbox   = $window->vbox;
 my $canvas = Goo::Canvas->new;
 $canvas->set_size_request( $_CANVAS_SIZE, $_CANVAS_SIZE );
 $canvas->{border} = $_CANVAS_BORDER;
 $vbox->add($canvas);
 my $root = $canvas->get_root_item;

 $canvas->signal_connect(
  'button-press-event' => sub {
   my ( $widget, $event ) = @_;
   if ( defined $widget->{selected} ) {
    $widget->{selected}->set( 'fill-color' => 'black' );
    undef $widget->{selected};
   }
   return FALSE
     if ( $#{ $widget->{val} } + 1 >= $opt->{max_values}
    or $widget->{on_val} );
   my $fleur = Gtk2::Gdk::Cursor->new('fleur');
   my ( $x, $y ) = to_graph( $widget, $event->x, $event->y );
   $x = int($x) + 1;
   splice @{ $widget->{val} }, $x, 0, $y;
   splice @{ $widget->{items} }, $x, 0, add_value( $root, $widget );
   update_graph($widget);
   return TRUE;
  }
 );

 $canvas->signal_connect_after(
  'key_press_event',
  sub {
   my ( $widget, $event ) = @_;
   if (
    $event->keyval ==
    $Gtk2::Gdk::Keysyms{Delete}    ## no critic (ProhibitPackageVars)
    and defined $widget->{selected}
     )
   {
    my $item = $widget->{selected};
    undef $widget->{selected};
    $widget->{on_val} = FALSE;
    splice @{ $widget->{val} },   $item->{index}, 1;
    splice @{ $widget->{items} }, $item->{index}, 1;
    my $parent = $item->get_parent;
    my $num    = $parent->find_child($item);
    $parent->remove_child($num);
    update_graph($widget);
   }
   return FALSE;
  }
 );
 $canvas->can_focus(TRUE);
 $canvas->grab_focus($root);

 $canvas->{opt} = $opt;

 $canvas->{val} = $canvas->{opt}->{val};
 for ( @{ $canvas->{val} } ) {
  push @{ $canvas->{items} }, add_value( $root, $canvas );
 }

 if ( $opt->{constraint_type} == SANE_CONSTRAINT_WORD_LIST ) {
  @{ $opt->{constraint} } = sort { $a <=> $b } @{ $opt->{constraint} };
 }

 # HBox for buttons
 my $hbox = Gtk2::HBox->new;
 $vbox->pack_start( $hbox, FALSE, TRUE, 0 );

 # Apply button
 my $abutton = Gtk2::Button->new_from_stock('gtk-apply');
 $hbox->pack_start( $abutton, TRUE, TRUE, 0 );
 $abutton->signal_connect(
  clicked => sub {
   $self->set_option( $opt, $canvas->{val} );

 # when INFO_INEXACT is implemented, so that the value is reloaded, check for it
 # here, so that the reloaded value is not overwritten.
   $opt->{val} = $canvas->{val};
   $window->destroy;
  }
 );

 # Cancel button
 my $cbutton = Gtk2::Button->new_from_stock('gtk-cancel');
 $hbox->pack_end( $cbutton, FALSE, FALSE, 0 );
 $cbutton->signal_connect( clicked => sub { $window->destroy } );

# Have to show the window before updating it otherwise is doesn't know how big it is
 $window->show_all;
 update_graph($canvas);
 return;
}

sub add_value {
 my ( $root, $canvas ) = @_;
 my $item = Goo::Canvas::Rect->new(
  $root, 0, 0, $_CANVAS_POINT_SIZE, $_CANVAS_POINT_SIZE,
  'fill-color' => 'black',
  'line-width' => 0,
 );
 $item->signal_connect(
  'enter-notify-event' => sub {
   $canvas->{on_val} = TRUE;
   return TRUE;
  }
 );
 $item->signal_connect(
  'leave-notify-event' => sub {
   $canvas->{on_val} = FALSE;
   return TRUE;
  }
 );
 $item->signal_connect(
  'button-press-event' => sub {
   my ( $widget, $target, $ev ) = @_;
   $canvas->{selected} = $item;
   $item->set( 'fill-color' => 'red' );
   my $fleur = Gtk2::Gdk::Cursor->new('fleur');
   $widget->get_canvas->pointer_grab( $widget,
    [ 'pointer-motion-mask', 'button-release-mask' ],
    $fleur, $ev->time );
   return TRUE;
  }
 );
 $item->signal_connect(
  'button-release-event' => sub {
   my ( $widget, $target, $ev ) = @_;
   $widget->get_canvas->pointer_ungrab( $widget, $ev->time );
   return TRUE;
  }
 );
 my $opt = $canvas->{opt};
 $item->signal_connect(
  'motion-notify-event' => sub {
   my ( $widget, $target, $event ) = @_;
   if (
    not(
     $event->state >=    ## no critic (ProhibitMismatchedOperators)
     'button1-mask'
    )
     )
   {
    return FALSE;
   }

   my ( $x, $y ) = ( $event->x, $event->y );
   my ( $xgr, $ygr ) = ( 0, $y );
   if ( $opt->{constraint_type} == SANE_CONSTRAINT_RANGE ) {
    ( $xgr, $ygr ) = to_graph( $canvas, 0, $y );
    if ( $ygr > $opt->{constraint}{max} ) {
     $ygr = $opt->{constraint}{max};
    }
    elsif ( $ygr < $opt->{constraint}{min} ) {
     $ygr = $opt->{constraint}{min};
    }
   }
   elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_WORD_LIST ) {
    ( $xgr, $ygr ) = to_graph( $canvas, 0, $y );
    for ( 1 .. $#{ $opt->{constraint} } ) {
     if ( $ygr < ( $opt->{constraint}[$_] + $opt->{constraint}[ $_ - 1 ] ) / 2 )
     {
      $ygr = $opt->{constraint}[ $_ - 1 ];
      last;
     }
     elsif ( $_ == $#{ $opt->{constraint} } ) {
      $ygr = $opt->{constraint}[$_];
     }
    }
   }
   $canvas->{val}[ $widget->{index} ] = $ygr;
   ( $x, $y ) = to_canvas( $canvas, $xgr, $ygr );
   $widget->set( y => $y - $_CANVAS_POINT_SIZE / 2 );
   return TRUE;
  }
 );
 return $item;
}

# convert from graph co-ordinates to canvas co-ordinates

sub to_canvas {
 my ( $canvas, $x, $y ) = @_;
 return ( $x - $canvas->{bounds}[0] ) * $canvas->{scale}[0] + $canvas->{border},
   $canvas->{cheight} -
   ( $y - $canvas->{bounds}[1] ) * $canvas->{scale}[1] -
   $canvas->{border};
}

# convert from canvas co-ordinates to graph co-ordinates

sub to_graph {
 my ( $canvas, $x, $y ) = @_;
 return ( $x - $canvas->{border} ) / $canvas->{scale}[0] + $canvas->{bounds}[0],
   ( $canvas->{cheight} - $y - $canvas->{border} ) / $canvas->{scale}[1] +
   $canvas->{bounds}[1];
}

sub update_graph {
 my ($canvas) = @_;

 # Calculate bounds of graph
 my ( @xbounds, @ybounds );
 for ( @{ $canvas->{val} } ) {
  if ( not defined $ybounds[0] or $_ < $ybounds[0] ) { $ybounds[0] = $_ }
  if ( not defined $ybounds[1] or $_ > $ybounds[1] ) { $ybounds[1] = $_ }
 }
 my $opt = $canvas->{opt};
 $xbounds[0] = 0;
 $xbounds[1] = $#{ $canvas->{val} };
 if ( $xbounds[0] >= $xbounds[1] ) {
  $xbounds[0] = -$_CANVAS_MIN_WIDTH / 2;
  $xbounds[1] = $_CANVAS_MIN_WIDTH / 2;
 }
 if ( $opt->{constraint_type} == SANE_CONSTRAINT_RANGE ) {
  $ybounds[0] = $opt->{constraint}{min};
  $ybounds[1] = $opt->{constraint}{max};
 }
 elsif ( $opt->{constraint_type} == SANE_CONSTRAINT_WORD_LIST ) {
  $ybounds[0] = $opt->{constraint}[0];
  $ybounds[1] = $opt->{constraint}[ $#{ $opt->{constraint} } ];
 }
 my ( $vwidth, $vheight ) =
   ( $xbounds[1] - $xbounds[0], $ybounds[1] - $ybounds[0] );

 # Calculate bounds of canvas
 my ( $x, $y, $cwidth, $cheight ) = $canvas->allocation->values;

 # Calculate scale factors
 my @scale = (
  ( $cwidth - $canvas->{border} * 2 ) / $vwidth,
  ( $cheight - $canvas->{border} * 2 ) / $vheight
 );

 $canvas->{scale}   = \@scale;
 $canvas->{bounds}  = [ $xbounds[0], $ybounds[0], $xbounds[1], $xbounds[1] ];
 $canvas->{cheight} = $cheight;

 # Update canvas
 for ( 0 .. $#{ $canvas->{items} } ) {
  my $item = $canvas->{items}[$_];
  $item->{index} = $_;
  my ( $xc, $yc ) = to_canvas( $canvas, $_, $canvas->{val}[$_] );
  $item->set( x => $xc - $_CANVAS_BORDER / 2, y => $yc - $_CANVAS_BORDER / 2 );
 }
 return;
}

# roll my own Data::Dumper to walk the reference tree without printing the results

sub my_dumper {
 my ($ref) = @_;
 given ( ref $ref ) {
  when ('ARRAY') {
   for ( @{$ref} ) {
    my_dumper($_);
   }
  }
  when ('HASH') {
   while ( my ( $key, $val ) = each( %{$ref} ) ) {
    my_dumper($val);
   }
  }
 }
 return;
}

# Helper sub to reduce code duplication

sub set_option_emit_signal {
 my ( $self, $i, $defaults, $signal1, $signal2 ) = @_;
 if ( $i < @{$defaults} ) { $i = $self->set_option_widget( $i, $defaults ) }

 # Only emit the changed-current-scan-options signal when we have finished
 if ( ( not defined($i) or $i > $#{$defaults} )
  and $self->signal_handler_is_connected($signal1)
  and $self->signal_handler_is_connected($signal2) )
 {
  $self->signal_handler_disconnect($signal1);
  $self->signal_handler_disconnect($signal2);
  if ( not $self->{setting_profile} ) { $self->set( 'profile', undef ) }
  $self->signal_emit( 'changed-current-scan-options',
   $self->get('current-scan-options') );
 }
 return $i;
}

# Extract a option value from a profile

sub get_option_from_profile {
 my ( $self, $name, $profile ) = @_;

 # for reasons I don't understand, without walking the reference tree,
 # parts of $profile are undef
 my_dumper($profile);
 for ( @{$profile} ) {
  my ( $key, $val ) = each( %{$_} );
  return $val if ( $key eq $name );
 }
 return;
}

sub make_progress_string {
 my ( $i, $npages ) = @_;
 return sprintf $d->get("Scanning page %d of %d"), $i, $npages
   if ( $npages > 0 );
 return sprintf $d->get("Scanning page %d"), $i;
}

1;

__END__
